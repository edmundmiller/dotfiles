use anyhow::Result;
use colored::Colorize;

use crate::args::Args;
use crate::output::OutputChannel;
use crate::repo::Repo;

pub fn execute(args: &Args, out: &mut OutputChannel, bookmark: Option<&str>) -> Result<()> {
    let repo = Repo::discover(&args.current_dir)?;

    let mut cmd_args = vec!["git", "push"];
    if let Some(b) = bookmark {
        cmd_args.extend_from_slice(&["-b", b]);
    }

    let result = repo.jj_cmd(&cmd_args)?;

    if out.is_json() {
        let json = serde_json::json!({
            "pushed": true,
            "bookmark": bookmark,
            "output": result.trim(),
        });
        out.write_json(&json)?;
    } else {
        out.human(&format!("{}", "Pushed".green().bold()));
        if !result.trim().is_empty() {
            out.human(result.trim());
        }
    }

    Ok(())
}
