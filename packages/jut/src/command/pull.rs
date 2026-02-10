use anyhow::Result;
use colored::Colorize;

use crate::args::Args;
use crate::output::OutputChannel;
use crate::repo::Repo;

pub fn execute(args: &Args, out: &mut OutputChannel) -> Result<()> {
    let repo = Repo::discover(&args.current_dir)?;

    // Fetch
    let fetch_result = repo.jj_cmd(&["git", "fetch"])?;

    if out.is_json() {
        let json = serde_json::json!({
            "fetched": true,
            "output": fetch_result.trim(),
        });
        out.write_json(&json)?;
    } else {
        out.human(&format!("{}", "Fetched".green().bold()));
        if !fetch_result.trim().is_empty() {
            out.human(fetch_result.trim());
        }
    }

    if args.status_after {
        crate::command::status::execute(args, out)?;
    }

    Ok(())
}
