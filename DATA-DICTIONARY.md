# DATA-DICTIONARY.md — Marketo Dashboard Data Sources

Column reference for every file loaded by the dashboards. Use this when building new pages to get correct field names without reading the raw data.

> **Note on column naming:** Marketo export column names often contain spaces and special characters. Always use bracket notation: `r['Column Name']` not `r.columnName`.

---

## Dashboard_Export.csv

**Path:** `Reports/YYYY-MM-DD Dashboard_Export.csv`
**Used by:** `marketo-db-analysis.html`, `marketo-analytics-lead-generation.html`, `marketo-db-quality.html`
**Format:** CSV, one row per Marketo person record
**Typical size:** Up to 260MB (full database export)

| Column Name | Type | Notes |
|-------------|------|-------|
| `Created At` | date string | Record creation date. Parse with `parseDate()`. |
| `Organisation` | string | Ansell org unit (e.g. `Americas Healthcare`). Blank = DQ issue. |
| `1. GBU` | string | Global Business Unit (e.g. `Industrial`, `Healthcare`). Prefixed with `1.` |
| `Deliverability Segment` | string | Opt-in/suppression status. See `DELIV_COLORS` for valid values. |
| `SFDC Type` | string | `Lead`, `Contact`, or blank (Marketo-only person). |
| `Acquisition Program Name` | string | Program that created the record. Used by `deriveChannel()`. |
| `Country` | string | ISO country name. Blank = DQ issue. |
| `Region` | string | `NA`, `EMEA`, `APAC`, etc. |
| `Vertical` | string | Industry vertical (e.g. `Food & Beverage`). Industrial only. |
| `Sub Vertical` | string | Sub-segment of Vertical. |
| `Role Description` | string | Contact role (e.g. `Safety Manager`). |
| `Job Title` | string | Free-text job title. High blank rate expected. |
| `Phone Number` | string | Business phone. Monitored by DQ for blank rate. |
| `Person Status` | string | Lifecycle stage (e.g. `Known`, `MQL`, `Working`, `Converted`). |
| `Record Type ID (A)` | string | SFDC Account record type ID (18-char). Maps via `RECORD_TYPE_MAP`. |
| `Record Type ID` | string | SFDC Lead record type ID (15 or 18-char). Maps via `LEAD_RT_MAP`. |
| `Account ID 18` | string | SFDC Account ID (18-char). Used for account reach counts. |
| `Language 2025 Segment` | string | Language segmentation field (renamed 2025). |
| `1. Current Opt-In Timestamp` | date string | When explicit opt-in was recorded. Prefixed with `1.`. |
| `MQL Date` | date string | Date record reached MQL status. |
| `Working Date` | date string | Date record entered Working status. |
| `Nurture Date` | date string | Date record entered Nurture. |
| `Unqualified Date` | date string | Date record was unqualified. |
| `Converted Date` | date string | Date record was converted to Contact. |
| `Referral Date` | date string | Date referral was recorded. |
| `In Nurture` | string/boolean | Whether record is in a nurture program. |
| `Recycled Reason` | string | Reason for recycling back from sales. |
| `Unqualified Reason` | string | Reason for unqualification. |
| `Queue Name` | string | SFDC queue the record is assigned to. |
| `Referral` | string | Referral source or flag. |
| `Sales Owner Email Address` | string | Email of the assigned sales rep. |
| `Relative Urgency` | string/number | Lead scoring urgency component. |
| `Relative Score` | string/number | Lead scoring score component. |
| `Last Program Name` | string | Most recent program the person was a member of. |
| `Last Qualified Program Name` | string | Most recent program where they achieved Success. |
| `History Last Successful Program` | string | Historical last successful program name. |
| `History Program Membership Qualified` | string/number | Count of qualified memberships in history. |

---

## Supermetrics — Membership v2.xlsx

**Path:** `Reports/omnichannel/YYYY-MM-DD Supermetrics - Membership v2.xlsx`
**Used by:** `marketo-analytics-program.html`
**Format:** xlsx, one row per program-month membership snapshot

| Column Name | Type | Notes |
|-------------|------|-------|
| `Program Name` | string | Marketo program name. Joined to cost/opp files on this key. |
| `Membership Date` | date | Month/period of the membership snapshot. |
| `GBU` | string | Global Business Unit. |
| `Region` | string | Geographic region. |
| `Email Type` | string | Email channel type. |
| `Program Channel` | string | Marketo program channel (e.g. `Email`, `Event`). |
| `Members` | number | Total member count for the period. |
| `New Names` | number | New records acquired this period. |
| `Success (Total)` | number | Total successes (all members). |
| `Success (New Names)` | number | Successes among new names only. |

---

## Supermetrics — Qualified v3.xlsx

**Path:** `Reports/omnichannel/YYYY-MM-DD Supermetrics - Qualified v3.xlsx`
**Used by:** `marketo-analytics-program.html`
**Format:** xlsx, one row per program-month qualified snapshot

| Column Name | Type | Notes |
|-------------|------|-------|
| `Program Name` | string | Marketo program name. |
| `Membership Date` | date | Month/period of snapshot. |
| `Members` | number | Member count. |
| `New Names` | number | New names acquired. |

---

## Supermetrics — Opp Create v8.xlsx

**Path:** `Reports/omnichannel/YYYY-MM-DD Supermetrics - Opp Create v8.xlsx`
**Used by:** `marketo-analytics-program.html`
**Format:** xlsx, one row per program-opportunity attribution

| Column Name | Type | Notes |
|-------------|------|-------|
| `Opportunity ID 18` | string | SFDC opportunity ID (18-char). Used for deduplication. |
| `Program Name` | string | Attributed program. |
| `Amount USD` | number | Opportunity amount in USD. |
| `Opportunity Stage` | string | SFDC stage at time of record. |
| `Opportunity Created Date` | date | When the opp was created. |
| `Opportunity Closed Date` | date | When the opp closed. |
| `Opportunity Closed` | string/boolean | Whether opp is closed. |
| `GBU` | string | Global Business Unit. |
| `Region` | string | Geographic region. |
| `Year` | string/number | Fiscal or calendar year. |
| `Program Channel` | string | Marketo program channel. |
| `Email Type` | string | Email channel type. |
| `(MT) Opportunities Created` | number | Multi-touch attributed opps created. |
| `(MT) Opportunities Won` | number | Multi-touch attributed opps won. |
| `(FT) Opportunities Created` | number | First-touch attributed opps created. |
| `(FT) Opportunities Won` | number | First-touch attributed opps won. |

---

## Supermetrics — Opps Won v10.xlsx

**Path:** `Reports/omnichannel/YYYY-MM-DD Supermetrics - Opps Won v10.xlsx`
**Used by:** `marketo-analytics-program.html`
**Format:** xlsx. Same schema as Opp Create v8 above — same columns, filtered to won opps.

---

## iCapture Events.csv

**Path:** `Reports/YYYY-MM-DD iCapture Events.csv`
**Used by:** `marketo-analytics-program.html`
**Format:** CSV, one row per event

| Column Name | Type | Notes |
|-------------|------|-------|
| `Event Name` | string | Name of the event. |
| `Campaign Name` | string | Associated Marketo campaign. |
| `Start Date` | date | Event start date. |
| `Event Size` | number | Expected or actual attendees. |
| `Budget` | number | Event budget (currency unspecified — check for EUR). |
| `# Leads` | number | Number of leads captured at event. |
| `$ Lead` | number | Cost per lead. |
| `# Team Members` | number | Ansell staff at the event. |

---

## Cost Sheet (umt-builder-cost.xlsx)

**Path:** `Reports/omnichannel/YYYY-MM-DD umt-builder-cost.xlsx`
**Used by:** `marketo-analytics-program.html`
**Format:** xlsx, one row per program cost entry

| Column Name | Type | Notes |
|-------------|------|-------|
| `Generated Campaign Name - Please copy paste it and place it from the other tabs` | string | Long header — this is the join key to Program Name. Exact string required. |
| `Program Name` | string | May be used as fallback join key. |
| `Currency` | string | `USD` or `EUR`. Used with `toUSD()` for conversion. |
| `Agency costs` | number | Agency fees in stated currency. |
| `Other costs` | number | Miscellaneous costs. |
| `Spent_3rd_party_publisher` | number | Third-party spend (underscored, no spaces). |
| `Agency name/ Publisher name` | string | Vendor name. |
| `Owner` | string | Program owner. |
| `Service type` | string | Type of service purchased. |

> **Cost helper:** `getCostTotal(c)` = `agencyCosts + otherCosts + thirdPartySpend`. All amounts converted to USD via `toUSD(amount, currency)` using `EUR_USD_RATE = 0.917431`.

---

## Marketo REST API (Tools pages)

**Used by:** `marketo-tools-programs.html`, `marketo-tools-smartcampaigns.html`, `marketo-tools-landing-pages.html`, `marketo-tools-forms.html`
**Proxy:** `http://localhost:3791` (run `mkto-proxy.ps1`)

### Programs API (`/rest/asset/v1/programs.json`)

| Field | Type | Notes |
|-------|------|-------|
| `id` | number | Marketo program ID. |
| `name` | string | Program name. |
| `type` | string | `Email`, `Event`, `Engagement`, `Default`, etc. |
| `channel` | string | Marketo channel tag. |
| `status` | string | `Active`, `Inactive`, etc. |
| `workspace` | string | Marketo workspace name. |
| `folder` | object | `{ id, type, folderName }` |
| `sfdcId` | string | Linked SFDC campaign ID. |
| `sfdcName` | string | Linked SFDC campaign name. |
| `description` | string | Program description (often blank). |
| `createdAt` | ISO date string | Creation timestamp. |
| `updatedAt` | ISO date string | Last modified timestamp. |

---

## DQ Field Monitoring Reference

`marketo-db-quality.html` scores these fields for blank rates and picklist anomalies. Internal JS key → Dashboard_Export.csv column:

| JS key | CSV column | DQ concern |
|--------|-----------|-----------|
| `org` | `Organisation` | High blank = sync issue |
| `gbu` | `1. GBU` | High blank = acquisition gap |
| `personStatus` | `Person Status` | Non-picklist values = dirty |
| `vertical` | `Vertical` | Industrial only; HC records expected blank |
| `subVertical` | `Sub Vertical` | Subset of Vertical |
| `country` | `Country` | High blank = enrichment gap |
| `leadRecordType` | `Record Type ID` | Non-HC/IND values = DQ issue |
| `roleDescription` | `Role Description` | High blank = form gap |
| `phone` | `Phone Number` | High blank = form gap |
| `jobTitle` | `Job Title` | Free text; monitored for anomalies |
| `acqProgram` | `Acquisition Program Name` | Blank = created outside Marketo |
