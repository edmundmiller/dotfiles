package format

import (
	"fmt"
	"sort"
	"strings"
	"time"

	"github.com/1set/todotxt"
)

type FormatterV2 struct {
	SortTags string // "none" or "alpha"
	SortMeta string // "none" or "alpha"
	Verbose  bool
}

func (f *FormatterV2) FormatTaskList(taskList todotxt.TaskList) ([]string, bool) {
	var result []string
	changed := false
	
	for i, task := range taskList {
		original := task.String()
		formatted := f.formatTask(&task)
		
		result = append(result, formatted)
		
		if formatted != original {
			changed = true
			if f.Verbose {
				fmt.Printf("Line %d changed:\n  Before: %s\n  After:  %s\n", 
					i+1, original, formatted)
			}
		}
	}
	
	return result, changed
}

func (f *FormatterV2) FormatLines(lines []string) ([]string, bool) {
	// Parse lines into TaskList, preserving comments and blank lines
	taskList := todotxt.NewTaskList()
	lineTypes := make([]string, len(lines)) // track what each line is
	
	for i, line := range lines {
		line = strings.TrimSpace(line)
		
		if line == "" {
			lineTypes[i] = "blank"
			// Create dummy task to preserve position
			task := todotxt.NewTask()
			task.Original = ""
			task.Todo = ""
			taskList = append(taskList, task)
		} else if strings.HasPrefix(line, "#") {
			lineTypes[i] = "comment"
			// Create dummy task to preserve position
			task := todotxt.NewTask()
			task.Original = line
			task.Todo = line
			taskList = append(taskList, task)
		} else {
			lineTypes[i] = "task"
			// Parse as actual task
			task, err := todotxt.ParseTask(line)
			if err != nil {
				// If parsing fails, treat as raw line
				lineTypes[i] = "raw"
				taskVal := todotxt.NewTask()
				taskVal.Original = line
				taskVal.Todo = line
				taskList = append(taskList, taskVal)
			} else {
				taskList = append(taskList, *task)
			}
		}
	}
	
	// Format each item
	result := make([]string, len(taskList))
	changed := false
	
	for i, task := range taskList {
		switch lineTypes[i] {
		case "blank":
			result[i] = ""
		case "comment", "raw":
			result[i] = task.Original
		case "task":
			formatted := f.formatTask(&task)
			result[i] = formatted
			if formatted != task.Original {
				changed = true
				if f.Verbose {
					fmt.Printf("Line %d changed:\n  Before: %s\n  After:  %s\n", 
						i+1, task.Original, formatted)
				}
			}
		}
	}
	
	return result, changed
}

func (f *FormatterV2) FormatTask(task *todotxt.Task) string {
	return f.formatTask(task)
}

func (f *FormatterV2) formatTask(task *todotxt.Task) string {
	return f.formatTaskComprehensive(task)
}


func (f *FormatterV2) formatTaskComprehensive(task *todotxt.Task) string {
	// For comprehensive mode, let's just use the library's built-in formatting
	// but ensure consistent spacing and ordering
	
	// Let the library generate the properly formatted string
	formatted := task.String()
	
	// Just normalize spacing
	return f.normalizeSpacing(formatted)
}

func (f *FormatterV2) normalizeSpacing(text string) string {
	// Normalize spacing
	fields := strings.Fields(text)
	return strings.Join(fields, " ")
}

func (f *FormatterV2) extractMainDescription(task *todotxt.Task) string {
	// Get the original todo text and parse out just the description part
	// We'll let the library handle parsing rather than doing string manipulation
	
	// Start with the original todo text
	todo := task.Todo
	
	// Remove contexts
	for _, context := range task.Contexts {
		todo = strings.ReplaceAll(todo, "@"+context, "")
	}
	
	// Remove projects
	for _, project := range task.Projects {
		todo = strings.ReplaceAll(todo, "+"+project, "")
	}
	
	// Remove additional tags (metadata)
	for key, value := range task.AdditionalTags {
		todo = strings.ReplaceAll(todo, key+":"+value, "")
	}
	
	// Clean up extra spaces
	return f.normalizeSpacing(todo)
}

func (f *FormatterV2) isDate(s string) bool {
	_, err := time.Parse(todotxt.DateLayout, s)
	return err == nil
}

func (f *FormatterV2) extractAndSortContexts(contexts []string) []string {
	if len(contexts) == 0 {
		return nil
	}
	
	// Add @ prefix and deduplicate
	contextMap := make(map[string]bool)
	for _, ctx := range contexts {
		contextMap["@"+ctx] = true
	}
	
	result := make([]string, 0, len(contextMap))
	for ctx := range contextMap {
		result = append(result, ctx)
	}
	
	if f.SortTags == "alpha" {
		sort.Strings(result)
	}
	
	return result
}

func (f *FormatterV2) extractAndSortProjects(projects []string) []string {
	if len(projects) == 0 {
		return nil
	}
	
	// Add + prefix and deduplicate
	projectMap := make(map[string]bool)
	for _, proj := range projects {
		projectMap["+"+proj] = true
	}
	
	result := make([]string, 0, len(projectMap))
	for proj := range projectMap {
		result = append(result, proj)
	}
	
	if f.SortTags == "alpha" {
		sort.Strings(result)
	}
	
	return result
}

func (f *FormatterV2) extractAndSortMetadata(task *todotxt.Task) []string {
	if len(task.AdditionalTags) == 0 {
		return nil
	}
	
	result := make([]string, 0, len(task.AdditionalTags))
	for key, value := range task.AdditionalTags {
		// Normalize date metadata
		if f.isDateMetadata(key) {
			if normalized := f.normalizeDateValue(value); normalized != "" {
				value = normalized
			}
		}
		result = append(result, key+":"+value)
	}
	
	if f.SortMeta == "alpha" {
		sort.Strings(result)
	}
	
	return result
}

func (f *FormatterV2) isDateMetadata(key string) bool {
	dateKeys := []string{"due", "t", "threshold", "start", "scheduled"}
	for _, dateKey := range dateKeys {
		if key == dateKey {
			return true
		}
	}
	return false
}

func (f *FormatterV2) normalizeDateValue(value string) string {
	// Try to parse and reformat date
	if t, err := time.Parse(todotxt.DateLayout, value); err == nil {
		return t.Format(todotxt.DateLayout) // Already in correct format
	}
	
	// Try other common formats
	layouts := []string{
		"2006/01/02",
		"2006.01.02", 
		"01/02/2006",
		"02-01-2006",
		"2006-01-02T15:04:05Z07:00", // ISO format
	}
	
	for _, layout := range layouts {
		if t, err := time.Parse(layout, value); err == nil {
			return t.Format(todotxt.DateLayout)
		}
	}
	
	return value // Could not normalize, return as-is
}