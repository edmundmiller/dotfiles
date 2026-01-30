# Todo.txt Worktrees Organization

This directory contains the migrated todo.sh actions and utilities from `~/.todo.actions.d`, including all development branches that were managed as git worktrees.

## Main Branch Content

The main directory contains the latest stable version of todo.sh actions:

- **Core Scripts**: `deps`, `today`, `tracktime`, `urgency`, etc.
- **Utilities**: `addr`, `futureTasks`, `open`, `recur`, `schedule`
- **Config**: `todo.cfg` - main todo.sh configuration
- **Tests**: Complete test suite in `tests/` directory
- **Documentation**: Various markdown files with specifications and plans

## Preserved Worktrees

The `worktrees/` subdirectory preserves all development branches from the original repository:

### `feat-todo-deps/`

Dependency-related feature development branch containing:

- Modified versions of core scripts for dependency tracking
- Temporary files: `comments.tmp`, `empty.tmp`, `project.tmp`
- Experimental dependency specification work

### `implementation/`

Implementation branch with:

- Enhanced versions of core scripts
- Additional test coverage
- Library improvements in `lib/`
- Updated configuration files

### `issue-gh-macos/`

macOS-specific issue resolution branch:

- Platform-specific fixes
- Simplified test scripts
- Installation utilities for dependencies
- Compatibility improvements

### `review/`

Code review and testing branch:

- Review artifacts and test data
- Comparison files (`all_current.txt`, `no_review_needed.txt`)
- Testing configurations
- Custom task management script (`task.sh`)

## Usage

- **Current development**: Use files in the main directory
- **Historical reference**: Check `worktrees/` for branch-specific implementations
- **Feature backport**: Copy implementations from worktree branches as needed

## Migration Notes

- All original git history is preserved in the source repository
- Worktree content represents the state at migration time
- File permissions and executable bits are maintained
- All dependencies and test suites are included

This organization maintains access to all development work while consolidating everything under the dotfiles structure.
