# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

A collection of standalone single-page HTML dashboards for Ansell Healthcare's Marketo marketing analytics. No build process — all code is inline HTML/CSS/JS, served via VS Code Live Server.

**Hub:** `index.html` → links to all dashboards

**Design system:** See [`DESIGN.md`](resources/DESIGN.md) for the full visual language — colors, typography, component patterns, grids, and the page skeleton to use when building new pages.

**Data dictionary:** See [`DATA-DICTIONARY.md`](resources/DATA-DICTIONARY.md) for exact column names, types, and notes for every CSV/xlsx source and the Marketo REST API.

---

## File Map

| File | Purpose |
|------|---------|
| `index.html` | Navigation hub with dashboard cards and FAQ |
| `pages/marketo-analytics-email.html` | Email performance: KPIs, trendline, engagement heatmap, hour-of-day, reputation, content topics, country map |
| `pages/marketo-analytics-program.html` | Program performance: KPIs, trendline, butterfly (FT/MT attribution), iCapture events, fixed costs. Has **dual source mode** (Manual / Cloud Export — see below). |
| `pages/marketo-analytics-lead-generation.html` | Lead gen funnel: pipeline stages (People→MQL→SQL→Converted), transitions, multi-touch programs, omnichannel |
| `pages/marketo-analytics-user-activity.html` | Marketo audit trail viewer |
| `pages/marketo-db-analysis.html` | Database analysis: deliverability, GBU, acquisition channel, growth trends, record types. Has People/Leads/Contacts quick-filter buttons in filter bar. |
| `pages/marketo-db-consent.html` | Consent analysis: opt-in rates, consent status by country/GBU, program-level breakdown |
| `pages/marketo-db-quality.html` | Data quality scoring: field coverage, blank rates, org/country mismatches, picklist anomalies, live Marketo fix panel |
| `pages/marketo-tools-landing-pages.html` | Landing page inventory + bulk operations |
| `pages/marketo-tools-forms.html` | Forms inventory |
| `pages/marketo-tools-programs.html` | Programs inventory |
| `pages/marketo-tools-smartcampaigns.html` | Smart campaigns inventory |
| `TEST-marketo-analytics.html` | Dev sandbox (do not deploy) |
| `ansell.digital.css` | Shared Ansell brand design system (never edit unless explicitly asked) |
| `resources/world.svg` | SVG world map used by country choropleth charts |
| `resources/DESIGN.md` | Full visual design system reference |
| `resources/DATA-DICTIONARY.md` | Column names, types, and notes for all data sources |
| `mkto-proxy.ps1` | Local CORS proxy on port 3791 for Marketo API calls |
| `Preprocess-CloudImport.ps1` | Pre-processing script: reads latest `* Imports.csv` from `Reports/omnichannel v2/` → writes `*_slim.csv` |

---

## Tech Stack

- **Chart.js** — `https://cdn.jsdelivr.net/npm/chart.js` — all charts
- **SheetJS** — `https://cdn.jsdelivr.net/npm/xlsx/dist/xlsx.full.min.js` — reads `.xlsx` and `.csv`
- **PapaParse** — `https://cdn.jsdelivr.net/npm/papaparse@5.4.1/papaparse.min.js` — CSV parsing (some pages)
- **Google Fonts** — Asap 400/500/600/700
- Vanilla JS, no frameworks, no bundler

---

## Pre-processing Pipelines

### Cloud Export pipeline (`marketo-analytics-program.html` — Cloud Export mode)

`Preprocess-CloudImport.ps1` aggregates the large raw Imports CSV into a slim file. Run it each time a new `* Imports.csv` lands in `Reports/omnichannel v2/`:

```powershell
powershell -ExecutionPolicy Bypass -File Preprocess-CloudImport.ps1
```

Output: `YYYY-MM-DD Imports_slim.csv` in the same folder. The script groups by all dimension columns and sums all metric columns. It also filters to the last 4 years.

> **File-lock note:** The script writes to a `.tmp` file first, then `Move-Item` to the final name. This avoids errors when Live Server has the slim CSV open in the browser.

### Database analysis pipeline (`marketo-db-analysis.html`)

There was previously a `Preprocess-DashboardExport.ps1` for this page. If a new equivalent is added in future, it must keep `Get-Channel`, `LEAD_RT_MAP`, `RECORD_TYPE_MAP`, `CHANNEL_EXCEPTIONS`, and `CHANNEL_PICKLIST` **in sync** with the JS equivalents in `marketo-db-analysis.html` and `marketo-analytics-lead-generation.html`.

---

## Data Sources

Files are loaded via `fetch()` from the `Reports/` folder (served by Live Server). All files are named with a `YYYY-MM-DD` prefix and auto-detected.

### Reports/ (root)
```
YYYY-MM-DD Dashboard_Export.csv              ← lead/contact data for most dashboards
YYYY-MM-DD Dashboard_Export_Consent.csv      ← consent analysis (marketo-db-consent.html)
YYYY-MM-DD Dashboard_Emails_Performance.xlsx ← email send metrics (marketo-analytics-email.html)
YYYY-MM-DD Dashboard_Emails_URL.xlsx         ← URL click activity (marketo-analytics-email.html)
YYYY-MM-DD Audit_Trail_Asset.csv
YYYY-MM-DD iCapture Events.csv
YYYY-MM-DD iCapture Users.csv
YYYY-MM-DD iCapture Membership.xlsx
YYYY-MM-DD iCapture Revenue Created.xlsx
```

`Dashboard_Emails_Performance.xlsx` has one row per email × device type × send date. Key columns: `Sent (Date)`, `Sent Hour` (format: `9 AM`), `Program Name`, `Email Name`, `Sent`, `Delivered`, `Opened`, `Unique Clicks`. `Sent Hour` is separate from the date and must be parsed with `parseHour12()`, not `parseDate()`.

`Dashboard_Emails_URL.xlsx` has one row per URL × email × clicked date. Key columns: `Clicked (Date)`, `Clicked Hour`, `Email Name`, `URL`, `Clicked`.

`Dashboard_Export_Consent.csv` uses underscore-separated date prefix (`YYYY_MM_DD_`) in addition to the standard space-separated form. The consent page tries both variants when auto-detecting.

### Reports/omnichannel/ (Manual mode files)
```
YYYY-MM-DD Supermetrics - Membership v2.xlsx
YYYY-MM-DD Supermetrics - Qualified v3.xlsx
YYYY-MM-DD Supermetrics - Opp Create v8.xlsx
YYYY-MM-DD Supermetrics - Opps Won v10.xlsx
YYYY-MM-DD umt-builder-cost.xlsx
```

### Reports/omnichannel v2/ (Cloud Export mode file)
```
YYYY-MM-DD Imports.csv           ← raw cloud export (large — do not load directly)
YYYY-MM-DD Imports_slim.csv      ← preprocessed by Preprocess-CloudImport.ps1
```

**Date detection pattern:** `detectLatestDateFor(suffix)` scans backwards up to 90 days via sequential HEAD requests, returns the most recent date with a matching file.

**SheetJS read pattern (works for both .xlsx and .csv):**
```js
const buf = await fetch(path).then(r => r.arrayBuffer());
const wb  = XLSX.read(buf, { type: 'array', cellDates: true });
const data = XLSX.utils.sheet_to_json(wb.Sheets[wb.SheetNames[0]], { defval: '', raw: false });
```

---

## Dual Data Source Architecture (`marketo-analytics-program.html`)

The program analytics page has two source modes toggled by buttons in the filter bar:

| Button label | Internal key | Source |
|---|---|---|
| **Manual** | `'legacy'` | 4 Supermetrics xlsx files from `Reports/omnichannel/` |
| **Cloud Export (Cloud Ready)** | `'cloud'` | Single `Imports_slim.csv` from `Reports/omnichannel v2/` |

### `DATA_SOURCE_NAME` column semantics (cloud mode only)

The slim CSV contains a `DATA_SOURCE_NAME` column that determines what `CUSTOM_IMPORTS_DATE` represents for each row:

| `DATA_SOURCE_NAME` starts with | Row type | `CUSTOM_IMPORTS_DATE` meaning |
|---|---|---|
| `4.` | Opportunity created | Created date (use for pipeline) |
| `5.` | Opportunity won | Closed/won date (use for revenue) |
| anything else | Membership / qualified | Membership date |

These helpers (defined after the raw data is loaded) handle the column safely even when it's absent from an older slim file:

```js
var _hasDs = Object.keys(raw[0] || {}).includes('DATA_SOURCE_NAME');
function _isV8(r)  { return !_hasDs || str(r.DATA_SOURCE_NAME).startsWith('4.'); }
function _isV10(r) { return !_hasDs || str(r.DATA_SOURCE_NAME).startsWith('5.'); }
function _isOpp(r) { return _hasDs && (str(r.DATA_SOURCE_NAME).startsWith('4.') || str(r.DATA_SOURCE_NAME).startsWith('5.')); }
```

- `rawMembership` is pre-filtered to `!_isOpp(r)` rows
- `rawOppsCreate` is filtered to `_isV8(r)` rows only
- `rawOppsWon` is filtered to `_isV10(r)` rows only

### Channel derivation in cloud mode

`cloudChannel(r)` runs `parseProgramName()` on the program name first (same channel logic as Manual mode), then falls back to raw `PROGRAM_CHANNEL` / `T_CHANNEL_CIMP` fields if the name doesn't parse. This ensures `getAcqGroup()` receives parsed channel format (e.g. `Paid-social-LN`), not raw Marketo picklist values.

### `TOTAL_OPP_COUNT` normalization

The slim CSV stores FT/MT opportunity counts as integers (one per opportunity row). When building `rawOppsCreate`/`rawOppsWon`, divide FT and MT counts by `TOTAL_OPP_COUNT` to restore the 0–1 fractional attribution values.

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

### KPI period fallback pattern

When computing "current period" KPIs, the current bucket may be zero because the period just started. Use a non-zero fallback:

```js
var nonZero = bktKeys.filter(k => (bktByScale[k] || 0) > 0);
var curKey  = (bktByScale[todayBktKey] || 0) > 0
    ? todayBktKey
    : (nonZero.length ? nonZero[nonZero.length - 1] : (bktKeys.length ? bktKeys[bktKeys.length - 1] : null));
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
| `parseDate(v)` | String or Excel serial → Date — see format note below |
| `parseHour12(v)` | `"9 AM"` / `"11 PM"` → 0–23 integer (email analytics only) |
| `getBucket(date, scale)` | Date → bucket key string (e.g. `2025-03`) |
| `getCostTotal(c)` | `agencyCosts + otherCosts + thirdPartySpend` |
| `toUSD(amount, currency)` | EUR→USD using `EUR_USD_RATE = 0.917431` |
| `parseProgramName(name)` | Returns `{ valid, channel, region, gbu, ... }` from program name string |
| `STAGE_PROB` | File-level constant: stage → win probability |

**`parseDate` handles three formats** (in priority order):
1. `YYYY-MM-DD [time]` — ISO, used by older Dashboard_Export.csv exports
2. `DD-MM-YYYY [HH:MM:SS AM|PM]` — legacy 4-digit year format
3. `DD-MM-YY [HH:MM[:SS]]` — **current Marketo export format as of Apr 2026** (2-digit year → 2000+YY, time without seconds)

Marketo changed the CSV date format from ISO to `DD-MM-YY` in April 2026. All three formats must remain supported.

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

## Marketo Subscription Timezone

Ansell's Marketo subscription is set to **Europe/Brussels (CET/CEST — UTC+1 in winter, UTC+2 in summer)**. All timestamps exported from Marketo RCE (including `Sent Hour` and `Clicked Hour` in the email performance files) are in this timezone, regardless of the locale setting (which is English/Australia).

### Timezone offset control (email analytics)

`pages/marketo-analytics-email.html` exposes a `tzOffset` module variable (integer hours, default `0`) that shifts all hour-of-day charts relative to the Brussels base. Fixed offsets from Brussels that remain constant year-round (both regions observe DST together):

| Region | Offset |
|---|---|
| Brussels (base) | 0 |
| London / Lisbon | −1 |
| US Eastern | −6 |
| US Central | −7 |
| US Pacific | −9 |
| UAE / Gulf | +2 |
| Singapore | +6 |
| Tokyo / Seoul | +7 |
| Sydney AEST (winter) | +8 |
| Sydney AEDT (summer) | +10 |

`setTzOffset(n)` updates the value and re-renders only the three affected charts. Hour wrapping: `((h + tzOffset) % 24 + 24) % 24`. The heatmap also adjusts the day-of-week when the offset crosses midnight.

---

## Narrative + KPI Flip Card Pattern

Both `marketo-analytics-email.html` and `marketo-analytics-lead-generation.html` use a section-level narrative layout:

```html
<div class="sec-narrative-row">
    <div class="sec-narrative">
        <div class="sec-narrative-eyebrow">Section Name</div>
        <div class="sec-narrative-title">Headline question</div>
        <p class="sec-narrative-body">Explanatory text…</p>
    </div>
    <div class="sec-narrative-kpis">
        <div class="kpi-flip">
            <div class="kpi-flip-inner">
                <div class="kpi-card teal kpi-front">
                    <div class="kpi-label">Metric Name</div>
                    <div class="kpi-val" id="narSomeId">—</div>
                    <div class="kpi-sub">context label</div>
                </div>
                <div class="kpi-back teal">…back face content…</div>
            </div>
        </div>
    </div>
</div>
```

`.kpi-flip` cards idle-nudge (CSS `kpiNudge` animation) and flip on hover (`kpiFlipIn`/`kpiFlipOut`). The `initFlipCards()` IIFE at the end of `<script>` wires up the animations. KPI values in `.kpi-val` elements are populated by `id` in the relevant render functions after data is computed.

---

## Acquisition Channel Derivation

`deriveChannel(name)` in `pages/marketo-db-analysis.html` and `pages/marketo-analytics-lead-generation.html` derives a channel from the **Acquisition Program Name** field (not a stored Marketo field). In `marketo-analytics-program.html`, the equivalent is `parseProgramName()` (which also returns region, GBU, and validity). All implementations must be kept in sync with each other.

**Logic order (first match wins):**

1. **Full-name EXCEPTIONS map** (exact lowercase match) — handles legacy/system program names:
   - `record created in salesforce` → `Sales`
   - `record created in webstore` → `Webstore`
   - `acquired prior to 2016` → `Legacy`
   - `created via list import` / `created via api connection` → `Operational`
   - `record account created in dandb emea` / `record account created in dandb na` → `DandB`
   - `record created in ansellguardian chemical` → `AnsellGuardian Chemical`
   - `record created in linkedin sales navigator` → `LinkedIn Sales Navigator`
   - `record created in myansell` → `Other`
   - Specific one-off legacy programs (e.g. Siebel DB Upload → `Operational`)

2. **PICKLIST** (substring `includes()` check, specific before generic):
   - Specific: `Organic-social-WCH/LN/FB/other`, `Paid-social-LN/FB/other`, `Paid-display/search/video/list/msg/mix`
   - Web forms: `Web-form-AI`, `Web-form-ORG`, `Web-form-DIR`, `Web Form` (space variant for old format), `Web-form` (bare, new underscore format without suffix)
   - `Referral-INT`
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
- Run as Administrator: `powershell -ExecutionPolicy Bypass -File mkto-proxy.ps1`
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
