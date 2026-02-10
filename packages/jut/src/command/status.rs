//! Status command: GitButler-style workspace visualization.
//!
//! Renders stacks of revisions with tree-drawing characters,
//! inspired by `but status`.

use anyhow::Result;
use colored::Colorize;

use crate::args::Args;
use crate::output::OutputChannel;
use crate::repo::Repo;
use crate::stack::{FileChange, RevisionInfo, Stack, WorkspaceState};

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
    let state = repo.workspace_state()?;

    if out.is_json() {
        return write_json_status(out, &state);
    }

    render_human_status(out, &state, show_files, verbose);
    Ok(())
}

fn write_json_status(out: &mut OutputChannel, state: &WorkspaceState) -> Result<()> {
    let json = serde_json::to_value(state)?;
    out.write_json(&json)
}

fn render_human_status(
    out: &OutputChannel,
    state: &WorkspaceState,
    show_files: bool,
    verbose: bool,
) {
    // Render each stack
    for (i, stack) in state.stacks.iter().enumerate() {
        render_stack(out, stack, show_files, verbose, i == 0);
    }

    // Working copy outside any stack
    if let Some(ref wc) = state.working_copy {
        render_detached_wc(out, wc, &state.uncommitted_files, show_files);
    }

    // Shared base revisions (fork points between stacks)
    for rev in &state.shared_base {
        let id_display = format_id(rev);
        let message = if rev.description.is_empty() {
            "(no description)".dimmed().italic().to_string()
        } else {
            rev.description.chars().take(72).collect::<String>()
        };
        let bookmark_display = if !rev.bookmarks.is_empty() {
            let names: String = rev
                .bookmarks
                .iter()
                .map(|b| b.green().to_string())
                .collect::<Vec<_>>()
                .join(", ");
            format!(" ({})", names)
        } else {
            String::new()
        };
        out.human(&format!(
            "┊● {} {}{} (shared base)",
            id_display,
            message,
            bookmark_display,
        ));
    }

    // Common base (trunk)
    if let Some(ref trunk) = state.trunk {
        let trunk_bookmarks: String = trunk
            .bookmarks
            .iter()
            .map(|b| b.green().bold().to_string())
            .collect::<Vec<_>>()
            .join(", ");

        let bookmark_display = if trunk_bookmarks.is_empty() {
            String::new()
        } else {
            format!(" [{}]", trunk_bookmarks)
        };

        out.human(&format!(
            "┴ {} (trunk){} {}",
            trunk.short_id.dimmed(),
            bookmark_display,
            trunk
                .description
                .chars()
                .take(50)
                .collect::<String>()
                .dimmed(),
        ));
    }
}

fn render_stack(
    out: &OutputChannel,
    stack: &Stack,
    show_files: bool,
    verbose: bool,
    _first: bool,
) {
    if stack.revisions.is_empty() {
        return;
    }

    let tip = stack.revisions.last().unwrap();

    // Stack header: bookmark name
    let branch_names: String = stack
        .bookmarks
        .iter()
        .map(|b| b.green().bold().to_string())
        .collect::<Vec<_>>()
        .join(", ");

    let branch_display = if branch_names.is_empty() {
        "(no bookmark)".dimmed().to_string()
    } else {
        branch_names
    };

    // Top-level ID for the stack
    let stack_id = tip.short_id.clone();
    out.human(&format!(
        "╭┄{} [{}]",
        stack_id.underline().blue(),
        branch_display,
    ));

    // Render commits from tip to base (newest first, like `but status`)
    for rev in stack.revisions.iter().rev() {
        render_commit(out, rev, show_files, verbose);
    }

    out.human(&format!("├╯"));
    out.human("┊");
}

fn render_commit(
    out: &OutputChannel,
    rev: &RevisionInfo,
    show_files: bool,
    verbose: bool,
) {
    let dot = commit_dot(rev);
    let id_display = format_id(rev);
    let message = if rev.description.is_empty() {
        "(no description)".dimmed().italic().to_string()
    } else {
        rev.description.chars().take(72).collect::<String>()
    };

    let empty_marker = if rev.is_empty && !rev.is_working_copy {
        " ∅".dimmed().to_string()
    } else {
        String::new()
    };

    let conflict_marker = if rev.is_conflicted {
        " {conflicted}".red().to_string()
    } else {
        String::new()
    };

    let wc_marker = if rev.is_working_copy {
        format!(" {}", "@".cyan().bold())
    } else {
        String::new()
    };

    // Inline bookmark display
    let bookmark_display = if !rev.bookmarks.is_empty() {
        let names: String = rev
            .bookmarks
            .iter()
            .map(|b| b.green().to_string())
            .collect::<Vec<_>>()
            .join(", ");
        format!(" ({})", names)
    } else {
        String::new()
    };

    if verbose {
        out.human(&format!(
            "┊{dot} {id_display} {} {}{wc_marker}{empty_marker}{conflict_marker}",
            rev.author,
            rev.timestamp.dimmed(),
        ));
        out.human(&format!(
            "┊│     {message}{bookmark_display}",
        ));
    } else {
        out.human(&format!(
            "┊{dot} {id_display} {message}{bookmark_display}{wc_marker}{empty_marker}{conflict_marker}",
        ));
    }

    // File changes
    if show_files || rev.is_working_copy {
        for file in &rev.files {
            let path_display = format_file_path(file);
            out.human(&format!("┊│     {} {}", file.status, path_display));
        }
        if rev.files.is_empty() && rev.is_working_copy {
            out.human(&format!("┊│     {}", "(no changes)".dimmed().italic()));
        }
    }
}

fn render_detached_wc(
    out: &OutputChannel,
    wc: &RevisionInfo,
    files: &[FileChange],
    show_files: bool,
) {
    let id_display = format_id(wc);
    let message = if wc.description.is_empty() {
        "(no description)".dimmed().italic().to_string()
    } else {
        wc.description.clone()
    };

    out.human(&format!(
        "╭┄{} [{}]",
        id_display,
        "working copy".cyan().bold(),
    ));
    out.human(&format!(
        "┊{} {} {} {}",
        "●".cyan(),
        wc.short_id.underline().blue(),
        "@".cyan().bold(),
        message,
    ));

    if show_files || true {
        // Always show files for working copy
        for file in files {
            let path_display = format_file_path(file);
            out.human(&format!("┊│     {} {}", file.status, path_display));
        }
        if files.is_empty() {
            out.human(&format!("┊│     {}", "(no changes)".dimmed().italic()));
        }
    }

    out.human("├╯");
    out.human("┊");
}

/// Colored dot for commit classification.
fn commit_dot(rev: &RevisionInfo) -> colored::ColoredString {
    if rev.is_working_copy {
        "●".cyan()
    } else if rev.is_conflicted {
        "●".red()
    } else if rev.is_empty {
        "○".dimmed()
    } else {
        "●".normal()
    }
}

/// Format the revision ID display: short_id + dimmed remainder.
fn format_id(rev: &RevisionInfo) -> String {
    let short = &rev.short_id;
    let full = &rev.commit_id;
    let end = if short.len() < 7 && full.len() >= 7 {
        full[short.len()..7].dimmed().to_string()
    } else {
        String::new()
    };
    format!("{}{}", short.underline().blue(), end)
}

/// Color file paths by status.
fn format_file_path(file: &FileChange) -> colored::ColoredString {
    match file.status {
        'A' => file.path.green(),
        'D' => file.path.red(),
        'M' => file.path.yellow(),
        'R' => file.path.purple(),
        _ => file.path.normal(),
    }
}
