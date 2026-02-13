use anyhow::Result;
use colored::Colorize;

use crate::args::Args;
use crate::output::OutputChannel;
use crate::repo::Repo;

pub fn execute(
    args: &Args,
    out: &mut OutputChannel,
    revisions: &[String],
    message: Option<&str>,
) -> Result<()> {
    let repo = Repo::open(&args.current_dir)?;
    repo.squash(revisions, message)?;

    if out.is_json() {
        let json = serde_json::json!({
            "squashed": true,
            "revisions": revisions,
            "message": message
        });
        out.write_json(&json)?;
    } else {
        out.human(&format!("{}", "Squashed".green().bold()));
    }

    if args.status_after {
        crate::command::status::execute(args, out)?;
    }

    Ok(())
}
