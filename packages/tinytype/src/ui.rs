use std::sync::{
    Arc,
    atomic::{AtomicU64, Ordering},
    mpsc::SyncSender,
};

use rune::{AppSpec, Cx, El, TextEdit, TextStyle, col, el, row, text};
use rune_kit::{Button, ButtonVariant, Switch, TextArea};

use crate::host::Request;

const EXAMPLE: &str = "I got a letter form the bank and did not recieve it.";

/// Rune owns window state; native text and inference live on the host thread.
pub struct Ui {
    pub commands: Option<SyncSender<Request>>,
    pub enabled_gate: Option<Arc<AtomicU64>>,
    pub enabled: bool,
    pub trusted: bool,
    pub apple_autocorrect: Option<bool>,
    pub ready: bool,
    pub busy: bool,
    pub status: String,
    pub draft: TextEdit,
    pub result: Option<(String, usize)>,
    pub corrections: usize,
}

impl Ui {
    pub fn new() -> Self {
        Self {
            commands: None,
            enabled_gate: None,
            enabled: false,
            trusted: false,
            apple_autocorrect: None,
            ready: false,
            busy: false,
            status: "Loading the bundled TinyFix model...".into(),
            draft: TextEdit::new(EXAMPLE),
            result: None,
            corrections: 0,
        }
    }

    pub fn send(&mut self, request: Request) {
        let changes_enabled = matches!(request, Request::Enabled(_));
        if self
            .commands
            .as_ref()
            .is_some_and(|tx| tx.try_send(request).is_err())
        {
            if changes_enabled {
                self.enabled = false;
                if let Some(gate) = &self.enabled_gate {
                    gate.fetch_and(!1, Ordering::SeqCst);
                }
            }
            self.busy = false;
            self.status = "TinyType is busy. Try again in a moment.".into();
        }
    }

    pub fn toggle_enabled(&mut self) {
        if !self.ready || (!self.enabled && !self.trusted) {
            return;
        }
        self.enabled = !self.enabled;
        if let Some(gate) = &self.enabled_gate {
            let current = gate.load(Ordering::SeqCst);
            let generation = (current / 2 + 1) * 2 + u64::from(self.enabled);
            gate.store(generation, Ordering::SeqCst);
            self.send(Request::Enabled(generation));
        }
    }
}

fn view(s: &Ui, cx: &mut Cx<Ui>) -> El {
    let k = rune_theme_opencode::kit(cx.system_dark());
    let t = rune::tok::theme(cx.system_dark());
    let caption = TextStyle::new(12.0, 450.0).lh(18.0);
    let section = TextStyle::new(13.0, 600.0).lh(20.0);
    let card = |body: El| {
        body.w_full()
            .px(20.0)
            .py(18.0)
            .radius(k.radius.lg)
            .fill(k.c.layer_01)
            .border(1.0, k.c.border_base)
    };
    col()
        .key("tinytype")
        .w_full()
        .h_full()
        .fill(k.c.bg_base)
        .px(32.0)
        .py(28.0)
        .gap(22.0)
        .child(
            row()
                .w_full()
                .center_y()
                .gap(12.0)
                .child(
                    col()
                        .grow(1.0)
                        .gap(4.0)
                        .child(
                            text("TinyType")
                                .font(TextStyle::new(26.0, 650.0))
                                .color(k.c.text_base),
                        )
                        .child(
                            text("A second look at the word you meant.")
                                .font(k.ty.ui)
                                .color(k.c.text_weak),
                        ),
                )
                .child(
                    text("ON DEVICE")
                        .font(TextStyle::new(10.0, 600.0))
                        .color(k.c.text_weak),
                ),
        )
        .child(card(
            col()
                .gap(14.0)
                .child(
                    row()
                        .w_full()
                        .center_y()
                        .gap(16.0)
                        .child(
                            col()
                                .grow(1.0)
                                .gap(4.0)
                                .child(
                                    text("Autocorrect while typing")
                                        .font(section)
                                        .color(k.c.text_base),
                                )
                                .child(
                                    text("Across accessible Mac inputs. Starts paused.")
                                        .font(caption)
                                        .color(k.c.text_weak),
                                ),
                        )
                        .child(
                            Switch::new(s.enabled)
                                .label("Autocorrect while typing")
                                .hide_label()
                                .disabled(!s.ready || !s.trusted)
                                .on_toggle(|s: &mut Ui| s.toggle_enabled())
                                .build(k)
                                .key("autocorrect"),
                        ),
                )
                .child(el().w_full().h(1.0).fill(k.c.border_base))
                .child(
                    row()
                        .w_full()
                        .center_y()
                        .gap(12.0)
                        .child(
                            col()
                                .grow(1.0)
                                .gap(3.0)
                                .child(
                                    text(if s.trusted {
                                        "Accessibility allowed"
                                    } else {
                                        "Accessibility permission needed"
                                    })
                                    .font(k.ty.ui)
                                    .color(k.c.text_base),
                                )
                                .child(
                                    text(if s.trusted {
                                        "TinyType can correct text in other apps."
                                    } else {
                                        "Drag the app into System Settings with the setup guide."
                                    })
                                    .font(caption)
                                    .color(k.c.text_weak),
                                ),
                        )
                        .child(
                            Button::new(if s.trusted {
                                "Open settings"
                            } else {
                                "Set up Accessibility"
                            })
                            .disabled(!s.ready)
                            .on_press(|s: &mut Ui| s.send(Request::Permission))
                            .build(k)
                            .key("permission"),
                        ),
                ),
        ))
        .child(card(
            row()
                .w_full()
                .center_y()
                .gap(12.0)
                .child(
                    col()
                        .grow(1.0)
                        .gap(3.0)
                        .child(
                            text(match s.apple_autocorrect {
                                Some(true) => "Warning: macOS autocorrect is on",
                                Some(false) => "macOS autocorrect is off",
                                None => "macOS autocorrect not checked",
                            })
                            .key("apple-autocorrect")
                            .font(section)
                            .color(k.c.text_base),
                        )
                        .child(
                            text(if s.apple_autocorrect == Some(true) {
                                "Two autocorrect engines can conflict.\nTurn off Correct spelling automatically."
                            } else {
                                "Apps can override the global setting.\nSpelling underlines are separate."
                            })
                            .font(caption)
                            .color(t.text_secondary),
                        ),
                )
                .child(
                    Button::new("Keyboard settings")
                        .disabled(!s.ready)
                        .on_press(|s: &mut Ui| s.send(Request::KeyboardSettings))
                        .build(k)
                        .key("keyboard-settings"),
                ),
        ))
        .child(
            col()
                .gap(10.0)
                .child(
                    row()
                        .w_full()
                        .center_y()
                        .child(
                            text("Try a sentence")
                                .font(section)
                                .color(k.c.text_base)
                                .grow(1.0),
                        )
                        .child(
                            Button::new("Reset example")
                                .on_press(|s: &mut Ui| {
                                    s.draft.replace_text(EXAMPLE);
                                    s.result = None;
                                })
                                .build(k)
                                .key("reset"),
                        ),
                )
                .child(
                    TextArea::new(&s.draft)
                        .label("Text to check")
                        .rows(3)
                        .spellcheck(false)
                        .on_edit(|s: &mut Ui| &mut s.draft)
                        .on_change(|s: &mut Ui, _| s.result = None)
                        .build(k)
                        .key("draft"),
                )
                .child(
                    row()
                        .w_full()
                        .center_y()
                        .gap(12.0)
                        .child(
                            Button::new(if s.busy {
                                "Checking..."
                            } else {
                                "Check sentence"
                            })
                            .variant(ButtonVariant::Contrast)
                            .disabled(
                                !s.ready
                                    || s.busy
                                    || s.draft.text.is_empty()
                                    || s.draft.text.encode_utf16().count() > 16384,
                            )
                            .on_press(|s: &mut Ui| {
                                s.busy = true;
                                s.send(Request::Check(s.draft.text.clone()));
                            })
                            .build(k)
                            .key("check"),
                        )
                        .child(
                            text("English only · Careful mode")
                                .font(caption)
                                .color(k.c.text_weak),
                        ),
                ),
        )
        .child(card(
            col()
                .gap(8.0)
                .child(
                    text(match &s.result {
                        Some((_, 1)) => "1 suggested correction".into(),
                        Some((_, count)) => format!("{count} suggested corrections"),
                        None => "Corrected text".into(),
                    })
                    .font(caption)
                    .color(k.c.text_weak),
                )
                .child(
                    text(
                        s.result
                            .as_ref()
                            .map_or("Check a sentence to see what TinyFix would change.", |r| {
                                r.0.as_str()
                            }),
                    )
                    .key("result")
                    .font(TextStyle::new(16.0, 450.0).lh(25.0))
                    .color(k.c.text_base)
                    .selectable(true),
                )
                .child(
                    Button::new("Copy corrected text")
                        .disabled(s.result.is_none())
                        .on_press_tx(|s: &mut Ui, tx| {
                            if let Some((text, _)) = &s.result {
                                tx.copy(text.clone());
                            }
                        })
                        .build(k)
                        .key("copy"),
                ),
        ))
        .child(col().grow(1.0).min_h(0.0))
        .child(
            col()
                .gap(5.0)
                .child(
                    text(&s.status)
                        .key("status")
                        .font(caption)
                        .color(t.text_secondary),
                )
                .child(
                    text("⌥⌘. pause / resume     ⌥⌘Z undo in the unchanged field")
                        .font(caption)
                        .color(k.c.text_weak),
                )
                .child(
                    text("No clipboard access for autocorrect. No text saved or sent.")
                        .font(caption)
                        .color(k.c.text_weak),
                ),
        )
}

/// Fixture scenes render with no host, permissions, settings, or model processes.
pub fn app_spec() -> AppSpec<Ui> {
    AppSpec {
        fonts: rune_theme_opencode::FONTS,
        families: rune_theme_opencode::FAMILIES,
        min_size: Some((650.0, 800.0)),
        scenes: &[
            ("paused", |s| {
                s.ready = true;
                s.apple_autocorrect = Some(false);
                s.status = "Model ready. Autocorrect is paused.".into();
            }),
            ("apple-autocorrect-on", |s| {
                s.ready = true;
                s.trusted = true;
                s.apple_autocorrect = Some(true);
                s.status = "Model ready. Autocorrect is paused.".into();
            }),
            ("corrected", |s| {
                s.ready = true;
                s.apple_autocorrect = Some(false);
                s.result = Some((
                    "I got a letter from the bank and did not receive it.".into(),
                    2,
                ));
                s.status = "Model ready. Autocorrect is paused.".into();
            }),
            ("enabled", |s| {
                s.ready = true;
                s.trusted = true;
                s.enabled = true;
                s.apple_autocorrect = Some(false);
                s.status = "Watching new typing in accessible text fields across apps.".into();
            }),
            ("error", |s| {
                s.status = "TinyType model could not load. Quit and rebuild the app.".into();
            }),
        ],
        ..AppSpec::new("TinyType", (700.0, 820.0), Ui::new, view)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use rune::{Env, Runtime};

    #[test]
    fn checking_queues_the_draft_without_enabling_autocorrect() {
        let mut rt = Runtime::new(Ui::new(), view, (700.0, 820.0), Env::new(false, 1.0));
        let (tx, rx) = std::sync::mpsc::sync_channel(8);
        rt.state.commands = Some(tx);
        rt.state.ready = true;
        rt.frame(0.0);
        let (x, y) = rt.find("check").unwrap();
        rt.pointer_down(x, y);
        rt.pointer_up(x, y);
        rt.frame(1.0 / 60.0);
        assert!(matches!(rx.try_recv(), Ok(Request::Check(text)) if text == EXAMPLE));
        assert!(!rt.state.enabled);
        assert!(rt.state.busy);
        let (x, y) = rt.find("permission").unwrap();
        rt.pointer_down(x, y);
        rt.pointer_up(x, y);
        rt.frame(2.0 / 60.0);
        assert!(matches!(rx.try_recv(), Ok(Request::Permission)));
        assert!(!rt.state.enabled); // Opening setup is not consent to read other apps.
        let (x, y) = rt.find("keyboard-settings").unwrap();
        rt.pointer_down(x, y);
        rt.pointer_up(x, y);
        rt.frame(3.0 / 60.0);
        assert!(matches!(rx.try_recv(), Ok(Request::KeyboardSettings)));
        assert!(!rt.state.enabled);
    }

    #[test]
    fn pause_invalidates_inflight_work_even_after_resuming() {
        let mut state = Ui::new();
        let (tx, rx) = std::sync::mpsc::sync_channel(3);
        let gate = Arc::new(AtomicU64::new(0));
        state.commands = Some(tx);
        state.enabled_gate = Some(gate.clone());
        state.ready = true;
        state.toggle_enabled();
        assert!(rx.try_recv().is_err()); // Permission is required even for shortcuts.
        state.trusted = true;
        state.toggle_enabled();
        let first = gate.load(Ordering::SeqCst);
        assert_eq!(first % 2, 1);
        state.toggle_enabled();
        assert_eq!(gate.load(Ordering::SeqCst) % 2, 0);
        state.toggle_enabled();
        assert_ne!(gate.load(Ordering::SeqCst), first);
        assert!(state.enabled);
        // A full request queue must fail closed, not leave an unacknowledged enable.
        state.toggle_enabled();
        assert!(!state.enabled);
        assert_eq!(gate.load(Ordering::SeqCst) % 2, 0);
        state.toggle_enabled();
        assert!(!state.enabled);
        assert_eq!(gate.load(Ordering::SeqCst) % 2, 0);
    }
}
