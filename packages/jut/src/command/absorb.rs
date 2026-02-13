use anyhow::Result;
use colored::Colorize;

use crate::args::Args;
use crate::output::OutputChannel;
use crate::repo::Repo;

pub fn execute(args: &Args, out: &mut OutputChannel, dry_run: bool) -> Result<()> {
    let repo = Repo::open(&args.current_dir)?;
    let report = repo.absorb(dry_run)?;

    if out.is_json() {
        let json = serde_json::json!({
            "absorbed": !dry_run,
            "dry_run": dry_run,
            "target_commits": report.target_commits,
            "rewritten_destinations": report.rewritten_destinations,
            "rebased_descendants": report.rebased_descendants,
            "skipped_paths": report.skipped_paths,
        });
        out.write_json(&json)?;
    } else {
        if dry_run {
            out.human(&format!(
                "{} {}",
                "Absorb plan:".bold(),
                report.target_commits
            ));
        } else {
            out.human(&format!("{}", "Absorbed".green().bold()));
        }
        if report.rewritten_destinations > 0 {
            out.human(&format!(
                "Rewrote {} destination commits",
                report.rewritten_destinations
            ));
        }
        if report.rebased_descendants > 0 {
            out.human(&format!(
                "Rebased {} descendant commits",
                report.rebased_descendants
            ));
        }
        if !report.skipped_paths.is_empty() {
            for (path, reason) in &report.skipped_paths {
                out.human(&format!("Skipped {}: {}", path, reason));
            }
        }
    }

    if args.status_after && !dry_run {
        crate::command::status::execute(args, out)?;
    }

    Ok(())
}
