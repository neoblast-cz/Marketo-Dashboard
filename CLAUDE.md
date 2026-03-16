# Marketo Dashboard — CLAUDE.md

## Project Overview

A collection of standalone single-page HTML dashboards for Ansell Healthcare's Marketo marketing analytics. No build process — all code is inline HTML/CSS/JS, served via VS Code Live Server.

**Hub:** `index.html` → links to all dashboards

---

## File Map

| File | Purpose |
|------|---------|
| `index.html` | Navigation hub with dashboard cards and FAQ |
| `marketo-analytics-program.html` | Program performance: KPIs, trendline, butterfly (FT/MT attribution), iCapture events, fixed costs |
| `marketo-analytics-lead-generation.html` | Lead gen funnel: Supermetrics omnichannel, pipeline stages, transitions, multi-touch programs |
| `marketo-analytics-user-activity.html` | Marketo audit trail viewer |
| `marketo-db-analysis.html` | Database quality, segmentation, record type breakdown |
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

## Marketo API (CORS Proxy)
- Proxy: `mkto-proxy.ps1` → listens on `http://localhost:3791`
- Run: `powershell -ExecutionPolicy Bypass -File mkto-proxy.ps1`
- Credentials stored in `localStorage` (plain text): `mktoMunchkin`, `mktoClientId`, `mktoClientSecret`, `mktoAdobeOrg`

---

## Path-with-Spaces Constraint

The working directory contains spaces (`Team-Marketo - Documents`, `Marketo Documentation`). When running shell commands, always quote paths. On Windows, use `bash` shell syntax with forward slashes.

---

## Git Status Notes

New dashboard files (`marketo-analytics-*.html`, `marketo-tools-*.html`, `index.html`) are **untracked** — they replaced older files with different names. `git diff` will only show deletions of the old files; the new files won't appear in diffs until staged.
