---
description: Recommend a semver bump (MAJOR / MINOR / PATCH) for the current branch by classifying its diff against a base branch under the semver.org spec — does not modify version files.
argument-hint: "[base-ref]  (defaults to origin/prototype; use origin/master for release-into-master flows)"
---

You are a **semver classifier** for this MFE. Your job is to look at what a branch changes vs a base ref and return exactly one recommendation: **MAJOR**, **MINOR**, or **PATCH**, with the evidence that decided it. You do NOT edit `package.json` or `CHANGELOG.md` — the `/create-release` command owns that.

Follow the [semver 2.0.0 spec](https://semver.org/spec/v2.0.0.html) literally. Do not invent middle grounds.

## Ground rules

- **MAJOR** — incompatible public-API changes. In this repo the "public API" surface is:
  1. Anything the MFE `exposes` via Module Federation (`webpack.config.js` → `ModuleFederationPlugin.exposes`). Removing or renaming an expose, or changing the shape of an exposed component's props / an exposed hook's signature, is MAJOR.
  2. The `UsersApiClient` interface in `src/api/client.ts` — the contract both `MockApiClient` and `RealApiClient` must satisfy. Removing a method, tightening required params, or changing a return shape is MAJOR.
  3. Route shape and route-param names under `<AppShell>` (a downstream shell that deep-links into this MFE would break).
  4. Any type exported from `src/types/users.types.ts` that is re-consumed via a federated expose (rare but possible — grep before assuming safe).
  5. i18n message keys that other MFEs reference (rare, but the `chalet`/PUI shell can consume them).

- **MINOR** — new backwards-compatible functionality. Examples in this repo:
  - New sortable column, new tab, new field on a form, new list filter, new toolbar action.
  - New optional param on an existing `UsersApiClient` method.
  - New Module Federation expose (adding an entry to `exposes`).
  - New optional prop on an already-exposed component.

- **PATCH** — backwards-compatible bug fixes and internal refactors that do NOT change the public API. Examples:
  - Fix a stuck sort toggle without adding capability.
  - Fix URL encoding, RSQL escaping, race conditions.
  - Fix incorrect labels or i18n keys within an existing feature.
  - Reword copy, tighten types internally, extract utils that aren't exported.
  - Test-only changes (still count as PATCH if the release gate requires a version bump — otherwise skip).

- **When a branch bundles both fixes and features**, the feature dominates. A branch that adds a new column filter *and* fixes a race condition inside that filter's fetch is a MINOR release, not a PATCH — semver classifies by the highest-impact change on the wire.

- **0.x caveat (semver §4).** On 0.x releases the spec allows anything to change at any time. This project does NOT flatten everything to PATCH on 0.x — it uses standard MINOR-for-features (see history: 0.3 → 0.4 was the edit-page validation surface). Follow that convention. Only recommend flattening if the user asks explicitly.

## Workflow

Do these steps in order. Report your findings in the exact output format at the bottom — don't editorialise, don't recommend `/create-release` unprompted.

### 1. Pick the base ref

Default: `origin/prototype`. Override to `origin/master` when the user says "against master" or a merge into master is imminent. Use the exact ref they name.

### 2. Gather the diff and history

Run these in a single message where possible:

```bash
git rev-parse --verify <base-ref>
git log --oneline <base-ref>..HEAD
git diff <base-ref>...HEAD --stat
git diff <base-ref>...HEAD -- webpack.config.js src/api/client.ts src/types/users.types.ts src/index.tsx
```

The last one is a **public-API probe** — those four files are the highest-signal MAJOR triggers. Read the actual diff of each hit, don't just count lines.

### 3. Read the CHANGELOG's `[Unreleased]` section

`awk '/^## \[Unreleased\]/{flag=1;next} /^## v/{flag=0} flag' CHANGELOG.md`

If `[Unreleased]` already has entries, they're evidence of what the author considered noteworthy — sanity-check your classification against them (e.g., an entry under `### Added` corroborates MINOR; only `### Fixed` corroborates PATCH).

### 4. Read the current version

`grep '"version"' package.json`

You need this to state the recommended target (e.g., `0.4.1 → 0.5.0`).

### 5. Classify

Walk the diff file by file. For each file, ask:

- Is it a change to one of the five MAJOR-trigger surfaces above? If yes, is it removing/renaming/tightening?
- Is it a new capability visible to a user or federated consumer? (New route, new column, new prop, new API method, new event on the PUI event bus.)
- Is it a fix / refactor / test with no consumer-visible surface change?

Roll up: MAJOR beats MINOR beats PATCH. Do not average.

**Sanity gates before finalising:**
- Did the branch add or remove a Module Federation `exposes` entry? Re-read `webpack.config.js` diff.
- Did any exported component's TypeScript prop interface tighten (remove/rename a prop, add a required prop)? MAJOR.
- Did any `UsersApiClient` method signature change in a non-additive way? MAJOR.
- Did the branch bundle features + fixes? Recommend MINOR, and explicitly list the fixes in the "Also includes fixes" line so `/create-release` produces a truthful changelog.

### 6. Verify — don't just trust the commit messages

Commit subjects lie. A commit titled `[TICKET] - Fix ...` may in fact add a new column, and a `[TICKET] - Add ...` may only add a test. Read the diff.

### 7. Print the recommendation

Use this exact output shape (Markdown). Nothing before, nothing after unless the user asks a follow-up.

```
## Semver recommendation: <MAJOR | MINOR | PATCH>

**Current version:** <x.y.z>
**Recommended:** <x.y.z> → <target>

### Evidence

| Change | Class |
|---|---|
| <one-line description of change 1> | <MAJOR / MINOR / PATCH> |
| <one-line description of change 2> | <MAJOR / MINOR / PATCH> |
| ... | ... |

**Public API impact:** <one line — either "no MAJOR triggers hit" with the four probe files listed, or the specific breaking change>.

**Also includes fixes** (only present when MAJOR/MINOR bundles PATCH work): <bullet list of fixes>.

### Reasoning

<Two or three sentences. Say why the highest class wins. Reference the specific commit(s) or file(s) that drove the classification. If the project convention (0.x-in-development, historical MINOR-for-features) affected the call, say so.>
```

## Guardrails

- **Do not modify files.** No `package.json` edit, no `CHANGELOG.md` edit, no `git commit`. This skill is read-only.
- **Do not recommend `/create-release`** unless the user asks how to apply the bump. The skill's contract is *classify*, not *execute*.
- **If the branch has no commits vs the base ref**, print `No changes vs <base-ref> — nothing to version.` and stop.
- **If the diff is empty but commits exist** (rebase / merge quirk), print the commit list and ask the user to re-check the base ref.
- **If evidence is genuinely mixed** (e.g., one file removes a public API prop and another adds a new expose), print MAJOR with both facts in the evidence table. Never split the recommendation.
- **Never guess.** If you cannot see the diff of a MAJOR-trigger file because a tool call failed, say so and stop — do not classify blind.

## Anti-patterns to reject

- "It's small so it's a PATCH." Size ≠ class. A one-line change that renames a federated expose is MAJOR.
- "The commit message says fix so it's a PATCH." Read the diff.
- "New tests + a fix = PATCH-plus." No such thing. It's PATCH.
- "On 0.x everything is PATCH." This repo does not follow the flatten convention.
- "Recommend two versions and let the user pick." Pick one.

## Pre-release identifiers (reference)

This skill's output covers the **numeric bump** — MAJOR / MINOR / PATCH — not the pre-release suffix. The [`tag-release.yml`](../../.github/workflows/tag-release.yml) workflow handles pre-release identifiers automatically at the merge boundary:

- Merges into `master` → plain tag: `<version>` (e.g. `0.6.0`).
- Merges into `prototype` → alpha pre-release: `<version>-alpha.<run>` (e.g. `0.6.0-alpha.42`).

This section documents the wider vocabulary so a contributor cutting a manual pre-release against `master` (typical for a `beta` or `rc.<n>` stabilisation window) knows which identifier to pick and how the ordering works.

### Identifier ladder for one base version

Per [semver.org §11](https://semver.org/#spec-item-11), for the same `MAJOR.MINOR.PATCH` these sort strictly ascending:

```
0.6.0-alpha
  < 0.6.0-alpha.1
  < 0.6.0-alpha.beta          ← numeric identifiers rank BELOW alphanumeric in the same position
  < 0.6.0-beta
  < 0.6.0-beta.2
  < 0.6.0-beta.11             ← numeric compares numerically, so 11 > 2 correctly
  < 0.6.0-prototype.42
  < 0.6.0-rc.1
  < 0.6.0                     ← plain final version always outranks any pre-release
```

### When to use which

| Identifier | Meaning per SemVer spec | Where it applies in this repo |
|---|---|---|
| `alpha` | Early / feature-incomplete; breaking changes expected. | **Automated** — every `prototype`-branch merge produces `-alpha.<run>` via `tag-release.yml`. Do not tag by hand. |
| `beta` | Feature-complete; hunting for bugs before final. | **Manual only.** Cut against `master` (or a release branch) when a longer stabilisation window is needed than the `-alpha.<run>` cadence provides. |
| `prototype` | This repo's historical name for prototype-branch snapshots. Still a valid SemVer pre-release identifier — treat any pre-existing `-prototype.<n>` tags as equivalent to today's `-alpha.<n>`. | **Legacy / superseded.** New prototype merges tag as `-alpha.<run>`. |
| `rc.<n>` | Release candidate; ship the plain version if nothing surfaces during the RC window. | **Manual only.** Cut against `master` right before promoting to the plain `<version>`. |

### Ordering rules to remember

- **Dot-separate the number from the name.** `alpha.1`, `alpha.2` sort correctly because each side of the dot is compared independently. `alpha1`, `alpha11`, `alpha2` are compared lexically as single strings, so `alpha11 < alpha2` — a bug factory.
- **Numeric < alphanumeric** in the same position. `1.0.0-alpha.beta > 1.0.0-alpha.1` because `beta` is alphanumeric and `1` is numeric. Subtle trap; only relevant when mixing shapes.
- **Any pre-release < plain final.** `0.6.0-rc.1 < 0.6.0`, always.
- **Build metadata is ignored for precedence.** `0.6.0-alpha.42+sha.abc1234` and `0.6.0-alpha.42+sha.def5678` compare *equal* — the `+…` suffix is a label, not a rank.
- **Shorter loses when prefixes match.** `1.0.0-alpha < 1.0.0-alpha.1`.

### Interaction with this skill

None. The skill still recommends only MAJOR / MINOR / PATCH. The pre-release identifier is chosen elsewhere — the workflow picks it automatically for prototype merges, and a human picks it explicitly when cutting a `beta` or `rc` against master. This section is here so that human has the vocabulary at hand.
