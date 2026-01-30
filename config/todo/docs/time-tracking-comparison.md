# Time Tracking in todo.txt: donow vs timetrack

Last updated: 2025-09-09

## TL;DR

- **Choose `donow`** if you want simple, lightweight time tracking with reminder notifications and prefer time data stored directly with your tasks
- **Choose `timetrack`** if you need professional-grade time logs, comprehensive reporting, and detailed analytics for billing or project management

## Overview

Both methods extend todo.txt with time tracking capabilities but take fundamentally different approaches to data storage and workflow.

### donow

**Repository**: https://github.com/clobrano-forks/todo.txt-cli  
**Focus**: Simple inline time tracking with desktop notifications

`donow` is a straightforward time tracker that appends time information directly to your todo.txt entries. It's designed for personal productivity with built-in reminder notifications to keep you focused.

### timetrack

**Repository**: https://git.sr.ht/~proycon/todotxt-more  
**Focus**: Professional time logging with comprehensive reporting

`timetrack` maintains a separate detailed log file and provides extensive reporting capabilities. It's built for professional use cases requiring detailed time analysis and billing.

## Installation and Setup

### donow Requirements and Installation

**Dependencies:**

- Bash shell
- `todo.txt-cli` installed and configured
- For notifications:
  - macOS: Built-in `osascript` (included)
  - Linux: `libnotify-bin` package (`sudo apt-get install libnotify-bin`)

**Installation:**

```bash path=null start=null
# Download the donow script
curl -o ~/.todo.actions.d/donow \
  https://raw.githubusercontent.com/clobrano-forks/todo.txt-cli/master/todo.actions.d/donow

# Make it executable
chmod +x ~/.todo.actions.d/donow

# Optional: Enable evidence logging by editing the script
# Uncomment: EVIDENCE_LOG=$TODO_DIR/evidence.log
```

**Configuration:**
Edit the donow script to customize:

```bash path=null start=null
DESKTOP_NOTIFICATION=true        # Enable/disable notifications
REMINDER_INTERVAL=10             # Minutes between reminders
EVIDENCE_LOG=$TODO_DIR/evidence.log  # Optional detailed log
```

### timetrack Requirements and Installation

**Dependencies:**

- Bash shell
- Python 3 (for helper scripts)
- `todo.txt-cli` installed and configured
- Standard Unix utilities (`date`, `sed`, `grep`)

**Installation:**

```bash path=null start=null
# Download the timetrack script
curl -o ~/.todo.actions.d/timetrack \
  https://git.sr.ht/~proycon/todotxt-more/blob/master/todo.actions.d/timetrack

# Make it executable
chmod +x ~/.todo.actions.d/timetrack

# Download required helper scripts
mkdir -p ~/.todo.actions.d/helpers
curl -o ~/.todo.actions.d/helpers/timetrack_log.py \
  https://git.sr.ht/~proycon/todotxt-more/blob/master/todo.actions.d/helpers/timetrack_log.py
curl -o ~/.todo.actions.d/helpers/timetrack_sum.py \
  https://git.sr.ht/~proycon/todotxt-more/blob/master/todo.actions.d/helpers/timetrack_sum.py
```

**Configuration:**

```bash path=null start=null
export TIMETRACK_FILE="$TODO_DIR/timetrack.txt"  # Optional: custom log location
export TODOTXT_NOTIFY=1                           # Enable system notifications
```

## Usage Examples

### donow Usage

**Basic workflow:**

```bash path=null start=null
# List your tasks
$ todo.sh list
1 Write project report +work @office
2 Implement API feature +dev @coding

# Start tracking task #1
$ todo.sh donow 1
Working on: Write project report +work @office
[Write project report +work @office] 1 minute(s) passed
[Write project report +work @office] 2 minute(s) passed
...
[Write project report +work @office] 10 minute(s) passed  # Notification appears
...
# Press Ctrl+C to stop

# Check updated task
$ todo.sh list
1 Write project report +work @office min:15
2 Implement API feature +dev @coding
```

**Resuming work on the same task:**

```bash path=null start=null
$ todo.sh donow 1
Working on: Write project report +work @office min:15
[Write project report +work @office min:15] 8 minute(s) passed^C

# Time is accumulated
$ todo.sh list
1 Write project report +work @office min:23
```

### timetrack Usage

**Basic workflow:**

```bash path=null start=null
# Start tracking a task
$ todo.sh timetrack start 1
# Task gets marked with #timetracking tag

# Check what you're currently working on
$ todo.sh timetrack current
2025-09-09 Mon 14:30 Write project report +work @office

# Check with relative time
$ todo.sh timetrack current -d
1h13m Write project report +work @office

# Switch to another task (automatically stops the previous one)
$ todo.sh timetrack start 2

# Manually stop tracking
$ todo.sh timetrack stop

# View today's summary
$ todo.sh timetrack daysummary
2025-09-09 Mon 8h52m @office
2025-09-09 Mon 4h8m +work
2025-09-09 Mon 2h15m +dev
```

**Advanced reporting:**

```bash path=null start=null
# Weekly summary
$ todo.sh timetrack weeksummary 2025-09-01 2

# Monthly summary
$ todo.sh timetrack monthsummary 2025

# View detailed log
$ todo.sh timetrack log 2025-09-01 2025-09-08
```

## Feature Comparison

| Capability                      | donow             | timetrack              | Notes                                         |
| ------------------------------- | ----------------- | ---------------------- | --------------------------------------------- |
| **Start/stop tracking**         | ✅ Start only     | ✅ Start/stop/pause    | timetrack auto-stops when starting new task   |
| **Pause and resume**            | ❌                | ✅                     | timetrack can resume from idle state          |
| **Multiple sessions per task**  | ✅ Cumulative     | ✅ Detailed log        | donow adds time, timetrack logs sessions      |
| **Stores data in todo.txt**     | ✅ `min:X` suffix | ✅ `#timetracking` tag | Different annotation styles                   |
| **Uses separate log file**      | ⚠️ Optional       | ✅ Required            | donow has optional evidence.log               |
| **Built-in reporting**          | ❌                | ✅ Extensive           | timetrack has day/week/month summaries        |
| **Desktop notifications**       | ✅ Reminders      | ✅ Start/stop only     | donow reminds every N minutes                 |
| **Time units and format**       | Minutes only      | Flexible (s/m/h)       | timetrack shows `1h13m`, donow shows `min:73` |
| **Context/project aggregation** | ❌                | ✅                     | timetrack groups by `@context` `+project`     |
| **Historical analysis**         | ❌                | ✅                     | timetrack supports date ranges                |
| **Dependencies**                | Minimal           | Python + helpers       | donow is pure bash                            |
| **Configuration options**       | 3 variables       | Environment vars       | donow edits script, timetrack uses env        |
| **Cross-platform**              | ✅ macOS/Linux    | ✅ Unix-like           | Both support major platforms                  |
| **Installation complexity**     | Simple            | Moderate               | timetrack needs helper scripts                |

## Data Storage Formats

### donow Data Format

**In todo.txt:**

```bash path=null start=null
# Before tracking
Write project report +work @office

# After 23 minutes of tracking
Write project report +work @office min:23
```

**Optional evidence.log:**

```bash path=null start=null
2025-09-09 14:30:15 start: Write project report +work @office
2025-09-09 15:15:42 stop : Write project report +work @office min:23
```

### timetrack Data Format

**In todo.txt:**

```bash path=null start=null
# Active task gets tagged
Write project report +work @office #timetracking

# Completed or stopped tasks lose the tag
Write project report +work @office
```

**In timetrack.txt:**

```bash path=null start=null
2025-09-09 Mon 14:30 Write project report +work @office
2025-09-09 Mon 15:15 Implement API feature +dev @coding
2025-09-09 Mon 16:00 idle
2025-09-09 Mon 16:30 Write project report +work @office
2025-09-09 Mon 17:00 idle
```

## Pros and Cons

### donow Advantages

- **Simple setup**: Single script, minimal dependencies
- **Inline data**: Time stored with tasks, easy to see at a glance
- **Focus reminders**: Notifications help maintain concentration
- **Cumulative tracking**: Natural accumulation of total time spent
- **Lightweight**: Pure bash, no external tools needed

### donow Disadvantages

- **Limited reporting**: Only shows total minutes per task
- **No historical analysis**: Can't analyze time patterns over periods
- **Manual task switching**: Must stop and start manually
- **Basic time format**: Only shows minutes, no hours/days
- **No project aggregation**: Can't see time by context or project

### timetrack Advantages

- **Professional reporting**: Daily, weekly, monthly summaries
- **Automatic switching**: Starting new task stops previous one
- **Flexible time display**: Shows time in human-readable format (1h13m)
- **Context/project analysis**: Groups time by `@context` and `+project`
- **Historical queries**: Analyze any date range
- **Separate audit log**: Detailed tracking without cluttering todo.txt
- **Rich command set**: Many options for different workflows

### timetrack Disadvantages

- **Complex setup**: Requires Python helpers and more configuration
- **Separate files**: Time data not immediately visible in todo.txt
- **Learning curve**: Many commands and options to master
- **Dependencies**: Requires Python and Unix utilities
- **Log management**: Need to maintain separate timetrack.txt file

## Recommendations

### Choose donow if you are:

- **Personal productivity focused**: Want simple time awareness
- **Minimalist**: Prefer data stored directly with tasks
- **Notification-driven**: Like regular reminders while working
- **Simplicity-seeking**: Want minimal setup and maintenance
- **Task-centric**: Care more about total time per task than when work happened

### Choose timetrack if you are:

- **Professional time tracking**: Need to bill clients or track projects
- **Analytics-oriented**: Want to understand time patterns and productivity
- **Multi-project juggling**: Work on many tasks/contexts and need reporting
- **Team/manager role**: Need to analyze team time allocation
- **Audit-compliant**: Require detailed time logs for business purposes

### By Persona

**Freelancer/Contractor**: **timetrack** - Need detailed logs for client billing  
**Student**: **donow** - Simple focus tracking for study sessions  
**Project Manager**: **timetrack** - Need team time analysis and reporting  
**Personal Productivity**: **donow** - Want awareness without complexity  
**Consultant**: **timetrack** - Multiple clients require detailed time breakdown  
**Developer**: Either - **donow** for focus, **timetrack** for project analysis

## Technical Implementation Details

### donow Implementation

- **Language**: Pure Bash script
- **Time calculation**: Minute-based counter with sleep loops
- **Signal handling**: Uses trap for SIGINT to save time on Ctrl+C
- **Data persistence**: Regex replacement of `min:X` pattern in todo.txt
- **Notifications**: Platform detection (macOS osascript vs Linux notify-send)

### timetrack Implementation

- **Language**: Bash script with Python helpers
- **Time format**: ISO date format `YYYY-MM-DD Day HH:MM`
- **Log structure**: Append-only log with task descriptions
- **Aggregation**: Python scripts parse logs and sum by context/project
- **Task marking**: Adds/removes `#timetracking` tag in todo.txt

### Data Migration and Interoperability

**Converting from donow to timetrack:**

```bash path=null start=null
# Extract time data from donow format
grep "min:[0-9]" todo.txt | while read line; do
  # Manual conversion needed - donow doesn't track when time was spent
  echo "Need to manually create timetrack.txt entries"
done
```

**Converting from timetrack to donow:**

```bash path=null start=null
# Sum total time per task from timetrack.txt
# Add min:X suffix to corresponding todo.txt entries
# (Complex script needed for full automation)
```

**Running both simultaneously:**

- ⚠️ **Not recommended** - creates conflicting data formats
- If attempted, use different TODO_DIR or disable timetrack todo.txt modifications

## Troubleshooting

### Common donow Issues

- **No notifications**: Check DESKTOP_NOTIFICATION setting and platform dependencies
- **Time not saved**: Ensure todo.txt is writable and task number exists
- **Wrong time count**: Ctrl+C timing affects final count

### Common timetrack Issues

- **Python errors**: Ensure helper scripts are installed and executable
- **Missing timetrack.txt**: File created automatically on first use
- **Tag conflicts**: Other scripts may interfere with #timetracking tag

## References

### Source Repositories

- **donow**: https://github.com/clobrano-forks/todo.txt-cli/blob/master/todo.actions.d/donow
- **timetrack**: https://git.sr.ht/~proycon/todotxt-more/blob/master/todo.actions.d/timetrack

### Version Information

- Research conducted: 2025-09-09
- donow source: GitHub clobrano-forks/todo.txt-cli master branch
- timetrack source: proycon/todotxt-more master branch

### Related Projects

- **todo.txt-cli**: https://github.com/todotxt/todo.txt-cli (base CLI)
- **todotxt-more**: https://github.com/proycon/todotxt-more (extended actions)
- **todo.txt format**: http://todotxt.org/ (official specification)

---

_This comparison was created through hands-on analysis of both tools' source code and documentation. Commands and outputs were verified against the actual implementations._
