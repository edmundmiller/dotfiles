//! Stack detection: walk from bookmarks back to trunk to identify stacks.
//!
//! Inspired by GitButler's workspace model where parallel stacks of commits
//! branch from a common base.

use std::collections::{BTreeMap, HashMap, HashSet};

use anyhow::Result;
use serde::Serialize;

use crate::repo::Repo;

/// A single revision in the DAG.
#[derive(Debug, Clone, Serialize)]
pub struct RevisionInfo {
    pub change_id: String,
    pub commit_id: String,
    pub short_id: String,
    pub description: String,
    pub bookmarks: Vec<String>,
    pub is_empty: bool,
    pub is_immutable: bool,
    pub is_conflicted: bool,
    pub is_working_copy: bool,
    pub parent_change_ids: Vec<String>,
    pub author: String,
    pub timestamp: String,
    /// File changes (status letter + path), populated lazily
    pub files: Vec<FileChange>,
}

#[derive(Debug, Clone, Serialize)]
pub struct FileChange {
    pub status: char,
    pub path: String,
}

/// A stack is a linear chain of revisions from trunk to a bookmark tip.
#[derive(Debug, Clone, Serialize)]
pub struct Stack {
    /// The bookmark names at the tip of this stack
    pub bookmarks: Vec<String>,
    /// Revisions in order from base (closest to trunk) to tip
    pub revisions: Vec<RevisionInfo>,
}

/// The workspace state: stacks + common base + working copy info.
#[derive(Debug, Clone, Serialize)]
pub struct WorkspaceState {
    /// The common merge base (trunk commit)
    pub trunk: Option<RevisionInfo>,
    /// Detected stacks branching from trunk
    pub stacks: Vec<Stack>,
    /// Shared revisions between stacks (fork points)
    pub shared_base: Vec<RevisionInfo>,
    /// Working copy revision (if not part of a stack)
    pub working_copy: Option<RevisionInfo>,
    /// Uncommitted files in working copy
    pub uncommitted_files: Vec<FileChange>,
}

const RS: &str = "\x1e"; // Record separator
const US: &str = "\x1f"; // Unit separator

impl Repo {
    /// Get full workspace state: stacks, trunk, working copy.
    pub fn workspace_state(&self) -> Result<WorkspaceState> {
        // Get all mutable revisions + trunk + working copy
        let revisions = self.query_revisions("trunk().. | trunk()")?;
        let wc_change_id = self.current_change_id()?;

        // Build lookup maps
        let mut by_change_id: BTreeMap<String, RevisionInfo> = BTreeMap::new();
        let mut children: HashMap<String, Vec<String>> = HashMap::new();
        let mut trunk_rev = None;

        for mut rev in revisions {
            rev.is_working_copy = rev.change_id == wc_change_id;
            if rev.is_immutable {
                trunk_rev = Some(rev.clone());
            }
            for parent_id in &rev.parent_change_ids {
                children
                    .entry(parent_id.clone())
                    .or_default()
                    .push(rev.change_id.clone());
            }
            by_change_id.insert(rev.change_id.clone(), rev);
        }

        // Get working copy file changes
        let uncommitted_files = self.query_file_changes("@")?;

        // Identify stack tips: revisions with bookmarks, or leaf revisions (no children)

        // Find bookmark tips
        let mut bookmark_tips: Vec<String> = Vec::new();
        for (cid, rev) in &by_change_id {
            if !rev.bookmarks.is_empty() && !rev.is_immutable {
                bookmark_tips.push(cid.clone());
            }
        }

        // If no bookmarks, treat working copy as a tip
        if bookmark_tips.is_empty() {
            if let Some(wc) = by_change_id.get(&wc_change_id) {
                if !wc.is_immutable {
                    bookmark_tips.push(wc_change_id.clone());
                }
            }
        }

        // Build stacks by walking from each tip back to trunk.
        // Track revision usage counts to detect shared bases.
        let mut stacks = Vec::new();
        let mut used_revisions: HashSet<String> = HashSet::new();

        // First pass: collect all chains
        let mut raw_chains: Vec<Vec<String>> = Vec::new();
        for tip_id in &bookmark_tips {
            let mut chain = Vec::new();
            let mut current = tip_id.clone();
            loop {
                if let Some(rev) = by_change_id.get(&current) {
                    if rev.is_immutable {
                        break;
                    }
                    chain.push(current.clone());
                    if let Some(parent) = rev.parent_change_ids.first() {
                        current = parent.clone();
                    } else {
                        break;
                    }
                } else {
                    break;
                }
            }
            chain.reverse();
            raw_chains.push(chain);
        }

        // Count how many chains use each revision
        let mut rev_usage_count: HashMap<String, usize> = HashMap::new();
        for chain in &raw_chains {
            for cid in chain {
                *rev_usage_count.entry(cid.clone()).or_insert(0) += 1;
            }
        }

        // Build stacks: only include revisions unique to this stack,
        // plus the first shared revision as the "fork point" for context.
        for chain in &raw_chains {
            let mut revisions = Vec::new();
            for cid in chain {
                if let Some(rev) = by_change_id.get(cid) {
                    let count = rev_usage_count.get(cid).copied().unwrap_or(0);
                    // Include if unique to this stack, OR if it's the fork point
                    // (shared but has children unique to this stack)
                    if count <= 1 {
                        revisions.push(rev.clone());
                        used_revisions.insert(cid.clone());
                    }
                }
            }

            if !revisions.is_empty() {
                let bookmarks: Vec<String> = revisions
                    .last()
                    .map(|tip| tip.bookmarks.clone())
                    .unwrap_or_default();

                stacks.push(Stack {
                    bookmarks,
                    revisions,
                });
            }
        }

        // Collect shared base revisions (used by multiple stacks)
        let mut shared_base: Vec<RevisionInfo> = Vec::new();
        for (cid, count) in &rev_usage_count {
            if *count > 1 {
                if let Some(rev) = by_change_id.get(cid) {
                    if !rev.is_immutable {
                        shared_base.push(rev.clone());
                        used_revisions.insert(cid.clone());
                    }
                }
            }
        }
        // Sort shared base from trunk to tip (by walking parents)
        shared_base.sort_by(|a, b| {
            if a.parent_change_ids.contains(&b.change_id) {
                std::cmp::Ordering::Greater
            } else if b.parent_change_ids.contains(&a.change_id) {
                std::cmp::Ordering::Less
            } else {
                a.change_id.cmp(&b.change_id)
            }
        });

        // Working copy outside any stack?
        let working_copy = if !used_revisions.contains(&wc_change_id) {
            by_change_id.get(&wc_change_id).cloned()
        } else {
            None
        };

        // Populate file changes for each revision in stacks
        for stack in &mut stacks {
            for rev in &mut stack.revisions {
                if rev.is_working_copy {
                    rev.files = uncommitted_files.clone();
                } else {
                    // Get diff for this specific revision
                    rev.files = self.query_file_changes_quiet(&rev.change_id);
                }
            }
        }

        Ok(WorkspaceState {
            trunk: trunk_rev,
            stacks,
            shared_base,
            working_copy,
            uncommitted_files,
        })
    }

    /// Query revisions matching a revset, returning structured info.
    fn query_revisions(&self, revset: &str) -> Result<Vec<RevisionInfo>> {
        // Use JSON-ish template to avoid newline-in-field issues.
        // jj's description.first_line() includes trailing newline, so we
        // output each field on its own line in a known order, separated
        // by a record marker.
        let template = format!(
            concat!(
                "change_id",
                " ++ \"{}\" ++ ",
                "commit_id",
                " ++ \"{}\" ++ ",
                // Surround description in markers to handle embedded newlines
                "\"DESC:\" ++ description.first_line().trim() ++ \":DESC\"",
                " ++ \"{}\" ++ ",
                "bookmarks.join(\",\")",
                " ++ \"{}\" ++ ",
                "if(empty, \"empty\", \"changed\")",
                " ++ \"{}\" ++ ",
                "if(immutable, \"immutable\", \"mutable\")",
                " ++ \"{}\" ++ ",
                "parents.map(|p| p.change_id()).join(\",\")",
                " ++ \"{}\" ++ ",
                "if(conflict, \"conflict\", \"clean\")",
                " ++ \"{}\" ++ ",
                "\"AUTH:\" ++ coalesce(author.name(), \"(unknown)\") ++ \":AUTH\"",
                " ++ \"{}\" ++ ",
                "author.timestamp()",
                " ++ \"{}\"",
            ),
            US, US, US, US, US, US, US, US, US, RS,
        );

        let output = self.jj_cmd(&[
            "--config=ui.log-word-wrap=false",
            "log", "--no-graph", "-r", revset, "-T", &template,
        ])?;

        let mut revisions = Vec::new();
        for record in output.split(RS) {
            let record = record.trim();
            if record.is_empty() {
                continue;
            }
            let fields: Vec<&str> = record.split(US).collect();
            if fields.len() < 10 {
                continue;
            }

            let change_id = fields[0].trim().to_string();
            let commit_id = fields[1].trim().to_string();
            let description = extract_delimited(fields[2], "DESC:");
            let bookmarks_str = fields[3].trim();
            let is_empty = fields[4].trim() == "empty";
            let is_immutable = fields[5].trim() == "immutable";
            let parents_str = fields[6].trim();
            let is_conflicted = fields[7].trim() == "conflict";
            let author = extract_delimited(fields[8], "AUTH:");
            let timestamp = fields[9].trim().to_string();

            let bookmarks: Vec<String> = if bookmarks_str.is_empty() {
                Vec::new()
            } else {
                bookmarks_str.split(',').map(|s| s.trim().to_string()).collect()
            };

            let parent_change_ids: Vec<String> = if parents_str.is_empty() {
                Vec::new()
            } else {
                parents_str.split(',').map(|s| s.trim().to_string()).collect()
            };

            let short_id = self
                .shortest_change_id_prefix(&change_id)
                .unwrap_or_else(|_| change_id[..4.min(change_id.len())].to_string());

            revisions.push(RevisionInfo {
                change_id,
                commit_id,
                short_id,
                description,
                bookmarks,
                is_empty,
                is_immutable,
                is_conflicted,
                is_working_copy: false,
                parent_change_ids,
                author,
                timestamp,
                files: Vec::new(),
            });
        }

        Ok(revisions)
    }

    /// Get file changes for a revision.
    fn query_file_changes(&self, rev: &str) -> Result<Vec<FileChange>> {
        let output = self.jj_cmd(&["diff", "--summary", "-r", rev])?;
        Ok(parse_file_changes(&output))
    }

    /// Get file changes, returning empty vec on error (for non-critical display).
    fn query_file_changes_quiet(&self, rev: &str) -> Vec<FileChange> {
        self.query_file_changes(rev).unwrap_or_default()
    }
}

/// Extract content from `TAG:content:TAG` delimited fields, handling embedded newlines.
fn extract_delimited(field: &str, tag: &str) -> String {
    let end_tag = format!(":{}",  tag.trim_end_matches(':'));
    if let Some(start) = field.find(tag) {
        let after_tag = &field[start + tag.len()..];
        if let Some(end) = after_tag.find(&end_tag) {
            return after_tag[..end].trim().to_string();
        }
        return after_tag.trim().to_string();
    }
    field.trim().to_string()
}

fn parse_file_changes(output: &str) -> Vec<FileChange> {
    let mut files = Vec::new();
    for line in output.lines() {
        let line = line.trim();
        if line.len() > 2 && line.chars().nth(1) == Some(' ') {
            let status = line.chars().next().unwrap();
            let path = line[2..].to_string();
            files.push(FileChange { status, path });
        }
    }
    files
}
