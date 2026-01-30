---
name: pr-review
description: >
  Review GitHub pull requests with structured analysis and gh CLI integration.
  Use when asked to "review a PR", "check my PRs", "review pull request",
  or help with code review workflows.
license: MIT
metadata:
  version: "1.0.0"
  author: "Rafael Garcia <https://github.com/rgarcia>"
  source: "https://gist.github.com/rgarcia/742d8a91b051a57c51dcab8aba6d352e"
---

# PR Review Skill

Structured workflow for reviewing GitHub pull requests with gh CLI.

## Workflow

### Step 1: Find Relevant PRs

Find open PRs where I am assigned, requested as a reviewer, or have already submitted a review:

```bash
gh pr list \
  --search "is:open (review-requested:@me OR reviewed-by:@me OR assignee:@me)" \
  --limit 10 \
  --json number,title,author,reviewRequests,assignees,createdAt \
  --jq '.[] | {number, title, author: .author.login, reviewers: [.reviewRequests[]?.login], assignees: [.assignees[]?.login], created: .createdAt}'
```

If there are multiple PRs, ask which one I want to review. Present the results to me as a numbered list for me to choose from. If there's only one, confirm before proceeding.

### Step 2: Check Out and Examine the PR

Once I confirm the PR:

1. Check out the PR locally: `gh pr checkout <PR_NUMBER>`
2. Get PR details: `gh pr view <PR_NUMBER>`
3. Get the full diff against the base branch: `gh pr diff <PR_NUMBER>`
4. Check for existing review comments: `gh api repos/{owner}/{repo}/pulls/{pr_number}/comments`

### Step 3: Analyze the Changes

Examine the diff and provide:

**High-Level Summary**

- What is the overall purpose of this PR?
- New APIs introduced (endpoints, functions, methods)
- New or modified data structures (types, interfaces, schemas)
- New dependencies or libraries added
- Architectural or design pattern changes
- Configuration changes
- Database migrations or schema changes
- Any breaking changes

**Dependency Check**

- For any new dependencies: check if they are actively maintained
- Flag archived, deprecated, or unmaintained libraries
- Look for existing libraries in the codebase that could be used instead (check imports across the codebase)

**Impact Assessment**

- How does this affect existing code?
- What areas of the codebase will need to be aware of these changes?
- Are there documentation implications?

### Step 4: Review Focus Areas

Provide a numbered list of files or directories to review, in logical order (foundational changes first, then core logic, then usages, then tests). For each item, briefly note what to focus on:

- API or DB schema design considerations, if any
- Complex logic that needs careful examination
- Potential edge cases or error handling gaps
- Performance considerations
- Security implications
- Test coverage gaps
- Code style or consistency issues

### Step 5: Suggested Comments

Prepare a list of suggested review comments, **ordered by line number ascending** (group by file, then sort by line within each file). For each comment:

- Use casual, lowercase messaging (e.g., "consider..." not "Consider...")
- Keep it short and to the point
- Use a friendly, suggestion-based tone (e.g., "consider...", "might be worth...", "nit: ...")
- Only be strongly opinionated if there's an obvious bug or issue
- Include the file path and line number as a clickable link to get me directly to the file and line within my editor
- **Verify line numbers** by reading the actual file content before suggesting

Format each suggestion as plain text (not in code blocks, since code blocks don't wrap and are hard to read):

File: `<path>`
Line: `<number>`
Comment: <your suggestion>

### Step 6: Prepare gh CLI Commands

Generate ready-to-run commands. **Important**: Create a pending review first, add each line comment individually, then submit.

1. Get the commit SHA for comments:

   ```bash
   COMMIT_SHA=$(gh pr view <PR_NUMBER> --json headRefOid -q .headRefOid)
   ```

2. Check for an existing pending review before creating a new one:

   ```bash
   gh api repos/{owner}/{repo}/pulls/{pr_number}/reviews \
     --jq '.[] | select(.state == "PENDING") | {id, user: .user.login, state}'
   ```

   If a pending review exists, skip creating a new one and add comments to it instead.

3. Create an empty pending review (only if no pending review exists):

   ```bash
   gh api repos/{owner}/{repo}/pulls/{pr_number}/reviews \
     -f commit_id="$COMMIT_SHA"
   ```

4. Add each line comment to the pending review (one call per comment):

   ```bash
   gh api repos/{owner}/{repo}/pulls/{pr_number}/comments \
     -f body="<comment>" \
     -f path="<file_path>" \
     -f commit_id="$COMMIT_SHA" \
     -F line=<line_number> \
     -f side="RIGHT"
   ```

5. Reply to existing comments (if needed):

   ```bash
   gh api repos/{owner}/{repo}/pulls/{pr_number}/comments/{comment_id}/replies \
     -f body="<reply>"
   ```

6. **After all comments are added**, submit the review as an approval:

   ```bash
   gh pr review <PR_NUMBER> --approve --body "Short summary here."
   ```

   **Keep the final review body short** (1-2 sentences). The detailed feedback is in the line comments.

## Output Format

Present findings in sections, then wait for user feedback. The user will:

- Ask to modify suggestions
- Tell which comments to keep/remove
- Request changes to the review approach

Do NOT submit any reviews or comments until the user explicitly approves the plan.
