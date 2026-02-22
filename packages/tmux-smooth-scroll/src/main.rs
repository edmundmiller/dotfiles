use std::env;
use std::f64::consts::PI;
use std::io::{BufRead, BufReader, Write};
use std::process::{Command, Stdio};
use std::thread;
use std::time::Duration;

// ── Config ──────────────────────────────────────────────────────────────────

struct Config {
    speed: u32,         // 0-1000
    easing: Easing,
    normal_lines: u32,
    halfpage_lines: Option<u32>, // None = pane_height/2
    fullpage_lines: Option<u32>, // None = pane_height
}

#[derive(Clone, Copy)]
enum Easing {
    Linear,
    Sine,
    Quad,
}

#[derive(Clone, Copy)]
enum Direction {
    Up,
    Down,
}

enum ScrollType {
    Normal,
    Halfpage,
    Fullpage,
    Lines(u32),
}

// ── Tmux IPC ────────────────────────────────────────────────────────────────

/// Read a tmux user option, returning None if unset/empty.
fn tmux_option(name: &str) -> Option<String> {
    let out = Command::new("tmux")
        .args(["show-option", "-gqv", name])
        .output()
        .ok()?;
    let val = String::from_utf8_lossy(&out.stdout).trim().to_string();
    if val.is_empty() { None } else { Some(val) }
}

fn pane_height() -> u32 {
    Command::new("tmux")
        .args(["display-message", "-p", "#{pane_height}"])
        .output()
        .ok()
        .and_then(|o| String::from_utf8_lossy(&o.stdout).trim().parse().ok())
        .unwrap_or(24)
}

/// Open a tmux control-mode subprocess and send scroll commands through it.
/// Falls back to per-line send-keys if control mode fails.
fn scroll_via_control(direction: Direction, lines: u32, delays: &[Duration]) {
    let cmd = match direction {
        Direction::Up => "send-keys -X scroll-up",
        Direction::Down => "send-keys -X scroll-down",
    };

    // Try control mode first — single process, zero fork overhead per line
    if let Ok(mut child) = Command::new("tmux")
        .args(["-C", "attach"])
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .stderr(Stdio::null())
        .spawn()
    {
        let mut stdin = match child.stdin.take() {
            Some(s) => s,
            None => {
                let _ = child.kill();
                return scroll_fallback(direction, lines, delays);
            }
        };

        // Drain stdout in background so tmux doesn't block
        let stdout = child.stdout.take();
        let drain = thread::spawn(move || {
            if let Some(out) = stdout {
                let r = BufReader::new(out);
                for _ in r.lines() {}
            }
        });

        for i in 0..lines {
            if writeln!(stdin, "{cmd}").is_err() {
                break;
            }
            if i < lines - 1 {
                thread::sleep(delays[i as usize]);
            }
        }

        drop(stdin); // EOF → tmux exits control mode
        let _ = child.wait();
        let _ = drain.join();
        return;
    }

    scroll_fallback(direction, lines, delays);
}

/// Fallback: one tmux send-keys per line (same as upstream Perl).
fn scroll_fallback(direction: Direction, lines: u32, delays: &[Duration]) {
    let dir = match direction {
        Direction::Up => "scroll-up",
        Direction::Down => "scroll-down",
    };
    for i in 0..lines {
        let _ = Command::new("tmux")
            .args(["send-keys", "-X", dir])
            .status();
        if i < lines - 1 {
            thread::sleep(delays[i as usize]);
        }
    }
}

// ── Easing ──────────────────────────────────────────────────────────────────

fn velocity(easing: Easing, t: f64) -> f64 {
    match easing {
        Easing::Linear => 1.0,
        Easing::Sine => 0.3 + (t * PI).sin() * 2.7,
        Easing::Quad => {
            let v = if t < 0.5 {
                2.0 * t * t
            } else {
                1.0 - ((-2.0 * t + 2.0).powi(2)) / 2.0
            };
            0.2 + v * 2.8
        }
    }
}

fn compute_delays(lines: u32, base_delay_us: f64, easing: Easing) -> Vec<Duration> {
    if lines <= 1 {
        return vec![];
    }

    let total = lines as f64;
    let scale = if total < 10.0 {
        1.0 + 2.0 * (10.0 - total) / 9.0
    } else {
        1.0
    };

    (0..lines - 1)
        .map(|i| {
            let t = i as f64 / (total - 1.0);
            let v = velocity(easing, t);
            let us = (base_delay_us * scale) / v;
            Duration::from_micros(us.ceil() as u64)
        })
        .collect()
}

// ── Config loading ──────────────────────────────────────────────────────────

fn load_config() -> Config {
    Config {
        speed: tmux_option("@smooth-scroll-speed")
            .and_then(|s| s.parse().ok())
            .unwrap_or(100),
        easing: match tmux_option("@smooth-scroll-easing").as_deref() {
            Some("linear") => Easing::Linear,
            Some("quad") => Easing::Quad,
            _ => Easing::Sine,
        },
        normal_lines: tmux_option("@smooth-scroll-normal")
            .and_then(|s| s.parse().ok())
            .unwrap_or(3),
        halfpage_lines: tmux_option("@smooth-scroll-halfpage")
            .and_then(|s| s.parse().ok()),
        fullpage_lines: tmux_option("@smooth-scroll-fullpage")
            .and_then(|s| s.parse().ok()),
    }
}

// ── Init (key rebinding) ────────────────────────────────────────────────────

/// Scan existing copy-mode bindings and rebind scroll keys to use this binary.
fn init() {
    let exe = env::current_exe()
        .unwrap_or_else(|_| "tmux-smooth-scroll".into());
    let exe = exe.display();

    // Detect vi vs emacs mode
    let mode_keys = Command::new("tmux")
        .args(["show-option", "-gwq", "mode-keys"])
        .output()
        .map(|o| String::from_utf8_lossy(&o.stdout).trim().to_string())
        .unwrap_or_default();
    let table = if mode_keys == "emacs" { "copy-mode" } else { "copy-mode-vi" };

    let mouse_scroll = tmux_option("@smooth-scroll-mouse")
        .map(|v| v != "false")
        .unwrap_or(true);

    // List current bindings
    let output = Command::new("tmux")
        .args(["list-keys", "-T", table])
        .output()
        .expect("failed to run tmux list-keys");
    let bindings = String::from_utf8_lossy(&output.stdout);

    for line in bindings.lines() {
        // Skip mouse events if disabled
        if !mouse_scroll && line.contains("Wheel") {
            continue;
        }

        let params = if line.contains("scroll-up") && line.contains("send-keys") {
            "up normal"
        } else if line.contains("scroll-down") && line.contains("send-keys") {
            "down normal"
        } else if line.contains("halfpage-up") && line.contains("send-keys") {
            "up halfpage"
        } else if line.contains("halfpage-down") && line.contains("send-keys") {
            "down halfpage"
        } else if line.contains("page-up") && line.contains("send-keys") {
            "up fullpage"
        } else if line.contains("page-down") && line.contains("send-keys") {
            "down fullpage"
        } else {
            continue;
        };

        // Extract key name (4th field in `bind-key -T copy-mode-vi <key> ...`)
        let key = match line.split_whitespace().nth(3) {
            Some(k) => k,
            None => continue,
        };

        let _ = Command::new("tmux")
            .args([
                "bind-key", "-T", table, key,
                "run-shell", "-b",
                &format!("{exe} {params}"),
            ])
            .status();
    }
}

// ── Main ────────────────────────────────────────────────────────────────────

fn main() {
    let args: Vec<String> = env::args().collect();

    if args.len() < 2 {
        eprintln!("usage: tmux-smooth-scroll <init|up|down> [normal|halfpage|fullpage|N]");
        std::process::exit(1);
    }

    // `init` subcommand: rebind scroll keys
    if args[1] == "init" {
        init();
        return;
    }

    // Scroll mode: <up|down> <type>
    if args.len() < 3 {
        eprintln!("usage: tmux-smooth-scroll <up|down> <normal|halfpage|fullpage|N>");
        std::process::exit(1);
    }

    let direction = match args[1].as_str() {
        "up" => Direction::Up,
        "down" => Direction::Down,
        _ => {
            eprintln!("direction must be up or down");
            std::process::exit(1);
        }
    };

    let scroll_type = match args[2].as_str() {
        "normal" => ScrollType::Normal,
        "halfpage" => ScrollType::Halfpage,
        "fullpage" => ScrollType::Fullpage,
        n => ScrollType::Lines(n.parse().unwrap_or_else(|_| {
            eprintln!("invalid scroll type: {n}");
            std::process::exit(1);
        })),
    };

    let cfg = load_config();

    let lines = match scroll_type {
        ScrollType::Normal => cfg.normal_lines,
        ScrollType::Halfpage => cfg.halfpage_lines.unwrap_or_else(|| pane_height() / 2),
        ScrollType::Fullpage => cfg.fullpage_lines.unwrap_or_else(pane_height),
        ScrollType::Lines(n) => n,
    };

    if lines == 0 {
        return;
    }

    let base_delay_us = 1000.0 + cfg.speed as f64 * 90.0;
    let delays = compute_delays(lines, base_delay_us, cfg.easing);

    scroll_via_control(direction, lines, &delays);
}
