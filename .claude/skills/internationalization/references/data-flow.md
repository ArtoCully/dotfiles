# users-admin-ui — i18n Data Flow & Scripts

Snapshot: 2026-11-03.

## 1. Runtime data flow (locale → rendered string)

```
┌─ Shell event bus ─────────────────────────────────────────┐
│ SHELL_CONFIG_EVENT ({ locale: 'fr-CA', schemaVersion })   │
└───────────────┬───────────────────────────────────────────┘
                │ useSubscribeEvent (requestInitialData: true)
                ▼
         src/hooks/useShellLocale.ts
                │ returns BCP-47 string (or undefined)
                ▼
         src/components/App.tsx
                │ pickLocale(propLocale, shellLocale)   ← prop wins, then shell, else en_US
                ▼
         pickLocale → resolveLocale (src/i18n/locales.ts)
                │ maps 'fr-CA' | 'fr_CA' | 'fr' → SupportedLocale ('fr_CA')
                │ handles zh-Hant → zh_TW; LANGUAGE_DEFAULTS fallback
                ▼
         useLocaleMessages(locale, onLoadFailure)
         (src/i18n/useLocaleMessages.ts)
                │ initial state: { locale: 'en_US', messages: EN_US_MESSAGES }
                │ en_US branch: synchronous, no network
                │ other locales: loadMessages(locale) via webpack lazy chunk
                │   LOADERS[locale]() → import('./messages/<ll_CC>.json')
                │   merged on top of EN_US_MESSAGES (missing keys fall back to English)
                │ onLoadFailure → observability (reportError source:'i18n.loadMessages')
                │                 and state stays on en_US
                ▼
         <IntlProvider
             locale={toBcp47(catalogue.locale)}   ← 'fr_CA' → 'fr-CA' at the boundary
             messages={catalogue.messages}
             defaultLocale={toBcp47(DEFAULT_LOCALE)} />
                ▼
         Components call intl.formatMessage(messages.someKey)
         Messages defined in src/i18n/messages.ts via defineMessages({ id, defaultMessage })
         Key convention: 'users.{section}.{element}' (dot-lowercase)
```

### Key boundary rule

- **Catalogue keys / backend**: Java form (`en_US`, underscore) — matches CM-API responses byte-for-byte.
- **react-intl / `IntlProvider`**: BCP-47 (`en-US`, hyphen).
- Conversion happens only at `IntlProvider` via `toBcp47` (defined in `src/i18n/locales.ts`, re-exported from `src/i18n/index.ts`).
- Passing Java form to `IntlProvider` throws `RangeError: Invalid language tag: en_US`.

### Supported locales (26 total)

`en_US` (default, bundled) + 25 lazy chunks:
`en_GB en_AU en_CA fr_FR fr_CA de_DE es_ES it_IT nl_NL pt_BR ja_JP zh_CN zh_TW ko_KR ru_RU pl_PL hr_HR hi_IN ar_AE da_DK no_NO sv_SE vi_VN th_TH cy_GB`.

Registry: `SUPPORTED_LOCALES` in `src/i18n/locales.ts`.

## 2. Authoring data flow (defineMessages → catalogues)

```
Source code (.ts/.tsx)
   defineMessages({ someKey: { id: 'users.x.y', defaultMessage: '...' } })
   intl.formatMessage(messages.someKey) / <FormattedMessage id="..." />
            │
            │ yarn extract            (@formatjs/cli)
            ▼
   src/extracted/en.json             ← raw extraction output (ids + defaults)
            │
            │ yarn compile            (@formatjs/cli)
            ▼
   src/i18n/messages/en_US.json      ← source of truth; never hand-edited
            │
            │ python3 scripts/i18n-translate.py
            │   (re-sources from the 25 maintained JSON files;
            │    writes translation-status.csv + need-translation/<ll_CC>.json;
            │    status values: claude-provisional | same-as-english-ok | unsourced)
            ▼
   For each locale with `unsourced` rows:
   author translations into src/i18n/messages/authored/<ll_CC>.json
   (English variants en_GB/en_AU/en_CA copy en_US verbatim)
            │
            │ python3 scripts/i18n-translate.py --authored src/i18n/messages/authored/
            ▼
   src/i18n/messages/<ll_CC>.json     ← 25 locale catalogues updated
   src/i18n/messages/translation-status.csv updated
            │
            │ python3 scripts/i18n-translate.py --check   (CI gate; exits 1 if any unsourced)
            ▼
   rm -rf src/i18n/messages/authored/   (scratch dir; never commit)
   commit `src/i18n/messages/`
```

## 3. Scripts to run (in order)

| Step | Command | Purpose | Exit behaviour |
|---|---|---|---|
| 1 | `yarn extract-compile` | Chains `yarn extract` → `yarn compile`. Regenerates `src/extracted/en.json` then `src/i18n/messages/en_US.json`. Run after any new `defineMessages` / `intl.formatMessage` / `<FormattedMessage>` call. | Non-zero on parse / id-collision; stop and fix before continuing. |
| 2 | `yarn extract` | Standalone extraction (`formatjs extract 'src/**/*.ts*' --out-file src/extracted/en.json --flatten`). | — |
| 3 | `yarn compile` | Standalone compile (`formatjs compile src/extracted/en.json --out-file src/i18n/messages/en_US.json`). | — |
| 4 | `python3 scripts/i18n-translate.py` | Re-sources all 25 catalogues; writes `translation-status.csv` and per-locale `need-translation/<ll_CC>.json` with English source for every unsourced key. | Writes files; exits 0. |
| 5 | `python3 scripts/i18n-translate.py --authored src/i18n/messages/authored/` | Merges the staged `authored/<ll_CC>.json` files into the live catalogues as `claude-provisional` (or `same-as-english-ok` for en_GB/en_AU/en_CA). | Writes catalogues + CSV. |
| 6 | `yarn i18n:translate` (= `python3 scripts/i18n-translate.py --check`) | **CI gate.** No writes. Exits 1 if any key is still `unsourced`; lists them to stderr. | Non-zero blocks CI. |
| 7 | `yarn i18n:translate:dry-run` (= `python3 scripts/i18n-translate.py --dry-run`) | Read-only preview — lists unsourced keys but exits 0. Safe for pre-commit hooks / editor integrations. | Always 0. |
| 8 | `python3 scripts/i18n-translate.py --doc` | Rewrites the generated section of `docs/i18n.md` (counts + rejections table). | Writes docs. |
| 9 | `rm -rf src/i18n/messages/authored/` | Cleanup; the `authored/` directory is scratch and must not be committed. | — |

Automation entry point: the `/internationalization` skill (`.claude/skills/internationalization/SKILL.md`) orchestrates steps 1 → 6 and then (optionally with `--commit`) stages `src/i18n/messages/` and commits as `[TICKET] - Translate <N> new i18n key(s) across 25 locales`.

## 4. Files owned by the i18n pipeline

| Path | Role | Edited by |
|---|---|---|
| `src/i18n/messages.ts` | All `defineMessages` for the MFE; sole call-site convention. | Humans. |
| `src/extracted/en.json` | Raw formatjs extraction output. | `yarn extract`. |
| `src/i18n/messages/en_US.json` | Compiled source of truth catalogue; synchronously bundled. | `yarn compile`. Never hand-edited. |
| `src/i18n/messages/<ll_CC>.json` | 25 lazy-chunk translated catalogues. | `scripts/i18n-translate.py --authored`. |
| `src/i18n/messages/translation-status.csv` | Provenance ledger (`claude-provisional` / `same-as-english-ok` / `unsourced`). | `scripts/i18n-translate.py`. |
| `src/i18n/messages/need-translation/<ll_CC>.json` | Scratch: English source for keys the locale still needs. Regenerated every run. | `scripts/i18n-translate.py`. |
| `src/i18n/messages/authored/<ll_CC>.json` | **Scratch** — new translations only, keys sorted. Deleted after merge. | Translator (human / Claude). |
| `src/i18n/messages/legacy-rejections.json` | Candidate translations blocked for sense. | Humans. |
| `src/i18n/locales.ts` | Registry: `SUPPORTED_LOCALES`, `LANGUAGE_DEFAULTS`, `LOADERS`, `resolveLocale`, `pickLocale`, `loadMessages`, `toBcp47`. | Humans. |
| `src/i18n/useLocaleMessages.ts` | React hook; en_US sync, others via lazy chunk; stable `onLoadFailure` ref. | Humans. |
| `src/i18n/index.ts` | Barrel re-export (keeps legacy `LocaleMessages` alias). | Humans. |
| `src/hooks/useShellLocale.ts` | Reads shell locale from `SHELL_CONFIG_EVENT` with `requestInitialData: true`. | Humans. |
| `src/components/App.tsx` | Composes `pickLocale → useLocaleMessages → IntlProvider` with `toBcp47` at the boundary. | Humans. |
| `scripts/i18n-translate.py` | Authoritative triage + merge + CI gate tool. | Do not modify (per skill contract). |
| `docs/i18n.md` | Human doc; "Counts" + rejections sections regenerated by `--doc`. | Humans + `--doc`. |

## 5. Typical sequence after adding a new string

```
# 1. Add a new entry to src/i18n/messages.ts and use it via intl.formatMessage(messages.yourKey)

yarn extract-compile                                        # refresh en_US.json
python3 scripts/i18n-translate.py                           # populate need-translation/
#   author new keys into src/i18n/messages/authored/<ll_CC>.json
python3 scripts/i18n-translate.py --authored src/i18n/messages/authored/
yarn i18n:translate                                         # CI gate — must exit 0
rm -rf src/i18n/messages/authored/
git add src/i18n/messages/
git commit -m "[PLAT-XXXXX] - Translate N new i18n key(s) across 25 locales"
```

Or invoke the skill end-to-end: `/internationalization --ticket PLAT-XXXXX --commit`.
