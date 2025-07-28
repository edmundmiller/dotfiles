# Add New Task

Create a new task in Taskwarrior with proper attributes.

## Quick Task Creation

Tell me what task you'd like to add and I'll help you create it with appropriate:
- **Description**: Clear, actionable task description
- **Project**: Group related tasks together  
- **Tags**: Categorize for easy filtering
- **Priority**: H/M/L based on importance
- **Due date**: When the task needs to be completed
- **Dependencies**: If it depends on other tasks

## Example Usage

Here are some examples of tasks I can help you create:

1. **Code tasks**: "Fix the login bug in authentication module"
   ```bash
   task add "Fix login authentication bug" project:auth +bug priority:H due:tomorrow
   ```

2. **Feature requests**: "Add dark mode toggle to settings"
   ```bash
   task add "Implement dark mode toggle" project:ui +feature priority:M +enhancement
   ```

3. **Documentation**: "Update API documentation for user endpoints"
   ```bash
   task add "Update user API documentation" project:docs +documentation priority:L
   ```

4. **Research tasks**: "Research React 18 migration impact"
   ```bash
   task add "Research React 18 migration" project:frontend +research priority:M
   ```

## Smart Task Parsing

I can parse natural language descriptions and extract:
- **Time estimates**: "This should take about 2 hours"
- **Context**: "When working on the mobile app"
- **Dependencies**: "After the database migration is complete"
- **Urgency indicators**: "ASAP", "urgent", "low priority"

Just describe the task you want to add and I'll format it properly for Taskwarrior!