//! Skill management: install, show, and check jut AI skills.

use std::fs;
use std::path::{Path, PathBuf};

use anyhow::{Context, Result};
use colored::Colorize;

use crate::args::SkillAction;
use crate::output::OutputChannel;

const SKILL_CONTENT: &str = include_str!("../../skill/SKILL.md");

pub fn execute(out: &mut OutputChannel, action: Option<&SkillAction>) -> Result<()> {
    match action {
        None | Some(SkillAction::Show) => show(out),
        Some(SkillAction::Install { global, target }) => install(out, *global, target.as_deref()),
        Some(SkillAction::Check { update }) => check(out, *update),
    }
}

fn show(_out: &mut OutputChannel) -> Result<()> {
    print!("{}", SKILL_CONTENT);
    Ok(())
}

fn install(out: &mut OutputChannel, global: bool, target: Option<&str>) -> Result<()> {
    let targets = resolve_targets(global, target)?;

    for dir in &targets {
        fs::create_dir_all(dir)
            .with_context(|| format!("failed to create {}", dir.display()))?;

        let skill_path = dir.join("SKILL.md");
        fs::write(&skill_path, SKILL_CONTENT)
            .with_context(|| format!("failed to write {}", skill_path.display()))?;

        if out.is_json() {
            let json = serde_json::json!({
                "installed": true,
                "path": skill_path.to_string_lossy(),
                "version": env!("CARGO_PKG_VERSION"),
            });
            out.write_json(&json)?;
        } else {
            out.human(&format!(
                "{} {}",
                "Installed:".green().bold(),
                skill_path.display()
            ));
        }
    }

    Ok(())
}

fn check(out: &mut OutputChannel, update: bool) -> Result<()> {
    let targets = find_installed()?;

    if targets.is_empty() {
        if out.is_json() {
            let json = serde_json::json!({
                "installed": false,
                "message": "no jut skill found — run `jut skill install`",
            });
            out.write_json(&json)?;
        } else {
            out.human(&format!(
                "{} no jut skill found — run {}",
                "Not installed:".yellow().bold(),
                "jut skill install".cyan()
            ));
        }
        return Ok(());
    }

    let current_version = env!("CARGO_PKG_VERSION");

    for path in &targets {
        let content = fs::read_to_string(path)
            .with_context(|| format!("failed to read {}", path.display()))?;

        let installed_version = parse_version(&content);
        let up_to_date = installed_version.as_deref() == Some(current_version);

        if up_to_date {
            if out.is_json() {
                let json = serde_json::json!({
                    "path": path.to_string_lossy(),
                    "version": current_version,
                    "up_to_date": true,
                });
                out.write_json(&json)?;
            } else {
                out.human(&format!(
                    "{} {} (v{})",
                    "Up to date:".green().bold(),
                    path.display(),
                    current_version
                ));
            }
        } else if update {
            let parent = path.parent().unwrap();
            fs::create_dir_all(parent)?;
            fs::write(path, SKILL_CONTENT)?;

            if out.is_json() {
                let json = serde_json::json!({
                    "path": path.to_string_lossy(),
                    "old_version": installed_version,
                    "new_version": current_version,
                    "updated": true,
                });
                out.write_json(&json)?;
            } else {
                out.human(&format!(
                    "{} {} → v{}",
                    "Updated:".green().bold(),
                    path.display(),
                    current_version
                ));
            }
        } else {
            if out.is_json() {
                let json = serde_json::json!({
                    "path": path.to_string_lossy(),
                    "installed_version": installed_version,
                    "current_version": current_version,
                    "up_to_date": false,
                });
                out.write_json(&json)?;
            } else {
                out.human(&format!(
                    "{} {} (v{} → v{}) — run {}",
                    "Outdated:".yellow().bold(),
                    path.display(),
                    installed_version.as_deref().unwrap_or("unknown"),
                    current_version,
                    "jut skill check --update".cyan()
                ));
            }
        }
    }

    Ok(())
}

/// Determine where to install skill files.
fn resolve_targets(global: bool, explicit: Option<&str>) -> Result<Vec<PathBuf>> {
    if let Some(t) = explicit {
        return Ok(vec![PathBuf::from(t)]);
    }

    if global {
        let home = dirs::home_dir().context("cannot find home directory")?;
        let mut targets = vec![];

        // Install to all agent skill directories
        let pi_dir = home.join(".pi/agent/skills/jut");
        targets.push(pi_dir);

        let claude_dir = home.join(".claude/skills/jut");
        targets.push(claude_dir);

        return Ok(targets);
    }

    // Project-local: find repo root and install to .pi/agent/skills/jut/
    let cwd = std::env::current_dir()?;
    let mut targets = vec![];

    // Prefer .agents/ for cross-agent compatibility
    let agents_dir = find_repo_root(&cwd)
        .unwrap_or_else(|| cwd.clone())
        .join(".agents/skills/jut");
    targets.push(agents_dir);

    Ok(targets)
}

/// Find installed skill files in known locations.
fn find_installed() -> Result<Vec<PathBuf>> {
    let mut found = vec![];

    // Check global locations
    if let Some(home) = dirs::home_dir() {
        for subdir in &[".pi/agent/skills/jut", ".claude/skills/jut"] {
            let path = home.join(subdir).join("SKILL.md");
            if path.exists() {
                found.push(path);
            }
        }
    }

    // Check project-local locations
    let cwd = std::env::current_dir()?;
    if let Some(root) = find_repo_root(&cwd) {
        for subdir in &[".agents/skills/jut", ".pi/agent/skills/jut", ".claude/skills/jut"] {
            let path = root.join(subdir).join("SKILL.md");
            if path.exists() {
                found.push(path);
            }
        }
    }

    found.sort();
    found.dedup();
    Ok(found)
}

fn find_repo_root(start: &Path) -> Option<PathBuf> {
    let mut dir = start.to_path_buf();
    loop {
        if dir.join(".jj").exists() || dir.join(".git").exists() {
            return Some(dir);
        }
        if !dir.pop() {
            return None;
        }
    }
}

fn parse_version(content: &str) -> Option<String> {
    // Parse version from YAML frontmatter
    let content = content.strip_prefix("---")?;
    let end = content.find("---")?;
    let frontmatter = &content[..end];
    for line in frontmatter.lines() {
        let line = line.trim();
        if let Some(rest) = line.strip_prefix("version:") {
            return Some(rest.trim().trim_matches('"').to_string());
        }
    }
    None
}
