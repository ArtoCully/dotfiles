---
description: Post a PR review request to a Chalet room (default "CC London Thor - ENG")
argument-hint: "[PR-ref ...] [--first|--bump] [--summary]"
---

# /request-review

Post a review request for a GitHub PR to a Chalet room. Always shows the draft for approval before sending — never auto-posts.

## Inputs

- **PR refs** (zero or more): each ref can be a bare PR number (resolved against the current repo) or a full GitHub PR URL like `https://github.com/<owner>/<repo>/pull/<N>` (any repo). Mix freely. If no refs are given, use the PR for the current branch.
- `--first` / `--bump` (optional): force first-ping or bump mode. Default is auto-detect (single-PR only — see step 6).
- `--summary` (optional): generate a 1-line diff summary subtitle. Off by default — the PR title is usually enough.
- If the user mentions a different room in the invocation (e.g. "/request-review 1234 to <some other room>"), use that instead of the default.

## Steps

### 1. Resolve the PRs and group by repo

For each PR ref provided (or for the current-branch PR if none):

- Bare number (e.g. `1234`): resolve in current repo via `gh pr view 1234 --json number,title,url,body,headRefName,additions,deletions,changedFiles,isDraft,commits,reviews`
- Full URL (e.g. `https://github.com/8x8/repo/pull/1234`): parse `<owner>/<repo>` and PR number from the URL, then `gh pr view 1234 --repo 8x8/repo --json ...` (same fields).
- Current branch (no refs): `gh pr view --json ...` — owner/repo comes from `gh repo view --json owner,name`.

If any `gh pr view` fails, surface that ref and stop — don't silently skip.

**Group the resolved PRs by `<owner>/<repo>`.** The number of groups determines how many messages get sent: one per repo. Within each group:
- Group of 1 PR → use the **rich format** (step 7).
- Group of 2+ PRs → use the **compact format** (step 7), which drops Ticket/Approvals/Size in favor of a tight title+URL list.

### 2. Extract the Jira ticket key (rich-format groups only)

- Regex: `[A-Z][A-Z0-9]+-[0-9]+` against `headRefName` first, then `title` as fallback.
- Build URL: `https://agile.8x8.com/browse/<KEY>`
- If no key found, omit the Ticket line entirely (don't fabricate one, don't ask).

### 3. Compute approval state (rich-format groups only)

- From `reviews`, group by `author.login` and keep each user's **latest** review (latest `submittedAt`).
- Count users whose latest state is `APPROVED`. Collect their logins.
- If count > 0: build line `Approvals: <N> (<login1>, <login2>, ...)`. If count == 0, omit the line entirely.

### 4. (Optional) Generate a 1-line diff summary

**Skip this step entirely unless `--summary` was passed.** The PR title carries the message most of the time; a generated summary is opt-in.

If `--summary`:
- Run `gh pr diff <number>` (cap at ~5000 lines if huge — pipe through `head -5000`).
- Write a SINGLE sentence describing the user-visible / behavioral change. Not "modifies 3 files in src/" — say what the change does.
- Cap at ~140 chars. If you can't summarize confidently from the diff, fall back to the first non-empty line of the PR body.

### 5. Resolve the Chalet room

- Default name: `CC London Thor - ENG` (only override if user named another room in their invocation).
- Use `mcp__plugin_chalet_chalet__find_people_and_rooms` with the room name. Pick the exact name match. If none, surface the candidates and ask.

### 6. Determine first-ping vs bump (per repo group)

Per group resolution:
1. **If `--first` or `--bump` was passed**, the flag forces mode for every group and we skip the history search.
2. **Single-PR group with no flag**: search the room with `mcp__plugin_chalet_chalet__search_messages` using that PR URL as the query.
   - Prior message with this URL → **bump mode**, capture the most recent timestamp.
   - No prior message → **first-ping mode**.
3. **Multi-PR group with no flag**: skip auto-detect, default to **first-ping**. Auto-detect across a batch produces ambiguous results; the user can pass `--bump` if they really want a batch bump.

When showing the draft for approval, tell the user the mode of each group and how it was decided (auto-detect vs flag-forced).

### 7. Compose the message

Chalet rendering rules (verified by test): `*single asterisks*` = **bold**, `_underscores_` = _italic_, `[text](url)` = masked link, `` `code` `` = code span, plain URLs auto-link. Blockquote `>` and double-asterisk `**` do NOT render — use the `▸` glyph and single asterisks instead.

**T-shirt size.** Compute from `additions + deletions` (lines) and `changedFiles`. Pick the **larger** of the two dimensions:

| Size | Lines changed | Files changed |
|------|---------------|---------------|
| XS   | < 10          | ≤ 2           |
| S    | < 100         | ≤ 5           |
| M    | < 500         | ≤ 20          |
| L    | < 1500        | ≤ 50          |
| XL   | ≥ 1500 or > 50 |              |

Example: 40 files / +1106 / −246 → 1352 lines (< 1500 → L) and 40 files (≤ 50 → L) → **L**.

Compose **one message per repo group**. The group's PR count picks the format.

#### Rich format (single-PR groups)

**First-ping:**

```
🔎 *Review request* — <title>
[_<one-line diff summary>_]   ← only when --summary was passed

*Pull Request:* <url>
*Ticket:* [<KEY>](https://agile.8x8.com/browse/<KEY>)
*Approvals:* <N> · _<login1>, <login2>_
*Size:* <SIZE> · `+<additions>` / `−<deletions>` across `<changedFiles>` files
```

Omit subtitle if `--summary` wasn't passed. Omit `*Ticket:*` if no key (step 2). Omit `*Approvals:*` if zero (step 3).

**Bump:** subtitle only appears when `--summary` was passed AND there are new commits since the last ping. Otherwise omit it.

```
🔔 *Bump* — <title>
[_<one-line summary of what changed since last ping>_]   ← only when --summary AND new commits exist

*Pull Request:* <url>
*Approvals:* <N> · _<login1>, <login2>_
```

Omit `*Approvals:*` if zero.

#### Compact format (multi-PR groups)

Drops Ticket / Approvals / Size — title + masked PR link per row. The header verb matches the mode (`*Review requests*` for first-ping, `*Bumps*` for bump).

**Bracket sanitisation:** before using a PR title as masked-link text, replace every `[` with `(` and every `]` with `)`. Square brackets inside link text close the link parser early, breaking the URL render. Example: `[VOD-35350] Guard null sentiments` → `(VOD-35350) Guard null sentiments`. Rich-format titles render as plain text and don't need this transformation.

```
🔎 *Review requests* in `<owner>/<repo>` — <N> PRs

• [<title-1>](<url-1>)
• [<title-2>](<url-2>)
• [<title-N>](<url-N>)
```

Bump variant — same shape, swap the emoji and verb:

```
🔔 *Bumps* in `<owner>/<repo>` — <N> PRs

• [<title-1>](<url-1>)
• [<title-2>](<url-2>)
```

`--summary` has no effect on the compact format — the per-PR subtitle would clutter the list.

### 8. Confirm before sending

Show the user:
- The resolved room name (and a note if it's the default vs an override).
- A summary table: one row per repo group with `<owner>/<repo>` · PR count · format (rich/compact) · mode (first-ping/bump) · how the mode was decided.
- For any bump auto-detect: the timestamp of the last ping found for that PR.
- **Each drafted message in full**, in the order they will be sent.

Wait for explicit batch approval before sending. Accept inline edits ("change X to Y in the second message, then send") and mode swaps ("send the first one as bump instead").

### 9. Send

For each repo group in order, call `mcp__plugin_chalet_chalet__send_message` to the resolved room with that group's message body. Report each returned message permalink so the user can verify.

## Rules

- **Never @-mention** anyone or use @here-style group pings (the approvers list is plain-text usernames, not a mention).
- **No draft-PR guard** — drafts get reviewed here, post normally.
- **Never auto-post** — always confirm.
- If anything is ambiguous (PR not found, multiple matching rooms, can't resolve ticket), surface the issue and stop rather than guessing.
