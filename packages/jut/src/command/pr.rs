use anyhow::{Context, Result, bail};
use colored::Colorize;

use crate::args::Args;
use crate::output::OutputChannel;
use crate::repo::Repo;

/// Create a PR using gh CLI (no GitHub app required).
pub fn execute(
    args: &Args,
    out: &mut OutputChannel,
    bookmark: Option<&str>,
    message: Option<&str>,
) -> Result<()> {
    let repo = Repo::open(&args.current_dir)?;

    // Ensure bookmark exists and is pushed
    let bookmark_name = match bookmark {
        Some(b) => b.to_string(),
        None => {
            // Try to find the bookmark for the current revision
            let repo_mut = Repo::open(&args.current_dir)?;
            let change_id = repo_mut.current_change_id()?;
            let bookmarks = repo_mut.bookmarks()?;
            bookmarks
                .iter()
                .find(|(_, id)| id == &change_id)
                .map(|(name, _)| name.clone())
                .context("no bookmark on current revision; specify one with: jut pr <bookmark>")?
        }
    };

    // Push the bookmark first
    let push_result = repo.jj_cmd(&["git", "push", "-b", &bookmark_name]);
    if let Err(e) = &push_result {
        out.error(&format!("Warning: push failed: {}", e));
    }

    // Create PR via gh
    let mut gh_args = vec!["pr", "create", "--head", &bookmark_name];
    let title;
    if let Some(m) = message {
        // Split first line as title, rest as body
        let lines: Vec<&str> = m.splitn(2, '\n').collect();
        title = lines[0].to_string();
        gh_args.extend_from_slice(&["--title", &title]);
        if lines.len() > 1 {
            gh_args.extend_from_slice(&["--body", lines[1]]);
        }
    } else {
        gh_args.push("--fill");
    }

    let gh_output = std::process::Command::new("gh")
        .args(&gh_args)
        .current_dir(repo.root())
        .output()
        .context("failed to run gh CLI (is it installed?)")?;

    let stdout = String::from_utf8_lossy(&gh_output.stdout).to_string();
    let stderr = String::from_utf8_lossy(&gh_output.stderr).to_string();

    if !gh_output.status.success() {
        bail!("gh pr create failed: {}", stderr.trim());
    }

    let pr_url = stdout.trim().to_string();

    if out.is_json() {
        let json = serde_json::json!({
            "created": true,
            "bookmark": bookmark_name,
            "pr_url": pr_url,
        });
        out.write_json(&json)?;
    } else {
        out.human(&format!(
            "{} {}",
            "PR created:".green().bold(),
            pr_url.cyan()
        ));
    }

    Ok(())
}
