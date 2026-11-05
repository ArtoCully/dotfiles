---
name: session-handoff
description: Summarize everything done in the current session and generate a handoff/memory markdown file that a future Claude session can read to pick up where this one left off.
---

# Session Handoff Skill

Generate a comprehensive handoff document that captures the full state of the current session so a future Claude session (or human) can continue the work with no context loss.

## Invocation

- `@session-handoff` — prompt the user for the output directory, then write the file.
- `@session-handoff --path <path>` — write directly to `<path>` without prompting.

## Path Handling

The default filename convention is `[timestamp]-handoff-[short-title-of-changes].md` where:
- `[timestamp]` is `YYYY-MM-DD-HH:MM` in 24-hour local time, generated via `date "+%Y-%m-%d-%H:%M"` (do not reuse a cached date). The separator between hour and minute **must be a literal colon `:` (U+003A)** — never substitute `/`, `.`, `-`, or `_`. Always produce the filename by interpolating the raw output of the `date` command; do not hand-assemble the timestamp from parts, which is where the colon tends to get mangled into a slash. Example correct name: `2026-10-20-17:36-handoff-add-session-handoff-skill.md`. Example WRONG name: `2026-10-20-17/36-handoff-...` (slash is not a legal POSIX filename character and indicates the timestamp was built manually instead of from `date`).
- `[short-title-of-changes]` is a 2–5 word kebab-case summary of what was actually done this session (e.g. `add-session-handoff-skill`, `fix-login-redirect`, `refactor-auth-middleware`). Derive it from the real conversation — not a generic label like `work` or `updates`. Lowercase, hyphen-separated, no trailing punctuation.

> macOS note: Finder displays `:` as `/` for legacy-HFS reasons, but the on-disk POSIX filename stays `:`. Verify in Terminal with `ls`, not Finder.

Rules for resolving the final output path:

1. **No `--path` argument** — Use the `AskUserQuestion` tool to prompt the user for the directory. Offer `~/Desktop/claude-handoff` as the recommended default. Once the directory is known, append `[timestamp]-handoff-[short-title-of-changes].md`.
2. **`--path` points to a directory** (ends with `/` or is an existing directory, e.g. `~/Desktop/claude-handoff`) — append `[timestamp]-handoff-[short-title-of-changes].md` to it.
3. **`--path` points to a full file path** (e.g. `~/Desktop/claude-handoff/notes.md` or `~/Desktop/claude-handoff/[timestamp]-differentname.md`) — use that path verbatim. If the user included the literal token `[timestamp]` in the filename, substitute the real timestamp. The user-provided filename overrides the default short-title convention.
4. Create the target directory with `mkdir -p` if it does not exist.
5. Expand `~` to the user's home directory before writing.

## What To Include

Build the handoff from the actual conversation, not a generic template. Every section must reflect what really happened in this session. Omit sections that genuinely have no content (don't fill them with filler).

Required sections, in this order:

1. **Header** — title, timestamp, working directory, git branch, user, project name if derivable.
2. **Session Goal** — one or two sentences on what the user set out to do.
3. **What Was Done** — chronological bullet list of concrete actions (files created/edited, commands run, decisions made). Reference files as `path:line` when relevant.
4. **Current State** — where things stand right now: what works, what's half-done, what's untested, uncommitted changes, open branches, running background processes.
5. **Key Decisions & Rationale** — non-obvious choices and *why* they were made. Capture trade-offs the user accepted or rejected.
6. **Open Questions / Blockers** — anything waiting on the user, external systems, or a decision.
7. **Next Steps** — the concrete list of things a future session should pick up, ordered by priority. Be specific enough that someone cold-reading the file knows exactly what to type or edit next.
8. **Relevant Files** — bullet list of files touched or referenced, with a one-line note on each.
9. **Commands To Resume** — exact shell commands to re-enter the workspace (`cd`, branch checkout, dev-server start, etc.).
10. **Context For Future Claude** — a short prose block addressed to the next assistant: user's preferences observed this session, pitfalls to avoid, patterns to follow. Include links to any relevant memory files under `~/.claude/projects/.../memory/` if they were created or updated.

## Workflow

1. Resolve the output path per the rules above (prompt if needed).
2. Gather context by scanning the conversation: user prompts, your actions, tool results, and any errors. Also run `git status`, `git log -n 5 --oneline`, and `git diff --stat` to ground the handoff in real repo state (not just memory of what you did).
3. Draft the markdown following the section list above.
4. `mkdir -p` the target directory, then `Write` the file.
5. **Daily grouping** — after writing, check the output directory for sibling handoff files sharing the same `YYYY-MM-DD` prefix:
   - `OUTDIR` is the directory portion of the final resolved output path from step 1:
     - If `--path` was passed, `OUTDIR` is that path (directory-form) or its parent directory (file-form path).
     - If no `--path` was passed, `OUTDIR` defaults to `~/Desktop/claude-handoff` (expanded to the absolute home path) — this is the same default offered at the prompt, so it also applies if the user accepted the default at the prompt.
   - Count files in `OUTDIR` whose names start with the same `YYYY-MM-DD-` prefix as the file you just wrote (exclude any existing `YYYY-MM-DD/` subfolder from the count).
   - If the count is **2 or more**, create a subdirectory named `YYYY-MM-DD` inside `OUTDIR` and move *all* matching files into it with `mv`. The just-written file goes in too.
   - If the count is 1 (just the file you wrote), do nothing — leave it at the top level.
   - Run the check with something like (substitute `OUTDIR` and `DATE` with the resolved values):
     ```bash
     DATE=2026-10-20                          # the YYYY-MM-DD from the timestamp you just used
     OUTDIR="${HOME}/Desktop/claude-handoff"  # default; override with the --path value when one was passed
     COUNT=$(find "$OUTDIR" -maxdepth 1 -type f -name "${DATE}-*.md" | wc -l | tr -d ' ')
     if [ "$COUNT" -ge 2 ]; then
       mkdir -p "$OUTDIR/$DATE"
       mv "$OUTDIR"/${DATE}-*.md "$OUTDIR/$DATE/"
     fi
     ```
   - Report the final path (inside the dated subfolder if grouping fired).
6. Report back to the user with the absolute path and a one-line summary of what was captured. If daily grouping ran, note which files were moved.

## Style

- Write for a reader who was not in the room. Full sentences, no shorthand like "the thing we discussed."
- Prefer concrete paths, commands, and quotes over summaries.
- Keep it skimmable: short bullets, bold the actionable bits in "Next Steps."
- Do not invent progress — if something is unfinished, say so plainly.
- No emojis unless the user has shown a preference for them.
