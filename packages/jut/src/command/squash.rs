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
    let repo = Repo::discover(&args.current_dir)?;

    let mut cmd_args: Vec<&str> = vec!["squash"];
    if revisions.len() == 2 {
        cmd_args.extend_from_slice(&["--from", &revisions[0], "--into", &revisions[1]]);
    } else if revisions.len() == 1 {
        cmd_args.extend_from_slice(&["--from", &revisions[0]]);
    }
    // No revisions = squash working copy into parent (default jj behavior)

    if let Some(m) = message {
        cmd_args.extend_from_slice(&["-m", m]);
    }

    let result = repo.jj_cmd(&cmd_args)?;

    if out.is_json() {
        let json = serde_json::json!({
            "squashed": true,
            "revisions": revisions,
            "message": message,
            "output": result.trim(),
        });
        out.write_json(&json)?;
    } else {
        out.human(&format!("{}", "Squashed".green().bold()));
        if !result.trim().is_empty() {
            out.human(result.trim());
        }
    }

    if args.status_after {
        crate::command::status::execute(args, out)?;
    }

    Ok(())
}
