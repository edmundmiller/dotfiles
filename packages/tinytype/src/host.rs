use std::path::PathBuf;
use std::process::Command;
use std::sync::{
    Arc,
    atomic::{AtomicU64, Ordering},
    mpsc::{Receiver, RecvTimeoutError},
};
use std::time::{Duration, Instant};

use serde::{Deserialize, Serialize};
use serde_json::{Value, json};

use crate::{engine::JsonChild, ui::Ui};

/// Only explicit UI actions cross into the native host.
pub enum Request {
    Check(String),
    Enabled(u64),
    Permission,
    KeyboardSettings,
    Undo,
    Shutdown,
}

/// Offsets are UTF-16 units, shared by JavaScript and macOS Accessibility.
#[derive(Clone, Debug, Deserialize, PartialEq, Serialize)]
pub struct Snapshot {
    pub token: u64,
    pub text: String,
    pub caret: usize,
    pub pid: i32,
    pub bundle: String,
}

fn resources() -> Result<PathBuf, String> {
    if let Some(path) = std::env::var_os("TINYTYPE_RESOURCES") {
        return Ok(path.into());
    }
    let executable = std::env::current_exe()
        .and_then(|p| p.canonicalize())
        .map_err(|_| "TinyType cannot locate its app bundle")?;
    Ok(executable
        .parent()
        .and_then(|p| p.parent())
        .ok_or("TinyType cannot locate its resources")?
        .join("Resources"))
}

fn start_engine(resources: &std::path::Path) -> Result<JsonChild, String> {
    let node = std::env::var_os("TINYTYPE_NODE")
        .map(PathBuf::from)
        .unwrap_or_else(|| resources.join("node"));
    let mut engine = JsonChild::start(
        Command::new(node)
            .arg(resources.join("engine/tinyfix-worker.mjs"))
            .arg(resources.join("models")),
    )?;
    if engine.receive()?.get("ready").and_then(Value::as_bool) != Some(true) {
        return Err("TinyType model could not load".into());
    }
    Ok(engine)
}

/// The host serializes inference and native edits away from Rune's UI thread.
pub fn run(requests: Receiver<Request>, enabled: Arc<AtomicU64>, handle: rune::AppHandle<Ui>) {
    if let Err(error) = work(requests, enabled.clone(), &handle) {
        enabled.fetch_and(!1, Ordering::SeqCst);
        handle.update(move |s, _| {
            s.enabled = false;
            s.busy = false;
            s.ready = false;
            s.apple_autocorrect = None;
            s.status = error;
        });
    }
}

fn work(
    requests: Receiver<Request>,
    enabled: Arc<AtomicU64>,
    handle: &rune::AppHandle<Ui>,
) -> Result<(), String> {
    let resources = resources()?;
    let mut engine = start_engine(&resources)?;
    let mut native = JsonChild::start(&mut Command::new(resources.join("focused-text")))?;
    let status = native.request(json!({"op":"status"}))?;
    let trusted = status["trusted"].as_bool().unwrap_or(false);
    let apple_autocorrect = status["apple_autocorrect"].as_bool();
    handle.update(move |s, _| {
        s.ready = true;
        s.trusted = trusted;
        s.apple_autocorrect = apple_autocorrect;
        s.status = "Model ready. Autocorrect is paused.".into();
    });
    let mut previous: Option<Snapshot> = None;
    let mut pending = false;
    let mut changed = Instant::now();
    let mut permission_checked = Instant::now();
    loop {
        if permission_checked.elapsed() >= Duration::from_secs(2) {
            let status = native.request(json!({"op":"status"}))?;
            let trusted = status["trusted"].as_bool().unwrap_or(false);
            let apple_autocorrect = status["apple_autocorrect"].as_bool();
            if !trusted {
                enabled.fetch_and(!1, Ordering::SeqCst);
                previous = None;
                pending = false;
            }
            handle.update(move |s, _| {
                if trusted && !s.trusted {
                    s.status = "Accessibility allowed. Autocorrect is paused.".into();
                }
                s.trusted = trusted;
                s.apple_autocorrect = apple_autocorrect;
                if !trusted {
                    s.enabled = false;
                }
            });
            permission_checked = Instant::now();
        }
        match requests.recv_timeout(Duration::from_millis(250)) {
            Ok(Request::Shutdown) | Err(RecvTimeoutError::Disconnected) => return Ok(()),
            Ok(Request::Check(text)) => {
                let reply = engine.request(json!({"op":"check","text":text}))?;
                let output = reply["text"].as_str().unwrap_or(&text).to_owned();
                let count = reply["fixes"].as_array().map_or(0, Vec::len);
                handle.update(move |s, _| {
                    s.busy = false;
                    // Editing during inference invalidates the preview, not the newer draft.
                    if s.draft.text == text {
                        s.result = Some((output, count));
                    }
                });
            }
            Ok(Request::Enabled(generation)) => {
                if enabled.load(Ordering::SeqCst) != generation {
                    continue;
                }
                previous = None;
                pending = false;
                native.request(json!({"op":"clear"}))?;
                let status = native.request(json!({"op":"status"}))?;
                let trusted = status["trusted"].as_bool().unwrap_or(false);
                if !trusted {
                    let _ = enabled.compare_exchange(
                        generation,
                        generation & !1,
                        Ordering::SeqCst,
                        Ordering::SeqCst,
                    );
                }
                let on = generation % 2 == 1 && trusted;
                let gate = enabled.clone();
                handle.update(move |s, _| {
                    if gate.load(Ordering::SeqCst) != (generation & !1 | u64::from(on)) {
                        return;
                    }
                    s.enabled = on;
                    s.trusted = trusted;
                    s.status = if on {
                        "Watching new typing in accessible text fields across apps."
                    } else if !trusted {
                        "Allow Accessibility, then enable autocorrect."
                    } else {
                        "Autocorrect is paused. No text is being read."
                    }
                    .into();
                });
            }
            Ok(Request::Permission) => {
                let reply = native.request(json!({"op":"permission"}))?;
                let trusted = reply["trusted"].as_bool().unwrap_or(false);
                let list = reply["list"].as_str().unwrap_or("Accessibility").to_owned();
                handle.update(move |s, _| {
                    s.trusted = trusted;
                    s.status = format!(
                        "System Settings > Privacy & Security > {list}. Switch on TinyType."
                    );
                });
            }
            Ok(Request::KeyboardSettings) => {
                let reply = native.request(json!({"op":"keyboard_settings"}))?;
                handle.update(move |s, _| {
                    s.status = if reply["reason"].is_string() {
                        "Open System Settings > Keyboard > Text Input > Edit manually."
                    } else {
                        "Keyboard > Text Input > Edit: turn off Correct spelling automatically."
                    }
                    .into();
                });
            }
            Ok(Request::Undo) => {
                let reply = native.request(json!({"op":"undo"}))?;
                if reply["reason"]
                    .as_str()
                    .is_some_and(|reason| reason.starts_with("edit_failed"))
                {
                    return Err("TinyType paused after an incomplete undo. Check the field before reopening TinyType.".into());
                }
                if reply["applied"].as_bool() == Some(true) {
                    if let Some(word) = reply["original"].as_str() {
                        engine.request(json!({"op":"ignore","word":word}))?;
                    }
                }
                previous = None;
                pending = false;
                let applied = reply["applied"].as_bool() == Some(true);
                handle.update(move |s, _| {
                    s.status = if applied {
                        "Correction undone. That word is ignored until you quit."
                    } else {
                        "Nothing undone. Return to the unchanged field and press Option-Command-Z."
                    }
                    .into()
                });
            }
            Err(RecvTimeoutError::Timeout) => {
                let generation = enabled.load(Ordering::SeqCst);
                if generation % 2 == 0 {
                    continue;
                }
                let reply = native.request(json!({"op":"snapshot"}))?;
                let next: Option<Snapshot> = serde_json::from_value(reply["snapshot"].clone())
                    .map_err(|_| "TinyType received an invalid native snapshot")?;
                let Some(next) = next else {
                    previous = None;
                    pending = false;
                    continue;
                };
                if previous.as_ref() != Some(&next) {
                    pending = previous
                        .as_ref()
                        .is_some_and(|old| typed_at_caret(old, &next));
                    changed = Instant::now();
                    previous = Some(next);
                    continue;
                }
                if !pending || changed.elapsed() < Duration::from_millis(900) {
                    continue;
                }
                pending = false;
                let Some(range) = recent_finished_words(&next.text, next.caret) else {
                    continue;
                };
                let fixes = engine.request(json!({"op":"check","text":next.text,"range":range}))?;
                // One word per pause keeps the native edit and undo small. A newer
                // UI pause takes effect even while inference is running.
                if enabled.load(Ordering::SeqCst) != generation {
                    previous = None;
                    continue;
                }
                if let Some(fix) = fixes["fixes"].as_array().and_then(|f| f.last()) {
                    let mut request = serde_json::to_value(&next)
                        .map_err(|_| "TinyType snapshot encoding failed")?;
                    request["op"] = json!("replace");
                    for key in ["from", "to", "original", "replacement"] {
                        request[key] = fix[key].clone();
                    }
                    let result = native.request(request)?;
                    if result["reason"]
                        .as_str()
                        .is_some_and(|reason| reason.starts_with("edit_failed"))
                    {
                        return Err("TinyType paused after an incomplete native edit. Check the field before reopening TinyType.".into());
                    }
                    if result["applied"].as_bool() == Some(true) {
                        handle.update(|s, _| {
                            s.corrections += 1;
                            s.status =
                                "Corrected one word. Option-Command-Z undoes it in the same field."
                                    .into();
                        });
                    }
                }
                // Never treat our own edit, an undo, or an already-open document as typing.
                previous = None;
            }
        }
    }
}

fn typed_at_caret(old: &Snapshot, next: &Snapshot) -> bool {
    if old.token != next.token
        || old.pid != next.pid
        || old.bundle != next.bundle
        || next.caret <= old.caret
        || next.caret - old.caret > 32
    {
        return false;
    }
    let before: Vec<u16> = old.text.encode_utf16().collect();
    let after: Vec<u16> = next.text.encode_utf16().collect();
    old.caret <= before.len()
        && next.caret <= after.len()
        && before[..old.caret] == after[..old.caret]
        && before[old.caret..] == after[next.caret..]
}

fn recent_finished_words(text: &str, caret: usize) -> Option<[usize; 2]> {
    // The suffix remains model context, but only completed words before the
    // caret may change. Reject offsets that split a UTF-16 surrogate pair.
    let units: Vec<u16> = text.encode_utf16().collect();
    let prefix = String::from_utf16(units.get(..caret)?).ok()?;
    let text = prefix.as_str();
    let line = text.rsplit_once('\n').map_or(text, |(_, line)| line);
    let start_byte = text.len() - line.len();
    let mut end = line.len();
    if line.ends_with(|c: char| c.is_alphabetic() || c == '\'') {
        end = line
            .char_indices()
            .rev()
            .find(|(_, c)| !c.is_alphabetic() && *c != '\'')
            .map_or(0, |(i, c)| i + c.len_utf8());
    }
    let finished = &line[..end];
    let starts: Vec<usize> = finished
        .match_indices(|c: char| c.is_whitespace())
        .map(|(i, c)| i + c.len())
        .chain(std::iter::once(0))
        .filter(|&i| finished[i..].starts_with(|c: char| c.is_alphabetic()))
        .collect();
    let mut starts = starts;
    starts.sort_unstable();
    let start = *starts.get(starts.len().saturating_sub(4))?;
    Some([
        text[..start_byte + start].encode_utf16().count(),
        text[..start_byte + end].encode_utf16().count(),
    ])
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn only_insertions_at_the_caret_are_eligible() {
        let original = Snapshot {
            token: 1,
            pid: 42,
            bundle: "com.apple.TextEdit".into(),
            text: "Hi 🦀".into(),
            caret: 5,
        };
        let mut next = original.clone();
        next.text.push(' ');
        next.caret = 6;
        assert!(typed_at_caret(&original, &next));
        next.token = 2;
        assert!(!typed_at_caret(&original, &next));
        next.token = 1;
        next.caret = 3;
        assert!(!typed_at_caret(&original, &next));
        next.caret = 6;
        next.text = "Yo 🦀 ".into();
        assert!(!typed_at_caret(&original, &next));
        assert!(!typed_at_caret(&next, &original)); // Backspace and undo never trigger a correction.

        let original = Snapshot {
            text: "Hi 🦀 later".into(),
            caret: 6,
            ..original
        };
        let mut next = Snapshot {
            text: "Hi 🦀 teh later".into(),
            caret: 10,
            ..original.clone()
        };
        assert!(typed_at_caret(&original, &next));
        next.text = "Hi 🦀 teh changed".into();
        assert!(!typed_at_caret(&original, &next)); // A rewrite elsewhere is not typing.
        next.text = format!("Hi 🦀 {}later", "x".repeat(32));
        next.caret = 38;
        assert!(typed_at_caret(&original, &next));
        next.text = format!("Hi 🦀 {}later", "x".repeat(33));
        next.caret = 39;
        assert!(!typed_at_caret(&original, &next));
    }

    #[test]
    fn ranges_exclude_incomplete_words_and_count_utf16() {
        assert_eq!(
            recent_finished_words("🦀 I got a letter form the ba", 29),
            Some([9, 27])
        );
        assert_eq!(recent_finished_words("unfinished", 10), None);
        assert_eq!(
            recent_finished_words("old paragraph\nI am to tired.", 28),
            Some([14, 28])
        );
        assert_eq!(recent_finished_words("Hi\u{2003}there", 8), Some([0, 3]));
        assert_eq!(recent_finished_words("🦀 teh later wrng ", 7), Some([3, 7]));
        assert_eq!(recent_finished_words("🦀 teh later wrng ", 1), None);
        assert_eq!(recent_finished_words("🦀 teh later wrng ", 99), None);
    }
}
