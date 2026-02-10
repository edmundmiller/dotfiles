use anyhow::Result;
use colored::Colorize;

use crate::args::Args;
use crate::output::OutputChannel;
use crate::repo::Repo;

pub fn execute(args: &Args, out: &mut OutputChannel, dry_run: bool) -> Result<()> {
    let repo = Repo::open(&args.current_dir)?;

    let mut cmd_args = vec!["absorb"];
    if dry_run {
        cmd_args.push("--dry-run");
    }

    let result = repo.jj_cmd(&cmd_args)?;

    if out.is_json() {
        let json = serde_json::json!({
            "absorbed": !dry_run,
            "dry_run": dry_run,
            "output": result.trim(),
        });
        out.write_json(&json)?;
    } else {
        if dry_run {
            out.human(&"Absorb plan:".bold().to_string());
        } else {
            out.human(&format!("{}", "Absorbed".green().bold()));
        }
        if !result.trim().is_empty() {
            out.human(result.trim());
        }
    }

    if args.status_after && !dry_run {
        crate::command::status::execute(args, out)?;
    }

    Ok(())
}
