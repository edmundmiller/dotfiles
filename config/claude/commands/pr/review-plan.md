---
allowed-tools: Bash(gh:*), Bash(git:*), Read, Glob, Grep
argument-hint: <pr-number-or-url>
description: Generate a structured PR review plan (not the review itself)
---

## Context

- Current repo: !`git remote get-url origin 2>/dev/null | sed 's/.*github.com[:/]//' | sed 's/.git$//'`
- Current branch: !`git branch --show-current`
- Your GitHub user: !`gh api user --jq .login 2>/dev/null || echo "unknown"`

## Your Task

Generate a **review plan** for the specified PR - not the review itself. The human will use your plan to conduct their own review with informed focus areas.

**Key Principle:** "Have the AI generate a _plan_ for your review, not the review itself."

### Step 1: Fetch PR Information

```bash
# Get PR details
gh pr view $ARGUMENT --json number,title,author,body,files,additions,deletions,baseRefName,headRefName

# Get the diff
gh pr diff $ARGUMENT
```

### Step 2: Analyze and Categorize Changes

Break down the PR by:

1. **File Categories**
   - New files vs modified files
   - Test files vs implementation files
   - Configuration changes
   - Documentation updates

2. **Change Patterns**
   - Refactoring (moves/renames)
   - New functionality
   - Bug fixes
   - Dependency changes

### Step 3: Generate Review Focus Areas

Create a prioritized list of areas to examine:

1. **Security Concerns** - Auth, input validation, secrets, SQL injection, XSS
2. **Edge Cases** - Null handling, error paths, boundary conditions
3. **Performance** - N+1 queries, unnecessary iterations, memory usage
4. **Test Coverage** - Are new paths tested? Edge cases covered?
5. **API Contracts** - Breaking changes, backwards compatibility
6. **Code Quality** - Naming, duplication, complexity

### Step 4: Prepare Suggested Comments

For each concern, format as:

```
FILE: path/to/file.ts
LINE: 42
CATEGORY: [Security|Performance|Edge Case|Style|Question]
COMMENT: Your observation here
SEVERITY: [Blocking|Suggestion|Nitpick]
```

### Step 5: Output Review Plan

Provide:

1. **Summary** - 2-3 sentence overview of PR purpose and scope
2. **Risk Assessment** - Low/Medium/High with reasoning
3. **Focus Areas** - Prioritized list with specific files and lines to examine
4. **Prepared Comments** - Draft comments for human review (DO NOT post)
5. **Questions for Author** - Clarifying questions to ask

### Important

- **DO NOT** post comments directly - only prepare them for human review
- **DO NOT** approve or request changes automatically
- Present the plan clearly so the human can review alongside the PR diff
- Be thorough but prioritize - the human's time is valuable
