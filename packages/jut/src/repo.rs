//! Repository operations.
//!
//! Uses jj-lib directly for read operations (repo discovery, commit data, bookmarks, short IDs).
//! Uses jj CLI for mutations (describe, new, squash, etc.) — these need working copy
//! snapshots and transaction handling that's complex to replicate.

use std::path::{Path, PathBuf};
use std::sync::Arc;

use anyhow::{Context, Result, bail};
use jj_lib::config::{ConfigLayer, ConfigSource, StackedConfig};
use jj_lib::object_id::ObjectId;
use jj_lib::repo::{ReadonlyRepo, Repo as RepoTrait};

use jj_lib::settings::UserSettings;
use jj_lib::workspace::{Workspace, default_working_copy_factories};

/// High-level repo handle with both jj-lib and CLI access.
pub struct Repo {
    root: PathBuf,
    inner: Arc<ReadonlyRepo>,
}

impl Repo {
    /// Open a jj repo from a path using jj-lib.
    pub fn open(start: &Path) -> Result<Self> {
        let workspace_path = find_workspace_root(start)?;

        // Minimal config — jj-lib needs UserSettings but we don't need much
        let config = load_jj_config()?;
        let settings = UserSettings::from_config(config)
            .context("failed to create jj settings")?;

        let store_factories = jj_lib::repo::StoreFactories::default();
        let wc_factories = default_working_copy_factories();

        let workspace = Workspace::load(&settings, &workspace_path, &store_factories, &wc_factories)
            .map_err(|e| anyhow::anyhow!("failed to load jj workspace at {}: {e:?}", workspace_path.display()))?;

        let repo = workspace
            .repo_loader()
            .load_at_head()
            .map_err(|e| anyhow::anyhow!("failed to load repo at head: {e:#}"))?;

        Ok(Self {
            root: workspace_path,
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
        let wc_name = jj_lib::ref_name::WorkspaceName::DEFAULT;
        let wc_commit_id = self
            .inner
            .view()
            .get_wc_commit_id(wc_name)
            .context("no working copy commit found")?;
        let commit = self.inner.store().get_commit(wc_commit_id)
            .map_err(|e| anyhow::anyhow!("failed to get wc commit: {e}"))?;
        Ok(jj_lib::hex_util::encode_reverse_hex(&commit.change_id().as_bytes()))
    }

    /// Get the shortest unique prefix for a change ID (reverse-hex string).
    pub fn shortest_change_id_prefix(&self, change_id_reverse_hex: &str) -> Result<String> {
        let bytes = jj_lib::hex_util::decode_reverse_hex(change_id_reverse_hex)
            .context("invalid change id")?;
        let change_id = jj_lib::backend::ChangeId::from_bytes(&bytes);
        let len = self
            .inner
            .shortest_unique_change_id_prefix_len(&change_id)
            .map_err(|e| anyhow::anyhow!("index error: {e}"))?;
        // Minimum 4 chars for readability
        let len = len.max(4);
        Ok(change_id_reverse_hex[..len.min(change_id_reverse_hex.len())].to_string())
    }

    /// Get local bookmarks as (name, change_id_reverse_hex) pairs.
    pub fn bookmarks(&self) -> Result<Vec<(String, String)>> {
        let view = self.inner.view();
        let mut result = Vec::new();
        for (name, target) in view.local_bookmarks() {
            if let Some(commit_id) = target.as_normal() {
                let commit = self.inner.store().get_commit(commit_id)
                    .map_err(|e| anyhow::anyhow!("failed to get bookmark commit: {e}"))?;
                let change_id_rhex = jj_lib::hex_util::encode_reverse_hex(&commit.change_id().as_bytes());
                result.push((name.as_str().to_string(), change_id_rhex));
            }
        }
        Ok(result)
    }

    /// Get files changed in the working copy.
    /// Uses jj CLI — tree diffing via jj-lib is complex and fragile.
    #[allow(dead_code)]
    pub fn changed_files(&self) -> Result<Vec<String>> {
        let out = self.jj_cmd(&["status"])?;
        let mut files = Vec::new();
        for line in out.lines() {
            let line = line.trim();
            if line.is_empty() {
                continue;
            }
            // "M path", "A path", "D path", "? path" (untracked)
            if line.len() > 2
                && (line.starts_with("M ")
                    || line.starts_with("A ")
                    || line.starts_with("D ")
                    || line.starts_with("? "))
            {
                files.push(line[2..].to_string());
            }
        }
        Ok(files)
    }

    // --- CLI fallback for mutations ---

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
        self.jj_cmd(&["describe", "-m", message])?;
        Ok(())
    }

    /// Create a new empty change on top of working copy (like `jj new`).
    pub fn new_change(&self, message: Option<&str>) -> Result<String> {
        if let Some(m) = message {
            self.jj_cmd(&["new", "-m", m])?;
        } else {
            self.jj_cmd(&["new"])?;
        }
        // After mutation, re-read from CLI since our ReadonlyRepo is stale
        let out = self.jj_cmd(&[
            "log", "-r", "@", "--no-graph", "-T", "change_id", "--limit", "1",
        ])?;
        Ok(out.trim().to_string())
    }
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

    // Get the full config from jj CLI — it knows all defaults
    let output = std::process::Command::new("jj")
        .args(["config", "list", "--include-defaults"])
        .output()
        .context("failed to run jj config list")?;

    if output.status.success() {
        let config_text = String::from_utf8_lossy(&output.stdout);
        // jj config list outputs "key = value" lines, which is valid TOML
        let layer = ConfigLayer::parse(ConfigSource::Default, &config_text)
            .map_err(|e| anyhow::anyhow!("failed to parse jj config: {e}"))?;
        config.add_layer(layer);
    } else {
        // Fallback: minimal config
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
    // Try jj config
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

    // Try git config
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
