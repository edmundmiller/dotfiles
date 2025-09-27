package io

import (
	"bytes"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/1set/todotxt"
	"github.com/emiller/todotxtfmt/internal/format"
)

type Handler struct {
	DryRun  bool
	Diff    bool
	Backup  string
	KeepEOL string
	Verbose bool
	Quiet   bool
}

type FileInfo struct {
	Lines       []string
	EOL         string
	HasBOM      bool
	HasFinalEOL bool
}

type Formatter interface {
	FormatLines(lines []string) ([]string, bool)
}

func (h *Handler) ProcessFileWithTodoTxt(inputPath, outputPath string, formatter *format.FormatterV2) (bool, error) {
	// Load the todo.txt file using the library
	taskList, err := todotxt.LoadFromPath(inputPath)
	if err != nil {
		return false, fmt.Errorf("loading file: %w", err)
	}
	
	if h.Verbose && !h.Quiet {
		fmt.Printf("Loaded %d tasks from %s\n", len(taskList), inputPath)
	}
	
	// Format using the library's task list
	originalLines := make([]string, len(taskList))
	for i, task := range taskList {
		originalLines[i] = task.String()
	}
	
	formattedLines, changed := formatter.FormatTaskList(taskList)
	if !changed {
		if h.Verbose && !h.Quiet {
			fmt.Printf("No changes needed for %s\n", inputPath)
		}
		return false, nil
	}
	
	if h.Verbose && !h.Quiet {
		fmt.Printf("Changes detected in %s\n", inputPath)
	}
	
	// Generate diff if requested
	if h.Diff {
		h.showDiff(inputPath, originalLines, formattedLines, "\n")
	}
	
	// If dry run, don't write
	if h.DryRun {
		return true, nil
	}
	
	// Determine output path
	if outputPath == "" {
		outputPath = inputPath
	}
	
	// Create backup if requested
	if h.Backup != "" {
		if err := h.createBackup(inputPath); err != nil {
			return false, fmt.Errorf("creating backup: %w", err)
		}
	}
	
	// Write formatted content
	if err := h.writeFormattedLines(outputPath, formattedLines); err != nil {
		return false, fmt.Errorf("writing file: %w", err)
	}
	
	if h.Verbose && !h.Quiet {
		fmt.Printf("Successfully updated %s\n", outputPath)
	}
	
	return true, nil
}

func (h *Handler) ProcessFile(inputPath, outputPath string, formatter Formatter) (bool, error) {
	// Read file
	fileInfo, err := h.readFile(inputPath)
	if err != nil {
		return false, fmt.Errorf("reading file: %w", err)
	}
	
	// Format lines
	formatted, changed := formatter.FormatLines(fileInfo.Lines)
	if !changed {
		if h.Verbose && !h.Quiet {
			fmt.Printf("No changes needed for %s\n", inputPath)
		}
		return false, nil
	}
	
	if h.Verbose && !h.Quiet {
		fmt.Printf("Changes detected in %s\n", inputPath)
	}
	
	// Generate diff if requested
	if h.Diff {
		h.showDiff(inputPath, fileInfo.Lines, formatted, fileInfo.EOL)
	}
	
	// If dry run, don't write
	if h.DryRun {
		return true, nil
	}
	
	// Determine output path
	if outputPath == "" {
		outputPath = inputPath
	}
	
	// Create backup if requested
	if h.Backup != "" {
		if err := h.createBackup(inputPath); err != nil {
			return false, fmt.Errorf("creating backup: %w", err)
		}
	}
	
	// Write formatted content
	if err := h.writeFile(outputPath, formatted, fileInfo); err != nil {
		return false, fmt.Errorf("writing file: %w", err)
	}
	
	if h.Verbose && !h.Quiet {
		fmt.Printf("Successfully updated %s\n", outputPath)
	}
	
	return true, nil
}

func (h *Handler) readFile(path string) (*FileInfo, error) {
	file, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	defer file.Close()
	
	// Read all content to detect BOM and EOL
	content, err := io.ReadAll(file)
	if err != nil {
		return nil, err
	}
	
	info := &FileInfo{}
	
	// Check for BOM
	if len(content) >= 3 && bytes.Equal(content[:3], []byte{0xEF, 0xBB, 0xBF}) {
		info.HasBOM = true
		content = content[3:]
	}
	
	// Detect EOL style
	text := string(content)
	if strings.Contains(text, "\r\n") {
		info.EOL = "\r\n"
	} else if strings.Contains(text, "\n") {
		info.EOL = "\n"
	} else {
		info.EOL = "\n" // Default
	}
	
	// Override EOL if specified
	switch h.KeepEOL {
	case "lf":
		info.EOL = "\n"
	case "crlf":
		info.EOL = "\r\n"
	// "auto" keeps detected EOL
	}
	
	// Check for final newline
	info.HasFinalEOL = len(content) > 0 && (content[len(content)-1] == '\n' || 
		(len(content) >= 2 && content[len(content)-2] == '\r' && content[len(content)-1] == '\n'))
	
	// Split into lines
	lines := strings.Split(text, info.EOL)
	
	// If file ends with newline, remove empty last line
	if len(lines) > 0 && lines[len(lines)-1] == "" {
		lines = lines[:len(lines)-1]
	}
	
	info.Lines = lines
	return info, nil
}

func (h *Handler) writeFile(path string, lines []string, info *FileInfo) error {
	// Prepare content
	var buf bytes.Buffer
	
	// Add BOM if original had it
	if info.HasBOM {
		buf.Write([]byte{0xEF, 0xBB, 0xBF})
	}
	
	// Write lines with appropriate EOL
	for i, line := range lines {
		buf.WriteString(line)
		if i < len(lines)-1 || info.HasFinalEOL {
			buf.WriteString(info.EOL)
		}
	}
	
	// Atomic write: write to temp file then rename
	dir := filepath.Dir(path)
	tempFile, err := os.CreateTemp(dir, ".todotxtfmt-*")
	if err != nil {
		return err
	}
	tempPath := tempFile.Name()
	
	// Clean up temp file on error
	defer func() {
		if err != nil {
			os.Remove(tempPath)
		}
	}()
	
	// Write content
	if _, err = tempFile.Write(buf.Bytes()); err != nil {
		tempFile.Close()
		return err
	}
	
	// Sync and close
	if err = tempFile.Sync(); err != nil {
		tempFile.Close()
		return err
	}
	
	if err = tempFile.Close(); err != nil {
		return err
	}
	
	// Copy original permissions
	if stat, statErr := os.Stat(path); statErr == nil {
		os.Chmod(tempPath, stat.Mode())
	}
	
	// Atomic rename
	return os.Rename(tempPath, path)
}

func (h *Handler) createBackup(path string) error {
	backupDir := filepath.Dir(path)
	if h.Backup != "" {
		backupDir = h.Backup
	}
	
	// Ensure backup directory exists
	if err := os.MkdirAll(backupDir, 0755); err != nil {
		return err
	}
	
	// Generate backup filename
	basename := filepath.Base(path)
	timestamp := time.Now().Format("20060102-150405")
	backupPath := filepath.Join(backupDir, fmt.Sprintf("%s.%s.bak", basename, timestamp))
	
	// Copy file
	source, err := os.Open(path)
	if err != nil {
		return err
	}
	defer source.Close()
	
	dest, err := os.Create(backupPath)
	if err != nil {
		return err
	}
	defer dest.Close()
	
	if _, err = io.Copy(dest, source); err != nil {
		return err
	}
	
	// Copy permissions
	if stat, err := source.Stat(); err == nil {
		dest.Chmod(stat.Mode())
	}
	
	if h.Verbose && !h.Quiet {
		fmt.Printf("Backup created: %s\n", backupPath)
	}
	
	return nil
}

func (h *Handler) showDiff(filename string, original, formatted []string, eol string) {
	fmt.Printf("\n=== Diff for %s ===\n", filename)
	
	// Simple unified diff implementation
	fmt.Printf("--- %s\n", filename)
	fmt.Printf("+++ %s (formatted)\n", filename)
	
	maxLines := len(original)
	if len(formatted) > maxLines {
		maxLines = len(formatted)
	}
	
	for i := 0; i < maxLines; i++ {
		var origLine, fmtLine string
		
		if i < len(original) {
			origLine = original[i]
		}
		if i < len(formatted) {
			fmtLine = formatted[i]
		}
		
		if origLine != fmtLine {
			if origLine != "" {
				fmt.Printf("-%s\n", origLine)
			}
			if fmtLine != "" {
				fmt.Printf("+%s\n", fmtLine)
			}
		}
	}
	
	fmt.Println()
}

func (h *Handler) writeFormattedLines(path string, lines []string) error {
	// Simple write - just join lines with newlines
	content := strings.Join(lines, "\n")
	if len(lines) > 0 && lines[len(lines)-1] != "" {
		content += "\n" // Ensure final newline
	}
	
	// Atomic write: write to temp file then rename
	dir := filepath.Dir(path)
	tempFile, err := os.CreateTemp(dir, ".todotxtfmt-*")
	if err != nil {
		return err
	}
	tempPath := tempFile.Name()
	
	// Clean up temp file on error
	defer func() {
		if err != nil {
			os.Remove(tempPath)
		}
	}()
	
	// Write content
	if _, err = tempFile.WriteString(content); err != nil {
		tempFile.Close()
		return err
	}
	
	// Sync and close
	if err = tempFile.Sync(); err != nil {
		tempFile.Close()
		return err
	}
	
	if err = tempFile.Close(); err != nil {
		return err
	}
	
	// Copy original permissions
	if stat, statErr := os.Stat(path); statErr == nil {
		os.Chmod(tempPath, stat.Mode())
	}
	
	// Atomic rename
	return os.Rename(tempPath, path)
}
