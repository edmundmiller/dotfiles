package main

import (
	"fmt"
	"os"

	"github.com/emiller/todotxtfmt/internal/cli"
)

var version = "dev"

func main() {
	if err := cli.Run(version, os.Args[1:]); err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		os.Exit(1)
	}
}