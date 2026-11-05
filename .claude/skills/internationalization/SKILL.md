---
name: internationalization
description: Repo-aware i18n/l10n translator. Detects the current repo's i18n pipeline (FormatJS, i18next, generic JSON) and adheres to it; otherwise falls back to the users-admin-ui FormatJS default. Prompts interactively for base locale, target locales, and do-not-translate terms. Translates unsourced keys across up to 25 locales, writes a detection + plan + summary report to the output dir, and verifies the CI gate.
argument-hint: "[--ticket <ID>] [--commit] [--base <locale>] [--locales <l1,l2,...|all>] [--do-not-translate \"<term1>, <term2>\"] [--no-detect] [--output <dir>]"
---

You are the **i18n translator** for whichever repo you are invoked in. Your job is to bring every target locale up to date with the base locale by producing accurate, natural-sounding translations that preserve every ICU argument placeholder and rich-text tag exactly as they appear in the source.

This skill is **generic + repo-aware**. It first detects the local i18n pipeline and adheres to it; if nothing is detected it falls back to the users-admin-ui FormatJS default documented in Tier B below.

## When to invoke

- The user runs `/internationalization` (optionally with flags listed in the frontmatter).
- New `defineMessages()` / `intl.formatMessage()` / `<FormattedMessage>` / `t('…')` / `i18n.t('…')` calls have been added to source code.
- A CI translation gate has failed with "unsourced keys" or equivalent.
- The user asks to "translate the new keys" or similar — the skill description is written so Claude can pick it up proactively.

---

## Arguments

- `--ticket <ID>` — ticket number for the commit subject (e.g. `PLAT-70156`). If omitted, inferred from the current branch name via `git rev-parse --abbrev-ref HEAD`.
- `--commit` — after translating, stage modified catalogues and commit with the ticket-prefixed message. Without this flag, stop after writing files so the user can review.
- `--base <locale>` — base/source locale (e.g. `en_US`). Skips the base-locale prompt.
- `--locales <l1,l2,...|all>` — comma-separated target locales, or `all` for every supported non-base locale. Skips the target-locale prompt.
- `--do-not-translate "<term1>, <term2>, ..."` — comma-separated terms to preserve verbatim across all translations. Merged with any detected on-disk list. Skips the DNT prompt.
- `--no-detect` — skip Tier A detection; go straight to the Tier B default FormatJS workflow.
- `--output <dir>` — override the report output directory. Default: `reports/internationlization/` at the repo root (i.e. the cwd from which the skill was invoked). The directory is created on demand and is gitignored by project convention.

---

## Workflow overview

The skill runs in four tiers:

1. **Tier A — Detection:** figure out the repo's i18n layout, base locale, catalogues, and any existing DO-NOT-TRANSLATE / glossary files. Write a detection report.
2. **Tier C — Interactive prompts:** ask the user (via `AskUserQuestion`) for anything detection could not infer — base locale, target locales, additional DNT terms.
3. **Tier B — Translate + verify:** execute the detected pipeline (or the default FormatJS workflow if detection failed).
4. **Tier D — Output + commit:** write detection, plan, translations, and summary reports to the output dir; optionally commit.

Tier B (the default workflow) is preserved verbatim below the tier descriptions — it's still the authoritative procedure when the repo looks like `users-admin-ui` or another FormatJS project.

---

## Tier A — Detection

Before any translation work, inspect the repo and write a detection report.

### A.1 — Identify the pipeline

Check in priority order; stop at the first match and record it as `pipeline` in the report:

| Pipeline | Signal |
|---|---|
| `users-admin-ui-formatjs` | `scripts/i18n-translate.py` exists AND `src/i18n/messages/en_US.json` exists |
| `generic-formatjs` | `@formatjs/cli` in `package.json` AND `yarn extract-compile` script defined |
| `i18next` | `i18next` in `package.json` dependencies AND any of `public/locales/<ll>/`, `src/locales/<ll>/`, `locales/<ll>/` exists |
| `generic-json` | `locales/` or `translations/` dir at repo root containing per-locale JSON files, no recognised framework |
| `vue-i18n` | `vue-i18n` in `package.json` — detection only; stop with a report (no translation support yet) |

If none match, record `pipeline: unknown` and fall through to the Tier B default FormatJS workflow, noting this in the report.

Also record under `pipeline_details`:
- Catalogue directory (absolute path).
- Base-locale catalogue filename (e.g. `en_US.json`, `en.json`).
- Target-locale filenames detected in the catalogue dir.
- Extraction/compile command detected (`yarn extract-compile`, `npm run i18n:extract`, etc.).
- Verification/gate command detected (`yarn i18n:translate`, `python3 scripts/i18n-translate.py --check`, etc.).

### A.2 — Infer the base locale

In order:
1. Explicit `--base <locale>` flag.
2. `defaultLocale` / `sourceLocale` / `fallbackLng` in `i18n` config files or `package.json` / `vite.config.*` / `webpack.config.*`.
3. Filename heuristic — presence of `en_US.json` (prefer) or `en.json` in the catalogue dir.
4. Ask the user via Tier C.

### A.3 — List candidate target locales

Enumerate every locale catalogue filename in the catalogue dir (excluding the base locale). For `users-admin-ui-formatjs` use the 25 locales listed in Appendix 1 — they are authoritative per `src/i18n/locales.ts` `SUPPORTED_LOCALES`.

### A.4 — English pass-through scan (CRITICAL — do not skip)

The repo's `--check` gate only fails on `status == unsourced`. It does NOT catch keys whose value in a non-English catalogue is identical to the English source — those pass-throughs carry status `claude-provisional` and look "done" from the CSV alone.

**Enter via the repo's own tooling, not a parallel scan.** After running `python3 scripts/i18n-translate.py`, every non-English locale has a file at `src/i18n/messages/need-translation/<ll_CC>.json`. Per the script (lines 132–133), this file lists every key that is either `claude-provisional` OR `unsourced`, paired with the English source value. It is NOT a worklist — it's the full reviewable set for that locale.

For each locale, build the pass-through candidate set by intersecting `need-translation/<ll_CC>.json` with the locale catalogue:

```python
need = json.load(open(f'src/i18n/messages/need-translation/{loc}.json'))
cat  = json.load(open(f'src/i18n/messages/{loc}.json'))
pass_through = [k for k in need if cat.get(k) == need[k]]  # cat value == English source
```

Do NOT scan `en_US.json` directly — the script's `need-translation/` already normalises what each locale is supposed to be measured against (including handling of rejections via `legacy-rejections.json`). Reinventing the comparison risks diverging from the script's definition of "needs review".

Classify each pass-through into one of three buckets:

| Bucket | Heuristic | Treatment |
|---|---|---|
| `legitimate-icu` | Value is ICU-only / symbol-only / punctuation (no alphabetic word ≥ 3 chars). Examples: `"*"`, `"/ {name}"`, `"{count}"` | Do NOT re-translate. Record in the report under "allowed pass-throughs". |
| `likely-data-label` | Key matches a known data-label pattern (e.g. `*.agent_interaction_languages.*` — language display names kept in English by design) | Do NOT re-translate without user confirmation. Record as "policy pass-through". |
| `suspect` | Everything else — a non-ICU English string sitting in a non-English catalogue | Treat as a candidate for translation. Surface the count and sample keys in the Tier C prompt. |

English variants (`en_GB`, `en_AU`, `en_CA`) are exempt from this scan — they're `same-as-english-ok` by design.

Record in the detection report, per locale: total pass-through count, suspect count, 3–5 sample suspect keys with their English values.

### A.5 — Detect existing DO-NOT-TRANSLATE lists

Search for any of:
- A file named `DO_NOT_TRANSLATE.md`, `.i18nignore`, `terminology.json`, `glossary.json`, `translation-glossary.*`.
- Any markdown file under `docs/`, `docs/i18n/`, `i18n/`, `locales/` containing a heading matching `/do[- ]?not[- ]?translate|glossary|terminology/i`.
- `translation-status.csv` or similar provenance file (record its path; do not treat its entries as DNT terms — it's provenance metadata).

Extract any clearly-listed terms from matched files (lines in a bullet list, table rows, or comma-separated values under a DNT heading). Record the raw file paths and the extracted term list separately in the detection report.

### A.6 — Write the detection report

Write `<output>/detection-<timestamp>.md` with:

```markdown
# i18n detection — <repo-name> — <ISO-8601 timestamp>

## Pipeline
<pipeline key from A.1>

## Pipeline details
- Catalogue dir: <path>
- Base locale catalogue: <filename>
- Target locale catalogues: <list>
- Extraction command: <command>
- Verification command: <command>

## Base locale
- Inferred: <locale>
- Source: <flag | config | filename | user-prompt>

## DO-NOT-TRANSLATE sources
- Files found: <list of paths>
- Terms extracted: <list>

## English pass-through scan
| Locale | Total pass-throughs | Suspect | Sample suspect keys |
|---|---|---|---|
| …     | …                   | …       | …                   |

## Fallback
<"Using detected pipeline" OR "No pipeline detected — falling back to Tier B default FormatJS workflow">
```

Link the report at the top to the skill's bundled reference, [`references/data-flow.md`](./references/data-flow.md), so the reader has context on the repo's runtime + authoring data flow. If the project also keeps an authoritative i18n doc (e.g. `docs/i18n.md`), link to it too.

---

## Tier C — Interactive prompts

Use `AskUserQuestion` for anything Tier A could not infer. Skip a prompt if the corresponding flag was supplied.

### C.1 — Base locale (only if A.2 couldn't infer)

Single-select, 2–4 options derived from the catalogue filenames, most-likely candidate first.

### C.2 — Target locales (always, unless `--locales` supplied)

Multi-select. Build the option list from A.3. For `users-admin-ui-formatjs` use the 25-locale set from Appendix 1. Include an **"All 25"** / **"All detected"** option that selects every candidate.

Each option's description must show both signals Tier A collected:

- `unsourced` count (from `translation-status.csv`) — what the `--check` gate blocks on.
- `suspect pass-through` count (from A.4) — keys whose value is the English source but which are not ICU-only or policy pass-throughs.

Pre-check locales where either count is non-zero so they're selected by default.

### C.3 — Additional DO-NOT-TRANSLATE terms (always, unless `--do-not-translate` supplied)

Single-select with options pre-populated from A.4 extracted terms, plus an **"Other"** that the user can fill with a comma-separated list. Explain in the question prompt that these are product names, acronyms, or branded terms that must be preserved verbatim in every locale (e.g. "Admin Workspace, Agent Workspace, AI Studio, PBX, PSTN, VCC, SIP, CRM").

Final DNT list = extracted terms (A.4) ∪ user-supplied terms (C.3 or `--do-not-translate`).

---

## Tier B — Default (FormatJS / users-admin-ui) workflow

This is the authoritative procedure when `pipeline` is `users-admin-ui-formatjs`, `generic-formatjs`, or `unknown` (fallback). For `i18next` / `generic-json`, substitute the equivalent commands recorded in the detection report.

You produce accurate, natural-sounding translations for the users-admin-ui MFE's 25 non-English message catalogues after new keys have been added to the source code.

### B.1 — Ensure the base catalogue is up to date

Run the detected extract command. For users-admin-ui:

```bash
yarn extract-compile
```

This regenerates `src/i18n/messages/en_US.json` from every `defineMessages` / `formatMessage` call in the source. If it exits non-zero, stop and report the error — do not continue with a stale catalogue.

### B.2 — Detect keys needing translation

Two independent signals determine what needs translating:

1. **Unsourced keys** — status `unsourced` in `src/i18n/messages/translation-status.csv`. The key is absent from the catalogue entirely. The `--check` gate blocks on these.
2. **Suspect pass-through keys** — collected in Tier A.4. Key is present in the catalogue but the value is byte-identical to the English source, and not classified as `legitimate-icu` / `likely-data-label`. The `--check` gate does NOT catch these.

Run the triage script to refresh both views:

```bash
python3 scripts/i18n-translate.py
```

This updates `src/i18n/messages/translation-status.csv` and writes per-locale files into `src/i18n/messages/need-translation/`. Note that `need-translation/<ll_CC>.json` is a reference file — it contains **every key the locale uses with the English source value**, regardless of whether the catalogue has a real translation. Do NOT read it as a worklist. Build the worklist as:

```
worklist(locale) = {unsourced keys for locale} ∪ {A.4 suspect pass-throughs for locale, filtered by user's C.3 selection}
```

Only stop early if `worklist(locale)` is empty for every locale the user selected in Tier C. Still write the Tier D summary in that case.

### B.3 — Read the English source for missing keys

For each locale that has `unsourced` rows, read `need-translation/<ll_CC>.json` to see the exact English strings that need translating. The keys that appear in `need-translation/` but NOT in `src/i18n/messages/<ll_CC>.json` are the ones you must translate.

Cross-check by reading both files and diffing the key sets in memory.

### B.4 — Translate the missing keys

Produce a translation for every new key into every locale that needs it, following these rules.

#### ICU preservation rules (CRITICAL — never violate)

- **Arguments** `{name}`, `{count}`, `{source}`, `{target}`, etc. — copy verbatim, including surrounding braces and exact spelling. Never translate the argument name.
- **Plurals** `{count,plural,one{# record} other{# records}}` — translate the label words (`record`, `records`) but keep the ICU plural wrapper, selectors (`one`, `other`, `zero`, `few`, `many`), and `#` unchanged. Add locale-appropriate plural categories when the target language needs them (e.g. Polish has `one`, `few`, `many`, `other`).
- **Rich-text tags** `<link>`, `<b>`, etc. — copy the tag names verbatim. Translate the content between tags only.
- **Non-translatable keys** — if the English value is a symbol, unit suffix, or ICU-only string with no prose (e.g. `"*"`, `"/ {name}"`), copy it unchanged.

#### DO-NOT-TRANSLATE guard

Every term in the final DNT list (from Tier A + Tier C) must appear verbatim in every translated value. After drafting a translation, scan it for any DNT term that may have been inflected, transliterated, or localised — revert those occurrences to the source form. This applies to product names (Admin Workspace, Agent Workspace, AI Studio), acronyms (PBX, PSTN, VCC, SIP, CRM), and branded trademarks.

#### Translation quality rules

- Produce **natural, native-sounding** text — not word-for-word literal translations.
- UI strings are short and imperative — match that register (e.g. "Save", "Cancel", "Loading…").
- Field labels use title case in English — follow the target language's convention for UI labels (German capitalises all nouns; Japanese and Chinese generally do not use punctuation for short labels).
- **Arabic (`ar_AE`)** — use Modern Standard Arabic (MSA), RTL text only. Do not add LTR marks or bidi overrides.
- **Welsh (`cy_GB`)** — use standard Welsh orthography. For UI technical terms with no Welsh equivalent, the English loanword is acceptable.
- **Shared loanwords** — terms like "Chat", "Agent", "Email", "IVR", "SIP", "CRM" are borrowed in most locales; keep them in English unless a natural local equivalent exists (e.g. German "E-Mail" is fine; French "Chat" is fine).

#### English variants (`en_GB`, `en_AU`, `en_CA`)

Do **not** translate. Copy the `en_US` value for every missing key. The `--authored` merge step records these as `same-as-english-ok` automatically.

### B.5 — Write translations into a staging directory

Create a temporary directory `src/i18n/messages/authored/` (create if absent). Write one JSON file per locale containing **only the newly translated keys** (not the full catalogue — `--authored` merges):

```
src/i18n/messages/authored/
  fr_FR.json   ← only the new keys
  de_DE.json
  ...
```

File format — standard JSON, keys sorted alphabetically to match the rest of the catalogue:

```json
{
  "users.misc.select_placeholder": "Sélectionner...",
  "users.new.key": "Traduction ici"
}
```

For English variants write their files too, with the English source values copied verbatim.

### B.6 — Merge authored translations

```bash
python3 scripts/i18n-translate.py --authored src/i18n/messages/authored/
```

This writes each key into `src/i18n/messages/<ll_CC>.json` with status `claude-provisional` (or `same-as-english-ok` for English variants).

### B.7 — Verify the CI gate

```bash
python3 scripts/i18n-translate.py --check
```

Exit code 0 means no `unsourced` keys remain. If it exits non-zero, read the output, identify which keys are still missing, and go back to B.4.

### B.8 — Clean up staging directory

```bash
rm -rf src/i18n/messages/authored/
```

### B.9 — Commit (if `--commit` was passed)

Stage all modified catalogue files and `translation-status.csv`:

```bash
git add src/i18n/messages/
```

Infer the ticket ID from the branch name if `--ticket` was not supplied:

```bash
git rev-parse --abbrev-ref HEAD
# improvement/PLAT-70156-internationalization → PLAT-70156
```

Commit with the conventional format:

```bash
git commit -m "[PLAT-70156] - Translate <N> new i18n key(s) across 25 locales"
```

Where `<N>` is the count of distinct keys added (not key×locale pairs).

---

## Tier D — Output + commit

Regardless of which pipeline ran, write the full set of reports to `<output>/` (default `reports/internationlization/` at the repo root):

| File | Contents |
|---|---|
| `detection-<timestamp>.md` | Written in Tier A — pipeline, base locale, DNT sources. |
| `plan-<timestamp>.md` | The executed plan: selected locales, final DNT list, key counts per locale, commands run. |
| `translations-<timestamp>.json` | `{ "<locale>": { "<key>": "<translation>", … } }` — the raw translations produced this run. Enables review and reuse across sessions. |
| `summary-<timestamp>.md` | Human-readable summary: total keys translated, per-locale counts, warnings (e.g. "en_GB copied verbatim"), next steps, link back to `data-flow.md` and `detection-<timestamp>.md`. |

The timestamp is a single value reused across the four files so they sort together. Use `date -u +%Y%m%dT%H%M%SZ` (`YYYYMMDDTHHMMSSZ`) in the filenames.

Then — if `--commit` was passed — execute B.9.

---

## Appendix 1 — users-admin-ui supported locales (25)

Reproduced here for the Tier C target-locale prompt when `pipeline = users-admin-ui-formatjs`. Authoritative source: `src/i18n/locales.ts` `SUPPORTED_LOCALES`.

| Locale | Language |
|---|---|
| `en_GB` | English (UK) — same-as-english-ok |
| `en_AU` | English (Australia) — same-as-english-ok |
| `en_CA` | English (Canada) — same-as-english-ok |
| `fr_FR` | French |
| `fr_CA` | French (Canada) |
| `de_DE` | German |
| `es_ES` | Spanish (Spain) |
| `it_IT` | Italian |
| `nl_NL` | Dutch |
| `pt_BR` | Portuguese (Brazil) |
| `ja_JP` | Japanese |
| `zh_CN` | Chinese Simplified |
| `zh_TW` | Chinese Traditional |
| `ko_KR` | Korean |
| `ru_RU` | Russian |
| `pl_PL` | Polish |
| `hr_HR` | Croatian |
| `hi_IN` | Hindi |
| `ar_AE` | Arabic (UAE) — RTL |
| `da_DK` | Danish |
| `no_NO` | Norwegian |
| `sv_SE` | Swedish |
| `vi_VN` | Vietnamese |
| `th_TH` | Thai |
| `cy_GB` | Welsh |

---

## Appendix 2 — Translation reference: domain vocabulary

These terms have established translations used throughout the existing catalogues. Match them for consistency — read the existing locale file before translating related keys.

| English term | Notes |
|---|---|
| Agent | Borrowed in most locales; check existing catalogue |
| Supervisor | Check existing catalogue |
| Queue | Check existing catalogue |
| Tenant | Check existing catalogue |
| Loading | Short, imperative — "Chargement" (fr), "Lädt" (de), etc. |
| Save / Cancel / Apply / Reset | Standard UI verbs — match existing catalogue entries |
| Enabled / Disabled | Check existing catalogue for adjectival form |

Before translating any key that touches a term already present in a locale's catalogue (e.g. `users.form.action.save` → "Enregistrer" in fr_FR), look up that term in the locale file and use the same word. Consistency within a locale matters more than the most technically accurate translation.

---

## Appendix 3 — Failure modes to avoid

| Mistake | Impact | Correct behaviour |
|---|---|---|
| Translating ICU argument names (`{name}` → `{nom}`) | Runtime crash — `react-intl` can't find the argument | Copy argument names verbatim |
| Changing ICU plural category names (`one` → `un`) | Plural forms silently fall back to `other` | Keep category names (`one`, `other`, `few`, `many`, `zero`) unchanged |
| Omitting a plural category the locale requires | Missing plural form for that number | Add locale-appropriate categories (e.g. Polish `few` for 2–4) |
| Adding content to a non-translatable key | Breaks layout or adds spurious text | Copy the source value unchanged |
| Writing the full catalogue to `authored/` | `--authored` merge overwrites existing translations | Write only the new/missing keys |
| Skipping the `--check` verification | Unsourced keys survive into the next CI run | Always verify zero unsourced before finishing |
| Committing `src/i18n/messages/authored/` | Scratch dir pollutes the repo | Always `rm -rf` it after `--authored` merge |
| Translating a DNT term | Breaks product-name consistency; legal exposure for trademarks | Revert to source form after translation |
| Skipping Tier A and running default pipeline in an i18next repo | Writes catalogues in the wrong location; CI gate stays red | Always run detection first unless `--no-detect` is passed |
| Trusting `--check` as the only completion signal | The gate only fails on `unsourced`. Keys whose catalogue value equals the English source stay `claude-provisional` and ship as English | Always run Tier A.4 pass-through scan; treat suspect pass-throughs as translation candidates |
| Scanning `en_US.json` against each locale catalogue directly, ignoring `need-translation/` | Diverges from the repo's own definition of "reviewable" (which handles `legacy-rejections.json`, the `acceptable()` check, and the `claude-provisional` vs `same-as-english-ok` distinction) | Enter via the script. Build pass-through candidates by filtering `need-translation/<ll_CC>.json` to entries where `cat[k] == need[k]` |
| Re-translating an ICU-only / symbol-only pass-through (`"*"`, `"/ {name}"`) | Breaks layout; corrupts data labels | Classify as `legitimate-icu` in A.4 and skip |

---

## Appendix 4 — Files owned by this skill

Within `users-admin-ui`:

| Path | Role |
|---|---|
| `src/i18n/messages/en_US.json` | Source of truth — regenerated by `yarn extract-compile`, never edited by hand |
| `src/i18n/messages/<ll_CC>.json` | 25 locale catalogues — updated by this skill |
| `src/i18n/messages/translation-status.csv` | Provenance ledger — updated by `scripts/i18n-translate.py` |
| `src/i18n/messages/need-translation/<ll_CC>.json` | Scratch — English source for pending keys; regenerated on every script run |
| `src/i18n/messages/authored/` | Scratch — staged translations; deleted after merge |
| `scripts/i18n-translate.py` | The authoritative triage and merge tool — **do not modify** |

Within the skill directory (`.claude/skills/internationalization/`):

| Path | Role |
|---|---|
| `SKILL.md` | This file — the executable workflow. |
| `references/data-flow.md` | Reference anchor — runtime + authoring data flow (users-admin-ui FormatJS pipeline). Linked from every detection report. |

Within the output directory (default `reports/internationlization/` at the repo root; gitignored by project convention):

| Path | Role |
|---|---|
| `detection-<timestamp>.md` | Per-run Tier A output. |
| `plan-<timestamp>.md` | Per-run Tier D plan. |
| `translations-<timestamp>.json` | Per-run raw translations keyed by locale. |
| `summary-<timestamp>.md` | Per-run human-readable summary. |
| `pass-through-census-<timestamp>.json` | Per-run Tier A.4 pass-through classification (every bucket, every locale). |
| `finding-*-<timestamp>.md` | Optional — ad-hoc findings the skill surfaces during a run (e.g. the pass-through gap writeup). |
