//! Repository operations.
//!
//! Pure CLI wrapper — all operations go through `jj` CLI.
//! jut is a thin opinionated layer around jj, not a replacement.

use std::path::{Path, PathBuf};

use anyhow::{Context, Result, bail};

/// High-level repo handle wrapping jj CLI.
pub struct Repo {
    root: PathBuf,
}

impl Repo {
    /// Open a jj repo by finding the workspace root.
    pub fn open(start: &Path) -> Result<Self> {
        let root = find_workspace_root(start)?;
        Ok(Self { root })
    }

    pub fn root(&self) -> &Path {
        &self.root
    }

    /// Get current working copy change ID (full reverse-hex).
    pub fn current_change_id(&self) -> Result<String> {
        let out = self.jj_cmd(&[
            "log", "-r", "@", "--no-graph", "-T", "change_id", "--limit", "1",
        ])?;
        let id = out.trim().to_string();
        if id.is_empty() {
            bail!("no working copy commit found");
        }
        Ok(id)
    }

    /// Get local bookmarks as (name, change_id) pairs.
    pub fn bookmarks(&self) -> Result<Vec<(String, String)>> {
        let out = self.jj_cmd(&[
            "bookmark", "list", "--all-tracking-patterns", "-T",
            r#"if(!tracking_remote_refs, name ++ "\t" ++ commit_id ++ "\n")"#,
        ])?;

        // Fallback: use simpler template if the above fails
        let out = if out.trim().is_empty() {
            self.jj_cmd(&[
                "bookmark", "list", "-T",
                r#"name ++ "\t" ++ commit_id ++ "\n""#,
            ])?
        } else {
            out
        };

        let mut result = Vec::new();
        for line in out.lines() {
            let line = line.trim();
            if line.is_empty() {
                continue;
            }
            if let Some((name, commit_id)) = line.split_once('\t') {
                // We need the change_id, not commit_id — look it up
                let change_id = self.jj_cmd(&[
                    "log", "-r", commit_id.trim(), "--no-graph", "-T", "change_id", "--limit", "1",
                ])?;
                result.push((name.to_string(), change_id.trim().to_string()));
            }
        }
        Ok(result)
    }

    /// Get files changed in the working copy.
    #[allow(dead_code)]
    pub fn changed_files(&self) -> Result<Vec<String>> {
        let out = self.jj_cmd(&["status"])?;
        let mut files = Vec::new();
        for line in out.lines() {
            let line = line.trim();
            if line.is_empty() {
                continue;
            }
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

    // --- CLI operations ---

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

    /// Create a new empty change on top of working copy.
    pub fn new_change(&self, message: Option<&str>) -> Result<String> {
        if let Some(m) = message {
            self.jj_cmd(&["new", "-m", m])?;
        } else {
            self.jj_cmd(&["new"])?;
        }
        self.current_change_id()
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
