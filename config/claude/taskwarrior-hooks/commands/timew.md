# Timewarrior Management

Track and analyze your development time with Timewarrior integration.

## Current Status

Check what you're currently tracking:

```bash
echo "=== CURRENT TRACKING ===" && \
timew && \
echo && echo "=== TODAY'S SUMMARY ===" && \
timew summary :day && \
echo && echo "=== THIS WEEK ===" && \
timew summary :week
```

## Time Tracking Control

Start, stop, and manage time tracking:

```bash
# Check if currently tracking
if timew get dom.active 2>/dev/null | grep -q "1"; then
    echo "⏱️  Currently tracking: $(timew get dom.active.tag.1 2>/dev/null || echo 'untagged work')"
    echo "Started: $(timew get dom.active.start 2>/dev/null)"
else
    echo "⏸️  Not currently tracking time"
    echo "Use 'timew start <tags>' to begin tracking"
fi
```

## Common Commands

Here are the most useful Timewarrior commands for development:

### Start Tracking
```bash
# Start general coding session
timew start coding

# Start with specific project and language
timew start coding python project:myapp

# Start with multiple tags
timew start coding debugging frontend react
```

### Stop and Continue
```bash
# Stop current tracking
timew stop

# Continue previous session
timew continue

# Continue with different tags
timew start $(timew get dom.active.tag.1) meeting
```

## Smart Time Tracking

I can help you:
- **Auto-tag by file type**: Python files → `python` tag
- **Detect project context**: Working in `myapp/` → `project:myapp` 
- **Categorize activities**: Code editing → `coding`, Reading → `review`
- **Track development phases**: `research`, `implementation`, `testing`, `debugging`

## Reports and Analysis

Generate detailed time reports:

```bash
echo "=== TIME BREAKDOWN ===" && \
timew summary :week :ids && \
echo && echo "=== BY PROJECT ===" && \
timew summary :week project && \
echo && echo "=== BY ACTIVITY ===" && \
timew summary :week coding debugging testing
```

What would you like to track or analyze?