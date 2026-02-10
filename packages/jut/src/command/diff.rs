use anyhow::Result;

use crate::args::Args;
use crate::output::OutputChannel;
use crate::repo::Repo;

pub fn execute(args: &Args, out: &mut OutputChannel, target: Option<&str>) -> Result<()> {
    let repo = Repo::discover(&args.current_dir)?;

    let mut cmd_args = vec!["diff"];
    if let Some(t) = target {
        cmd_args.extend_from_slice(&["-r", t]);
    }

    let diff_output = repo.jj_cmd(&cmd_args)?;

    if out.is_json() {
        // Parse diff into structured format
        let mut files: Vec<String> = Vec::new();
        let mut adds = 0usize;
        let mut dels = 0usize;
        for line in diff_output.lines() {
            if line.starts_with("+++ ") || line.starts_with("--- ") {
                let path = line[4..].trim_start_matches("a/").trim_start_matches("b/");
                if !path.is_empty() && path != "/dev/null" && !files.contains(&path.to_string()) {
                    files.push(path.to_string());
                }
            } else if line.starts_with('+') && !line.starts_with("+++") {
                adds += 1;
            } else if line.starts_with('-') && !line.starts_with("---") {
                dels += 1;
            }
        }
        let json = serde_json::json!({
            "target": target,
            "files_changed": files,
            "stats": { "additions": adds, "deletions": dels },
            "raw": diff_output,
        });
        out.write_json(&json)?;
    } else {
        if diff_output.is_empty() {
            out.human("(no changes)");
        } else {
            print!("{}", diff_output);
        }
    }

    Ok(())
}
