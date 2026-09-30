---
description: Run a WCAG (2.0, 2.1, 2.2, or 3.0 draft) A+AA accessibility audit on a scope and produce a triaged findings report
argument-hint: [--wcag 2.0|2.1|2.2|3.0] [<path> | diff | all]
---

Audit a scope of this MFE against a chosen version of WCAG and the project's Oxygen accessibility conventions, then output a triaged findings report. Use when reviewing a PR, prepping a release, or verifying that a focused a11y fix didn't regress anything else.

## Arguments

### `--wcag` (optional, defaults to `2.1`)

Picks the W3C spec that findings are cross-referenced against. Exactly one of the versions in the table below. Any other value is an error — print the usage block above and stop.

| Flag | Status | Success criteria | Understanding doc root | Normative TR |
|---|---|---|---|---|
| `--wcag 2.0` | W3C Recommendation (2008), superseded by 2.1 | 38 across 4 principles | [WCAG 2.0 Understanding](https://www.w3.org/WAI/WCAG20/Understanding/) | [TR/WCAG20](https://www.w3.org/TR/WCAG20/) |
| `--wcag 2.1` *(default)* | W3C Recommendation (2018) | 50 (38 from 2.0 + 12 new) | [WCAG 2.1 Understanding](https://www.w3.org/WAI/WCAG21/Understanding/) | [TR/WCAG21](https://www.w3.org/TR/WCAG21/) |
| `--wcag 2.2` | W3C Recommendation (2023) | 55 (50 from 2.1 + 6 new − SC 4.1.1 Parsing) | [WCAG 2.2 Understanding](https://www.w3.org/WAI/WCAG22/Understanding/) | [TR/WCAG22](https://www.w3.org/TR/WCAG22/) |
| `--wcag 3.0` | **W3C Working Draft** — not final, still evolving | Outcome-based (no fixed SC list) | *(no Understanding doc yet)* | [TR/wcag-3.0](https://www.w3.org/TR/wcag-3.0/) |

Guidance on which to pick:

- **2.0** — auditing legacy code that was built against 2.0 and is not being brought forward. The safety-net baseline.
- **2.1** *(default)* — auditing existing work in this project; matches what the a11y backlog was written against.
- **2.2** — new work, or any project targeting EAA / EN 301 549 compliance from June 2025 onward. Strictly more than 2.1.
- **3.0** — early-warning check against the working draft; findings are provisional because the spec itself is still moving. Do **not** use 3.0 for gate decisions on a merge — always pair it with a 2.1 or 2.2 pass.

### Positional scope (optional, defaults to `diff`)

Exactly one of:

- `<path>` — file or directory glob (e.g. `src/components/UserEditPage/GeneralTab.tsx`, `src/components/UsersListPage/**`). Anything `eslint` accepts works.
- `diff` *(default)* — audit only `.tsx`/`.jsx` files changed against `master` on the current branch (`git diff --name-only master...HEAD -- '*.tsx' '*.jsx'`). The right default for PR reviews.
- `all` — audit every component file under `src/components/**` and `src/pages/**`. Slow; use before a release.

Any other input is an error — print the usage block above and stop.

## Cross-reference targets (per `--wcag`)

Every version is audited against the same four best-practice axes; the version flag only changes the source-of-truth spec the report links to and which version-specific criteria are added or skipped.

| Axis | What the audit checks | Where findings link |
|---|---|---|
| **ARIA attributes and best practices** | `role`, `aria-*` props are valid for their host element; `aria-controls` / `aria-labelledby` / `aria-describedby` references resolve to real IDs; no `aria-hidden` on focusable content; no redundant roles (`<button role="button">`). Backed by `eslint-plugin-jsx-a11y`'s `aria-*` rules (step 2). | SC 4.1.2 Name, Role, Value · SC 1.3.1 Info and Relationships |
| **Keyboard navigation patterns** | Every interactive element is in the tab order or explicitly excluded; visible focus indicator on every focusable element; no keyboard traps; arrow-key + Esc + Enter wiring on composite widgets (menus, listboxes, tabs); skip-link present on page shells. | SC 2.1.1 Keyboard · SC 2.1.2 No Keyboard Trap · SC 2.4.3 Focus Order · SC 2.4.7 Focus Visible |
| **Color contrast ratios** | Body text ≥ **4.5:1** against background; large text (≥ 18.66px regular / 14px bold) ≥ 3:1; non-text UI (button borders, focus rings, form-field outlines) ≥ 3:1. Hardcoded colours in the audited files are an automatic finding — Oxygen theme tokens (`theme.textColor01`, `theme.error01`, etc.) carry guaranteed contrast and must be used instead. | SC 1.4.3 Contrast (Minimum) · SC 1.4.11 Non-text Contrast |
| **Screen reader compatibility patterns** | Form inputs have programmatically-associated labels (Oxygen `labelValue` or native `<label htmlFor>`); icon-only buttons have `aria-label`; status / error / success regions use `role="status"` or `role="alert"` (Toaster); decorative SVG/icons are `aria-hidden`; tables expose row/col headers. | SC 1.1.1 Non-text Content · SC 3.3.2 Labels or Instructions · SC 4.1.3 Status Messages |

### Version-specific criteria to add / skip

Beyond the shared axes above, each version brings its own delta. Apply only the deltas for the version passed via `--wcag`.

#### `--wcag 2.0`

Baseline set only. No additions beyond the shared axes. `SC 4.1.1 Parsing` **is** in scope for 2.0 (was later obsoleted in 2.2).

#### `--wcag 2.1` adds (over 2.0)

- **SC 1.3.4 Orientation (AA)** — content is not locked to portrait or landscape.
- **SC 1.3.5 Identify Input Purpose (AA)** — inputs collecting user info have appropriate `autocomplete` values.
- **SC 1.4.10 Reflow (AA)** — content reflows to a single column at 320 CSS px viewport width without loss of information.
- **SC 1.4.11 Non-text Contrast (AA)** — UI components and meaningful graphics ≥ 3:1 against adjacent colour.
- **SC 1.4.12 Text Spacing (AA)** — user-overridden line-height, paragraph-, letter-, word-spacing does not clip content.
- **SC 1.4.13 Content on Hover or Focus (AA)** — tooltip / popover content is dismissible, hoverable, and persistent.
- **SC 2.5.3 Label in Name (A)** — the accessible name of a control contains its visible label text.
- **SC 4.1.3 Status Messages (AA)** — status regions use `role="status"` / `role="alert"` (already in shared axes).

#### `--wcag 2.2` adds (over 2.1) AND removes SC 4.1.1

Add:

- **SC 2.4.11 Focus Not Obscured (Minimum) (AA)** — sticky headers / cookie banners must not fully hide the focused element.
- **SC 2.5.7 Dragging Movements (AA)** — every drag interaction has a single-pointer (click/tap) alternative.
- **SC 2.5.8 Target Size (Minimum) (AA)** — interactive targets are ≥ **24×24 CSS pixels** (or inline within text). Oxygen icon-buttons at default size satisfy this; small (`size="small"`) variants need verification.
- **SC 3.2.6 Consistent Help (A)** — help affordances appear in the same relative order across pages.
- **SC 3.3.7 Redundant Entry (A)** — information the user already entered in the session is not re-requested (or is auto-filled / available to select).
- **SC 3.3.8 Accessible Authentication (Minimum) (AA)** — no cognitive-function test (puzzle, memory) without an alternative.

Skip: **SC 4.1.1 Parsing** was obsoleted in 2.2 — do not report parsing findings when `--wcag 2.2`.

#### `--wcag 3.0` (Working Draft)

WCAG 3.0 replaces the SC / A / AA structure with outcome-based "guidelines" scored per method. The spec is still moving and there is no stable Understanding-doc URL scheme yet. For this audit:

- Keep the four shared axes above and cross-reference each finding to the closest 2.2 SC (this is the current W3C mapping guidance) **and** to the corresponding WCAG 3 outcome slug on [`TR/wcag-3.0`](https://www.w3.org/TR/wcag-3.0/) using a jump link (e.g. `#target-size-minimum`).
- Emit an explicit `Draft — provisional` tag on every WCAG 3 finding in the report so downstream readers know the mapping may change.
- Do **not** use 3.0 findings as a merge gate. Always run a 2.1 or 2.2 pass alongside.

## Steps

1. **Parse the flags**:
   - Default `--wcag` to `2.1` if absent. Reject anything not in `{2.0, 2.1, 2.2, 3.0}` — print the version table above and stop.
   - When `--wcag 3.0` is passed, additionally warn the user that findings are provisional (working draft) and recommend also running a 2.1 or 2.2 pass before making merge decisions.
   - Default the scope to `diff` if absent. Validate as in the "Positional scope" section above.
   - Echo `WCAG <version> · scope: <resolved description>` to the user before running anything else, so they can confirm.

2. **Resolve the file list** by translating the scope:
   - `diff` → `git diff --name-only master...HEAD -- '*.tsx' '*.jsx'`. If empty, stop and tell the user there are no changed UI files to audit.
   - `<path>` → pass through to eslint, but first verify the path resolves to at least one `.tsx`/`.jsx` file. If nothing matches, stop and ask the user to refine the scope.
   - `all` → `src/components/**/*.{tsx,jsx} src/pages/**/*.{tsx,jsx}`.

   Echo the resolved list before running any checks.

3. **Run the static jsx-a11y pass** scoped to those files with the `jsx-a11y/*` rules surfaced as errors:

   ```bash
   yarn lint --no-fix --rule '{"jsx-a11y/anchor-is-valid":"error","jsx-a11y/alt-text":"error","jsx-a11y/aria-props":"error","jsx-a11y/aria-role":"error","jsx-a11y/aria-unsupported-elements":"error","jsx-a11y/click-events-have-key-events":"error","jsx-a11y/heading-has-content":"error","jsx-a11y/iframe-has-title":"error","jsx-a11y/img-redundant-alt":"error","jsx-a11y/interactive-supports-focus":"error","jsx-a11y/label-has-associated-control":"error","jsx-a11y/no-autofocus":"error","jsx-a11y/no-noninteractive-element-interactions":"error","jsx-a11y/no-redundant-roles":"error","jsx-a11y/role-has-required-aria-props":"error","jsx-a11y/role-supports-aria-props":"error"}' <files>
   ```

   The plugin is already wired in `eslint.config.js` via `jsxA11y.flatConfigs.recommended` — running the explicit rule set ensures the audit catches violations even if a project override has downgraded any of them. Capture every `jsx-a11y/*` finding with file path, line number, rule id, and message.

4. **Invoke the deep-review skill** `front-end-development:a11y-review` on the same scope, **passing `--wcag <version>` so the skill applies the same version of the spec**. That skill is the canonical WCAG reviewer for Oxygen-based code — it understands which native primitives are banned, which Oxygen affordances replace them, and which Oxygen components have known a11y gotchas (focus traps in `Modal`, `aria-controls` on `Tab`, etc.). Pass the file list verbatim so both passes cover the same lines.

   The downstream skill was originally written against WCAG 2.1. If it rejects `2.0` or `3.0`, fall back to invoking it with `2.1` and note in the report header that the deep-review pass ran against `2.1` while the top-level audit was `<version>`.

5. **Cross-reference each finding against the W3C source-of-truth doc** for the selected version. Use this table:

   | Version | Understanding-doc root (deep-link findings here when available) | Normative TR (link when Understanding is absent) |
   |---|---|---|
   | `2.0` | `https://www.w3.org/WAI/WCAG20/Understanding/` | `https://www.w3.org/TR/WCAG20/` |
   | `2.1` | `https://www.w3.org/WAI/WCAG21/Understanding/` | `https://www.w3.org/TR/WCAG21/` |
   | `2.2` | `https://www.w3.org/WAI/WCAG22/Understanding/` | `https://www.w3.org/TR/WCAG22/` |
   | `3.0` | *(no Understanding doc yet)* | `https://www.w3.org/TR/wcag-3.0/` |

   For every finding, attach (a) the criterion / outcome id it maps to (e.g. `SC 1.4.3` for 2.x; the WCAG-3 outcome slug for `3.0`), (b) its full title, and (c) the direct deep-link. Slug pattern for 2.x is `https://www.w3.org/WAI/WCAG<ver>/Understanding/<criterion-slug>` (e.g. `.../contrast-minimum`). For `3.0`, link to the outcome anchor inside `TR/wcag-3.0` (e.g. `.../#target-size-minimum`) and additionally link the closest 2.2 SC so reviewers have a stable reference. Use `WebFetch` to pull the version's root doc once at the start of the audit to confirm slug → id mapping, then fetch individual criterion pages only when a finding needs a quoted rationale.

   Findings that don't cleanly map to a single criterion / outcome (e.g. mixed Oxygen-convention violations) get tagged `Oxygen-convention` and linked to the relevant section of `CLAUDE.md` instead.

6. **Run the four best-practice checks** from the table above on every audited file. These are not lint-rule findings — they are pattern checks the agent performs by reading the source:
   - **ARIA attributes:** grep every `aria-*` and `role=` in the scope. For each, confirm it's valid on its host element and that any id reference (`aria-controls`, `aria-labelledby`, `aria-describedby`) resolves to a real id in the same render tree.
   - **Keyboard navigation:** every `onClick` on a non-native-interactive element must have a matching `onKeyDown` (or be wrapped in `<button>`/Oxygen `Button`). Any element with `tabIndex={-1}` that the user is expected to reach is a finding.
   - **Color contrast:** flag every hex literal, `rgb(...)`, or `rgba(...)` in styled-components or inline styles. Theme-tokenised values are exempt; hardcoded values are an automatic Serious finding (Oxygen's theme tokens are the only contrast-guaranteed source).
   - **Screen reader compatibility:** every Oxygen `Input`/`Select`/`Checkbox`/`Radio`/`Textarea` must have a `labelValue` prop OR a visible `<label htmlFor=...>` referencing its `id`/`inputId`. Toast usage must rely on `notify({ type: 'error', ... })` so Oxygen's `role="alert"` wiring is preserved.

7. **Apply the version-specific deltas** from the "Version-specific criteria to add / skip" section above:
   - `2.0` → shared axes only; keep `SC 4.1.1 Parsing` in scope.
   - `2.1` → shared axes plus the 8 criteria new to 2.1; `SC 4.1.1 Parsing` still in scope.
   - `2.2` → shared axes plus the 6 criteria new to 2.2; **skip** `SC 4.1.1 Parsing` (obsoleted). SC 2.5.8 (target size) requires reading rendered CSS sizes — use Oxygen `size="small"` as the trigger to manually verify; do not auto-flag without confirming.
   - `3.0` → shared axes only, but tag every finding `Draft — provisional` and link both the 2.2 SC and the 3.0 outcome slug.

8. **Verify Oxygen prop usage on flagged components.** For any finding that names an Oxygen component, call `mcp__oxygen-mcp__get-component-props` on that component to confirm the recommended a11y prop (`ariaControls`, `aria-label`, `isRequired`, etc.) exists on the currently-installed version (`@8x8/oxygen-*` at `2.104.x` as of writing). The Oxygen API surface changes between releases — recommending a prop that doesn't exist on the installed version is worse than no recommendation at all.

9. **Cross-reference against the project's known a11y backlog** at [`docs/backlog/follow-ups.md`](../../docs/backlog/follow-ups.md), section "Accessibility (WCAG 2.1 A+AA)". Tag every finding as one of:
   - **NEW** — not in the backlog. Ship a fix or open a ticket.
   - **TRACKED** — already in the backlog. Note the bullet it matches so the reviewer can decide whether this PR should resolve it.
   - **REGRESSION** — the backlog says it was fixed (bullet is ticked) but the audit found it again. Flag in the report header — this is the priority case.

10. **Emit the report** as markdown to stdout (do NOT write a file unless the user asks). Required sections in this order:

    ```markdown
    ## WCAG <version> audit — <scope description>

    **Spec:** [<Understanding-doc or TR link for the version, per the table in step 5>]
    **Files audited:** <N>  ·  **Findings:** <total> (Critical: X · Serious: Y · Moderate: Z · Minor: W)
    <if version === "3.0">**⚠️ Draft mode:** WCAG 3.0 is a W3C Working Draft. Findings are provisional and must not be used as a merge gate. Pair with a 2.1 or 2.2 pass.</if>

    ### Regressions
    <bullets — empty section if none, but always show the heading>

    ### Critical (must-fix before merge)
    <bullets: `file:line` — `SC x.y.z <Title>` ([link](...)) — one-line description — suggested fix>

    ### Serious
    <same shape>

    ### Moderate
    <same shape>

    ### Minor / advisory
    <same shape>

    ### Tracked items observed
    <list of TRACKED findings with backlog bullet refs>
    ```

    Severity follows axe-core's classification (Critical / Serious / Moderate / Minor). For findings the static linter raised, map the rule's default severity from `eslint-plugin-jsx-a11y`'s metadata; for findings the `a11y-review` skill raised, use the severity it returned; for the best-practice pattern checks in step 6, use these defaults: hardcoded colour → Serious; missing keyboard handler → Critical; unresolved aria id reference → Serious; missing label on a form input → Critical.

## Notes

- This command does NOT modify code, run `--fix`, or open PRs. Its only output is the report. For applying fixes, use the `a11y-review` skill directly with the same scope, or `/simplify` after staging the audit's findings as a task list.
- The `--wcag` flag is **not** a strictness setting**. 2.0 → 2.1 → 2.2 is a mostly-additive progression (2.2 also removes SC 4.1.1 Parsing). Picking `2.0` is the right call only for legacy code being audited against its original spec; `2.1` is the safe default and matches the project's a11y backlog; `2.2` is the right call for new work or any merge slated to ship after the project commits to EAA / EN 301 549. `3.0` is a Working Draft and its findings must be treated as provisional (see step 1 warning).
- Adding a new version: extend the version table in the `--wcag` argument section, add its URL row to the step-5 table, add a `--wcag <ver>` block to "Version-specific criteria to add / skip" listing the delta from the previous version, and add its case to step 7. No other rewriting should be needed.
- If the eslint or `a11y-review` invocation errors out (e.g. type-check failure in a touched file), surface the error verbatim and stop — do not produce a partial report. A broken type graph means jsx-a11y rules misfire.
- For routes/pages that render only after data loads (most of `UserEditPage`'s tabs), static lint catches obvious wiring issues but cannot catch focus-management bugs. The `a11y-review` skill's findings are the load-bearing ones for those — do not down-weight them just because the linter agreed.
- The Oxygen-specific banned-native-HTML list in `CLAUDE.md` § "Banned Native HTML Elements" is part of WCAG compliance in this project (a11y is one of the explicit rationales). Treat any `<table>`/`<button>`/`<input>` finding from that list as **Serious** at minimum.
- The "follow-ups" backlog at `docs/backlog/follow-ups.md` is the canonical store of known-but-not-yet-fixed a11y debt. Whenever a NEW finding is recorded, ask the user whether to append it there so the next audit recognises it as TRACKED. If you're running `--wcag 2.2` and a finding maps to a 2.2-only criterion, append it under a `### 2.2-only` sub-heading so future 2.1 audits don't misclassify it as REGRESSION.
