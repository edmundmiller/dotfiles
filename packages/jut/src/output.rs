use crate::args::OutputFormat;
use std::io::Write;

/// Output channel that handles human vs JSON formatting.
#[allow(dead_code)]
pub struct OutputChannel {
    format: OutputFormat,
    json_buffer: Option<serde_json::Value>,
}

impl OutputChannel {
    pub fn new(format: OutputFormat) -> Self {
        Self {
            format,
            json_buffer: None,
        }
    }

    pub fn is_json(&self) -> bool {
        matches!(self.format, OutputFormat::Json)
    }

    /// Write a line of human-readable output (ignored in JSON mode).
    pub fn human(&self, msg: &str) {
        if !self.is_json() {
            println!("{}", msg);
        }
    }

    /// Write to stderr (always visible).
    pub fn error(&self, msg: &str) {
        eprintln!("{}", msg);
    }

    /// Write a JSON value to stdout.
    pub fn write_json(&self, value: &serde_json::Value) -> anyhow::Result<()> {
        let stdout = std::io::stdout();
        let mut handle = stdout.lock();
        serde_json::to_writer_pretty(&mut handle, value)?;
        writeln!(handle)?;
        Ok(())
    }

    /// Buffer JSON for --status-after wrapping.
    #[allow(dead_code)]
    pub fn begin_status_after(&mut self) {
        if self.is_json() {
            self.json_buffer = Some(serde_json::Value::Null);
        }
    }

    /// Store mutation result JSON.
    #[allow(dead_code)]
    pub fn set_result_json(&mut self, value: serde_json::Value) {
        self.json_buffer = Some(value);
    }

    /// Take buffered JSON.
    #[allow(dead_code)]
    pub fn take_json_buffer(&mut self) -> Option<serde_json::Value> {
        self.json_buffer.take()
    }
}
