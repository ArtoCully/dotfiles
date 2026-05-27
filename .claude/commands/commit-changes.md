---
description: Stage, commit, push, and create or update a PR for the current branch
argument-hint: "[--no-push] [--draft]"
---

# /commit-changes

Stage all local changes, commit with a Jira-prefixed message, push to the remote tracking branch (never main/master), and create or update the PR with a summary and test plan.

## Inputs

- `--no-push` (optional): commit locally but skip push and PR steps.
- `--draft` (optional): create the PR as a draft. Ignored if a PR already exists.

## Steps

### 1. Gather context

Run in parallel:
- `git status --short` — identify staged and unstaged changes; if there is nothing to commit, report and stop.
- `git diff HEAD` — understand what changed.
- `git log --oneline -5` — read recent commit style for the repo.
- `git branch --show-current` — capture `<branch>`.
- `git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null` — check whether an upstream tracking branch is set.
- `gh pr view --json number,title,url,body 2>/dev/null` — check whether a PR already exists for this branch.

**Safety check**: if `<branch>` is `main` or `master`, stop immediately and tell the user to switch to a feature branch before committing.

### 2. Extract the Jira ticket key

Apply regex `[A-Z][A-Z0-9]+-[0-9]+` against `<branch>` first, then the most recent commit subject as fallback.

If no key is found, ask the user to provide one before continuing — do not fabricate or omit it.

### 3. Stage changes

```bash
git add -A
```

### 4. Draft the commit message

Using the diff and gathered context, compose:

- **Subject**: `<TICKET> - <short imperative description>` (72 chars max, e.g. `VCC-182106 - add retry logic to payment handler`).
- **Body**: 3–6 bullet points, each starting with a verb, describing *what* changed and *why*. Wrap at 72 chars.

Show the full draft to the user and wait for explicit approval or edits before committing.

### 5. Commit

Pass the message via HEREDOC to avoid shell quoting issues:

```bash
git commit -m "$(cat <<'EOF'
<subject line>

<body bullets>

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

### 6. Push to remote

If `--no-push` was passed, skip to step 7 and note that no push was performed.

**Determine the push target:**

- If an upstream tracking branch already exists, push to it:
  ```bash
  git push
  ```
- If no upstream exists, set it to `origin/<branch>` (same name as the local branch — never `main` or `master`):
  ```bash
  git push -u origin <branch>
  ```

If the push is rejected due to a non-fast-forward conflict, report the error and stop — never force push.

### 7. Create or update the PR

If `--no-push` was passed, skip this step entirely.

**Draft the PR body** from the commit body bullets:

```
## Summary

- <bullet 1>
- <bullet 2>
- <bullet 3>

## Test Plan

- [ ] Unit tests pass locally
- [ ] Manual smoke test of the affected feature
- [ ] Edge cases covered: <list relevant edge cases inferred from the diff>
- [ ] No regressions in related areas

🤖 Generated with [Claude Code](https://claude.com/claude-code)
```

**If no PR exists**, create one:

```bash
gh pr create --title "<subject line>" [--draft] --body "$(cat <<'EOF'
<pr body>
EOF
)"
```

**If a PR already exists**, update its body (preserve the existing title):

```bash
gh pr edit <number> --body "$(cat <<'EOF'
<pr body>
EOF
)"
```

### 8. Report

Output a single summary block:

- Commit SHA (`git rev-parse --short HEAD`)
- Whether the upstream was newly set or already existed
- PR URL (new or existing)

## Rules

- **Never push to `main` or `master`** — abort at step 1 if the current branch is either.
- **Never force push** (`--force` / `--force-with-lease`).
- **Never skip hooks** (`--no-verify`).
- **Always confirm** the commit message before committing (step 4).
- If the Jira ticket key cannot be determined automatically, ask — do not guess or omit.
- If anything is ambiguous (push conflict, PR API error), surface the issue and stop rather than guessing.
