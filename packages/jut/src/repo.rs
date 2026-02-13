//! Repository operations.
//!
//! Read operations are handled directly by jj-lib. Write operations are also
//! migrated to jj-lib transactions, with minimal jj CLI calls used only for:
//! - working-copy snapshotting before mutations
//! - synchronizing stale working copies after mutations
//! - resolving user revset strings to commit IDs

use std::collections::HashMap;
use std::io;
use std::path::{Path, PathBuf};
use std::sync::Arc;

use anyhow::{Context, Result, bail};
use futures_util::StreamExt as _;
use jj_lib::absorb::{AbsorbSource, absorb_hunks, split_hunks_to_trees};
use jj_lib::backend::{ChangeId, CommitId};
use jj_lib::commit::Commit;
use jj_lib::config::{ConfigLayer, ConfigSource, StackedConfig};
use jj_lib::git::{
    self, GitBranchPushTargets, GitFetch, GitFetchRefExpression, GitImportOptions, GitSettings,
    GitProgress, GitSidebandLineTerminator, GitSubprocessCallback, expand_fetch_refspecs,
    load_default_fetch_bookmarks,
};
use jj_lib::matchers::{EverythingMatcher, PrefixMatcher};
use jj_lib::object_id::ObjectId;
use jj_lib::op_store::OperationId;
use jj_lib::ref_name::{RemoteName, WorkspaceName};
use jj_lib::refs::{BookmarkPushAction, classify_bookmark_push_action};
use jj_lib::repo::{ReadonlyRepo, Repo as RepoTrait};
use jj_lib::repo_path::RepoPathBuf;
use jj_lib::rewrite::{CommitWithSelection, restore_tree, squash_commits};
use jj_lib::settings::UserSettings;
use jj_lib::str_util::StringExpression;
use jj_lib::workspace::{Workspace, default_working_copy_factories};
use pollster::FutureExt as _;

const UNDO_OP_DESC_PREFIX: &str = "undo: restore to operation ";

#[derive(Debug, Clone)]
pub struct GitFetchReport {
    pub remotes: Vec<String>,
    pub imported_refs: usize,
}

#[derive(Debug, Clone)]
pub struct GitPushReport {
    pub remote: String,
    pub pushed_refs: Vec<String>,
}

#[derive(Debug, Clone)]
pub struct AbsorbReport {
    pub target_commits: usize,
    pub rewritten_destinations: usize,
    pub rebased_descendants: usize,
    pub skipped_paths: Vec<(String, String)>,
}

struct NullGitCallback;

impl GitSubprocessCallback for NullGitCallback {
    fn needs_progress(&self) -> bool {
        false
    }

    fn progress(&mut self, _progress: &GitProgress) -> io::Result<()> {
        Ok(())
    }

    fn local_sideband(
        &mut self,
        _message: &[u8],
        _term: Option<GitSidebandLineTerminator>,
    ) -> io::Result<()> {
        Ok(())
    }

    fn remote_sideband(
        &mut self,
        _message: &[u8],
        _term: Option<GitSidebandLineTerminator>,
    ) -> io::Result<()> {
        Ok(())
    }
}

/// High-level repo handle with both jj-lib and CLI access.
pub struct Repo {
    root: PathBuf,
    settings: UserSettings,
    inner: Arc<ReadonlyRepo>,
}

impl Repo {
    /// Open a jj repo from a path using jj-lib.
    pub fn open(start: &Path) -> Result<Self> {
        let workspace_path = find_workspace_root(start)?;

        let config = load_jj_config()?;
        let settings = UserSettings::from_config(config).context("failed to create jj settings")?;

        let repo = load_repo_at_head(&settings, &workspace_path)?;

        Ok(Self {
            root: workspace_path,
            settings,
            inner: repo,
        })
    }

    pub fn root(&self) -> &Path {
        &self.root
    }

    /// Get the underlying ReadonlyRepo.
    #[allow(dead_code)]
    pub fn jj_repo(&self) -> &Arc<ReadonlyRepo> {
        &self.inner
    }

    /// Get current working copy change ID as reverse-hex string (matching jj's display).
    pub fn current_change_id(&self) -> Result<String> {
        let commit = self.working_copy_commit(&self.inner)?;
        Ok(jj_lib::hex_util::encode_reverse_hex(
            &commit.change_id().as_bytes(),
        ))
    }

    /// Get the shortest unique prefix for a change ID (reverse-hex string).
    pub fn shortest_change_id_prefix(&self, change_id_reverse_hex: &str) -> Result<String> {
        let bytes = jj_lib::hex_util::decode_reverse_hex(change_id_reverse_hex)
            .context("invalid change id")?;
        let change_id = ChangeId::from_bytes(&bytes);
        let len = self
            .inner
            .shortest_unique_change_id_prefix_len(&change_id)
            .map_err(|e| anyhow::anyhow!("index error: {e}"))?;
        let len = len.max(4);
        Ok(change_id_reverse_hex[..len.min(change_id_reverse_hex.len())].to_string())
    }

    /// Get local bookmarks as (name, change_id_reverse_hex) pairs.
    pub fn bookmarks(&self) -> Result<Vec<(String, String)>> {
        let view = self.inner.view();
        let mut result = Vec::new();
        for (name, target) in view.local_bookmarks() {
            if let Some(commit_id) = target.as_normal() {
                let commit = self
                    .inner
                    .store()
                    .get_commit(commit_id)
                    .map_err(|e| anyhow::anyhow!("failed to get bookmark commit: {e}"))?;
                let change_id_rhex =
                    jj_lib::hex_util::encode_reverse_hex(&commit.change_id().as_bytes());
                result.push((name.as_str().to_string(), change_id_rhex));
            }
        }
        Ok(result)
    }

    /// Get files changed in the working copy with summary status.
    pub fn changed_files_with_status(&self) -> Result<Vec<(char, String)>> {
        self.snapshot_working_copy()?;
        let repo = self.load_head_repo()?;
        let commit = self.working_copy_commit(&repo)?;
        self.diff_commit_against_parent(&repo, &commit)
    }

    /// Run a jj CLI command and return stdout.
    pub fn jj_cmd(&self, args: &[&str]) -> Result<String> {
        let output = std::process::Command::new("jj")
            .args(args)
            .current_dir(&self.root)
            .output()
            .context("failed to run jj (is it installed?)")?;
        if !output.status.success() {
            let stderr = String::from_utf8_lossy(&output.stderr);
            bail!("jj {} failed: {}", args.join(" "), stderr.trim());
        }
        Ok(String::from_utf8_lossy(&output.stdout).to_string())
    }

    /// Describe the working copy commit.
    pub fn describe(&self, message: &str) -> Result<()> {
        self.snapshot_working_copy()?;
        let repo = self.load_head_repo()?;
        let wc_commit = self.working_copy_commit(&repo)?;

        let mut tx = repo.start_transaction();
        tx.repo_mut()
            .rewrite_commit(&wc_commit)
            .set_description(message)
            .write()?;
        tx.repo_mut().rebase_descendants()?;
        tx.commit(format!("describe commit {}", wc_commit.id().hex()))?;
        self.sync_working_copy()?;
        Ok(())
    }

    /// Create a new empty change on top of working copy (like `jj new`).
    pub fn new_change(&self, message: Option<&str>) -> Result<String> {
        self.snapshot_working_copy()?;
        let repo = self.load_head_repo()?;
        let wc_commit = self.working_copy_commit(&repo)?;

        let mut tx = repo.start_transaction();
        let mut builder = tx
            .repo_mut()
            .new_commit(vec![wc_commit.id().clone()], wc_commit.tree())
            .detach();
        if let Some(message) = message {
            builder.set_description(message);
        }
        let new_commit = builder.write(tx.repo_mut())?;
        tx.repo_mut()
            .edit(WorkspaceName::DEFAULT.to_owned(), &new_commit)?;
        tx.commit("new empty commit")?;
        self.sync_working_copy()?;

        Ok(jj_lib::hex_util::encode_reverse_hex(
            &new_commit.change_id().as_bytes(),
        ))
    }

    /// Squash revisions using jj-lib rewrite APIs.
    pub fn squash(&self, revisions: &[String], message: Option<&str>) -> Result<()> {
        self.snapshot_working_copy()?;
        let repo = self.load_head_repo()?;

        let (source, destination) = match revisions {
            [from, into] => (
                self.resolve_single_commit(&repo, from)?,
                self.resolve_single_commit(&repo, into)?,
            ),
            [from] => {
                let source = self.resolve_single_commit(&repo, from)?;
                let parent = source
                    .parents()
                    .next()
                    .transpose()?
                    .context("cannot squash root commit")?;
                (source, parent)
            }
            [] => {
                let source = self.working_copy_commit(&repo)?;
                let parent = source
                    .parents()
                    .next()
                    .transpose()?
                    .context("cannot squash root commit")?;
                (source, parent)
            }
            _ => bail!("expected at most two revisions for squash"),
        };

        if source.id() == destination.id() {
            bail!("source and destination revisions are the same");
        }

        let source_commit = CommitWithSelection {
            commit: source.clone(),
            selected_tree: source.tree(),
            parent_tree: source.parent_tree(repo.as_ref())?,
        };

        let mut tx = repo.start_transaction();
        if let Some(squashed) = squash_commits(tx.repo_mut(), &[source_commit], &destination, false)?
        {
            let mut commit_builder = squashed.commit_builder.detach();
            if let Some(message) = message {
                commit_builder.set_description(message);
            } else {
                commit_builder.set_description(destination.description());
            }
            commit_builder.write(tx.repo_mut())?;
            tx.repo_mut().rebase_descendants()?;
        }

        if tx.repo().has_changes() {
            tx.commit(format!(
                "squash commit {} into {}",
                source.id().hex(),
                destination.id().hex()
            ))?;
            self.sync_working_copy()?;
        }

        Ok(())
    }

    /// Restore a path in the working copy from its parent (like `jj restore <path>`).
    pub fn restore_path(&self, target: &str) -> Result<()> {
        self.snapshot_working_copy()?;
        let repo = self.load_head_repo()?;
        let wc_commit = self.working_copy_commit(&repo)?;
        let parent_tree = wc_commit.parent_tree(repo.as_ref())?;

        let rel_path = Path::new(target);
        let repo_path = RepoPathBuf::from_relative_path(rel_path)
            .map_err(|e| anyhow::anyhow!("invalid path `{target}`: {e}"))?;
        let matcher = PrefixMatcher::new([repo_path.as_ref()]);

        let new_tree = restore_tree(
            &parent_tree,
            &wc_commit.tree(),
            "parents".to_string(),
            wc_commit.conflict_label(),
            &matcher,
        )
        .block_on()?;

        if new_tree.tree_ids() == wc_commit.tree_ids() {
            return Ok(());
        }

        let mut tx = repo.start_transaction();
        tx.repo_mut()
            .rewrite_commit(&wc_commit)
            .set_tree(new_tree)
            .write()?;
        tx.repo_mut().rebase_descendants()?;
        tx.commit(format!(
            "restore path {target} in commit {}",
            wc_commit.id().hex()
        ))?;
        self.sync_working_copy()?;
        Ok(())
    }

    /// Abandon a revision (like `jj abandon <rev>`).
    pub fn abandon_revision(&self, revision: &str) -> Result<()> {
        self.snapshot_working_copy()?;
        let repo = self.load_head_repo()?;
        let target = self.resolve_single_commit(&repo, revision)?;

        let mut tx = repo.start_transaction();
        tx.repo_mut().record_abandoned_commit(&target);
        tx.repo_mut().rebase_descendants()?;
        tx.commit(format!("abandon commit {}", target.id().hex()))?;
        self.sync_working_copy()?;
        Ok(())
    }

    /// Undo the last operation by restoring the previous operation view.
    pub fn undo(&self) -> Result<String> {
        let repo = self.load_head_repo()?;
        let mut op_to_undo = repo.operation().clone();

        if let Some(restored_hex) = op_to_undo
            .metadata()
            .description
            .strip_prefix(UNDO_OP_DESC_PREFIX)
        {
            if let Some(restored_id) = OperationId::try_from_hex(restored_hex) {
                op_to_undo = repo.loader().load_operation(&restored_id)?;
            }
        }

        let mut parent_ops = op_to_undo.parents();
        let mut op_to_restore = match (parent_ops.next(), parent_ops.next()) {
            (None, _) => bail!("cannot undo root operation"),
            (Some(parent), None) => parent?,
            (Some(_), Some(_)) => bail!("cannot undo a merge operation"),
        };

        if let Some(original_hex) = op_to_restore
            .metadata()
            .description
            .strip_prefix(UNDO_OP_DESC_PREFIX)
        {
            if let Some(original_id) = OperationId::try_from_hex(original_hex) {
                op_to_restore = repo.loader().load_operation(&original_id)?;
            }
        }

        let op_id_hex = op_to_restore.id().hex().to_string();
        let mut tx = repo.start_transaction();
        tx.repo_mut()
            .set_view(op_to_restore.view()?.store_view().clone());
        tx.commit(format!("{UNDO_OP_DESC_PREFIX}{op_id_hex}"))?;
        self.sync_working_copy()?;
        Ok(op_id_hex)
    }

    /// Absorb working-copy changes into mutable ancestors.
    pub fn absorb(&self, dry_run: bool) -> Result<AbsorbReport> {
        self.snapshot_working_copy()?;
        let repo = self.load_head_repo()?;
        let source_commit = self.working_copy_commit(&repo)?;
        let source = AbsorbSource::from_commit(repo.as_ref(), source_commit.clone())?;

        let destinations_revset = format!("mutable() & ::{}", source_commit.id().hex());
        let destination_ids = self.resolve_commit_ids(&destinations_revset)?;
        let destinations = jj_lib::revset::ResolvedRevsetExpression::commits(destination_ids);

        let selected_trees =
            split_hunks_to_trees(repo.as_ref(), &source, &destinations, &EverythingMatcher)
                .block_on()?;

        let skipped_paths: Vec<(String, String)> = selected_trees
            .skipped_paths
            .into_iter()
            .map(|(path, reason)| (path.as_internal_file_string().to_string(), reason))
            .collect();

        let target_commits = selected_trees.target_commits.len();
        if dry_run {
            return Ok(AbsorbReport {
                target_commits,
                rewritten_destinations: 0,
                rebased_descendants: 0,
                skipped_paths,
            });
        }

        let mut tx = repo.start_transaction();
        let stats = absorb_hunks(tx.repo_mut(), &source, selected_trees.target_commits)?;
        if tx.repo().has_changes() {
            tx.commit(format!(
                "absorb changes into {} commits",
                stats.rewritten_destinations.len()
            ))?;
            self.sync_working_copy()?;
        }

        Ok(AbsorbReport {
            target_commits,
            rewritten_destinations: stats.rewritten_destinations.len(),
            rebased_descendants: stats.num_rebased,
            skipped_paths,
        })
    }

    /// Fetch from all configured git remotes using jj-lib.
    pub fn git_fetch(&self) -> Result<GitFetchReport> {
        let repo = self.load_head_repo()?;
        let mut tx = repo.start_transaction();
        let all_remotes = git::get_all_remote_names(tx.repo().store())?;
        if all_remotes.is_empty() {
            bail!("No git remotes to fetch from");
        }

        let git_settings = GitSettings::from_settings(&self.settings)?;
        let import_options = GitImportOptions {
            auto_local_bookmark: git_settings.auto_local_bookmark,
            abandon_unreachable_commits: git_settings.abandon_unreachable_commits,
            remote_auto_track_bookmarks: HashMap::new(),
        };

        let git_repo = git::get_git_backend(tx.repo_mut().store())?.git_repo();
        let mut fetcher = GitFetch::new(
            tx.repo_mut(),
            git_settings.to_subprocess_options(),
            &import_options,
        )?;

        let mut fetched_remotes = Vec::new();
        for remote in &all_remotes {
            let (_, bookmark_expr) = load_default_fetch_bookmarks(remote, &git_repo)?;
            let ref_expr = GitFetchRefExpression {
                bookmark: bookmark_expr,
                tag: StringExpression::none(),
            };
            let expanded = expand_fetch_refspecs(remote, ref_expr)?;
            fetcher.fetch(remote, expanded, &mut NullGitCallback, None, None)?;
            fetched_remotes.push(remote.as_str().to_string());
        }

        let import_stats = fetcher.import_refs()?;
        if tx.repo().has_changes() {
            tx.commit(format!("fetch from git remote(s) {}", fetched_remotes.join(",")))?;
        }

        Ok(GitFetchReport {
            remotes: fetched_remotes,
            imported_refs: import_stats.changed_remote_bookmarks.len()
                + import_stats.changed_remote_tags.len(),
        })
    }

    /// Push bookmarks using jj-lib git push APIs.
    pub fn git_push(&self, bookmark: Option<&str>) -> Result<GitPushReport> {
        let repo = self.load_head_repo()?;
        let mut tx = repo.start_transaction();
        let all_remotes = git::get_all_remote_names(tx.repo().store())?;
        if all_remotes.is_empty() {
            bail!("No git remotes configured");
        }

        let remote = all_remotes
            .iter()
            .find(|r| r.as_str() == "origin")
            .unwrap_or(&all_remotes[0]);
        let remote_name = RemoteName::new(remote.as_str());

        let mut saw_requested = bookmark.is_none();
        let mut updates = Vec::new();
        for (name, targets) in tx.repo().view().local_remote_bookmarks(remote_name) {
            if let Some(bookmark_name) = bookmark {
                if name.as_str() != bookmark_name {
                    continue;
                }
            }
            saw_requested = true;
            match classify_bookmark_push_action(targets) {
                BookmarkPushAction::Update(update) => updates.push((name.to_owned(), update)),
                BookmarkPushAction::AlreadyMatches => {}
                BookmarkPushAction::LocalConflicted => {
                    bail!("bookmark `{}` is conflicted locally", name.as_str())
                }
                BookmarkPushAction::RemoteConflicted => {
                    bail!("bookmark `{}` is conflicted on remote", name.as_str())
                }
                BookmarkPushAction::RemoteUntracked => {
                    bail!("bookmark `{}` is untracked on remote", name.as_str())
                }
            }
        }

        if !saw_requested {
            if let Some(bookmark_name) = bookmark {
                bail!("bookmark `{bookmark_name}` not found");
            }
            bail!("no bookmarks selected to push");
        }

        if updates.is_empty() {
            return Ok(GitPushReport {
                remote: remote_name.as_str().to_string(),
                pushed_refs: Vec::new(),
            });
        }

        let targets = GitBranchPushTargets {
            branch_updates: updates,
        };
        let git_settings = GitSettings::from_settings(&self.settings)?;
        let stats = git::push_branches(
            tx.repo_mut(),
            git_settings.to_subprocess_options(),
            remote_name,
            &targets,
            &mut NullGitCallback,
        )?;

        if !stats.rejected.is_empty() || !stats.remote_rejected.is_empty() {
            bail!("one or more bookmarks were rejected by remote during push");
        }

        if tx.repo().has_changes() {
            tx.commit(format!(
                "push bookmarks to git remote {}",
                remote_name.as_symbol()
            ))?;
        }

        Ok(GitPushReport {
            remote: remote_name.as_str().to_string(),
            pushed_refs: stats
                .pushed
                .iter()
                .map(|name| name.as_symbol().to_string())
                .collect(),
        })
    }

    fn diff_commit_against_parent(
        &self,
        repo: &Arc<ReadonlyRepo>,
        commit: &Commit,
    ) -> Result<Vec<(char, String)>> {
        let parent_tree = commit.parent_tree(repo.as_ref())?;
        let mut stream = parent_tree.diff_stream(&commit.tree(), &EverythingMatcher);
        let mut files = Vec::new();

        while let Some(entry) = stream.next().block_on() {
            let path = entry.path.as_internal_file_string().to_string();
            let diff = entry.values?;
            let status = if diff.before.is_absent() && !diff.after.is_absent() {
                'A'
            } else if !diff.before.is_absent() && diff.after.is_absent() {
                'D'
            } else {
                'M'
            };
            files.push((status, path));
        }

        Ok(files)
    }

    fn working_copy_commit(&self, repo: &Arc<ReadonlyRepo>) -> Result<Commit> {
        let wc_commit_id = repo
            .view()
            .get_wc_commit_id(WorkspaceName::DEFAULT)
            .context("no working copy commit found")?;
        repo.store()
            .get_commit(wc_commit_id)
            .map_err(|e| anyhow::anyhow!("failed to get working-copy commit: {e}"))
    }

    fn snapshot_working_copy(&self) -> Result<()> {
        self.jj_cmd(&["debug", "snapshot"])?;
        Ok(())
    }

    fn sync_working_copy(&self) -> Result<()> {
        self.jj_cmd(&["workspace", "update-stale"])?;
        Ok(())
    }

    fn load_head_repo(&self) -> Result<Arc<ReadonlyRepo>> {
        load_repo_at_head(&self.settings, &self.root)
    }

    fn resolve_commit_ids(&self, revset: &str) -> Result<Vec<CommitId>> {
        let out = self.jj_cmd(&[
            "--config=ui.log-word-wrap=false",
            "log",
            "--no-graph",
            "-r",
            revset,
            "-T",
            "commit_id ++ \"\\n\"",
        ])?;

        Ok(out
            .lines()
            .map(str::trim)
            .filter(|line| !line.is_empty())
            .map(|line| {
                CommitId::try_from_hex(line)
                    .ok_or_else(|| anyhow::anyhow!("invalid commit id from jj log: {line}"))
            })
            .collect::<Result<Vec<_>>>()?)
    }

    fn resolve_single_commit(&self, repo: &Arc<ReadonlyRepo>, revset: &str) -> Result<Commit> {
        let ids = self.resolve_commit_ids(revset)?;
        match ids.as_slice() {
            [] => bail!("revset `{revset}` did not resolve to any revisions"),
            [id] => repo
                .store()
                .get_commit(id)
                .map_err(|e| anyhow::anyhow!("failed to load commit for `{revset}`: {e}")),
            _ => bail!("revset `{revset}` resolved to more than one revision"),
        }
    }
}

fn load_repo_at_head(settings: &UserSettings, workspace_path: &Path) -> Result<Arc<ReadonlyRepo>> {
    let store_factories = jj_lib::repo::StoreFactories::default();
    let wc_factories = default_working_copy_factories();
    let workspace = Workspace::load(settings, workspace_path, &store_factories, &wc_factories)
        .map_err(|e| {
            anyhow::anyhow!(
                "failed to load jj workspace at {}: {e:?}",
                workspace_path.display()
            )
        })?;
    workspace
        .repo_loader()
        .load_at_head()
        .map_err(|e| anyhow::anyhow!("failed to load repo at head: {e:#}"))
}

/// Walk up directories to find .jj workspace root.
fn find_workspace_root(start: &Path) -> Result<PathBuf> {
    let mut current = start.canonicalize().unwrap_or_else(|_| start.to_path_buf());
    loop {
        if current.join(".jj").exists() {
            return Ok(current);
        }
        if !current.pop() {
            bail!("no jj repository found (searched from {})", start.display());
        }
    }
}

/// Load jj config by reading the user's actual config via `jj config list`.
/// This ensures we get all the defaults and user overrides that jj-lib expects.
fn load_jj_config() -> Result<StackedConfig> {
    let mut config = StackedConfig::empty();

    let output = std::process::Command::new("jj")
        .args(["config", "list", "--include-defaults"])
        .output()
        .context("failed to run jj config list")?;

    if output.status.success() {
        let config_text = String::from_utf8_lossy(&output.stdout);
        let layer = ConfigLayer::parse(ConfigSource::Default, &config_text)
            .map_err(|e| anyhow::anyhow!("failed to parse jj config: {e}"))?;
        config.add_layer(layer);
    } else {
        let (name, email) = get_user_identity();
        let hostname = gethostname();
        let username = std::env::var("USER")
            .or_else(|_| std::env::var("USERNAME"))
            .unwrap_or_else(|_| "jut".to_string());

        let toml = format!(
            r#"
[user]
name = "{name}"
email = "{email}"

[operation]
hostname = "{hostname}"
username = "{username}"

[signing]
behavior = "drop"

[merge]
hunk-level = "line"
"#,
        );

        let layer = ConfigLayer::parse(ConfigSource::Default, &toml)
            .map_err(|e| anyhow::anyhow!("failed to parse config: {e}"))?;
        config.add_layer(layer);
    }

    Ok(config)
}

fn gethostname() -> String {
    std::process::Command::new("hostname")
        .output()
        .ok()
        .and_then(|o| {
            if o.status.success() {
                Some(String::from_utf8_lossy(&o.stdout).trim().to_string())
            } else {
                None
            }
        })
        .unwrap_or_else(|| "localhost".to_string())
}

/// Try to get user identity from jj config, then git config, then defaults.
fn get_user_identity() -> (String, String) {
    if let Ok(output) = std::process::Command::new("jj")
        .args(["config", "get", "user.name"])
        .output()
    {
        if output.status.success() {
            let name = String::from_utf8_lossy(&output.stdout).trim().to_string();
            if let Ok(email_out) = std::process::Command::new("jj")
                .args(["config", "get", "user.email"])
                .output()
            {
                if email_out.status.success() {
                    let email = String::from_utf8_lossy(&email_out.stdout).trim().to_string();
                    if !name.is_empty() && !email.is_empty() {
                        return (name, email);
                    }
                }
            }
        }
    }

    if let Ok(output) = std::process::Command::new("git")
        .args(["config", "user.name"])
        .output()
    {
        if output.status.success() {
            let name = String::from_utf8_lossy(&output.stdout).trim().to_string();
            if let Ok(email_out) = std::process::Command::new("git")
                .args(["config", "user.email"])
                .output()
            {
                if email_out.status.success() {
                    let email = String::from_utf8_lossy(&email_out.stdout).trim().to_string();
                    if !name.is_empty() && !email.is_empty() {
                        return (name, email);
                    }
                }
            }
        }
    }

    ("jut".to_string(), "jut@localhost".to_string())
}
