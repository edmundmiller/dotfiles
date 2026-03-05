// Graceful EPIPE/SIGPIPE handling for Node.js processes.
//
// Problem: Tools like `pi` use #!/usr/bin/env node and write to stdout/stderr.
// When the pipe reader dies (tmux pane closes, API stream drops), Node raises
// an unhandled EPIPE error and crashes. This is especially bad on Node 25+.
//
// Fix: Preloaded via NODE_OPTIONS="--require /path/to/epipe-handler.js".
// Catches EPIPE on stdout/stderr and exits cleanly instead of crashing.
//
// Upstream: https://github.com/badlogic/pi-mono (packages/coding-agent)

"use strict";

function handleEpipe(err) {
  if (err.code === "EPIPE" || err.code === "EOF") {
    process.exit(0);
  }
  // Re-throw non-EPIPE errors so they're not silently swallowed
  throw err;
}

process.stdout.on("error", handleEpipe);
process.stderr.on("error", handleEpipe);

// Ignore SIGPIPE (default on macOS is to terminate the process)
process.on("SIGPIPE", () => {});
