# DESIGN.md — Ansell Digital Design System

Visual design reference for all Marketo Dashboard pages. All shared CSS lives in `ansell.digital.css` (never edit unless explicitly asked). Page-specific overrides go in a `<style>` block in the page's `<head>`.

---

## Color Palette

All colors are CSS custom properties on `:root`:

| Variable | Hex | Usage |
|----------|-----|-------|
| `--ansell-blue` | `#0063AC` | Primary: CTAs, active states, borders, chart fills |
| `--ansell-teal` | `#00A28F` | Secondary: success, "opted-in", teal KPI accent |
| `--ansell-dark` | `#2C2A29` | Body text, headings, primary values |
| `--ansell-gray` | `#75787B` | Secondary labels, metadata, muted text |
| `--ansell-light-gray` | `#BBBCBC` | Borders, disabled states, placeholder text |
| `--accent-purple` | `#7030A0` | Accent (KPI purple, tags, hub card) |
| `--danger-red` | `#c62828` | Errors, suppressed, destructive states |
| `--warning-amber` | `#ef6c00` | Warnings, data quality issues, dirty badges |

**Page background:** `#f5f6f7`
**Card/panel background:** `#ffffff`

### Semantic tint pairs (used for badges, chips, icon backgrounds)

| Meaning | Background | Foreground |
|---------|-----------|-----------|
| Blue info | `#e8f1f8` | `--ansell-blue` |
| Teal / success | `#e0f5f2` | `--ansell-teal` / `#007a6a` |
| Green clean | `#e8f5e9` | `#388e3c` |
| Amber warning | `#fff3e0` | `--warning-amber` |
| Red / error | `#fbe9e7` | `--danger-red` |
| Purple | `#f0e8f7` | `--accent-purple` |
| Yellow data quality | `#fff8e1` | `#7a5c00` (border `#ffe082`) |

---

## Typography

**Font stack:** `'Asap', 'Segoe UI', -apple-system, BlinkMacSystemFont, Roboto, sans-serif`
Loaded from Google Fonts at weights 400 / 500 / 600 / 700.

| Role | Size | Weight | Case / Tracking |
|------|------|--------|-----------------|
| Page title (`h1`) | 26px | 700 | uppercase, 0.5px |
| Section label | 12px | 700 | uppercase, 1px |
| Chart / card title | 11px | 700 | uppercase, 0.8px |
| KPI label | 10px | 700 | uppercase, 0.8px |
| KPI value | 30px | 700 | — |
| KPI percentage | 14px | 600 | — |
| KPI sub-text | 11px | 400 | — |
| Filter label | 11px | 600 | uppercase, 0.5px |
| Body / table text | 12–13px | 400 | — |
| Footer | 11px | 400 | — |

**Title pattern:** `Marketo | <span style="color:var(--ansell-blue)">Page Name</span>`
The first segment is dark (`--ansell-dark`), the page name is blue.

---

## Header

```html
<header class="header">
  <div class="header-left">
    <div class="ansell-logo"><!-- Ansell SVG (copy from any page) --></div>
    <div>
      <h1>Marketo | <span>Page Name</span></h1>
      <div class="header-sub">Subtitle text</div>
    </div>
  </div>
  <div class="header-buttons">
    <!-- Load Data button (blue, filled) -->
    <button class="load-btn">...</button>
    <!-- Export button (gray outline, appears after data load) -->
    <button class="export-btn" style="display:none">...</button>
    <!-- Hub back link -->
    <a href="index.html" class="home-btn">Hub</a>
  </div>
</header>
```

- Sticky (`top: 0; z-index: 100`), white bg, `4px solid var(--ansell-blue)` bottom border.
- `.load-btn` — blue filled. `.home-btn` — blue outline, fills on hover. `.export-btn` / `.api-btn` — light gray outline, turns blue on hover.
- Header is NOT sticky on the hub page (`index.html`).

---

## Filter Bar

```html
<div class="filter-bar" id="filterBar" style="display:none">
  <span class="filter-label">Filter:</span>
  <!-- multi-select dropdowns (.ms-wrap) -->
  <!-- quick toggle buttons -->
  <button class="filter-reset" onclick="resetFilters()">Reset All</button>
  <span class="filter-count" id="filterCount"></span>
</div>
```

- Sticky below header (`z-index: 98`), white bg, `1px solid #e8e8e8` bottom border.
- Hidden until data loads — revealed by `showDash()`.
- Two-row variant: use `.fb-row` wrappers inside the bar.

### Multi-select dropdown (`.ms-wrap`)

```html
<div class="ms-wrap" id="ms-f-foo">
  <button class="ms-btn" onclick="toggleMs('f-foo', event)">
    <span id="ms-f-foo-label">Label</span>
    <svg class="ms-chevron" viewBox="0 0 10 6"><path d="M0 0l5 6 5-6z" fill="currentColor"/></svg>
  </button>
  <div class="ms-panel" id="ms-f-foo-panel" onclick="event.stopPropagation()">
    <div class="ms-search-wrap"><input class="ms-search" placeholder="Search…"></div>
    <div class="ms-actions">
      <button onclick="selectAllMs('f-foo')">Select All</button>
      <button onclick="clearMs('f-foo')">Clear</button>
    </div>
    <div class="ms-list" id="ms-f-foo-list"></div>
  </div>
</div>
```

- Button shows selected count or field name when all selected.
- `.ms-btn.active` = blue text/bg when a subset is selected.
- Chevron rotates 180° when open (`.ms-btn.open`).
- Omit `.ms-search-wrap` for small-cardinality fields.

### Quick-filter toggle buttons

```html
<button class="quick-filter-btn" id="btnFoo" onclick="toggleFoo()">Label</button>
```

Active state: add `.active` class → blue filled pill.
Inline record-type toggles (People/Leads/Contacts) use a slightly different style — `border-radius:12px`, inline `padding:3px 10px`, activated via `background: var(--ansell-blue)`.

---

## Page Load States

Three mutually exclusive states — never set `display` directly on content divs:

```js
showLoading(msg)  // spinner + message, hides content + filter bar
showEmpty()       // empty state panel, hides content
showDash()        // reveals content + filter bar
```

### Loading state
```html
<div id="loadingState" style="display:none; padding:80px 30px; text-align:center">
  <div class="loading-spinner"></div>
  <p style="color:var(--ansell-gray); font-size:13px" id="loadingMsg">Loading data...</p>
</div>
```

### Empty state
```html
<div id="emptyState">
  <div class="state-panel">
    <!-- icon SVG (48×48, --ansell-light-gray stroke) -->
    <h2>No data loaded</h2>
    <p>Instructions…</p>
    <button class="state-btn">Load Data</button>
  </div>
</div>
```

### Dashboard content
```html
<div id="dashContent" style="display:none">
  <div class="main"><!-- all sections here --></div>
</div>
```

`.main` — max-width 1200px, centered, `padding: 30px 30px 50px`.

---

## Layout — Sections and Grids

### Section label
```html
<div class="section-label">Section Title</div>
```
12px / 700 / uppercase / 1px tracking / `--ansell-gray`. First child gets `margin-top: 0`.

Optional note suffix: `<span class="section-label-note">note text</span>`

### Grid variants

| Class | Columns | Gap | Use case |
|-------|---------|-----|---------|
| `.kpi-grid` | 4 equal | 16px | KPI cards (collapses to 2 on ≤900px) |
| `.chart-grid-equal` | 2 equal | 16px | Side-by-side charts |
| `.chart-grid-2` | 1fr 2fr | 16px | Narrow + wide |
| `.chart-grid-3` | 3 equal | 16px | Three charts |
| `.dq-summary-grid` | 5 equal | 10px | DQ KPI cards (collapses to 3/2) |
| `.dq-section-grid` | 2 equal | 16px | DQ section pairs |

All collapse to single column at `≤900px`. Always use `margin-bottom: 16px` between grids.

---

## KPI Cards

```html
<div class="kpi-card blue">
  <div class="kpi-label">Metric Name</div>
  <div class="kpi-value" id="kpiVal">—<span class="kpi-pct" id="kpiPct"></span></div>
  <div class="kpi-sub">Supporting text</div>
</div>
```

Top-border accent colors: `.blue` `#0063AC` · `.teal` `#00A28F` · `.green` `#43a047` · `.red` `#c62828` · `.amber` `#ef6c00` · `.purple` `#7030A0`

Default placeholder: `—` (em dash). Use `fmt(n)` helper for formatted numbers.

---

## Chart Cards

```html
<div class="chart-card">
  <span class="blank-badge" id="blankBadge_foo"></span>  <!-- shown when field has blanks -->
  <div class="chart-title">Chart Title</div>
  <div class="chart-wrap" style="height:250px">
    <canvas id="chartFoo"></canvas>
  </div>
</div>
```

- White bg, `0 1px 4px rgba(0,0,0,0.07)` shadow, `22px 24px` padding. No border radius.
- `.blank-badge` — amber pill (top-right, absolute), shown by JS when a field has blank values.
- `.chart-wrap` — `position:relative`. Set explicit height for fixed-size charts; omit for auto (bar charts).
- **Always destroy before recreating:** `if (charts['id']) charts['id'].destroy();`

### Chart color palettes (JS constants)

```js
// Organisation
const ORG_COLORS = {
  'Americas Healthcare': '#0063AC', 'Americas Industrial': '#1976d2',
  'EMEA Healthcare': '#00A28F',     'EMEA Industrial': '#26a69a',
  'APAC Healthcare': '#7030A0', ...
};

// Deliverability
const DELIV_COLORS = {
  'Opted-In Explicit': '#00A28F', 'Opted-In Implicit (No Response)': '#0063AC',
  'Unsubscribed': '#e53935', 'Email Invalid': '#ef6c00',
  'Suspended Email': '#f59e0b', '(blank)': '#cfd8dc', ...
};

// Lead Record Type
const LEAD_RT_COLORS = {
  Healthcare: '#0063AC', Industrial: '#00A28F',
  Prospect: '#f59e0b', Other: '#e74c3c', '(blank)': '#cfd8dc'
};
```

General palette for unlabeled series: start with `--ansell-blue`, then `--ansell-teal`, `--accent-purple`, amber, green, then lighter/darker shades.

### Standard Chart.js defaults

```js
plugins: { legend: { display: false } }  // legends usually custom-rendered
```

Horizontal bar charts preferred for ranked lists. Doughnut for composition (donut hole ~60%). Combo (bar + line) for trendlines.

---

## Tabs

Used when a page has multiple views (e.g. DB Quality):

```html
<nav class="tab-nav">
  <button class="tab-btn active" onclick="switchTab('foo')">
    <svg><!-- icon --></svg> Tab Label
  </button>
  <button class="tab-btn" onclick="switchTab('bar')">Bar</button>
</nav>
```

- Sticky below filter bar (`z-index: 99`). White bg, `1px solid #e8e8e8` bottom border.
- Active: `color: --ansell-blue`, `border-bottom: 3px solid --ansell-blue`.

---

## Data Tables (`.prog-table` / tools pages)

Tables on tools pages use inline styles or page-specific CSS; no shared class. Conventions to follow:

- `<thead>` with `position:sticky; top:<filter+tab offset>; z-index:1`
- Header cells: `font-size:11px; font-weight:700; text-transform:uppercase; letter-spacing:0.5px; color:--ansell-gray`; `2px solid #e8e8e8` bottom border; `background:#fafafa`
- Body rows: `font-size:12px; border-bottom:1px solid #f5f6f7`; hover `background:#fafafa`
- Numeric columns: `text-align:right; font-variant-numeric:tabular-nums`
- Status badges: pill chips with tint pairs from the semantic color table above

---

## Badges and Chips

| Pattern | HTML | Style |
|---------|------|-------|
| Export date | `.export-badge` | Blue tint, teal dot indicator |
| Drill filter active | `.drill-chip` | Blue filled pill, animated in |
| Blank field warning | `.blank-badge` | Amber tint pill, absolute top-right of card |
| Data quality dirty | `.wc-badge.dirty` | Amber tint |
| Data quality ok | `.wc-badge.ok` | Green tint |
| DQ fix chip (bad value) | `.dq-fix-chip` | Red tint pill |
| Picklist value clean | `.wc-tag.clean` | Blue tint |
| Picklist value dirty | `.wc-tag.dirty` | Amber tint + border |
| Picklist value rare | `.wc-tag.rare` | Red tint + border |
| Picklist value blank | `.wc-tag.blank` | Gray tint + dashed border |

---

## Sticky Z-Index Layers

| Element | `top` | `z-index` |
|---------|-------|-----------|
| Header | 0 | 100 |
| Tab nav | 71px | 99 |
| Filter bar | 71px (or 71+tab height) | 98 |
| Table `<thead>` | within scroll container | 1 |
| Bulk action bar | — | 200 |
| Floating panels / modals | — | 500–9999 |

---

## Hub Cards (`index.html`)

```html
<a href="page.html" class="dash-card blue">
  <div class="dash-card-icon"><svg><!-- 22×22 icon --></svg></div>
  <h2>Card Title</h2>
  <p>Short description.</p>
  <div class="data-file">Source: filename.csv</div>
</a>
```

Colors: `.blue` · `.teal` · `.purple` · `.orange` (#D97706) · `.green` (#2e7d32)
Disabled: add `.disabled` (opacity 0.55, no pointer events).
Hover: subtle lift (`translateY(-2px)`) + deeper shadow.

---

## FAQ / Knowledge Base Cards

```html
<div class="faq-card" onclick="toggleFaq(this)">
  <div class="faq-q">
    <span class="faq-icon">?</span>
    Question text
  </div>
  <div class="faq-a">Answer text…</div>
  <span class="faq-tag data">data</span>
</div>
```

Tag types: `.data` (blue) · `.method` (teal) · `.howto` (purple)
Expanded via `.expanded` class (max-height transition).

---

## Word Cloud Cards (`.wc-card`)

Used in DB Quality for picklist anomaly display. Tags are sized by frequency.

```html
<div class="wc-card">
  <div class="wc-header">
    <div class="wc-title">Field Name</div>
    <div class="wc-badges">
      <span class="wc-badge dirty">12 dirty</span>
      <span class="wc-badge ok">clean</span>
    </div>
  </div>
  <div class="wc-desc">Description</div>
  <div class="wc-cloud">
    <span class="wc-tag clean" style="font-size:14px">
      <span class="wc-word">Value</span>
      <span class="wc-count">1,234</span>
    </span>
  </div>
</div>
```

---

## Footer

```html
<div class="footer" id="footerEl" style="display:none">Ansell Healthcare · Page Name</div>
```

Revealed by `showDash()`. Centered, `11px`, `--ansell-light-gray`.

---

## Page Template Skeleton

```html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Page Name | Marketo Dashboard</title>
  <link rel="stylesheet" href="ansell.digital.css">
  <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
  <!-- add SheetJS/PapaParse if needed -->
  <style>/* page-specific overrides only */</style>
</head>
<body>

  <header class="header"><!-- see Header section --></header>
  <div class="filter-bar" id="filterBar" style="display:none"><!-- filters --></div>

  <input type="file" id="fileInput" accept=".csv,.xlsx" onchange="handleFileInput(event)">

  <div id="loadingState" style="display:none; padding:80px 30px; text-align:center">
    <div class="loading-spinner"></div>
    <p style="color:var(--ansell-gray); font-size:13px" id="loadingMsg">Loading…</p>
  </div>

  <div id="emptyState">
    <div class="state-panel"><!-- icon, h2, p, state-btn --></div>
  </div>

  <div id="dashContent" style="display:none">
    <div class="main">
      <div class="section-label">Section</div>
      <div class="kpi-grid"><!-- kpi-cards --></div>
      <div class="chart-grid-equal"><!-- chart-cards --></div>
    </div>
  </div>

  <div class="footer" id="footerEl" style="display:none">Ansell Healthcare · Page Name</div>

  <script>
  // State machine
  function showLoading(msg) { /* ... */ }
  function showEmpty()      { /* ... */ }
  function showDash()       { /* ... */ }
  </script>
</body>
</html>
```
