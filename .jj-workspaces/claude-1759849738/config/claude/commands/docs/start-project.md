Start new project structure

Create a new project structure in this directory according to these guidelines. You will create a few files and dirs.

## Root README.md
Create a minimal README.md file in the root as follows, filling in the information as needed:

```README.md
# [Project Name]

**[1-2 sentence description of what this project does]**

## Quick Start

```bash
# Basic setup commands
npm install
npm run dev
```

## Tech Stack
- [List main technologies]

## Current Status
- ✅ [Completed feature]
- 🚧 [In progress feature]
- 📋 [Planned feature]

## Documentation

📖 **[Full Documentation](docs/start-here.md)** - Complete setup and development guide

📋 **[Current Tasks](docs/tasks/active/)** - What's being worked on now

🔧 **[Quick Reference](docs/quick-reference.md)** - Commands and common fixes
```

## docs/start-here.md
Create a docs/start-here.md file as follows, filling in the information as needed:

```start-here.md
# START HERE - [project name] Development

## 🎯 What You're Building
**[project name]** - [1-2 sentence description of project]

**Current Status**: [1-2 sentence very high-level update of where the project is]
**Your Mission**: [upcoming big tasks, projects]

## 🚀 Quick Start (5 minutes)

### 1. Get the Code Running
[a bash code block example of how to get the code up and running, with all relevant steps/commands, if we're at that stage -- aim to be maximally helpful here]

### 2. Your Roadmap
Work through these in order:
[a numbered list of done/todo items -- below are example rows to show you the format we use]
[example: 1. ✅ **[Phase 1: Database Setup](dev-guides/01-DATABASE-SETUP.md)** - COMPLETED]
[example: 2. ✅ **[Phase 1A: Security & RLS](dev-guides/01A-SECURITY-RLS.md)** - COMPLETED (July 30, 2025)]
[example: 3. 🚨 **[Phase 1B: Backend Authentication](dev-guides/01B-BACKEND-AUTH.md)** ← **DO THIS NEXT**]
[example: 5. **[Phase 2: Payment Integration](dev-guides/02-PAYMENTS.md)**]
[example: 6. **[Phase 3: User Features](dev-guides/03-USER-FEATURES.md)**]

## 📚 Documentation Structure

### When You Need Help
- **[quick-reference.md](quick-reference.md)** - Commands, URLs, and common fixes
- **[tasks/](tasks/)** - Step-by-step implementation task lists -- your checklist for getting things done
- **[reference/](reference/)** - Deep technical documentation (read only if needed)
- **[how-to-guides/](how-to-guides/)** - Project-specific walkthroughs (e.g. Supabase CLI setup)

### Key Principle
**Read docs just-in-time**. Start with the next task that needs to be done (which you get from a mixture of reading this doc and verifying in tasks/ dir files), and reference other docs only when you need specific information. It's important to work on the correct next thing, so take a small amount of extra time in the beginning to make sure you're looking at the next tasks.

## ✅ Success Criteria
MVP is complete when:
- Users can pay via Stripe
- Daily emails with podcast summaries are sent automatically
- Users can manage their subscriptions
- System runs without manual intervention

## 🎯 **Ready? Go look for the next task to do, then create a plan, and get to work →**
```

## docs/tasks/ dir
Create a docs/tasks/ dir (if it doesn't exist already) with the following structure:

./docs/tasks
├── active
│   ├── 01-[name of prioritized task or feature].md
│   └── 02-[name of prioritized task or feature].md
├── backlog
│   └── [backlog task or feature name].md
├── completed
│   ├── [completed task or feature name].md
│   ├── [completed task or feature name].md
│   └── [completed task or feature name].md
└── README.md

The README.md should be this:

```README.md
# Task Management System

This directory organizes development tasks and technical improvements for the [project name] repository.

## Directory Structure

### `active/`
Current high-priority tasks that need to be completed in sequence. Files are prefixed with numbers (01-, 02-, etc.) to indicate order.

### `backlog/`
Tasks that should be done but have no specific timeline or order. Includes performance improvements, technical debt, and nice-to-have features.

### `completed/`
Archive of completed tasks. Move files here when done to maintain history of what's been accomplished.

## File Naming Conventions

**Active tasks:** `01-description.md`, `02-description.md`
**Backlog tasks:** `descriptive-name.md`
**Completed tasks:** Keep original name, optionally add completion date

## Task Format

Each task file should include the following, in this order:
- **Summary**: 2-3 sentences describing the issue/improvement
- **Action Items**: Specific steps to complete as md checkboxes, with short notes about the task (if it's stalled, if there are important details or caveats, etc.)
- **Technical Details**: Relevant code locations, dependencies, etc.

## Usage

1. Check `active/` for next priority task
2. Create new tasks in appropriate directory
3. Move completed tasks to `completed/`
4. Review `backlog/` during planning sessions
```

## Create other docs

Create the docs directory structure with the following subdirectories and files:

📁 docs/
├── 📁 tasks/              → Actionable checklists and TODOs
├── 📁 how-to-guides/      → Project-specific walkthroughs (e.g. Supabase CLI setup)
├── 📁 reference/          → In-depth conceptual docs (e.g. auth flow diagram, schema)
├── 📄 start-here.md       → Main project development guide
└── 📄 quick-reference.md  → One-pager for frequent lookups

Populate how-to-guides and reference with any documentation that already exists or extremely high value docs that should exist, but no need to create things here just for the sake of it.
