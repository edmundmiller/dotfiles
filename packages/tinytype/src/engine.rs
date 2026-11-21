use std::io::{BufRead, BufReader, Read, Write};
use std::process::{Child, ChildStdin, Command, Stdio};
use std::sync::mpsc::{Receiver, channel};
use std::time::Duration;

use serde_json::Value;

/// A private JSON-lines child process. Deadlines kill the child, never the UI.
pub struct JsonChild {
    child: Child,
    input: ChildStdin,
    replies: Receiver<Result<Value, String>>,
}

impl JsonChild {
    pub fn start(command: &mut Command) -> Result<Self, String> {
        let mut child = command
            .stdin(Stdio::piped())
            .stdout(Stdio::piped())
            .stderr(Stdio::null())
            .spawn()
            .map_err(|_| "TinyType could not start a bundled helper")?;
        let input = child
            .stdin
            .take()
            .ok_or("TinyType helper stdin unavailable")?;
        let output = child
            .stdout
            .take()
            .ok_or("TinyType helper stdout unavailable")?;
        let (tx, replies) = channel();
        std::thread::spawn(move || {
            // A helper emits at most one bounded reply per request.
            let mut reader = BufReader::new(output);
            loop {
                let mut line = String::new();
                let result = reader.by_ref().take(262145).read_line(&mut line);
                match result {
                    Ok(0) | Err(_) => break,
                    _ if line.len() > 262144 => {
                        let _ = tx.send(Err("TinyType helper reply exceeded its limit".into()));
                        break;
                    }
                    _ => {
                        let parsed = serde_json::from_str(&line)
                            .map_err(|_| "TinyType helper returned invalid JSON".into());
                        if tx.send(parsed).is_err() {
                            break;
                        }
                    }
                }
            }
        });
        Ok(Self {
            child,
            input,
            replies,
        })
    }

    pub fn receive(&mut self) -> Result<Value, String> {
        match self.replies.recv_timeout(Duration::from_secs(15)) {
            Ok(value) => value,
            Err(_) => {
                let _ = self.child.kill();
                Err("TinyType helper stopped responding; quit and reopen TinyType".into())
            }
        }
    }

    pub fn request(&mut self, request: Value) -> Result<Value, String> {
        serde_json::to_writer(&mut self.input, &request)
            .map_err(|_| "TinyType helper write failed")?;
        self.input
            .write_all(b"\n")
            .and_then(|_| self.input.flush())
            .map_err(|_| "TinyType helper disconnected")?;
        let reply = self.receive()?;
        if reply.get("error").is_some() {
            return Err("TinyType could not check this text".into());
        }
        Ok(reply)
    }
}

impl Drop for JsonChild {
    fn drop(&mut self) {
        let _ = self.child.kill();
        let _ = self.child.wait();
    }
}
