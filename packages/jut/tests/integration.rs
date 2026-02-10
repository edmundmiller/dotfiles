//! Integration tests for jut.
//!
//! These test actual jut behavior against real jj repos.
//! Requires `jj` CLI installed.

use std::process::Command;

use assert_cmd::Command as AssertCmd;
use tempfile::TempDir;

/// Create a jj repo in a temp dir with some initial content.
fn setup_repo() -> TempDir {
    let dir = TempDir::new().unwrap();
    let path = dir.path();

    // Init jj repo
    Command::new("jj")
        .args(["git", "init"])
        .current_dir(path)
        .output()
        .expect("jj must be installed");

    // Create a file and describe
    std::fs::write(path.join("hello.txt"), "hello world\n").unwrap();
    Command::new("jj")
        .args(["describe", "-m", "initial commit"])
        .current_dir(path)
        .output()
        .unwrap();

    dir
}

#[allow(deprecated)]
fn jut() -> AssertCmd {
    AssertCmd::cargo_bin("jut").unwrap()
}

// --- Spec tests: document intended feature behavior ---

#[test]
fn status_shows_current_change() {
    let repo = setup_repo();

    let output = jut()
        .args(["-C", repo.path().to_str().unwrap(), "status"])
        .output()
        .unwrap();

    let stdout = String::from_utf8_lossy(&output.stdout);
    assert!(stdout.contains("@"), "status should show @ marker");
}

#[test]
fn status_json_has_workspace_structure() {
    let repo = setup_repo();

    let output = jut()
        .args(["-C", repo.path().to_str().unwrap(), "status", "--json"])
        .output()
        .unwrap();

    let stdout = String::from_utf8_lossy(&output.stdout);
    let json: serde_json::Value = serde_json::from_str(&stdout).expect("valid JSON");

    // New workspace structure
    assert!(json["stacks"].is_array(), "must have stacks");
    assert!(json["uncommitted_files"].is_array(), "must have uncommitted_files");

    // Should have at least one stack (working copy creates one if no bookmarks)
    let stacks = json["stacks"].as_array().unwrap();
    assert!(!stacks.is_empty(), "should have at least one stack");

    // First stack should have revisions
    let revisions = stacks[0]["revisions"].as_array().unwrap();
    assert!(!revisions.is_empty(), "stack should have revisions");

    // Each revision should have required fields
    let rev = &revisions[0];
    assert!(rev["change_id"].is_string(), "revision must have change_id");
    assert!(rev["short_id"].is_string(), "revision must have short_id");
    assert!(rev["description"].is_string(), "revision must have description");

    // Short ID should be at least 4 chars
    let short = rev["short_id"].as_str().unwrap();
    assert!(short.len() >= 4, "short_id must be >= 4 chars, got {short}");
}

#[test]
fn status_json_shows_working_copy_files() {
    let repo = setup_repo();

    // Track the file first
    Command::new("jj")
        .args(["file", "track", "hello.txt"])
        .current_dir(repo.path())
        .output()
        .unwrap();

    let output = jut()
        .args(["-C", repo.path().to_str().unwrap(), "status", "--json"])
        .output()
        .unwrap();

    let json: serde_json::Value =
        serde_json::from_str(&String::from_utf8_lossy(&output.stdout)).unwrap();

    // Check uncommitted_files or files within the working copy revision
    let stacks = json["stacks"].as_array().unwrap();
    let has_file = stacks.iter().any(|stack| {
        stack["revisions"].as_array().map_or(false, |revs| {
            revs.iter().any(|rev| {
                rev["is_working_copy"].as_bool() == Some(true)
                    && rev["files"].as_array().map_or(false, |files| {
                        files
                            .iter()
                            .any(|f| f["path"].as_str() == Some("hello.txt"))
                    })
            })
        })
    });

    assert!(has_file, "should show hello.txt in working copy files");
}

#[test]
fn commit_creates_new_change() {
    let repo = setup_repo();
    let path = repo.path().to_str().unwrap();

    // Get initial working copy change ID
    let before = jut()
        .args(["-C", path, "status", "--json"])
        .output()
        .unwrap();
    let before_json: serde_json::Value =
        serde_json::from_str(&String::from_utf8_lossy(&before.stdout)).unwrap();
    let before_id = find_working_copy_change_id(&before_json);

    // Commit
    jut()
        .args(["-C", path, "commit", "-m", "test commit"])
        .assert()
        .success();

    // New change should have different ID
    let after = jut()
        .args(["-C", path, "status", "--json"])
        .output()
        .unwrap();
    let after_json: serde_json::Value =
        serde_json::from_str(&String::from_utf8_lossy(&after.stdout)).unwrap();
    let after_id = find_working_copy_change_id(&after_json);

    assert_ne!(before_id, after_id, "commit should create a new change");
}

/// Find the working copy change_id from the new workspace JSON structure.
fn find_working_copy_change_id(json: &serde_json::Value) -> String {
    // Check stacks for working copy
    if let Some(stacks) = json["stacks"].as_array() {
        for stack in stacks {
            if let Some(revs) = stack["revisions"].as_array() {
                for rev in revs {
                    if rev["is_working_copy"].as_bool() == Some(true) {
                        return rev["change_id"].as_str().unwrap().to_string();
                    }
                }
            }
        }
    }
    // Check standalone working_copy
    if let Some(wc) = json["working_copy"].as_object() {
        return wc["change_id"].as_str().unwrap().to_string();
    }
    panic!("no working copy found in JSON output");
}

#[test]
fn commit_json_output() {
    let repo = setup_repo();

    let output = jut()
        .args([
            "-C",
            repo.path().to_str().unwrap(),
            "commit",
            "-m",
            "json commit test",
            "--json",
        ])
        .output()
        .unwrap();

    let stdout = String::from_utf8_lossy(&output.stdout);
    let json: serde_json::Value = serde_json::from_str(&stdout).expect("valid JSON");

    assert_eq!(json["committed"], true);
    assert_eq!(json["message"], "json commit test");
    assert!(json["new_change_id"].is_string());
}

#[test]
fn status_after_flag_appends_status() {
    let repo = setup_repo();

    let output = jut()
        .args([
            "-C",
            repo.path().to_str().unwrap(),
            "commit",
            "-m",
            "status-after test",
            "--json",
            "--status-after",
        ])
        .output()
        .unwrap();

    let stdout = String::from_utf8_lossy(&output.stdout);

    // Should contain two pretty-printed JSON objects
    let full = stdout.to_string();
    assert!(full.contains("committed"), "should have commit result");
    assert!(full.contains("stacks"), "should have status after with stacks");

    // Use a streaming JSON deserializer to count objects
    let mut deserializer =
        serde_json::Deserializer::from_str(&full).into_iter::<serde_json::Value>();
    let mut count = 0;
    while let Some(Ok(_)) = deserializer.next() {
        count += 1;
    }
    assert!(count >= 2, "should have at least 2 JSON objects, got {count}");
}

#[test]
fn log_shows_history() {
    let repo = setup_repo();

    let output = jut()
        .args(["-C", repo.path().to_str().unwrap(), "log"])
        .output()
        .unwrap();

    let stdout = String::from_utf8_lossy(&output.stdout);
    assert!(
        stdout.contains("initial commit"),
        "log should show commit description"
    );
}

#[test]
fn diff_runs_without_error() {
    let repo = setup_repo();

    jut()
        .args(["-C", repo.path().to_str().unwrap(), "diff"])
        .assert()
        .success();
}

#[test]
fn show_displays_revision() {
    let repo = setup_repo();

    let output = jut()
        .args(["-C", repo.path().to_str().unwrap(), "show", "@"])
        .output()
        .unwrap();

    let stdout = String::from_utf8_lossy(&output.stdout);
    assert!(stdout.contains("Change ID:"), "show should display change ID");
    assert!(
        stdout.contains("initial commit"),
        "show should display description"
    );
}

#[test]
fn json_flag_works_globally() {
    let repo = setup_repo();

    // --json before subcommand
    let output = jut()
        .args(["--json", "-C", repo.path().to_str().unwrap(), "status"])
        .output()
        .unwrap();

    let stdout = String::from_utf8_lossy(&output.stdout);
    let json: serde_json::Value =
        serde_json::from_str(&stdout).expect("--json should produce valid JSON");
    assert!(json["stacks"].is_array(), "JSON should have stacks");
}

#[test]
fn bookmarks_shown_in_status() {
    let repo = setup_repo();
    let path = repo.path().to_str().unwrap();

    // Create a bookmark
    Command::new("jj")
        .args(["bookmark", "create", "test-bookmark"])
        .current_dir(repo.path())
        .output()
        .unwrap();

    let output = jut()
        .args(["-C", path, "status", "--json"])
        .output()
        .unwrap();

    let json: serde_json::Value =
        serde_json::from_str(&String::from_utf8_lossy(&output.stdout)).unwrap();
    let stacks = json["stacks"].as_array().unwrap();

    // The bookmark should appear in a stack's bookmarks or revision's bookmarks
    let has_bookmark = stacks.iter().any(|stack| {
        stack["bookmarks"]
            .as_array()
            .map_or(false, |bs| bs.iter().any(|b| b.as_str() == Some("test-bookmark")))
    });

    assert!(
        has_bookmark,
        "status should show test-bookmark in stacks, got: {stacks:?}"
    );
}

#[test]
fn undo_reverts_last_operation() {
    let repo = setup_repo();
    let path = repo.path().to_str().unwrap();

    // Get initial state
    let before = jut()
        .args(["-C", path, "status", "--json"])
        .output()
        .unwrap();
    let before_json: serde_json::Value =
        serde_json::from_str(&String::from_utf8_lossy(&before.stdout)).unwrap();
    let before_id = find_working_copy_change_id(&before_json);

    // Commit (changes state)
    jut()
        .args(["-C", path, "commit", "-m", "to be undone"])
        .assert()
        .success();

    // Undo
    jut()
        .args(["-C", path, "undo"])
        .assert()
        .success();

    // Should be back to original change
    let after = jut()
        .args(["-C", path, "status", "--json"])
        .output()
        .unwrap();
    let after_json: serde_json::Value =
        serde_json::from_str(&String::from_utf8_lossy(&after.stdout)).unwrap();
    let after_id = find_working_copy_change_id(&after_json);

    assert_eq!(before_id, after_id, "undo should restore previous change");
}

#[test]
fn no_repo_gives_error() {
    let dir = TempDir::new().unwrap();

    jut()
        .args(["-C", dir.path().to_str().unwrap(), "status"])
        .assert()
        .failure();
}

// --- Regression: stacked branches visualization ---

#[test]
fn status_shows_stacked_branches() {
    let repo = setup_repo();
    let path = repo.path();

    // Create a stack: commit1 -> commit2 (with bookmark)
    Command::new("jj")
        .args(["new", "-m", "second commit"])
        .current_dir(path)
        .output()
        .unwrap();
    std::fs::write(path.join("file2.txt"), "content\n").unwrap();
    Command::new("jj")
        .args(["file", "track", "file2.txt"])
        .current_dir(path)
        .output()
        .unwrap();
    Command::new("jj")
        .args(["bookmark", "set", "my-feature"])
        .current_dir(path)
        .output()
        .unwrap();

    let output = jut()
        .args(["-C", path.to_str().unwrap(), "status"])
        .output()
        .unwrap();

    let stdout = String::from_utf8_lossy(&output.stdout);

    // Should show stack structure with tree characters
    assert!(stdout.contains("╭"), "should have stack header");
    assert!(stdout.contains("my-feature"), "should show bookmark name");
    assert!(stdout.contains("├╯"), "should have stack footer");
    assert!(stdout.contains("┴"), "should have trunk marker");
}

#[test]
fn status_shows_parallel_stacks() {
    let repo = setup_repo();
    let path = repo.path();

    // Create first stack with bookmark
    Command::new("jj")
        .args(["new", "-m", "feature-a work"])
        .current_dir(path)
        .output()
        .unwrap();
    std::fs::write(path.join("file_a.txt"), "a content\n").unwrap();
    Command::new("jj")
        .args(["file", "track", "file_a.txt"])
        .current_dir(path)
        .output()
        .unwrap();

    // Save the feature-a change id before moving working copy
    let feature_a_id = {
        let out = Command::new("jj")
            .args(["log", "--no-graph", "-T", "change_id.shortest(8)", "-r", "@", "-n", "1"])
            .current_dir(path)
            .output()
            .unwrap();
        String::from_utf8_lossy(&out.stdout).trim().to_string()
    };

    // Get the initial commit's change ID for branching (parent of @)
    let init_id = {
        let out = Command::new("jj")
            .args(["log", "--no-graph", "-T", "change_id.shortest(8)", "-r", "@-", "-n", "1"])
            .current_dir(path)
            .output()
            .unwrap();
        String::from_utf8_lossy(&out.stdout).trim().to_string()
    };

    // Create parallel stack from initial commit
    Command::new("jj")
        .args(["new", "-m", "feature-b work", "-r", &init_id])
        .current_dir(path)
        .output()
        .unwrap();
    std::fs::write(path.join("file_b.txt"), "b content\n").unwrap();
    Command::new("jj")
        .args(["file", "track", "file_b.txt"])
        .current_dir(path)
        .output()
        .unwrap();

    // Now set bookmarks on the correct revisions
    Command::new("jj")
        .args(["bookmark", "set", "feature-a", "-r", &feature_a_id])
        .current_dir(path)
        .output()
        .unwrap();
    Command::new("jj")
        .args(["bookmark", "set", "feature-b"])
        .current_dir(path)
        .output()
        .unwrap();

    let output = jut()
        .args(["-C", path.to_str().unwrap(), "status"])
        .output()
        .unwrap();

    let stdout = String::from_utf8_lossy(&output.stdout);

    // Should show both stacks
    assert!(
        stdout.contains("feature-a"),
        "should show feature-a: {stdout}"
    );
    assert!(
        stdout.contains("feature-b"),
        "should show feature-b: {stdout}"
    );
    // Should have two stack headers
    assert!(
        stdout.matches("╭┄").count() >= 2,
        "should have at least 2 stacks: {stdout}"
    );
}

// --- Branch command tests ---

#[test]
fn branch_create_parallel() {
    let repo = setup_repo();
    let path = repo.path().to_str().unwrap();

    // Commit so we have a trunk
    jut()
        .args(["-C", path, "commit", "-m", "base work"])
        .assert()
        .success();

    let output = jut()
        .args(["-C", path, "branch", "my-feature", "--json"])
        .output()
        .unwrap();

    let stdout = String::from_utf8_lossy(&output.stdout);
    let json: serde_json::Value = serde_json::from_str(&stdout).expect("valid JSON");

    assert_eq!(json["created"], true);
    assert_eq!(json["bookmark"], "my-feature");
    assert!(json["change_id"].is_string());
    assert_eq!(json["base"], "trunk");
    assert_eq!(json["stacked"], false);
}

#[test]
fn branch_create_stacked() {
    let repo = setup_repo();
    let path = repo.path().to_str().unwrap();

    let output = jut()
        .args(["-C", path, "branch", "stacked-work", "-s", "--json"])
        .output()
        .unwrap();

    let stdout = String::from_utf8_lossy(&output.stdout);
    let json: serde_json::Value = serde_json::from_str(&stdout).expect("valid JSON");

    assert_eq!(json["created"], true);
    assert_eq!(json["bookmark"], "stacked-work");
    assert_eq!(json["stacked"], true);
    assert_eq!(json["base"], "@");
}

#[test]
fn branch_list_shows_bookmarks() {
    let repo = setup_repo();
    let path = repo.path().to_str().unwrap();

    // Create a bookmark
    Command::new("jj")
        .args(["bookmark", "set", "test-branch"])
        .current_dir(repo.path())
        .output()
        .unwrap();

    let output = jut()
        .args(["-C", path, "branch", "--list"])
        .output()
        .unwrap();

    let stdout = String::from_utf8_lossy(&output.stdout);
    assert!(stdout.contains("test-branch"), "list should show bookmark: {stdout}");
}

#[test]
fn branch_delete_removes_bookmark() {
    let repo = setup_repo();
    let path = repo.path().to_str().unwrap();

    // Create then delete
    Command::new("jj")
        .args(["bookmark", "set", "to-delete"])
        .current_dir(repo.path())
        .output()
        .unwrap();

    let output = jut()
        .args(["-C", path, "branch", "-d", "to-delete", "--json"])
        .output()
        .unwrap();

    let stdout = String::from_utf8_lossy(&output.stdout);
    let json: serde_json::Value = serde_json::from_str(&stdout).expect("valid JSON");

    assert_eq!(json["deleted"], true);
    assert_eq!(json["bookmark"], "to-delete");

    // Verify it's gone
    let bookmarks = Command::new("jj")
        .args(["bookmark", "list"])
        .current_dir(repo.path())
        .output()
        .unwrap();
    let bm_out = String::from_utf8_lossy(&bookmarks.stdout);
    assert!(!bm_out.contains("to-delete"), "bookmark should be deleted");
}

#[test]
fn branch_rename() {
    let repo = setup_repo();
    let path = repo.path().to_str().unwrap();

    Command::new("jj")
        .args(["bookmark", "set", "old-name"])
        .current_dir(repo.path())
        .output()
        .unwrap();

    let output = jut()
        .args(["-C", path, "branch", "--rename", "old-name", "new-name", "--json"])
        .output()
        .unwrap();

    let stdout = String::from_utf8_lossy(&output.stdout);
    let json: serde_json::Value = serde_json::from_str(&stdout).expect("valid JSON");

    assert_eq!(json["renamed"], true);
    assert_eq!(json["old"], "old-name");
    assert_eq!(json["new"], "new-name");

    // Verify
    let bookmarks = Command::new("jj")
        .args(["bookmark", "list"])
        .current_dir(repo.path())
        .output()
        .unwrap();
    let bm_out = String::from_utf8_lossy(&bookmarks.stdout);
    assert!(bm_out.contains("new-name"), "new name should exist");
    assert!(!bm_out.contains("old-name"), "old name should be gone");
}

// --- Pull command tests ---

#[test]
fn pull_basic_fetch() {
    let repo = setup_repo();
    let path = repo.path().to_str().unwrap();

    // Without a remote, fetch gracefully reports no remotes
    let output = jut()
        .args(["-C", path, "pull", "--no-rebase", "--json"])
        .output()
        .unwrap();

    let stdout = String::from_utf8_lossy(&output.stdout);
    let json: serde_json::Value = serde_json::from_str(&stdout).expect("valid JSON");

    // No remote = fetched is false, but command succeeds
    assert_eq!(json["fetched"], false);
    assert_eq!(json["rebased"], false);
}

#[test]
fn pull_dry_run() {
    let repo = setup_repo();
    let path = repo.path().to_str().unwrap();

    let output = jut()
        .args(["-C", path, "pull", "--dry-run", "--json"])
        .output()
        .unwrap();

    let stdout = String::from_utf8_lossy(&output.stdout);
    let json: serde_json::Value = serde_json::from_str(&stdout).expect("valid JSON");

    assert_eq!(json["dry_run"], true);
    assert!(json["plan"]["fetch"].as_bool().unwrap());
    assert!(json["plan"]["rebase"].as_bool().unwrap());
}

#[test]
fn pull_dry_run_no_rebase() {
    let repo = setup_repo();
    let path = repo.path().to_str().unwrap();

    let output = jut()
        .args(["-C", path, "pull", "--dry-run", "--no-rebase", "--json"])
        .output()
        .unwrap();

    let stdout = String::from_utf8_lossy(&output.stdout);
    let json: serde_json::Value = serde_json::from_str(&stdout).expect("valid JSON");

    assert!(!json["plan"]["rebase"].as_bool().unwrap());
}

// --- Oplog command tests ---

#[test]
fn oplog_lists_operations() {
    let repo = setup_repo();
    let path = repo.path().to_str().unwrap();

    let output = jut()
        .args(["-C", path, "oplog", "--json"])
        .output()
        .unwrap();

    let stdout = String::from_utf8_lossy(&output.stdout);
    let json: serde_json::Value = serde_json::from_str(&stdout).expect("valid JSON");

    let ops = json["operations"].as_array().unwrap();
    assert!(!ops.is_empty(), "should have at least one operation");

    // Each op should have required fields
    let op = &ops[0];
    assert!(op["id"].is_string());
    assert!(op["short_id"].is_string());
    assert!(op["description"].is_string());
    assert!(op["timestamp"].is_string());
}

#[test]
fn oplog_limit_works() {
    let repo = setup_repo();
    let path = repo.path().to_str().unwrap();

    // Do some operations to have history
    for i in 0..3 {
        jut()
            .args(["-C", path, "commit", "-m", &format!("commit {i}")])
            .assert()
            .success();
    }

    let output = jut()
        .args(["-C", path, "oplog", "-n", "2", "--json"])
        .output()
        .unwrap();

    let stdout = String::from_utf8_lossy(&output.stdout);
    let json: serde_json::Value = serde_json::from_str(&stdout).expect("valid JSON");

    let ops = json["operations"].as_array().unwrap();
    assert!(ops.len() <= 2, "should respect limit, got {}", ops.len());
}

#[test]
fn oplog_restore_works() {
    let repo = setup_repo();
    let path = repo.path().to_str().unwrap();

    // Get current op ID
    let before = jut()
        .args(["-C", path, "oplog", "--json", "-n", "1"])
        .output()
        .unwrap();
    let before_json: serde_json::Value =
        serde_json::from_str(&String::from_utf8_lossy(&before.stdout)).unwrap();
    let op_id = before_json["operations"][0]["id"].as_str().unwrap().to_string();

    // Make a change
    jut()
        .args(["-C", path, "commit", "-m", "to be restored away"])
        .assert()
        .success();

    // Restore
    let output = jut()
        .args(["-C", path, "oplog", "restore", &op_id, "--json"])
        .output()
        .unwrap();

    let stdout = String::from_utf8_lossy(&output.stdout);
    let json: serde_json::Value = serde_json::from_str(&stdout).expect("valid JSON");

    assert_eq!(json["restored"], true);

}

#[test]
fn oplog_human_output() {
    let repo = setup_repo();
    let path = repo.path().to_str().unwrap();

    let output = jut()
        .args(["-C", path, "oplog"])
        .output()
        .unwrap();

    let stdout = String::from_utf8_lossy(&output.stdout);
    assert!(stdout.contains("Operations:"), "should show header: {stdout}");
}
