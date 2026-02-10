use anyhow::Result;
use colored::Colorize;

use crate::args::Args;
use crate::output::OutputChannel;
use crate::repo::Repo;

/// The universal combine primitive.
///
/// ```text
/// SOURCE / TARGET  │ zz (discard)     │ Revision              │ Bookmark
/// ─────────────────┼──────────────────┼───────────────────────┼─────────────
/// File             │ jj restore file  │ jj squash --into rev  │ -
/// Revision         │ jj abandon rev   │ jj squash rev into    │ jj rebase
/// ```
pub fn execute(args: &Args, out: &mut OutputChannel, source: &str, target: &str) -> Result<()> {
    let repo = Repo::open(&args.current_dir)?;

    let is_file = std::path::Path::new(source).exists()
        || repo.root().join(source).exists();
    let is_discard = target == "zz";

    let (action, result) = if is_file && is_discard {
        // Restore file: discard changes
        let r = repo.jj_cmd(&["restore", source])?;
        ("restore", r)
    } else if is_file {
        // Squash file into revision
        let r = repo.jj_cmd(&["squash", "--into", target, source])?;
        ("amend", r)
    } else if is_discard {
        // Abandon revision
        let r = repo.jj_cmd(&["abandon", source])?;
        ("abandon", r)
    } else {
        // Squash revision into revision
        let r = repo.jj_cmd(&["squash", "--from", source, "--into", target])?;
        ("squash", r)
    };

    if out.is_json() {
        let json = serde_json::json!({
            "action": action,
            "source": source,
            "target": target,
            "output": result.trim(),
        });
        out.write_json(&json)?;
    } else {
        let action_label = match action {
            "restore" => "Restored".green(),
            "amend" => "Amended".green(),
            "abandon" => "Abandoned".red(),
            "squash" => "Squashed".green(),
            _ => action.normal(),
        };
        out.human(&format!(
            "{} {} → {}",
            action_label.bold(),
            source.yellow(),
            target.cyan()
        ));
        if !result.trim().is_empty() {
            out.human(result.trim());
        }
    }

    if args.status_after {
        crate::command::status::execute(args, out)?;
    }

    Ok(())
}
