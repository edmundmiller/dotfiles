use anyhow::Result;

use crate::args::Args;
use crate::output::OutputChannel;
use crate::repo::Repo;

pub fn execute(args: &Args, out: &mut OutputChannel, limit: usize, all: bool) -> Result<()> {
    let repo = Repo::open(&args.current_dir)?;

    if out.is_json() {
        // Structured JSON output via jj-lib query
        let revset = if all {
            "all()".to_string()
        } else {
            format!("ancestors(visible_heads(), {limit})")
        };

        let wc_change_id = repo.current_change_id()?;
        let mut revisions = repo.query_revisions(&revset)?;
        for rev in &mut revisions {
            rev.is_working_copy = rev.change_id == wc_change_id;
        }

        let json = serde_json::json!({
            "revisions": revisions,
        });
        out.write_json(&json)?;
    } else {
        // Human output: pass through jj's formatted log
        let limit_str = limit.to_string();
        let mut cmd_args = vec!["log"];
        if all {
            cmd_args.extend_from_slice(&["--revisions", "all()"]);
        } else {
            cmd_args.extend_from_slice(&["--limit", &limit_str]);
        }

        let result = repo.jj_cmd(&cmd_args)?;
        print!("{}", result);
    }

    Ok(())
}
