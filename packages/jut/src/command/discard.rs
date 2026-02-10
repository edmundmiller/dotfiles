use anyhow::Result;
use colored::Colorize;

use crate::args::Args;
use crate::output::OutputChannel;
use crate::repo::Repo;

pub fn execute(args: &Args, out: &mut OutputChannel, target: &str) -> Result<()> {
    let repo = Repo::discover(&args.current_dir)?;

    // Check if target is a file path or revision
    let is_file = repo.root().join(target).exists();

    let result = if is_file {
        repo.jj_cmd(&["restore", target])?
    } else {
        repo.jj_cmd(&["abandon", target])?
    };

    if out.is_json() {
        let action = if is_file { "restore" } else { "abandon" };
        let json = serde_json::json!({
            "discarded": true,
            "action": action,
            "target": target,
        });
        out.write_json(&json)?;
    } else {
        out.human(&format!(
            "{} {}",
            "Discarded".red().bold(),
            target.yellow()
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
