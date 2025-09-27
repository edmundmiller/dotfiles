package cli

import (
	"fmt"
	"os"

	"github.com/spf13/pflag"
	"github.com/emiller/todotxtfmt/internal/format"
	"github.com/emiller/todotxtfmt/internal/io"
)

type Config struct {
	DryRun      bool
	Diff        bool
	Backup      string
	Verbose     bool
	Quiet       bool
	Input       string
	Output      string
	InPlace     bool
	KeepEOL     string
	SortTags    string
	SortMeta    string
	Version     bool
}

func Run(version string, args []string) error {
	var cfg Config
	
	flags := pflag.NewFlagSet("todotxtfmt", pflag.ContinueOnError)
	
	// Behavior
	flags.BoolVarP(&cfg.DryRun, "dry-run", "n", false, "preview changes without applying them")
	flags.BoolVar(&cfg.Diff, "diff", false, "show unified diff of changes")
	flags.StringVar(&cfg.Backup, "backup", "", "create backup (optional directory)")
	
	// Output control
	flags.BoolVarP(&cfg.Verbose, "verbose", "v", false, "verbose output")
	flags.BoolVarP(&cfg.Quiet, "quiet", "q", false, "suppress non-essential output")
	flags.StringVarP(&cfg.Input, "input", "i", "", "input file (default: $TODO_FILE)")
	flags.StringVarP(&cfg.Output, "output", "o", "", "output file (default: same as input)")
	flags.BoolVar(&cfg.InPlace, "in-place", true, "modify files in place")
	
	// Advanced options
	flags.StringVar(&cfg.KeepEOL, "keep-eol", "auto", "EOL style: auto|lf|crlf")
	flags.StringVar(&cfg.SortTags, "sort-tags", "none", "sort @contexts and +projects: none|alpha")
	flags.StringVar(&cfg.SortMeta, "sort-meta", "none", "sort metadata keys: none|alpha")
	
	// Informational
	flags.BoolVar(&cfg.Version, "version", false, "show version")
	
	flags.Usage = func() {
		fmt.Fprintf(os.Stderr, `todotxtfmt - Format todo.txt files

Usage:
  todotxtfmt [options] [file]

Options:
`)
		flags.PrintDefaults()
		fmt.Fprintf(os.Stderr, `
Examples:
  todotxtfmt                          # Format $TODO_FILE in place
  todotxtfmt --mode comprehensive     # Use comprehensive formatting
  todotxtfmt --dry-run --diff         # Preview changes
  todotxtfmt myfile.txt               # Format specific file

Exit Codes:
  0  Success (changes written or none needed)
  2  Dry run with changes detected
  1  Error occurred
`)
	}
	
	if err := flags.Parse(args); err != nil {
		return err
	}
	
	if cfg.Version {
		fmt.Printf("todotxtfmt %s\n", version)
		return nil
	}
	
	// Determine input file
	if cfg.Input == "" {
		remaining := flags.Args()
		if len(remaining) > 0 {
			cfg.Input = remaining[0]
		} else {
			// Try TODO_FILE, then DONE_FILE, then common paths
			cfg.Input = os.Getenv("TODO_FILE")
			if cfg.Input == "" {
				cfg.Input = os.Getenv("DONE_FILE")
			}
			if cfg.Input == "" {
				// Try common default paths
				commonPaths := []string{
					os.Getenv("HOME") + "/Documents/todo/todo.txt",
					os.Getenv("HOME") + "/todo.txt",
					"./todo.txt",
				}
				for _, path := range commonPaths {
					if _, err := os.Stat(path); err == nil {
						cfg.Input = path
						break
					}
				}
			}
			if cfg.Input == "" {
				return fmt.Errorf("no input file found. Set TODO_FILE environment variable or specify a file")
			}
		}
	}
	
	// Create formatter
	formatter := &format.FormatterV2{
		SortTags: cfg.SortTags,
		SortMeta: cfg.SortMeta,
		Verbose:  cfg.Verbose,
	}
	
	// Create I/O handler
	ioHandler := &io.Handler{
		DryRun:  cfg.DryRun,
		Diff:    cfg.Diff,
		Backup:  cfg.Backup,
		KeepEOL: cfg.KeepEOL,
		Verbose: cfg.Verbose,
		Quiet:   cfg.Quiet,
	}
	
	// Process the file
	changed, err := ioHandler.ProcessFileWithTodoTxt(cfg.Input, cfg.Output, formatter)
	if err != nil {
		return err
	}
	
	// Handle exit codes for dry-run
	if cfg.DryRun && changed {
		os.Exit(2)
	}
	
	return nil
}