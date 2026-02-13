use anyhow::Result;
use colored::Colorize;

use crate::args::Args;
use crate::output::OutputChannel;
use crate::repo::Repo;

pub fn execute(args: &Args, out: &mut OutputChannel, bookmark: Option<&str>) -> Result<()> {
    let repo = Repo::open(&args.current_dir)?;
    let report = repo.git_push(bookmark)?;

    if out.is_json() {
        let json = serde_json::json!({
            "pushed": true,
            "bookmark": bookmark,
            "remote": report.remote,
            "pushed_refs": report.pushed_refs,
        });
        out.write_json(&json)?;
    } else {
        out.human(&format!("{}", "Pushed".green().bold()));
        out.human(&format!("Remote: {}", report.remote));
        if !report.pushed_refs.is_empty() {
            out.human(&format!("Updated: {}", report.pushed_refs.join(", ")));
        } else {
            out.human("No bookmark updates were needed");
        }
    }

    Ok(())
}
