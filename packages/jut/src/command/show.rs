use anyhow::Result;

use crate::args::Args;
use crate::output::OutputChannel;
use crate::repo::Repo;

pub fn execute(args: &Args, out: &mut OutputChannel, revision: &str, verbose: bool) -> Result<()> {
    let repo = Repo::open(&args.current_dir)?;

    let show_output = repo.jj_cmd(&["show", "-r", revision])?;

    if out.is_json() {
        let json = serde_json::json!({
            "revision": revision,
            "output": show_output,
        });
        out.write_json(&json)?;
    } else {
        print!("{}", show_output);
        if verbose {
            let diff = repo.jj_cmd(&["diff", "-r", revision])?;
            if !diff.is_empty() {
                println!("\n{}", diff);
            }
        }
    }

    Ok(())
}
