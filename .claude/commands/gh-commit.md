---
description: Stage current changes, generate a ticket-prefixed commit, and optionally push the branch
argument-hint: [--push]
---

Stage the modified files on the current branch, write a properly-formatted commit, and (optionally) push to the matching remote branch.

## Arguments

- `--push` (optional) — after committing, push the current branch to `origin` with upstream tracking (`git push -u origin <current-branch>`). Without this flag, the command stops after the local commit.

Any other arguments are an error — print usage and stop.

## Steps

1. **Inspect repo state** by running these in parallel:
   - `git status` — confirm there are unstaged changes and identify the modified files.
   - `git diff` — read the actual changes that will go into the commit (both staged and unstaged).
   - `git log -5 --pretty=format:"%h %s"` — sample the commit message style used by recent history on this branch.
   - `git rev-parse --abbrev-ref HEAD` — capture the current branch name (needed for the ticket id and for `--push`).

   If `git status` reports a clean tree, stop and tell the user there is nothing to commit. Do not create an empty commit.

2. **Derive the ticket id** from the branch name. Branches follow `<type>/<TICKET-ID>[-<slug>]` (e.g. `improvement/PLAT-71048-infinite-scroll-agent-groups` → `PLAT-71048`). If the branch has no recognisable ticket id (`VCC-…`, `PLAT-…`, etc. — see `CONTRIBUTING.md`), stop and ask the user for one before continuing.

3. **Stage the relevant files explicitly** by listing them on `git add <path> [<path> …]`. Do NOT use `git add -A` or `git add .` — those can scoop up untracked secrets, build artefacts, or test scratch files. Skip any file that obviously shouldn't be committed (`.env*`, credential files, large binaries, IDE settings) and warn the user about each one you skipped.

4. **Draft the commit message** following the project's convention from `CONTRIBUTING.md`:
   - **Subject line:** `<TICKET-ID> - <short imperative summary>` — under ~72 characters. Imperative voice ("Add", "Fix", "Expose"), no trailing period. Match the style of recent commits in `git log`.
   - **Blank line** separating subject from body.
   - **Long description:** 1-3 paragraphs explaining *why* the change exists (the problem it solves) and *what* the high-level shape of the change is. Bullet the per-module changes when there are more than two or three files touched. Don't restate the diff line-by-line — the diff already does that.
   - No "Co-Authored-By" trailers, no "Generated with Claude Code" footers, no emojis. The project's recent history doesn't use them.

5. **Commit** using a HEREDOC so multi-line formatting survives:

   ```bash
   git commit -m "$(cat <<'EOF'
   <TICKET-ID> - <subject>

   <body>
   EOF
   )"
   ```

   If the pre-commit hook fails, do NOT use `--no-verify`. Diagnose the failure (lint errors, type errors, failing tests), fix the underlying issue, re-stage, and create a NEW commit. Never `--amend` after a hook failure — the commit didn't happen, so `--amend` would modify the *previous* commit instead.

6. **Verify** with `git status` and `git log -1 --stat` so the user can confirm what landed.

7. **Push (only if `--push` was passed):**
   - Get the current branch name from step 1.
   - Refuse to push to `master` or `main` from this command — those branches must go through a PR. If the current branch is `master`/`main`, stop and tell the user to open a PR instead.
   - Run `git push -u origin <current-branch>`. The `-u` flag sets upstream tracking on the first push and is a no-op on subsequent pushes.
   - Never force-push from this command. If `git push` is rejected because the remote has diverged, stop and tell the user — they need to investigate (rebase, merge, or force-with-lease) deliberately.

## Notes

- This command does NOT open a pull request, create a tag, or bump the version. Releases go through `/create-release`; PRs go through `gh pr create` (or your own workflow).
- If multiple tickets are mixed into one set of changes, ask the user which ticket id should prefix the commit, or whether to split into multiple commits. Don't guess.
- The `--push` flag is a convenience for branches already past the "I'm still iterating locally" stage. If you're not sure the change is ready to share, omit it.
