/**
 * Rotated file logger for pi-dcp extension
 *
 * Provides structured logging to rotating log files with:
 * - Automatic log rotation when size limit reached
 * - Configurable number of backup files
 * - Multiple log levels (ERROR, WARN, INFO, DEBUG)
 * - Async writes to avoid blocking
 * - Timestamps and contextual information
 */

import { appendFileSync, existsSync, mkdirSync, renameSync, statSync, unlinkSync } from "fs";
import { dirname, join } from "path";
import { homedir } from "os";

export enum LogLevel {
  ERROR = 0,
  WARN = 1,
  INFO = 2,
  DEBUG = 3,
}

export interface LoggerConfig {
  /** Directory where log files will be stored */
  logDir?: string;
  /** Base name for log file (without extension) */
  logFileName?: string;
  /** Maximum size of log file in bytes before rotation (default: 10MB) */
  maxFileSize?: number;
  /** Number of rotated log files to keep (default: 5) */
  maxBackups?: number;
  /** Minimum log level to write (default: INFO) */
  minLevel?: LogLevel;
  /** Enable console output as well (default: false) */
  enableConsole?: boolean;
}

export class Logger {
  private logDir: string;
  private logFileName: string;
  private logFilePath: string;
  private maxFileSize: number;
  private maxBackups: number;
  private minLevel: LogLevel;
  private enableConsole: boolean;

  constructor(config: LoggerConfig = {}) {
    // Default to ~/.pi/logs/pi-dcp
    this.logDir = config.logDir || join(homedir(), ".pi", "logs");
    this.logFileName = config.logFileName || "pi-dcp.log";
    this.logFilePath = join(this.logDir, this.logFileName);
    this.maxFileSize = config.maxFileSize || 10 * 1024 * 1024; // 10MB
    this.maxBackups = config.maxBackups || 5;
    this.minLevel = config.minLevel ?? LogLevel.INFO;
    this.enableConsole = config.enableConsole || false;

    // Ensure log directory exists
    this.ensureLogDirectory();
  }

  private ensureLogDirectory(): void {
    if (!existsSync(this.logDir)) {
      mkdirSync(this.logDir, { recursive: true });
    }
  }

  private shouldRotate(): boolean {
    if (!existsSync(this.logFilePath)) {
      return false;
    }

    try {
      const stats = statSync(this.logFilePath);
      return stats.size >= this.maxFileSize;
    } catch (error) {
      return false;
    }
  }

  private rotateLogs(): void {
    try {
      // Delete oldest backup if we're at the limit
      const oldestBackup = join(this.logDir, `${this.logFileName}.${this.maxBackups}`);
      if (existsSync(oldestBackup)) {
        unlinkSync(oldestBackup);
      }

      // Shift all existing backups up by one
      for (let i = this.maxBackups - 1; i >= 1; i--) {
        const oldPath = join(this.logDir, `${this.logFileName}.${i}`);
        const newPath = join(this.logDir, `${this.logFileName}.${i + 1}`);
        if (existsSync(oldPath)) {
          renameSync(oldPath, newPath);
        }
      }

      // Move current log to .1
      const backupPath = join(this.logDir, `${this.logFileName}.1`);
      renameSync(this.logFilePath, backupPath);
    } catch (error) {
      // If rotation fails, try to continue with current log
      console.error("[pi-dcp] Failed to rotate logs:", error);
    }
  }

  private formatMessage(
    level: LogLevel,
    message: string,
    context?: Record<string, unknown>
  ): string {
    const timestamp = new Date().toISOString();
    const levelStr = LogLevel[level].padEnd(5);
    const contextStr = context ? ` ${JSON.stringify(context)}` : "";
    return `${timestamp} [${levelStr}] ${message}${contextStr}\n`;
  }

  private write(level: LogLevel, message: string, context?: Record<string, unknown>): void {
    // Skip if below minimum level
    if (level > this.minLevel) {
      return;
    }

    const formatted = this.formatMessage(level, message, context);

    // Write to console if enabled
    if (this.enableConsole) {
      const consoleMethod = level === LogLevel.ERROR ? console.error : console.log;
      consoleMethod(`[pi-dcp] ${message}`, context || "");
    }

    try {
      // Check if rotation is needed
      if (this.shouldRotate()) {
        this.rotateLogs();
      }

      // Append to log file (synchronous for simplicity)
      appendFileSync(this.logFilePath, formatted, "utf8");
    } catch (error) {
      // Fallback to console if file write fails
      console.error("[pi-dcp] Failed to write to log file:", error);
      console.log(formatted);
    }
  }

  error(message: string, context?: Record<string, unknown>): void {
    this.write(LogLevel.ERROR, message, context);
  }

  warn(message: string, context?: Record<string, unknown>): void {
    this.write(LogLevel.WARN, message, context);
  }

  info(message: string, context?: Record<string, unknown>): void {
    this.write(LogLevel.INFO, message, context);
  }

  debug(message: string, context?: Record<string, unknown>): void {
    this.write(LogLevel.DEBUG, message, context);
  }

  /**
   * Get the path to the current log file
   */
  getLogPath(): string {
    return this.logFilePath;
  }

  /**
   * Get list of all log files (current + backups)
   */
  getAllLogFiles(): string[] {
    const files: string[] = [];

    if (existsSync(this.logFilePath)) {
      files.push(this.logFilePath);
    }

    for (let i = 1; i <= this.maxBackups; i++) {
      const backupPath = join(this.logDir, `${this.logFileName}.${i}`);
      if (existsSync(backupPath)) {
        files.push(backupPath);
      }
    }

    return files;
  }

  /**
   * Update the minimum log level dynamically
   */
  setMinLevel(level: LogLevel): void {
    this.minLevel = level;
  }
}

// Singleton instance
let loggerInstance: Logger | null = null;

/**
 * Get or create the logger instance
 */
export function getLogger(config?: LoggerConfig): Logger {
  if (!loggerInstance) {
    loggerInstance = new Logger(config);
  }
  return loggerInstance;
}

/**
 * Reset the logger instance (useful for testing)
 */
export function resetLogger(): void {
  loggerInstance = null;
}
