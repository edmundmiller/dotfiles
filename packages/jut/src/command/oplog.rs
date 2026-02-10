//! Oplog: operations history for "go back in time".

use anyhow::Result;
use colored::Colorize;
use serde::Serialize;

use crate::args::{Args, OplogAction};
use crate::output::OutputChannel;
use crate::repo::Repo;

const RS: &str = "\x1e";
const US: &str = "\x1f";

#[derive(Debug, Clone, Serialize)]
pub struct OpEntry {
    pub id: String,
    pub short_id: String,
    pub description: String,
    pub timestamp: String,
    pub snapshot: bool,
}

pub fn execute(
    args: &Args,
    out: &mut OutputChannel,
    limit: usize,
    all: bool,
    action: Option<&OplogAction>,
) -> Result<()> {
    if let Some(OplogAction::Restore { op_id }) = action {
        return restore(args, out, op_id);
    }

    list(args, out, limit, all)
}

fn list(args: &Args, out: &mut OutputChannel, limit: usize, show_all: bool) -> Result<()> {
    let repo = Repo::open(&args.current_dir)?;

    // Fetch more than needed so we can filter snapshots and still get `limit` entries
    let fetch_limit = if show_all { limit } else { limit * 3 };

    let template = format!(
        concat!(
            "self.id().short(16)",
            " ++ \"{}\" ++ ",
            "self.description()",
            " ++ \"{}\" ++ ",
            "self.time().start()",
            " ++ \"{}\"",
        ),
        US, US, RS,
    );

    let output = repo.jj_cmd(&[
        "--config=ui.log-word-wrap=false",
        "operation",
        "log",
        "--no-graph",
        "-n",
        &fetch_limit.to_string(),
        "-T",
        &template,
    ])?;

    let mut entries = Vec::new();
    let mut full_ids: Vec<String> = Vec::new();

    for record in output.split(RS) {
        let record = record.trim();
        if record.is_empty() {
            continue;
        }
        let fields: Vec<&str> = record.split(US).collect();
        if fields.len() < 3 {
            continue;
        }

        let id = fields[0].trim().to_string();
        let description = fields[1].trim().to_string();
        let timestamp = fields[2].trim().to_string();

        let is_snapshot = description.contains("snapshot working copy")
            || description.contains("import git refs")
            || description.starts_with("snapshot");

        if !show_all && is_snapshot {
            continue;
        }

        full_ids.push(id.clone());

        entries.push(OpEntry {
            id: id.clone(),
            short_id: String::new(), // filled below
            description,
            timestamp,
            snapshot: is_snapshot,
        });

        if entries.len() >= limit {
            break;
        }
    }

    // Compute short IDs with collision extension
    let short_ids = compute_short_op_ids(&full_ids);
    for (entry, short) in entries.iter_mut().zip(short_ids.iter()) {
        entry.short_id = short.clone();
    }

    if out.is_json() {
        let json = serde_json::json!({
            "operations": entries,
        });
        return out.write_json(&json);
    }

    if entries.is_empty() {
        out.human(&format!("{}", "(no operations)".dimmed()));
        return Ok(());
    }

    out.human(&format!("{}", "Operations:".bold()));
    for entry in &entries {
        let snap_marker = if entry.snapshot {
            " (snapshot)".dimmed().to_string()
        } else {
            String::new()
        };
        out.human(&format!(
            "  {} {} {}{}",
            entry.short_id.blue().underline(),
            entry.timestamp.dimmed(),
            entry.description,
            snap_marker,
        ));
    }

    Ok(())
}

fn restore(args: &Args, out: &mut OutputChannel, op_id: &str) -> Result<()> {
    let repo = Repo::open(&args.current_dir)?;

    repo.jj_cmd(&["operation", "restore", op_id])?;

    if out.is_json() {
        let json = serde_json::json!({
            "restored": true,
            "operation": op_id,
        });
        out.write_json(&json)?;
    } else {
        out.human(&format!(
            "{} to operation {}",
            "Restored".green().bold(),
            op_id.blue().underline(),
        ));
    }

    if args.status_after {
        crate::command::status::execute(args, out)?;
    }

    Ok(())
}

/// Compute shortest unique prefixes for operation IDs.
fn compute_short_op_ids(ids: &[String]) -> Vec<String> {
    let min_len = 4;
    ids.iter()
        .map(|id| {
            let mut len = min_len;
            while len < id.len() {
                let prefix = &id[..len];
                let conflicts = ids.iter().filter(|other| other.starts_with(prefix)).count();
                if conflicts <= 1 {
                    break;
                }
                len += 1;
            }
            id[..len.min(id.len())].to_string()
        })
        .collect()
}
