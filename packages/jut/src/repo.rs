//! Repository operations.
//!
//! Uses jj CLI for most operations (robust, stable API).
//! Uses jj-lib directly where it provides clear wins (file listing, ID resolution).

use std::path::{Path, PathBuf};

use anyhow::{Context, Result, bail};

/// High-level repo handle.
pub struct Repo {
    root: PathBuf,
}

impl Repo {
    /// Discover a jj repo from cwd or ancestors.
    pub fn discover(start: &Path) -> Result<Self> {
        let mut current = start.canonicalize().unwrap_or_else(|_| start.to_path_buf());
        loop {
            if current.join(".jj").exists() {
                return Ok(Self { root: current });
            }
            if !current.pop() {
                bail!("no jj repository found (searched from {})", start.display());
            }
        }
    }

    pub fn root(&self) -> &Path {
        &self.root
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

    /// Get current change ID.
    pub fn current_change_id(&self) -> Result<String> {
        let out = self.jj_cmd(&[
            "log",
            "-r",
            "@",
            "--no-graph",
            "-T",
            "change_id",
            "--limit",
            "1",
        ])?;
        Ok(out.trim().to_string())
    }

    /// Get files changed in the working copy.
    pub fn changed_files(&self) -> Result<Vec<String>> {
        // Use jj status which shows both tracked changes and untracked paths
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

    /// Get bookmarks and their target change IDs.
    pub fn bookmarks(&self) -> Result<Vec<(String, String)>> {
        let out = self.jj_cmd(&[
            "bookmark",
            "list",
            "--template",
            r#"name ++ "\t" ++ if(normal_target, normal_target.change_id(), "(conflicted)") ++ "\n""#,
        ])?;
        let mut result = Vec::new();
        for line in out.lines() {
            let line = line.trim();
            if line.is_empty() {
                continue;
            }
            let parts: Vec<&str> = line.splitn(2, '\t').collect();
            if parts.len() == 2 {
                result.push((parts[0].to_string(), parts[1].to_string()));
            }
        }
        Ok(result)
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
        self.current_change_id()
    }
}
