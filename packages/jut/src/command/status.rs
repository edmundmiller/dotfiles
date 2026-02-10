use anyhow::Result;
use colored::Colorize;

use crate::args::Args;
use crate::output::OutputChannel;
use crate::repo::Repo;

pub fn execute(args: &Args, out: &mut OutputChannel) -> Result<()> {
    execute_with_opts(args, out, false, false)
}

pub fn execute_with_opts(
    args: &Args,
    out: &mut OutputChannel,
    show_files: bool,
    verbose: bool,
) -> Result<()> {
    let repo = Repo::open(&args.current_dir)?;
    let change_id = repo.current_change_id()?;
    let files = repo.changed_files()?;
    let bookmarks = repo.bookmarks()?;

    // Use jj-lib's shortest unique prefix for IDs
    let short_id = repo.shortest_change_id_prefix(&change_id)?;

    if out.is_json() {
        let json = serde_json::json!({
            "change_id": change_id,
            "short_id": short_id,
            "files_changed": files,
            "bookmarks": bookmarks.iter().map(|(name, id)| {
                let short = repo.shortest_change_id_prefix(id).unwrap_or_else(|_| id[..4.min(id.len())].to_string());
                serde_json::json!({
                    "name": name,
                    "change_id": id,
                    "short_id": short,
                })
            }).collect::<Vec<_>>(),
        });
        out.write_json(&json)?;
    } else {
        out.human(&format!(
            "{} {} ({})",
            "@".cyan().bold(),
            short_id.yellow(),
            &change_id[..12.min(change_id.len())]
        ));

        if files.is_empty() {
            out.human("  (no changes)");
        } else {
            out.human(&format!("  {} file(s) changed", files.len()));
            if show_files || true {
                // Always show file names
                for f in &files {
                    out.human(&format!("    {}", f));
                }
            }
        }

        if !bookmarks.is_empty() {
            out.human("");
            out.human(&"Bookmarks:".bold().to_string());
            for (name, id) in &bookmarks {
                let short = repo.shortest_change_id_prefix(id)
                    .unwrap_or_else(|_| id[..4.min(id.len())].to_string());
                out.human(&format!(
                    "  {} {} ({})",
                    short.yellow(),
                    name.green(),
                    &id[..8.min(id.len())]
                ));
            }
        }

        if verbose {
            out.human("");
            let log_output = repo.jj_cmd(&["log", "--limit", "5"])?;
            out.human(&log_output);
        }
    }

    Ok(())
}
