# Taskwarrior Management Commands

Show and manage your Taskwarrior tasks directly within Claude Code.

## Task Overview

First, let's get an overview of your current tasks:

```bash
echo "=== TASKWARRIOR SUMMARY ===" && \
task summary && \
echo && echo "=== PENDING TASKS ===" && \
task list && \
echo && echo "=== OVERDUE TASKS ===" && \
task overdue && \
echo && echo "=== TODAY'S AGENDA ===" && \
task list due:today
```

## Recent Activity

Show recent task activity and completed tasks:

```bash
echo "=== RECENTLY COMPLETED ===" && \
task completed limit:10 && \
echo && echo "=== RECENT MODIFICATIONS ===" && \
task history.monthly
```

## Filter and Search

Apply filters to find specific tasks:

- **By project**: Show tasks for a specific project
- **By tag**: Show tasks with specific tags  
- **By priority**: Show high/medium/low priority tasks
- **By due date**: Show tasks due soon

```bash
echo "Choose a filter type:" && \
echo "1. Project: task project:PROJECTNAME" && \
echo "2. Tag: task +TAGNAME" && \
echo "3. Priority: task priority:H" && \
echo "4. Due: task due:tomorrow" && \
echo "5. Urgent: task urgency \> 10"
```

Let me know which filter you'd like to apply or what specific tasks you want to see.