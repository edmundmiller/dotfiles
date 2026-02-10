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
    assert!(
        stdout.contains("file(s) changed") || stdout.contains("no changes"),
        "status should report file changes"
    );
}

#[test]
fn status_json_has_required_fields() {
    let repo = setup_repo();

    let output = jut()
        .args([
            "-C",
            repo.path().to_str().unwrap(),
            "status",
            "--json",
        ])
        .output()
        .unwrap();

    let stdout = String::from_utf8_lossy(&output.stdout);
    let json: serde_json::Value = serde_json::from_str(&stdout).expect("valid JSON");

    assert!(json["change_id"].is_string(), "must have change_id");
    assert!(json["short_id"].is_string(), "must have short_id");
    assert!(json["files_changed"].is_array(), "must have files_changed");
    assert!(json["bookmarks"].is_array(), "must have bookmarks");

    // Short ID should be at least 4 chars
    let short = json["short_id"].as_str().unwrap();
    assert!(short.len() >= 4, "short_id must be >= 4 chars, got {short}");

    // Change ID should be longer than short ID
    let full = json["change_id"].as_str().unwrap();
    assert!(full.len() > short.len(), "change_id should be longer than short_id");
    assert!(full.starts_with(short), "change_id should start with short_id");
}

#[test]
fn status_json_shows_changed_files() {
    let repo = setup_repo();

    let output = jut()
        .args(["-C", repo.path().to_str().unwrap(), "status", "--json"])
        .output()
        .unwrap();

    let json: serde_json::Value =
        serde_json::from_str(&String::from_utf8_lossy(&output.stdout)).unwrap();
    let files = json["files_changed"].as_array().unwrap();

    assert!(
        files.iter().any(|f| f.as_str() == Some("hello.txt")),
        "should show hello.txt as changed, got: {files:?}"
    );
}

#[test]
fn commit_creates_new_change() {
    let repo = setup_repo();
    let path = repo.path().to_str().unwrap();

    // Get initial change ID
    let before = jut()
        .args(["-C", path, "status", "--json"])
        .output()
        .unwrap();
    let before_json: serde_json::Value =
        serde_json::from_str(&String::from_utf8_lossy(&before.stdout)).unwrap();
    let before_id = before_json["change_id"].as_str().unwrap().to_string();

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
    let after_id = after_json["change_id"].as_str().unwrap();

    assert_ne!(before_id, after_id, "commit should create a new change");
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
    // Parse by splitting on "}\n{" boundary
    let full = stdout.to_string();
    assert!(full.contains("committed"), "should have commit result");
    assert!(full.contains("change_id"), "should have status after");

    // Use a streaming JSON deserializer to count objects
    let mut deserializer = serde_json::Deserializer::from_str(&full).into_iter::<serde_json::Value>();
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
    let _json: serde_json::Value = serde_json::from_str(&stdout).expect("--json should produce valid JSON");
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
    let bookmarks = json["bookmarks"].as_array().unwrap();

    assert!(
        bookmarks
            .iter()
            .any(|b| b["name"].as_str() == Some("test-bookmark")),
        "status should list bookmarks, got: {bookmarks:?}"
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
    let before_id = serde_json::from_str::<serde_json::Value>(
        &String::from_utf8_lossy(&before.stdout),
    )
    .unwrap()["change_id"]
        .as_str()
        .unwrap()
        .to_string();

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
    let after_id = serde_json::from_str::<serde_json::Value>(
        &String::from_utf8_lossy(&after.stdout),
    )
    .unwrap()["change_id"]
        .as_str()
        .unwrap()
        .to_string();

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
