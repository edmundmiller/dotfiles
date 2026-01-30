---
allowed-tools: Bash(gh:*), Bash(git:*), Read
description: Review a pull request with a structured 6-step workflow
---

## Your Task

You are helping me review a pull request. Follow this workflow:

### Step 1: Find Relevant PRs

Use `gh pr list` to locate open PRs where I'm assigned, requested as reviewer, or have already reviewed.

```bash
gh pr list --assignee @me
gh pr list --search "review-requested:@me"
gh pr list --search "reviewed-by:@me"
```

Present results as a numbered list for selection. If a PR number is provided as an argument, skip this step.

### Step 2: Check Out and Examine the PR

1. Check out the PR locally:

   ```bash
   gh pr checkout <PR_NUMBER>
   ```

2. View PR details:

   ```bash
   gh pr view <PR_NUMBER>
   ```

3. Retrieve the full diff:

   ```bash
   gh pr diff <PR_NUMBER>
   ```

4. Examine existing review comments:
   ```bash
   gh api repos/{owner}/{repo}/pulls/<PR_NUMBER>/comments
   ```

### Step 3: Analyze the Changes

Provide:

1. **High-level summary:**
   - Purpose of the changes
   - New APIs or data structures introduced
   - Dependencies added/modified
   - Architectural changes
   - Breaking changes
   - Impact on existing code

2. **Dependency maintenance checks** (if applicable):
   - Version bumps and their significance
   - Security implications
   - Compatibility concerns

### Step 4: Review Focus Areas

Provide a numbered list of files or directories to review, in logical order. Pay specific attention to:

- **API design:** Consistency, naming, contracts
- **Complex logic:** Algorithms, state management
- **Edge cases:** Error handling, boundary conditions
- **Performance:** Hot paths, memory usage, async patterns
- **Security:** Input validation, authentication, authorization
- **Test coverage:** Missing tests, edge case coverage
- **Style consistency:** Matches codebase conventions

### Step 5: Suggested Comments

Generate specific feedback with file paths and line numbers.

Format each comment as:

- **File:** `path/to/file.ext`
- **Line:** `<line_number>`
- **Comment:** Your specific feedback

**Important:** Verify line numbers by reading the actual file content before suggesting.

### Step 6: Prepare gh CLI Commands

Create the review using the GitHub CLI:

1. **Create a pending review:**

   ```bash
   gh api repos/{owner}/{repo}/pulls/<PR_NUMBER>/reviews \
     --method POST \
     --field event=PENDING
   ```

2. **Add individual line comments:**

   ```bash
   gh api repos/{owner}/{repo}/pulls/<PR_NUMBER>/comments \
     --method POST \
     --field body="<comment>" \
     --field commit_id="<commit_sha>" \
     --field path="<file_path>" \
     --field line=<line_number>
   ```

3. **Reply to existing comments if needed:**

   ```bash
   gh api repos/{owner}/{repo}/pulls/comments/<comment_id>/replies \
     --method POST \
     --field body="<reply>"
   ```

4. **Submit final approval with summary:**

   ```bash
   gh pr review <PR_NUMBER> --approve --body "<summary>"
   ```

   Or request changes:

   ```bash
   gh pr review <PR_NUMBER> --request-changes --body "<summary>"
   ```
