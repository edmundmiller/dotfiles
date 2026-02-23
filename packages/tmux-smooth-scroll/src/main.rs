use std::env;
use std::f64::consts::PI;
use std::process::Command;
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

/// Check if a pane is automated (e.g. Pi agent) and should skip animation.
fn is_automated_pane(pane: Option<&str>) -> bool {
    let exclude = tmux_option("@smooth-scroll-exclude")
        .unwrap_or_else(|| "π".to_string());
    let mut cmd = Command::new("tmux");
    cmd.args(["display-message", "-p"]);
    if let Some(t) = pane {
        cmd.args(["-t", t]);
    }
    cmd.arg("#{pane_title}");
    let title = cmd
        .output()
        .ok()
        .map(|o| String::from_utf8_lossy(&o.stdout).trim().to_string())
        .unwrap_or_default();
    exclude.split(',').any(|pat| title.contains(pat.trim()))
}

/// Check whether a pane target is still valid.
fn pane_exists(pane: &str) -> bool {
    Command::new("tmux")
        .args(["display-message", "-t", pane, "-p", ""])
        .stderr(std::process::Stdio::null())
        .status()
        .map(|s| s.success())
        .unwrap_or(false)
}

/// Send a single native scroll command (no animation).
fn scroll_instant(direction: Direction, scroll_type: &ScrollType, lines: u32, pane: Option<&str>) {
    let cmd_name = match (direction, scroll_type) {
        (Direction::Up, ScrollType::Halfpage) => "halfpage-up",
        (Direction::Down, ScrollType::Halfpage) => "halfpage-down",
        (Direction::Up, ScrollType::Fullpage) => "page-up",
        (Direction::Down, ScrollType::Fullpage) => "page-down",
        _ => {
            // Normal/Lines: send N individual scroll commands without delays
            let dir = match direction {
                Direction::Up => "scroll-up",
                Direction::Down => "scroll-down",
            };
            for _ in 0..lines {
                let mut c = Command::new("tmux");
                c.arg("send-keys");
                if let Some(t) = pane {
                    c.args(["-t", t]);
                }
                c.args(["-X", dir]);
                if !c.status().map(|s| s.success()).unwrap_or(false) {
                    return;
                }
            }
            return;
        }
    };
    let mut c = Command::new("tmux");
    c.arg("send-keys");
    if let Some(t) = pane {
        c.args(["-t", t]);
    }
    c.args(["-X", cmd_name]);
    let _ = c.status();
}

/// Send scroll commands one per line via tmux send-keys.
/// Compiled Rust has negligible fork overhead vs Perl — no need for control mode.
/// Bails early if any send-keys fails (pane closed mid-scroll, etc.).
fn scroll(direction: Direction, lines: u32, delays: &[Duration], pane: Option<&str>) {
    let dir = match direction {
        Direction::Up => "scroll-up",
        Direction::Down => "scroll-down",
    };
    for i in 0..lines {
        let mut cmd = Command::new("tmux");
        cmd.arg("send-keys");
        if let Some(t) = pane {
            cmd.args(["-t", t]);
        }
        cmd.args(["-X", dir]);
        if !cmd.status().map(|s| s.success()).unwrap_or(false) {
            return;
        }
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

        // Match both native tmux bindings (send-keys -X scroll-up) and
        // our own re-bindings (run-shell ... tmux-smooth-scroll ... up normal)
        let params = if line.contains("tmux-smooth-scroll") {
            // Already our binding — extract params to re-bind with current binary path
            if line.contains("up normal") {
                "up normal"
            } else if line.contains("down normal") {
                "down normal"
            } else if line.contains("up halfpage") {
                "up halfpage"
            } else if line.contains("down halfpage") {
                "down halfpage"
            } else if line.contains("up fullpage") {
                "up fullpage"
            } else if line.contains("down fullpage") {
                "down fullpage"
            } else {
                continue;
            }
        } else if line.contains("scroll-up") && line.contains("send-keys") {
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

        // Pass #{pane_id} so the binary targets the correct pane.
        // Without -t, send-keys -X fails from background run-shell.
        let _ = Command::new("tmux")
            .args([
                "bind-key", "-T", table, key,
                "run-shell", "-b",
                &format!("{exe} -t '#{{pane_id}}' {params}"),
            ])
            .status();
    }

    // Guard root-table WheelUpPane: prevent copy-mode entry in excluded panes
    // (e.g. Pi agents that don't set alternate_on or mouse_any_flag).
    // The default binding is:
    //   if alternate_on OR pane_in_mode OR mouse_any_flag → send-keys -M
    //   else → copy-mode -e
    // We add an exclude check so matched panes get send-keys -M instead.
    if mouse_scroll {
        let exclude = tmux_option("@smooth-scroll-exclude")
            .unwrap_or_else(|| "π".to_string());
        // Build a tmux format string: #{m:*pattern*,#{pane_title}} matches via fnmatch glob
        // We OR multiple patterns together for comma-separated excludes
        let match_exprs: Vec<String> = exclude
            .split(',')
            .map(|pat| format!("#{{m:*{}*,#{{pane_title}}}}", pat.trim()))
            .collect();
        let combined = match match_exprs.len() {
            1 => match_exprs[0].clone(),
            _ => {
                // Nest #{||:...} for multiple patterns
                let mut expr = match_exprs[0].clone();
                for m in &match_exprs[1..] {
                    expr = format!("#{{||:{expr},{m}}}");
                }
                expr
            }
        };

        // Excluded panes: swallow the wheel event entirely (no copy-mode, no passthrough).
        // Non-excluded: preserve default behavior (alternate/mode/mouse → passthrough, else copy-mode).
        let default_guard = "#{||:#{alternate_on},#{||:#{pane_in_mode},#{mouse_any_flag}}}";

        let _ = Command::new("tmux")
            .args([
                "bind-key", "-T", "root", "WheelUpPane",
                "if-shell", "-F", &combined,
                // Excluded pane: do nothing (swallow event)
                "",
                // Not excluded: run default logic
                &format!("if-shell -F \"{default_guard}\" \"send-keys -M\" \"copy-mode -e\""),
            ])
            .status();

        // Also guard WheelDownPane (can enter copy-mode in some tmux configs)
        let _ = Command::new("tmux")
            .args([
                "bind-key", "-T", "root", "WheelDownPane",
                "if-shell", "-F", &combined,
                "",
                "send-keys -M",
            ])
            .status();
    }
}

// ── Main ────────────────────────────────────────────────────────────────────

// ── Tests ───────────────────────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;

    // ── velocity() ──────────────────────────────────────────────────────

    #[test]
    fn linear_velocity_is_constant() {
        for &t in &[0.0, 0.25, 0.5, 0.75, 1.0] {
            assert_eq!(velocity(Easing::Linear, t), 1.0);
        }
    }

    #[test]
    fn sine_velocity_endpoints() {
        // sin(0) = 0, sin(π) = 0 → velocity = 0.3
        assert!((velocity(Easing::Sine, 0.0) - 0.3).abs() < 1e-9);
        assert!((velocity(Easing::Sine, 1.0) - 0.3).abs() < 1e-9);
    }

    #[test]
    fn sine_velocity_peak_at_midpoint() {
        // sin(π/2) = 1 → velocity = 0.3 + 2.7 = 3.0
        assert!((velocity(Easing::Sine, 0.5) - 3.0).abs() < 1e-9);
    }

    #[test]
    fn sine_velocity_is_symmetric() {
        let v_quarter = velocity(Easing::Sine, 0.25);
        let v_three_quarter = velocity(Easing::Sine, 0.75);
        assert!((v_quarter - v_three_quarter).abs() < 1e-9);
    }

    #[test]
    fn quad_velocity_endpoints() {
        // t=0: v=2*0*0=0, velocity = 0.2 + 0*2.8 = 0.2
        assert!((velocity(Easing::Quad, 0.0) - 0.2).abs() < 1e-9);
        // t=1: v=1-0/2=1, velocity = 0.2 + 1*2.8 = 3.0
        assert!((velocity(Easing::Quad, 1.0) - 3.0).abs() < 1e-9);
    }

    #[test]
    fn quad_velocity_at_midpoint() {
        // t=0.5: v=2*0.25=0.5, velocity = 0.2 + 0.5*2.8 = 1.6
        assert!((velocity(Easing::Quad, 0.5) - 1.6).abs() < 1e-9);
    }

    #[test]
    fn quad_velocity_is_monotonically_nondecreasing() {
        let steps = 100;
        let mut prev = velocity(Easing::Quad, 0.0);
        for i in 1..=steps {
            let t = i as f64 / steps as f64;
            let v = velocity(Easing::Quad, t);
            assert!(v >= prev - 1e-9, "quad velocity decreased at t={t}: {prev} > {v}");
            prev = v;
        }
    }

    // ── compute_delays() ────────────────────────────────────────────────

    #[test]
    fn zero_lines_returns_empty() {
        assert!(compute_delays(0, 10000.0, Easing::Linear).is_empty());
    }

    #[test]
    fn one_line_returns_empty() {
        // Single line = no gaps between lines
        assert!(compute_delays(1, 10000.0, Easing::Linear).is_empty());
    }

    #[test]
    fn delay_count_is_lines_minus_one() {
        for n in 2..=20 {
            let d = compute_delays(n, 5000.0, Easing::Sine);
            assert_eq!(d.len(), (n - 1) as usize);
        }
    }

    #[test]
    fn linear_delays_are_all_equal() {
        let delays = compute_delays(10, 5000.0, Easing::Linear);
        let first = delays[0];
        for d in &delays {
            assert_eq!(*d, first, "linear delays should be identical");
        }
    }

    #[test]
    fn linear_delay_value_at_scale_1() {
        // 10 lines → scale = 1.0, velocity = 1.0 → delay = base_delay_us
        let delays = compute_delays(10, 5000.0, Easing::Linear);
        assert_eq!(delays[0], Duration::from_micros(5000));
    }

    #[test]
    fn small_line_count_scales_up_delay() {
        // 3 lines: scale = 1 + 2*(10-3)/9 ≈ 2.556
        let d_small = compute_delays(3, 5000.0, Easing::Linear);
        let d_large = compute_delays(15, 5000.0, Easing::Linear);
        assert!(d_small[0] > d_large[0], "small scroll should have slower (larger) delays");
    }

    #[test]
    fn sine_delays_are_slowest_at_endpoints() {
        // Sine velocity is lowest at t=0 and t=1 → delays highest at first and last
        let delays = compute_delays(20, 5000.0, Easing::Sine);
        let mid = delays.len() / 2;
        assert!(delays[0] > delays[mid], "first delay should be > mid delay");
        assert!(delays[delays.len() - 1] > delays[mid], "last delay should be > mid delay");
    }

    #[test]
    fn default_speed_base_delay() {
        // speed=100 (default): base_delay = 1000 + 100*90 = 10000 µs
        let base = 1000.0 + 100.0 * 90.0;
        assert_eq!(base, 10000.0);
    }

    #[test]
    fn all_delays_are_positive() {
        for easing in [Easing::Linear, Easing::Sine, Easing::Quad] {
            let delays = compute_delays(50, 10000.0, easing);
            for (i, d) in delays.iter().enumerate() {
                assert!(!d.is_zero(), "delay[{i}] should be > 0");
            }
        }
    }
}

fn main() {
    let args: Vec<String> = env::args().collect();

    if args.len() < 2 {
        eprintln!("usage: tmux-smooth-scroll <init|up|down> [-t pane] [normal|halfpage|fullpage|N]");
        std::process::exit(1);
    }

    // `init` subcommand: rebind scroll keys
    if args[1] == "init" {
        init();
        return;
    }

    // Parse optional -t <pane> flag
    let mut pane: Option<String> = None;
    let mut positional: Vec<&str> = Vec::new();

    let mut i = 1;
    while i < args.len() {
        if args[i] == "-t" {
            i += 1;
            if i < args.len() {
                pane = Some(args[i].clone());
            }
        } else {
            positional.push(&args[i]);
        }
        i += 1;
    }

    if positional.len() < 2 {
        eprintln!("usage: tmux-smooth-scroll <up|down> [-t pane] <normal|halfpage|fullpage|N>");
        std::process::exit(1);
    }

    let direction = match positional[0] {
        "up" => Direction::Up,
        "down" => Direction::Down,
        _ => {
            eprintln!("direction must be up or down");
            std::process::exit(1);
        }
    };

    let scroll_type = match positional[1] {
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

    // Bail silently if target pane no longer exists (closed mid-scroll race)
    if let Some(ref p) = pane {
        if !pane_exists(p) {
            return;
        }
    }

    // Skip animation for automated panes (Pi agents, etc.)
    if is_automated_pane(pane.as_deref()) {
        scroll_instant(direction, &scroll_type, lines, pane.as_deref());
        return;
    }

    let base_delay_us = 1000.0 + cfg.speed as f64 * 90.0;
    let delays = compute_delays(lines, base_delay_us, cfg.easing);

    scroll(direction, lines, &delays, pane.as_deref());
}
