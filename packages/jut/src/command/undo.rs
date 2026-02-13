use anyhow::Result;
use colored::Colorize;

use crate::args::Args;
use crate::output::OutputChannel;
use crate::repo::Repo;

pub fn execute(args: &Args, out: &mut OutputChannel) -> Result<()> {
    let repo = Repo::open(&args.current_dir)?;
    let restored_op = repo.undo()?;

    if out.is_json() {
        let json = serde_json::json!({
            "undone": true,
            "restored_operation": restored_op,
        });
        out.write_json(&json)?;
    } else {
        out.human(&format!("{}", "Undone".green().bold()));
        out.human(&format!("Restored operation {}", restored_op));
    }

    if args.status_after {
        crate::command::status::execute(args, out)?;
    }

    Ok(())
}
