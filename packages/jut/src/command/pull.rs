//! Pull: fetch + rebase + detect/clean merged bookmarks.

use anyhow::Result;
use colored::Colorize;

use crate::args::Args;
use crate::output::OutputChannel;
use crate::repo::Repo;

pub fn execute(
    args: &Args,
    out: &mut OutputChannel,
    clean: bool,
    no_rebase: bool,
    dry_run: bool,
) -> Result<()> {
    let repo = Repo::open(&args.current_dir)?;

    if dry_run {
        return dry_run_plan(out, no_rebase, clean);
    }

    // 1. Fetch
    let fetch_report = match repo.git_fetch() {
        Ok(report) => Some(report),
        Err(e) => {
            let msg = e.to_string();
            if msg.contains("No git remotes") || msg.contains("No matching remotes") {
                None
            } else {
                return Err(e);
            }
        }
    };
    let fetched = fetch_report.is_some();

    if !out.is_json() {
        if let Some(report) = &fetch_report {
            out.human(&format!("{}", "Fetched".green().bold()));
            out.human(&format!("Remotes: {}", report.remotes.join(", ")));
            if report.imported_refs > 0 {
                out.human(&format!("Imported refs: {}", report.imported_refs));
            }
        } else {
            out.human(&format!("{}", "No remotes to fetch from".dimmed()));
        }
    }

    // 2. Rebase (unless --no-rebase)
    let mut rebased = false;
    let mut conflicts: Vec<String> = Vec::new();

    if !no_rebase {
        match repo.jj_cmd(&[
            "rebase",
            "-b",
            "all:roots(trunk()..mutable())",
            "-d",
            "trunk()",
        ]) {
            Ok(output) => {
                rebased = true;
                if !out.is_json() && !output.trim().is_empty() {
                    out.human(output.trim());
                }
            }
            Err(e) => {
                let msg = e.to_string();
                // "Nothing changed" is not an error
                if msg.contains("Nothing changed") || msg.contains("no matching") {
                    rebased = false;
                } else if msg.contains("conflict") {
                    rebased = true;
                    conflicts.push(msg);
                    if !out.is_json() {
                        out.human(&format!(
                            "{} Rebase produced conflicts",
                            "Warning:".yellow().bold()
                        ));
                    }
                } else {
                    return Err(e);
                }
            }
        }

        if rebased && !out.is_json() {
            out.human(&format!("{}", "Rebased onto trunk".green()));
        }
    }

    // 3. Detect merged bookmarks
    let merged_bookmarks = detect_merged_bookmarks(&repo)?;

    if !merged_bookmarks.is_empty() && !out.is_json() {
        out.human(&format!(
            "\n{} merged bookmarks:",
            "Found".blue().bold()
        ));
        for bm in &merged_bookmarks {
            out.human(&format!("  {} {}", "•".dimmed(), bm.green()));
        }
    }

    // 4. Clean merged bookmarks if requested
    let mut cleaned_bookmarks: Vec<String> = Vec::new();
    if clean && !merged_bookmarks.is_empty() && conflicts.is_empty() {
        for bm in &merged_bookmarks {
            match repo.jj_cmd(&["bookmark", "delete", bm]) {
                Ok(_) => {
                    cleaned_bookmarks.push(bm.clone());
                    if !out.is_json() {
                        out.human(&format!(
                            "  {} {}",
                            "Deleted".red(),
                            bm.green()
                        ));
                    }
                }
                Err(e) => {
                    if !out.is_json() {
                        out.human(&format!(
                            "  {} deleting {}: {}",
                            "Failed".red().bold(),
                            bm,
                            e,
                        ));
                    }
                }
            }
        }
    } else if clean && !conflicts.is_empty() && !out.is_json() {
        out.human(&format!(
            "{} Skipping cleanup due to conflicts",
            "Warning:".yellow().bold()
        ));
    }

    if out.is_json() {
        let json = serde_json::json!({
            "fetched": fetched,
            "rebased": rebased,
            "merged_bookmarks": merged_bookmarks,
            "cleaned_bookmarks": cleaned_bookmarks,
            "conflicts": conflicts,
        });
        out.write_json(&json)?;
    }

    if args.status_after {
        crate::command::status::execute(args, out)?;
    }

    Ok(())
}

/// Detect bookmarks whose commits are ancestors of trunk (merged).
fn detect_merged_bookmarks(repo: &Repo) -> Result<Vec<String>> {
    // Find bookmarks that are ancestors of trunk
    let output = match repo.jj_cmd(&[
        "--config=ui.log-word-wrap=false",
        "log",
        "--no-graph",
        "-r",
        "bookmarks() & ::trunk()",
        "-T",
        r#"bookmarks.join(",") ++ "\n""#,
    ]) {
        Ok(out) => out,
        Err(_) => return Ok(Vec::new()), // No matches = no merged bookmarks
    };

    let mut merged = Vec::new();
    for line in output.lines() {
        let line = line.trim();
        if line.is_empty() {
            continue;
        }
        for bm in line.split(',') {
            let bm = bm.trim();
            // Skip trunk-tracking bookmarks (e.g., main, master)
            if !bm.is_empty() && bm != "main" && bm != "master" && !bm.contains("@") {
                merged.push(bm.to_string());
            }
        }
    }

    merged.sort();
    merged.dedup();
    Ok(merged)
}

fn dry_run_plan(out: &mut OutputChannel, no_rebase: bool, clean: bool) -> Result<()> {
    if out.is_json() {
        let json = serde_json::json!({
            "dry_run": true,
            "plan": {
                "fetch": true,
                "rebase": !no_rebase,
                "clean_merged": clean,
            }
        });
        out.write_json(&json)?;
    } else {
        out.human(&format!("{}", "Dry run plan:".bold()));
        out.human("  1. jj git fetch");
        if !no_rebase {
            out.human("  2. jj rebase -b \"all:roots(trunk()..mutable())\" -d trunk()");
        }
        out.human("  3. Detect merged bookmarks");
        if clean {
            out.human("  4. Delete merged bookmarks");
        }
    }
    Ok(())
}
