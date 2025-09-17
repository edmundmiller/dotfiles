package main

import (
	"fmt"
	"github.com/1set/todotxt"
)

func main() {
	task := todotxt.NewTask()
	fmt.Printf("NewTask returns: %T\n", task)
	
	taskList := todotxt.NewTaskList()
	fmt.Printf("NewTaskList returns: %T\n", taskList)
	
	// Test parsing
	line := "(C) 2025-09-06 Get a gym bag @personal +fitness"
	parsed, err := todotxt.ParseTask(line)
	if err != nil {
		fmt.Printf("Parse error: %v\n", err)
	} else {
		fmt.Printf("ParseTask returns: %T\n", parsed)
		fmt.Printf("Projects: %v\n", parsed.Projects)
		fmt.Printf("Contexts: %v\n", parsed.Contexts)
		fmt.Printf("String: %s\n", parsed.String())
	}
}
