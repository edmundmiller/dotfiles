use anyhow::Result;
use colored::Colorize;

use crate::args::Args;
use crate::output::OutputChannel;
use crate::repo::Repo;

pub fn execute(args: &Args, out: &mut OutputChannel) -> Result<()> {
    let repo = Repo::discover(&args.current_dir)?;

    let result = repo.jj_cmd(&["undo"])?;

    if out.is_json() {
        let json = serde_json::json!({
            "undone": true,
            "output": result.trim(),
        });
        out.write_json(&json)?;
    } else {
        out.human(&format!("{}", "Undone".green().bold()));
        if !result.trim().is_empty() {
            out.human(result.trim());
        }
    }

    if args.status_after {
        crate::command::status::execute(args, out)?;
    }

    Ok(())
}
