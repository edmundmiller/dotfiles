use anyhow::Result;
use colored::Colorize;

use crate::args::Args;
use crate::output::OutputChannel;
use crate::repo::Repo;

pub fn execute(
    args: &Args,
    out: &mut OutputChannel,
    target: &str,
    message: Option<&str>,
) -> Result<()> {
    let repo = Repo::open(&args.current_dir)?;

    let mut cmd_args = vec!["describe", "-r", target];
    if let Some(m) = message {
        cmd_args.extend_from_slice(&["-m", m]);
    }

    let result = repo.jj_cmd(&cmd_args)?;

    if out.is_json() {
        let json = serde_json::json!({
            "reworded": true,
            "target": target,
            "message": message,
        });
        out.write_json(&json)?;
    } else {
        out.human(&format!(
            "{} {}",
            "Reworded".green().bold(),
            target.yellow()
        ));
        if !result.trim().is_empty() {
            out.human(result.trim());
        }
    }

    Ok(())
}
