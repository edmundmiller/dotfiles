use anyhow::Result;

use crate::args::Args;
use crate::output::OutputChannel;
use crate::repo::Repo;

pub fn execute(args: &Args, out: &mut OutputChannel, limit: usize, all: bool) -> Result<()> {
    let repo = Repo::open(&args.current_dir)?;

    let limit_str = limit.to_string();
    let mut cmd_args = vec!["log"];
    if all {
        cmd_args.extend_from_slice(&["--revisions", "all()"]);
    } else {
        cmd_args.extend_from_slice(&["--limit", &limit_str]);
    }

    let result = repo.jj_cmd(&cmd_args)?;

    if out.is_json() {
        // Parse log into structured output
        let json = serde_json::json!({
            "log": result.trim(),
        });
        out.write_json(&json)?;
    } else {
        print!("{}", result);
    }

    Ok(())
}
