# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

A collection of standalone single-page HTML dashboards for Ansell Healthcare's Marketo marketing analytics. No build process — all code is inline HTML/CSS/JS, served via VS Code Live Server.

**Hub:** `index.html` → links to all dashboards

**Design system:** See [`DESIGN.md`](docs/DESIGN.md) for the full visual language — colors, typography, component patterns, grids, and the page skeleton to use when building new pages.

**Data dictionary:** See [`DATA-DICTIONARY.md`](docs/DATA-DICTIONARY.md) for exact column names, types, and notes for every CSV/xlsx source and the Marketo REST API.

---

## File Map

| File | Purpose |
|------|---------|
| `index.html` | Navigation hub with dashboard cards and FAQ |
| `marketo-analytics-program.html` | Program performance: KPIs, trendline, butterfly (FT/MT attribution), iCapture events, fixed costs |
| `marketo-analytics-lead-generation.html` | Lead gen funnel: pipeline stages (People→MQL→SQL→Converted), transitions, multi-touch programs, omnichannel |
| `marketo-analytics-user-activity.html` | Marketo audit trail viewer |
| `marketo-db-analysis.html` | Database analysis: deliverability, GBU, acquisition channel, growth trends, record types. Has People/Leads/Contacts quick-filter buttons in filter bar. |
| `marketo-db-quality.html` | Data quality scoring: field coverage, blank rates, org/country mismatches, picklist anomalies, live Marketo fix panel |
| `marketo-tools-landing-pages.html` | Landing page inventory + bulk operations |
| `marketo-tools-forms.html` | Forms inventory |
| `marketo-tools-programs.html` | Programs inventory |
| `marketo-tools-smartcampaigns.html` | Smart campaigns inventory |
| `TEST-marketo-analytics.html` | Dev sandbox (do not deploy) |
| `ansell.digital.css` | Shared Ansell brand design system (never edit unless explicitly asked) |
| `mkto-proxy.ps1` | Local CORS proxy on port 3791 for Marketo API calls |

---

## Tech Stack

- **Chart.js** — `https://cdn.jsdelivr.net/npm/chart.js` — all charts
- **SheetJS** — `https://cdn.jsdelivr.net/npm/xlsx/dist/xlsx.full.min.js` — reads `.xlsx` and `.csv`
- **PapaParse** — `https://cdn.jsdelivr.net/npm/papaparse@5.4.1/papaparse.min.js` — CSV parsing (some pages)
- **Google Fonts** — Asap 400/500/600/700
- Vanilla JS, no frameworks, no bundler

---

## Data Sources

Files are loaded via `fetch()` from the `Reports/` folder (served by Live Server). All files are named with a `YYYY-MM-DD` prefix and auto-detected.

### Reports/ (root)
```
YYYY-MM-DD Dashboard_Export.csv
YYYY-MM-DD Audit_Trail_Asset.csv
YYYY-MM-DD iCapture Events.csv
YYYY-MM-DD iCapture Users.csv
YYYY-MM-DD iCapture Membership.xlsx
YYYY-MM-DD iCapture Revenue Created.xlsx
```

### Reports/omnichannel/
```
YYYY-MM-DD Supermetrics - Membership v2.xlsx
YYYY-MM-DD Supermetrics - Qualified v3.xlsx
YYYY-MM-DD Supermetrics - Opp Create v8.xlsx
YYYY-MM-DD Supermetrics - Opps Won v10.xlsx
YYYY-MM-DD umt-builder-cost.xlsx
```

**Date detection pattern:** `detectLatestDateFor(suffix)` scans backwards up to 90 days via sequential HEAD requests, returns the most recent date with a matching file.

**SheetJS read pattern (works for both .xlsx and .csv):**
```js
const buf = await fetch(path).then(r => r.arrayBuffer());
const wb  = XLSX.read(buf, { type: 'array', cellDates: true });
const data = XLSX.utils.sheet_to_json(wb.Sheets[wb.SheetNames[0]], { defval: '', raw: false });
```

---

## Architecture Patterns

### Rendering pipeline
```
loadAllFiles()
  → initFilters()      // populate multi-select dropdowns from data
  → renderAll()        // calls all render functions with filtered data
    → renderKPIs()
    → renderCombo()    // trendline combo chart
    → renderTable()
    → renderIc*()      // iCapture charts
```

### Page load state machine
Each page uses three mutually-exclusive states toggled via JS — never set `display` directly on content divs:
```js
showLoading(msg)  // shows spinner, hides content + filter bar
showEmpty()       // shows empty state, hides content
showDash()        // shows content + filter bar, hides spinner
```
Content divs (`dashContent`, `qualityContent`) start as `display:none` in HTML and are revealed only by `showDash()`.

### Chart lifecycle (always destroy before recreating)
```js
if (charts['chartCombo']) charts['chartCombo'].destroy();
charts['chartCombo'] = new Chart(ctx, config);
```

### Filter state
- Multi-select: `msState` object (Sets), toggled via `onMsChange()`
- Toggle buttons: `.quick-filter-btn` + `.active` class
- Attribution mode: `attributionMode = 'ft' | 'mt'`, set via `setAttrMode(m)`
- Time scale: `timeScale = 'week|month|quarter|year|fy'`, set via `setTimeScale(s)`

### Multi-select dropdowns (`.ms-wrap` pattern)
- Button shows selected count or "All"
- Menu contains checkboxes with `.ms-item` labels + right-aligned count badge
- DOM is the source of truth (no separate state array)

### Bucketing pattern
```js
records.forEach(r => {
    var key = getBucket(r.dateField, timeScale);
    if (!key) return;
    buckets[key] = (buckets[key] || 0) + r.value;
});
```

---

## Key Conventions

### Shared helpers (defined in each file)
| Function | Purpose |
|----------|---------|
| `fmt(n)` | Number with locale commas, returns `—` for null |
| `fmtUSD(n)` | `$1.2M` / `$450K` / `$123` format |
| `parseMoney(v)` | Strip `$`, commas → float |
| `parseNum(v)` | Strip commas → float |
| `parseDate(v)` | String or Excel serial → Date |
| `getBucket(date, scale)` | Date → bucket key string (e.g. `2025-03`) |
| `getCostTotal(c)` | `agencyCosts + otherCosts + thirdPartySpend` |
| `toUSD(amount, currency)` | EUR→USD using `EUR_USD_RATE = 0.917431` |
| `STAGE_PROB` | File-level constant: stage → win probability |

### Naming conventions
- `load*()` — async file loading
- `render*()` — chart/table rendering
- `init*()` — UI initialization
- `on*()` — event handlers
- `set*()` — state setters
- `detect*()` — file/date detection
- `raw*` — unfiltered source arrays (e.g. `rawMembership`)

### CSS class prefixes
- `.kpi-card` — KPI summary cards
- `.chart-card` — chart containers
- `.filter-bar` — sticky filter row
- `.ms-wrap` — multi-select dropdown
- `.quick-filter-btn` — small toggle button
- `.prog-table` — program data table
- `.lp-*` — landing page tool
- `.fb-row` — filter bar row (two-row filter bars)

---

## Sticky Positioning Z-Index Layers
| Element | `top` | `z-index` |
|---------|-------|-----------|
| Header | 0 | 100 |
| Filter bar | 71px | 99 |
| Table headers | (within container) | 1 |
| Bulk action bar | — | 200 |

---

## Fiscal Year
Ansell's fiscal year ends **June 30**. FY end lines on trendline charts are drawn via a `fyEndBuckets` array computed from `new Date(fy, 5, 30)` for all years in the data range.

---

## Currency
All monetary values stored in USD. EUR→USD conversion uses fixed rate `EUR_USD_RATE = 0.917431` via `toUSD(amount, currency)`.

---

## Acquisition Channel Derivation

`deriveChannel(name)` in `marketo-db-analysis.html` and `marketo-analytics-lead-generation.html` derives a channel from the **Acquisition Program Name** field (not a stored Marketo field). Both files must be kept in sync.

**Logic order (first match wins):**

1. **Full-name EXCEPTIONS map** (exact lowercase match) — handles legacy/system program names:
   - `record created in salesforce` → `Sales`
   - `record created in webstore` → `Webstore`
   - `acquired prior to 2016` → `Legacy`
   - `created via list import` / `created via api connection` → `Operational`
   - Specific one-off legacy programs (e.g. Siebel DB Upload → `Operational`)

2. **PICKLIST** (substring `includes()` check, specific before generic):
   - Specific: `Organic-social-WCH/LN/FB/other`, `Paid-social-LN/FB/other`, `Paid-display/search/video/list/msg/mix`
   - Web forms: `Web-form-AI`, `Web-form-ORG`, `Web-form-DIR`, `Web Form` (space variant for old format), `Web-form` (bare, new underscore format without suffix)
   - Generic: `Chatbot`, `DandB`, `Drift`, `Email`, `Events`, `Highspot`, `Online`, `Offline`, `Operational`, `Sales`, `Telemarketing`, `Third-party`, `Webinar`, `Webstore`

3. **Old abbreviation patterns** (space-bounded, pre-2019 naming convention like `REGION.GBU ABBREV YEAR`):
   - ` wf ` → `Web Form`
   - ` eb ` → `Email` (Email Broadcast)
   - ` ed ` → `Email` (Email Digest)
   - ` nl ` → `Email` (Newsletter)
   - ` ts ` → `Telemarketing`
   - ` li ` → `Paid-social-LN` (LinkedIn)
   - ` wb ` → `Webinar`
   - ` oa ` → `Paid-display` (Online Advertising)

4. **Singular Event** — `-event-` or `_event_` in name → `Events`

5. **Fallback** → `Other`

**Note:** Program names use different naming conventions by era:
- Pre-2019: `REGION.GBU ABBREV YEAR Description` (e.g. `NA.IND WF 2018 Contact Us`)
- 2019–2022: `REGION-GBU-Channel-Year-Description` (e.g. `NA-HC-Events-22-Trade Show`)
- Current: `REGION_GBU_Channel_FY_Country_...` (e.g. `NA_MULT_Web-form-ORG_FY25_...`)

---

## Marketo API (CORS Proxy)
- Proxy: `mkto-proxy.ps1` → listens on `http://localhost:3791`
- Run: `powershell -ExecutionPolicy Bypass -File mkto-proxy.ps1`
- Credentials stored in `localStorage` (plain text): `mktoMunchkin`, `mktoClientId`, `mktoClientSecret`, `mktoAdobeOrg`

---

## Marketo Activity Types (Ansell Instance)

Discovered via `GET /rest/v1/activities/types.json`.

### SFDC-related types
| ID | Name | Primary Attr | Key Attributes |
|----|------|-------------|----------------|
| 19 | Sync Lead to SFDC | Assign To (SFDC queue) | Campaign *(no error attrs defined in schema)* |
| 26 | SFDC Activity | Subject | Description, Priority, Status, Due Date, Activity Owner, Is Task |
| 29 | Delete Lead from SFDC | Delete in Marketo | *(none)* |
| 30 | SFDC Activity Updated | Subject | Description, Priority, Status, Due Date, Activity Owner, Is Task |
| 31 | SFDC Merge Leads | Merged | Winning Values |
| 42 | Add to SFDC Campaign | Campaign ID | Status |
| 43 | Remove from SFDC Campaign | Campaign ID | Status |
| 44 | Change Status in SFDC Campaign | Campaign ID | Old Status, New Status |

### Hidden / system type — SFDC sync failures
- **UI label:** "Sync to Person Updates to SFDC"
- **NOT returned** by `/rest/v1/activities/types.json`
- **NOT queryable** via `/rest/v1/activities.json?activityTypeIds=X` (API rejects unknown IDs)
- **Activity attributes** (seen in Marketo UI, activity ID 1002360954, lead 284345, 2026-03-17):
  - `SFDC Error` — error string e.g. `FIELD_INTEGRITY_EXCEPTION: ...`
  - `exceptionMessage` — same error string (duplicate)
  - `Person ID` — Marketo lead ID
- **No persistent SFDC error field** on lead records — Marketo only logs errors as this hidden activity type, never writes them back to a lead field
- **Paths forward if needed:** Marketo support for the hidden type ID, or Bulk Activities Extract API (async CSV export that may expose hidden types)

### Other notable types
| ID | Name | Notes |
|----|------|-------|
| 12 | New Lead | Source Type, SFDC Type, Lead Source |
| 13 | Change Data Value | primary = field name; attrs: New Value, Old Value, Reason |
| 21 | Convert Lead | Assign To, Send Notification Email, Converted Status |
| 32 | Merge Leads | Merge IDs, Master Updated |
| 104 | Change Status in Progression | Program status changes; Success flag |

---

## Marketo Lead Fields (Ansell Instance — SFDC-related)

### Standard SFDC sync fields
| REST API name | Description |
|---------------|-------------|
| `sfdcId` | SFDC record ID (null if not synced or sync failed) |
| `sfdcLeadId` | SFDC Lead record ID |
| `sfdcContactId` | SFDC Contact record ID |
| `sfdcAccountId` | SFDC Account record ID |
| `sfdcLeadOwnerId` | SFDC owner ID |
| `sfdcType` | `"Lead"` or `"Contact"` — which SFDC object type |

### Custom SFDC / sync fields
| REST API name | Description |
|---------------|-------------|
| `RecordTypeId` | SFDC record type ID |
| `Contact_ID__c` | Custom contact ID field |
| `Organisation__c` | Org/GBU (e.g. "Americas Industrial") |

---

## Path-with-Spaces Constraint

The working directory contains spaces (`Team-Marketo - Documents`, `Marketo Documentation`). When running shell commands, always quote paths. On Windows, use `bash` shell syntax with forward slashes.

---

## Git Status Notes

New dashboard files (`marketo-analytics-*.html`, `marketo-tools-*.html`, `marketo-db-*.html`, `index.html`) are **untracked** — they replaced older files with different names. `git diff` will only show deletions of the old files; the new files won't appear in diffs until staged.
