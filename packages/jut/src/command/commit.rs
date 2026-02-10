use anyhow::{Result, bail};
use colored::Colorize;

use crate::args::Args;
use crate::output::OutputChannel;
use crate::repo::Repo;

/// Commit = describe current + create new empty change (like `jj commit`).
pub fn execute(
    args: &Args,
    out: &mut OutputChannel,
    message: Option<&str>,
    _branch: Option<&str>,
) -> Result<()> {
    let repo = Repo::discover(&args.current_dir)?;

    let msg = match message {
        Some(m) => m.to_string(),
        None => {
            if out.is_json() {
                bail!("--message required in JSON mode");
            }
            // Open editor via jj
            repo.jj_cmd(&["commit"])?;
            if out.is_json() {
                let json = serde_json::json!({ "committed": true });
                out.write_json(&json)?;
            } else {
                out.human(&"Committed (via editor)".green().to_string());
            }
            return Ok(());
        }
    };

    // Describe current working copy, then create new change
    repo.describe(&msg)?;
    let new_id = repo.new_change(None)?;

    if out.is_json() {
        let json = serde_json::json!({
            "committed": true,
            "message": msg,
            "new_change_id": new_id,
        });
        out.write_json(&json)?;
    } else {
        out.human(&format!(
            "{} {}",
            "Committed:".green().bold(),
            msg
        ));
        out.human(&format!(
            "New change: {}",
            &new_id[..8.min(new_id.len())].yellow()
        ));
    }

    if args.status_after {
        crate::command::status::execute(args, out)?;
    }

    Ok(())
}
