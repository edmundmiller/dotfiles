use anyhow::Result;
use colored::Colorize;

use crate::args::Args;
use crate::id::IdMap;
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
    let repo = Repo::discover(&args.current_dir)?;
    let change_id = repo.current_change_id()?;
    let files = repo.changed_files()?;
    let bookmarks = repo.bookmarks()?;

    // Build ID map from all visible change IDs
    let mut all_ids: Vec<String> = bookmarks.iter().map(|(_, id)| id.clone()).collect();
    all_ids.push(change_id.clone());
    let id_map = IdMap::build(&all_ids);

    if out.is_json() {
        let json = serde_json::json!({
            "change_id": change_id,
            "short_id": id_map.short_id(&change_id),
            "files_changed": files,
            "bookmarks": bookmarks.iter().map(|(name, id)| {
                serde_json::json!({
                    "name": name,
                    "change_id": id,
                    "short_id": id_map.short_id(id),
                })
            }).collect::<Vec<_>>(),
        });
        out.write_json(&json)?;
    } else {
        let short = id_map.short_id(&change_id);
        out.human(&format!(
            "{} {} ({})",
            "@".cyan().bold(),
            short.yellow(),
            &change_id[..12.min(change_id.len())]
        ));

        if files.is_empty() {
            out.human("  (no changes)");
        } else {
            out.human(&format!("  {} file(s) changed", files.len()));
            if show_files {
                for f in &files {
                    out.human(&format!("    {}", f));
                }
            }
        }

        if !bookmarks.is_empty() {
            out.human("");
            out.human(&"Bookmarks:".bold().to_string());
            for (name, id) in &bookmarks {
                let short = id_map.short_id(id);
                out.human(&format!(
                    "  {} {} ({})",
                    short.yellow(),
                    name.green(),
                    &id[..8.min(id.len())]
                ));
            }
        }

        if verbose {
            // Show recent log
            out.human("");
            let log_output = repo.jj_cmd(&["log", "--limit", "5"])?;
            out.human(&log_output);
        }
    }

    Ok(())
}
