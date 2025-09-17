package main

import (
	"fmt"

	"github.com/1set/todotxt"
	"github.com/emiller/todotxtfmt/internal/format"
)

func main() {
	// Test data similar to what you had issues with
	testLines := []string{
		"(C) 2025-09-06 Get a gym bag for my car @personal +fitness",
		"Fix    critical    bug +webapp due:today",
		"x (A) 2025-09-06 Fill 30 prescription due:2025-09-07 t:2025-09-07",
		"   (B)  2025-09-08  Reschedule Amy @personal +meetings  due:2025-09-13  ",
		"# Some comment",
		"Write documentation    @work   +project due:2025-12-01",
		"x 2025-09-10 2025-09-09 Review chapter @phd +dissertation",
		"",
		"(A) 2025-09-12 Send dissertation to committee @phd +dissertation due:2025-09-12",
	}

	fmt.Println("=== Testing Formatter ===\n")
	testFormatter := &format.FormatterV2{
		SortTags: "alpha",
		SortMeta: "alpha",
		Verbose:  true,
	}

	result2, changed2 := testFormatter.FormatLines(testLines)
	fmt.Printf("Changed: %v\n\n", changed2)

	for i, line := range result2 {
		fmt.Printf("%2d: %s\n", i+1, line)
	}

	fmt.Println("\n=== Testing Direct Task Parsing ===")
	// Test specific problematic lines
	problemLines := []string{
		"+fitness should be preserved",
		"(C) 2025-09-06 Get a gym bag @personal +fitness",  
		"Write docs @work +project due:2025-12-01",
	}

	for _, line := range problemLines {
		fmt.Printf("\nOriginal: %s\n", line)
		
		// Try to parse with the library
		task, err := todotxt.ParseTask(line)
		if err != nil {
			fmt.Printf("Parse error: %v\n", err)
			continue
		}
		
		fmt.Printf("Parsed projects: %v\n", task.Projects)
		fmt.Printf("Parsed contexts: %v\n", task.Contexts)
		fmt.Printf("Task.String(): %s\n", task.String())
		
		// Test formatting
		formatted := testFormatter.FormatTask(task)
		fmt.Printf("Formatted: %s\n", formatted)
	}
}