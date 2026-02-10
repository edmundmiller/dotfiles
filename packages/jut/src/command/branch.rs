//! Branch management: create, stack, list, delete, rename bookmarks.

use anyhow::Result;
use colored::Colorize;

use crate::args::Args;
use crate::output::OutputChannel;
use crate::repo::Repo;

/// Parsed branch options from CLI.
pub struct BranchOpts<'a> {
    pub name: Option<&'a str>,
    pub list: bool,
    pub delete: Option<&'a str>,
    pub rename: Option<(&'a str, &'a str)>,
    pub stack: bool,
    pub from: Option<&'a str>,
}

pub fn execute(args: &Args, out: &mut OutputChannel, opts: BranchOpts<'_>) -> Result<()> {
    if opts.list {
        list_branches(args, out)
    } else if let Some(name) = opts.delete {
        delete_branch(args, out, name)
    } else if let Some((old, new)) = opts.rename {
        rename_branch(args, out, old, new)
    } else if let Some(name) = opts.name {
        create(args, out, name, opts.stack, opts.from)
    } else {
        list_branches(args, out)
    }
}

fn create(
    args: &Args,
    out: &mut OutputChannel,
    name: &str,
    stack: bool,
    from: Option<&str>,
) -> Result<()> {
    let repo = Repo::open(&args.current_dir)?;

    let base = if let Some(rev) = from {
        rev.to_string()
    } else if stack {
        "@".to_string()
    } else {
        "trunk()".to_string()
    };

    let base_label = if let Some(rev) = from {
        rev.to_string()
    } else if stack {
        "@".to_string()
    } else {
        "trunk".to_string()
    };

    // Create new revision from base
    repo.jj_cmd(&["new", "-r", &base])?;

    // Set bookmark on new working copy
    repo.jj_cmd(&["bookmark", "set", name])?;

    // Get the new change ID
    let change_id = repo.current_change_id()?;

    if out.is_json() {
        let json = serde_json::json!({
            "created": true,
            "bookmark": name,
            "change_id": change_id,
            "base": base_label,
            "stacked": stack,
        });
        out.write_json(&json)?;
    } else {
        let mode = if stack { "stacked on" } else { "from" };
        out.human(&format!(
            "{} branch {} {} {}",
            "Created".green().bold(),
            name.green().bold(),
            mode,
            base_label.blue(),
        ));
    }

    if args.status_after {
        crate::command::status::execute(args, out)?;
    }

    Ok(())
}

fn list_branches(args: &Args, out: &mut OutputChannel) -> Result<()> {
    let repo = Repo::open(&args.current_dir)?;
    let state = repo.workspace_state()?;

    if out.is_json() {
        let json = serde_json::to_value(&state)?;
        return out.write_json(&json);
    }

    // Reuse status rendering — it already shows stacks with bookmarks
    crate::command::status::execute(args, out)
}

fn delete_branch(args: &Args, out: &mut OutputChannel, name: &str) -> Result<()> {
    let repo = Repo::open(&args.current_dir)?;

    repo.jj_cmd(&["bookmark", "delete", name])?;

    if out.is_json() {
        let json = serde_json::json!({
            "deleted": true,
            "bookmark": name,
        });
        out.write_json(&json)?;
    } else {
        out.human(&format!(
            "{} branch {}",
            "Deleted".red().bold(),
            name.green(),
        ));
    }

    if args.status_after {
        crate::command::status::execute(args, out)?;
    }

    Ok(())
}

fn rename_branch(args: &Args, out: &mut OutputChannel, old: &str, new: &str) -> Result<()> {
    let repo = Repo::open(&args.current_dir)?;

    // jj 0.37: no native rename, so set+delete
    // First get the target of the old bookmark
    let target = repo.jj_cmd(&[
        "log", "--no-graph", "-r", &format!("bookmarks({old})"), "-T", "change_id", "-n", "1",
    ])?;
    let target = target.trim();
    if target.is_empty() {
        anyhow::bail!("bookmark '{}' not found", old);
    }

    // Set new bookmark at same revision, delete old
    repo.jj_cmd(&["bookmark", "set", new, "-r", &format!("bookmarks({old})")])?;
    repo.jj_cmd(&["bookmark", "delete", old])?;

    if out.is_json() {
        let json = serde_json::json!({
            "renamed": true,
            "old": old,
            "new": new,
        });
        out.write_json(&json)?;
    } else {
        out.human(&format!(
            "{} {} → {}",
            "Renamed".green().bold(),
            old.green(),
            new.green().bold(),
        ));
    }

    if args.status_after {
        crate::command::status::execute(args, out)?;
    }

    Ok(())
}
