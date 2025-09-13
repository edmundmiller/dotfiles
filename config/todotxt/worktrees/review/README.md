# 📋 task.sh - Interactive Todo.txt Review Tool

An interactive review system for todo.txt files, inspired by [Taskwarrior's review feature](https://taskwarrior.org/docs/review/), built with [gum](https://github.com/charmbracelet/gum) for a beautiful command-line experience.

## ✨ Features

- **Interactive review sessions** with beautiful TUI
- **Smart review scheduling** based on task age and due dates  
- **Full todo.txt compatibility** with standard formats and metadata
- **Safe file operations** with automatic backups
- **Flexible configuration** via environment variables and command-line options
- **Cross-platform support** (macOS, Linux, Windows with WSL)

## 🚀 Quick Start

### Prerequisites

1. **Install gum** (interactive CLI toolkit):
   ```bash
   # macOS
   brew install gum
   
   # Ubuntu/Debian
   sudo apt update && sudo apt install -y gum
   
   # Fedora
   sudo dnf install -y gum
   
   # Arch
   sudo pacman -S --noconfirm gum
   
   # Go (works anywhere with Go installed)
   go install github.com/charmbracelet/gum@latest
   ```

2. **Python 3** (for date calculations) - usually pre-installed on most systems

### Installation

1. Download the script:
   ```bash
   curl -o task.sh https://raw.githubusercontent.com/YOUR-USERNAME/YOUR-REPO/feat/review/task.sh
   chmod +x task.sh
   ```

2. (Optional) Add to your PATH:
   ```bash
   sudo cp task.sh /usr/local/bin/task-review
   ```

### Basic Usage

Start a review session:
```bash
./task.sh review
```

## 📖 How It Works

### Review Policy

A task needs review if **any** of these conditions are met:

1. **No review history**: Task has no `reviewed:YYYY-MM-DD` tag
2. **Stale review**: Last reviewed more than N days ago (default: 14 days)
3. **Due soon**: Has `due:YYYY-MM-DD` within 3 days or overdue

### Review Actions

During review, you can perform these actions on each task:

| Action | Description | Example |
|--------|-------------|---------|  
| **Modify** | Edit the complete task text | Change task description, add/remove contexts |
| **Mark reviewed** | Set `reviewed:today` | Task reviewed on 2024-09-10 |
| **Set due date** | Add/update/clear `due:YYYY-MM-DD` | Set due date to 2024-09-15 |
| **Priority** | Set priority `(A)`, `(B)`, `(C)`, `(D)`, or none | High priority task |
| **Snooze** | Review again in N days | Snooze for 7 days (reviewed:2024-09-17) |
| **Delete** | Remove task completely | Permanently delete the task |
| **Skip** | Leave unchanged for this session | Continue to next task |

### Metadata Tags

The tool uses standard todo.txt compatible metadata:

```
(A) Pay rent due:2024-10-01 reviewed:2024-09-01 @home +finance
│   │          │                      │              │      │
│   │          │                      │              │      └── Project
│   │          │                      │              └───────── Context  
│   │          │                      └──────────────────────── Last review date
│   │          └─────────────────────────────────────────────── Due date
│   └────────────────────────────────────────────────────────── Priority
└────────────────────────────────────────────────────────────── Task text
```

## ⚙️ Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `TODO_DIR` | `~/todo` | Directory containing todo files |
| `TODO_FILE` | `$TODO_DIR/todo.txt` | Path to main todo file |
| `DONE_FILE` | `$TODO_DIR/done.txt` | Path to completed tasks file |
| `REVIEW_DAYS` | `14` | Days before task needs review |

### Command-line Options

```bash
task.sh review [--file PATH] [--days N]

Options:
  --file PATH    Use specific todo.txt file
  --days N       Review tasks older than N days
```

## 📝 Examples

### Basic Review
```bash
# Review with defaults (~/todo/todo.txt, 14 days)
./task.sh review
```

### Custom Configuration
```bash
# Review work tasks more frequently
./task.sh review --file ~/work/todo.txt --days 7

# Review personal tasks less frequently
REVIEW_DAYS=21 ./task.sh review --file ~/personal/todo.txt

# Use environment variables
export TODO_FILE="$HOME/projects/todo.txt"
export REVIEW_DAYS=10
./task.sh review
```

### Integration Examples

Add to your shell profile for easy access:
```bash
# ~/.bashrc or ~/.zshrc
alias treview="~/bin/task.sh review"
alias treview-work="~/bin/task.sh review --file ~/work/todo.txt --days 5"
```

## 🛡️ Safety Features

### Automatic Backups
Every time tasks are modified, a backup is created:
```bash
todo.txt.bak.1634567890  # Timestamp-based backup
```

### Atomic Operations
- Changes are written to temporary files first
- Original file is only replaced after successful write
- Interruptions (Ctrl+C) won't corrupt your data

### Data Validation
- Date format validation for due dates
- Task integrity checks before saving
- Graceful handling of malformed input

## 🔧 Troubleshooting

### Common Issues

**gum not found**
```bash
# Install gum using your package manager
brew install gum  # macOS
# or follow installation instructions above
```

**python3 not found**
```bash
# Most systems have Python 3 pre-installed
python3 --version

# If not, install via your package manager
sudo apt install python3  # Ubuntu/Debian
brew install python3      # macOS
```

**Permission denied**
```bash
chmod +x task.sh
```

**Todo file not found**
```bash
mkdir -p ~/todo
touch ~/todo/todo.txt
```

### Debug Mode

For troubleshooting, run with bash debug mode:
```bash
bash -x ./task.sh review
```

## 🎯 Integration with Todo.txt Ecosystem

This tool is designed to work alongside existing todo.txt tools:

- **[todo.txt-cli](https://github.com/todotxt/todo.txt-cli)**: Primary task management
- **[task.sh review]**: Periodic maintenance and review
- **Your favorite editor**: Manual editing when needed

Example workflow:
```bash
# Add new tasks
todo.sh add "(A) Call dentist due:2024-09-15"
todo.sh add "Review quarterly goals +work"

# Daily/weekly review
./task.sh review

# Mark tasks complete  
todo.sh do 5
```

## 🚀 Advanced Usage

### Automated Reviews

Set up periodic reviews with cron:
```bash
# Review every Monday at 9 AM
crontab -e
0 9 * * 1 cd /path/to/review && ./task.sh review --days 14
```

### Multiple Todo Files

Manage different contexts separately:
```bash
# Work tasks - review weekly
./task.sh review --file ~/work/todo.txt --days 7

# Personal tasks - review bi-weekly  
./task.sh review --file ~/personal/todo.txt --days 14

# Project tasks - review monthly
./task.sh review --file ~/projects/todo.txt --days 30
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## 📄 License

MIT License - feel free to modify and distribute.

## 🙏 Acknowledgments

- [Taskwarrior](https://taskwarrior.org/) for the review concept
- [gum](https://github.com/charmbracelet/gum) for the beautiful TUI components  
- [todo.txt](http://todotxt.org/) for the simple, powerful format
- The open source community for inspiration and tools

## 🔗 Related Projects

- [todo.txt-cli](https://github.com/todotxt/todo.txt-cli) - The original todo.txt command-line tool
- [Taskwarrior](https://taskwarrior.org/) - Advanced task management with review features
- [gum](https://github.com/charmbracelet/gum) - Interactive CLI components
- [charm](https://charm.sh/) - Tools for making the command line glamorous
