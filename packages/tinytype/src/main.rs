mod engine;
mod host;
#[cfg(target_os = "macos")]
mod status_item;
mod ui;

use std::sync::{Arc, atomic::AtomicU64, mpsc::sync_channel};

fn main() {
    let spec = ui::app_spec();
    // Headless Rune scenes must never load a model, inspect another app, request
    // permissions, register a native shortcut, or create settings and logs.
    if rune::is_headless() {
        rune::run(spec);
        return;
    }
    // Kernel-held lock also covers direct CLI launches, not only LaunchServices.
    // Leave the empty file in place so another process cannot lock a new inode.
    let _instance = match std::fs::OpenOptions::new()
        .read(true)
        .write(true)
        .create(true)
        .truncate(false)
        .open(std::env::temp_dir().join("dev.edmundmiller.tinytype.lock"))
    {
        Ok(file) if file.try_lock().is_ok() => file,
        _ => {
            eprintln!("TinyType is already running or cannot acquire its instance lock.");
            return;
        }
    };
    let (commands, requests) = sync_channel(8);
    let enabled = Arc::new(AtomicU64::new(0));
    let ui_commands = commands.clone();
    let ui_enabled = enabled.clone();
    rune::orderly_exit();
    let mut app = rune::App::new(spec)
        .init(move || {
            let mut state = ui::Ui::new();
            state.commands = Some(ui_commands.clone());
            state.enabled_gate = Some(ui_enabled.clone());
            state
        })
        .keep_running()
        .global_shortcut("cmd+alt+z", |s, _| s.send(host::Request::Undo))
        .global_shortcut("cmd+alt+period", |s, _| s.toggle_enabled());
    let handle = app.handle();
    #[cfg(target_os = "macos")]
    {
        let menu_handle = handle.clone();
        app = app.on_ready(move |_| status_item::install(menu_handle.clone()));
    }
    let worker = std::thread::spawn(move || host::run(requests, enabled, handle));
    app.run();
    let _ = commands.send(host::Request::Shutdown);
    let _ = worker.join();
}
