use anyhow::Result;
use colored::Colorize;

use crate::args::Args;
use crate::output::OutputChannel;
use crate::repo::Repo;

pub fn execute(args: &Args, out: &mut OutputChannel, target: &str) -> Result<()> {
    let repo = Repo::open(&args.current_dir)?;

    // Check if target is a file path or revision
    let is_file = repo.root().join(target).exists();

    if is_file {
        repo.restore_path(target)?;
    } else {
        repo.abandon_revision(target)?;
    }

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
    }

    if args.status_after {
        crate::command::status::execute(args, out)?;
    }

    Ok(())
}
