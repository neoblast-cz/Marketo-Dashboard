<#
.SYNOPSIS
    Pre-processes Dashboard_Export.csv into two fast-loading files.

.DESCRIPTION
    Reads the latest YYYY-MM-DD Dashboard_Export.csv from Reports/ and writes:

      _agg.json  (~50 KB)  Pre-computed unfiltered aggregates for all chart
                           dimensions. Dashboard renders instantly from this.

      _slim.csv  (~30-50 MB)  Only the columns the dashboard actually uses,
                           with field names already mapped to JS allData keys
                           and channel/record-type lookups pre-applied.
                           Loaded on demand when filters are applied.

    Run this script each time a new Dashboard_Export.csv is placed in Reports/.

.PARAMETER ReportsPath
    Path to the Reports/ folder. Defaults to .\Reports (relative to this script).

.EXAMPLE
    .\Preprocess-DashboardExport.ps1
    .\Preprocess-DashboardExport.ps1 -ReportsPath "C:\full\path\to\Reports"
#>

param(
    [string]$ReportsPath = (Join-Path $PSScriptRoot "Reports")
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ── FIND LATEST EXPORT ──────────────────────────────────────────────────────

Write-Host "Scanning $ReportsPath for latest Dashboard_Export.csv..." -ForegroundColor Cyan

$csvFile = Get-ChildItem -Path $ReportsPath -Filter "*Dashboard_Export.csv" |
           Where-Object { $_.Name -notmatch '_slim|_agg' } |
           Sort-Object Name -Descending |
           Select-Object -First 1

if (-not $csvFile) {
    Write-Error "No Dashboard_Export.csv found in $ReportsPath"
    exit 1
}

$datePrefix = $csvFile.Name.Substring(0, 10)
$slimPath   = Join-Path $ReportsPath "$datePrefix Dashboard_Export_slim.csv"
$aggPath    = Join-Path $ReportsPath "$datePrefix Dashboard_Export_agg.json"
$inputMB    = [math]::Round($csvFile.Length / 1MB, 1)

Write-Host ""
Write-Host "  Input:    $($csvFile.Name) ($inputMB MB)"
Write-Host "  Slim CSV: $datePrefix Dashboard_Export_slim.csv"
Write-Host "  Agg JSON: $datePrefix Dashboard_Export_agg.json"
Write-Host ""

# ── LOOKUP TABLES (mirrors JS constants in marketo-db-analysis.html) ────────

$LEAD_RT_MAP = @{
    '0120o000000w1X3'    = 'Healthcare'
    '0120o000000w1X3AAI' = 'Healthcare'
    '0120o000000w1X4'    = 'Industrial'
    '0120o000000w1X4AAI' = 'Industrial'
    '012GB0000018QzF'    = 'Prospect'
    '012GB0000018QzFYAU' = 'Prospect'
}

$RECORD_TYPE_MAP = @{
    '0120o0000017h2RAAQ' = 'Webstore'
    '01290000000AEOiAAO' = 'Distributors'
    '01290000000AEOjAAO' = 'End-Users'
}

# Mirrors deriveChannel() — keep in sync if JS logic changes
$CHANNEL_EXCEPTIONS = @{
    'record account created in dandb emea'                                              = 'DandB'
    'record account created in dandb na'                                                = 'DandB'
    'record created in ansellguardian chemical'                                         = 'AnsellGuardian Chemical'
    'record created in linkedin sales navigator'                                         = 'LinkedIn Sales Navigator'
    'record created in myansell'                                                        = 'Other'
    'record created in salesforce'                                                      = 'Sales'
    'record created in webstore'                                                        = 'Webstore'
    'acquired prior to 2016'                                                            = 'Legacy'
    'created via list import'                                                           = 'Operational'
    'created via api connection'                                                        = 'Operational'
    'na.ind li 2016-09-16 initial siebel db upload - deleted (1716)'                   = 'Operational'
}

# Ordered specific → generic (first match wins, matches JS PICKLIST order)
$CHANNEL_PICKLIST = @(
    'Organic-social-WCH','Organic-social-LN','Organic-social-FB','Organic-social-other',
    'Paid-social-LN','Paid-social-FB','Paid-social-other',
    'Paid-display','Paid-search','Paid-video','Paid-list','Paid-msg','Paid-mix',
    'Web-form-AI','Web-form-ORG','Web-form-DIR','Web Form','Web-form',
    'Referral-INT',
    'Chatbot','DandB','Drift','Email','Events','Highspot','Online',
    'Offline','Operational','Sales','Telemarketing','Third-party','Webinar','Webstore'
)
# Pre-lowercase for fast comparison
$CHANNEL_PICKLIST_LOWER = $CHANNEL_PICKLIST | ForEach-Object { $_.ToLower() }

function Get-Channel([string]$name) {
    if ([string]::IsNullOrWhiteSpace($name)) { return '' }
    $n  = $name.Trim()
    $nl = $n.ToLower()

    if ($CHANNEL_EXCEPTIONS.ContainsKey($nl)) { return $CHANNEL_EXCEPTIONS[$nl] }

    for ($i = 0; $i -lt $CHANNEL_PICKLIST.Count; $i++) {
        if ($nl.Contains($CHANNEL_PICKLIST_LOWER[$i])) { return $CHANNEL_PICKLIST[$i] }
    }

    if ($nl.Contains(' wf '))  { return 'Web Form' }
    if ($nl.Contains(' eb '))  { return 'Email' }
    if ($nl.Contains(' ed '))  { return 'Email' }
    if ($nl.Contains(' nl '))  { return 'Email' }
    if ($nl.Contains(' ts '))  { return 'Telemarketing' }
    if ($nl.Contains(' li '))  { return 'Paid-social-LN' }
    if ($nl.Contains(' wb '))  { return 'Webinar' }
    if ($nl.Contains(' oa '))  { return 'Paid-display' }
    if ($nl.Contains('-event-') -or $nl.Contains('_event_')) { return 'Events' }

    return 'Other'
}

function Get-Year([string]$v) {
    if ([string]::IsNullOrWhiteSpace($v)) { return '' }
    try {
        $v = $v.Trim()
        # ISO: YYYY-MM-DD...
        if ($v -match '^\d{4}-\d{2}-\d{2}') { return $v.Substring(0, 4) }
        # DD-MM-YYYY HH:MM:SS AM/PM
        if ($v -match '^(\d{2})-(\d{2})-(\d{4})') { return $Matches[3] }
    } catch {}
    return ''
}

function Get-Month([string]$v) {
    if ([string]::IsNullOrWhiteSpace($v)) { return '' }
    try {
        $v = $v.Trim()
        if ($v -match '^\d{4}-(\d{2})-\d{2}') { return [int]$Matches[1] }
        if ($v -match '^(\d{2})-(\d{2})-(\d{4})')  { return [int]$Matches[2] }
    } catch {}
    return ''
}

function Csv-Escape([string]$v) {
    if ($v -match '[,"\r\n]') { return '"' + $v.Replace('"', '""') + '"' }
    return $v
}

function Inc([hashtable]$ht, [string]$key) {
    $k = if ([string]::IsNullOrWhiteSpace($key)) { '(blank)' } else { $key }
    if ($ht.ContainsKey($k)) { $ht[$k]++ } else { $ht[$k] = 1 }
}

# ── CASING NORMALIZATION PASS 1: count occurrences ──────────────────────────
# We do two passes: first to build canonical casing map, then to write output.
# Fields normalised (matching JS NORMALIZE_FIELDS):
$NORM_COLS = @('org','gbu','country','sfdcType','deliverability','language',
               'vertical','subVertical','acqProgram','channel','personStatus',
               'region','roleDescription')

$casingCounts = @{}
foreach ($f in $NORM_COLS) { $casingCounts[$f] = @{} }

# ── PASS 1: build casing maps + aggregates ───────────────────────────────────

Write-Host "Pass 1 of 2 — building casing maps and aggregates..." -ForegroundColor Yellow

$agg = @{
    byOrg             = @{}
    byGbu             = @{}
    byDeliverability  = @{}
    byChannel         = @{}
    byRegion          = @{}
    byCountry         = @{}
    byCreatedYear     = @{}
    byOptInYear       = @{}
    bySfdcType        = @{}
    byPersonStatus    = @{}
    byRoleDescription = @{}
    byVertical        = @{}
    byLanguage        = @{}
    byRecordTypeA     = @{}
    byLeadRecordType  = @{}
}

$totalRows = 0
$sw = [System.Diagnostics.Stopwatch]::StartNew()

# Helper: accumulate casing count
function CountCasing([hashtable]$map, [string]$v) {
    if ([string]::IsNullOrWhiteSpace($v)) { return }
    $k = $v.ToLower()
    if (-not $map.ContainsKey($k)) { $map[$k] = @{} }
    $cv = $map[$k]
    if ($cv.ContainsKey($v)) { $cv[$v]++ } else { $cv[$v] = 1 }
}

Import-Csv $csvFile.FullName | ForEach-Object {
    $r = $_
    $totalRows++
    if ($totalRows % 20000 -eq 0) {
        Write-Host "`r  Pass 1: $("{0:N0}" -f $totalRows) rows ($([math]::Round($sw.Elapsed.TotalSeconds))s)  " -NoNewline
    }

    $org    = ($r.'Organisation'            | Select-Object -First 1).ToString().Trim()
    $gbu    = ($r.'1. GBU'                  | Select-Object -First 1).ToString().Trim()
    $deliv  = ($r.'Deliverability Segment'  | Select-Object -First 1).ToString().Trim()
    $lang   = ($r.'Language 2025 Segment'   | Select-Object -First 1).ToString().Trim()
    $vert   = ($r.'Vertical'                | Select-Object -First 1).ToString().Trim()
    $subV   = ($r.'Sub Vertical'            | Select-Object -First 1).ToString().Trim()
    $sfdc   = ($r.'SFDC Type'               | Select-Object -First 1).ToString().Trim()
    $acq    = ($r.'Acquisition Program Name'| Select-Object -First 1).ToString().Trim()
    $ctry   = ($r.'Country'                 | Select-Object -First 1).ToString().Trim()
    $reg    = ($r.'Region'                  | Select-Object -First 1).ToString().Trim()
    $pst    = ($r.'Person Status'           | Select-Object -First 1).ToString().Trim()
    $rdesc  = ($r.'Role Description'        | Select-Object -First 1).ToString().Trim()
    $ch     = Get-Channel $acq
    $rtA    = if ($RECORD_TYPE_MAP.ContainsKey($r.'Record Type ID (A)')) { $RECORD_TYPE_MAP[$r.'Record Type ID (A)'] } elseif ($r.'Record Type ID (A)') { 'Other' } else { '' }
    $lrt_raw = ($r.'Record Type ID' | Select-Object -First 1).ToString().Trim()
    $lrt    = if ($LEAD_RT_MAP.ContainsKey($lrt_raw)) { $LEAD_RT_MAP[$lrt_raw] } else { $lrt_raw }

    $cyear  = Get-Year  $r.'Created At'
    $oiyear = Get-Year  $r.'1. Current Opt-In Timestamp'

    # Casing accumulation
    CountCasing $casingCounts.org           $org
    CountCasing $casingCounts.gbu           $gbu
    CountCasing $casingCounts.deliverability $deliv
    CountCasing $casingCounts.language      $lang
    CountCasing $casingCounts.vertical      $vert
    CountCasing $casingCounts.subVertical   $subV
    CountCasing $casingCounts.sfdcType      $sfdc
    CountCasing $casingCounts.acqProgram    $acq
    CountCasing $casingCounts.country       $ctry
    CountCasing $casingCounts.region        $reg
    CountCasing $casingCounts.personStatus  $pst
    CountCasing $casingCounts.roleDescription $rdesc
    CountCasing $casingCounts.channel       $ch

    # Aggregates (pre-normalization — will be re-keyed in Pass 2, close enough)
    Inc $agg.byOrg              $org
    Inc $agg.byGbu              $gbu
    Inc $agg.byDeliverability   $deliv
    Inc $agg.byChannel          $ch
    Inc $agg.byRegion           $reg
    Inc $agg.byCountry          $ctry
    Inc $agg.byCreatedYear      $cyear
    Inc $agg.byOptInYear        $oiyear
    Inc $agg.bySfdcType         $sfdc
    Inc $agg.byPersonStatus     $pst
    Inc $agg.byRoleDescription  $rdesc
    Inc $agg.byVertical         $vert
    Inc $agg.byLanguage         $lang
    Inc $agg.byRecordTypeA      $rtA
    Inc $agg.byLeadRecordType   $lrt
}

Write-Host "`r  Pass 1 complete: $("{0:N0}" -f $totalRows) rows in $([math]::Round($sw.Elapsed.TotalSeconds))s   " -ForegroundColor Green

# Build canonical casing map: lowercase → winning casing (most common)
$canonical = @{}
foreach ($field in $NORM_COLS) {
    $canonical[$field] = @{}
    foreach ($lk in $casingCounts[$field].Keys) {
        $winner = ($casingCounts[$field][$lk].GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 1).Key
        $canonical[$field][$lk] = $winner
    }
}

# ── PASS 2: write slim CSV ───────────────────────────────────────────────────

Write-Host "Pass 2 of 2 — writing slim CSV..." -ForegroundColor Yellow

$slimHeader = 'createdYear,createdMonth,optInYear,optInMonth,org,gbu,deliverability,' +
              'language,vertical,subVertical,sfdcType,channel,recordType,leadRecordType,' +
              'country,region,personStatus,roleDescription,accountId18,' +
              'mqlDate,workingDate,nurtureDate,unqualifiedDate,convertedDate,' +
              'inNurture,recycledReason,unqualifiedReason,assignedQueue,relUrgency,relScore'

$writer   = [System.IO.StreamWriter]::new($slimPath, $false, [System.Text.Encoding]::UTF8)
$writer.WriteLine($slimHeader)

function Norm([hashtable]$map, [string]$field, [string]$v) {
    if ([string]::IsNullOrWhiteSpace($v)) { return '' }
    $lk = $v.ToLower()
    if ($map[$field].ContainsKey($lk)) { return $map[$field][$lk] }
    return $v
}

$written = 0
$sw2 = [System.Diagnostics.Stopwatch]::StartNew()

Import-Csv $csvFile.FullName | ForEach-Object {
    $r = $_
    $written++
    if ($written % 20000 -eq 0) {
        Write-Host "`r  Pass 2: $("{0:N0}" -f $written) rows ($([math]::Round($sw2.Elapsed.TotalSeconds))s)  " -NoNewline
    }

    $acq    = ($r.'Acquisition Program Name' | Select-Object -First 1).ToString().Trim()
    $lrt_raw = ($r.'Record Type ID' | Select-Object -First 1).ToString().Trim()

    $org    = Norm $canonical 'org'             (($r.'Organisation'             ).Trim())
    $gbu    = Norm $canonical 'gbu'             (($r.'1. GBU'                   ).Trim())
    $deliv  = Norm $canonical 'deliverability'  (($r.'Deliverability Segment'   ).Trim())
    $lang   = Norm $canonical 'language'        (($r.'Language 2025 Segment'    ).Trim())
    $vert   = Norm $canonical 'vertical'        (($r.'Vertical'                 ).Trim())
    $subV   = Norm $canonical 'subVertical'     (($r.'Sub Vertical'             ).Trim())
    $sfdc   = Norm $canonical 'sfdcType'        (($r.'SFDC Type'                ).Trim())
    $ctry   = Norm $canonical 'country'         (($r.'Country'                  ).Trim())
    $reg    = Norm $canonical 'region'          (($r.'Region'                   ).Trim())
    $pst    = Norm $canonical 'personStatus'    (($r.'Person Status'            ).Trim())
    $rdesc  = Norm $canonical 'roleDescription' (($r.'Role Description'         ).Trim())
    $ch     = Norm $canonical 'channel'         (Get-Channel $acq)
    $rtA    = if ($RECORD_TYPE_MAP.ContainsKey($r.'Record Type ID (A)')) { $RECORD_TYPE_MAP[$r.'Record Type ID (A)'] } elseif ($r.'Record Type ID (A)') { 'Other' } else { '' }
    $lrt    = if ($LEAD_RT_MAP.ContainsKey($lrt_raw)) { $LEAD_RT_MAP[$lrt_raw] } else { $lrt_raw }

    $createdAt = ($r.'Created At'                   ).Trim()
    $optInAt   = ($r.'1. Current Opt-In Timestamp'  ).Trim()

    $line = "$( Get-Year  $createdAt)," +
            "$( Get-Month $createdAt)," +
            "$( Get-Year  $optInAt)," +
            "$( Get-Month $optInAt)," +
            "$(Csv-Escape $org)," +
            "$(Csv-Escape $gbu)," +
            "$(Csv-Escape $deliv)," +
            "$(Csv-Escape $lang)," +
            "$(Csv-Escape $vert)," +
            "$(Csv-Escape $subV)," +
            "$(Csv-Escape $sfdc)," +
            "$(Csv-Escape $ch)," +
            "$(Csv-Escape $rtA)," +
            "$(Csv-Escape $lrt)," +
            "$(Csv-Escape $ctry)," +
            "$(Csv-Escape $reg)," +
            "$(Csv-Escape $pst)," +
            "$(Csv-Escape $rdesc)," +
            "$(Csv-Escape ($r.'Account ID 18'.Trim()))," +
            "$(Csv-Escape ($r.'MQL Date'.Trim()))," +
            "$(Csv-Escape ($r.'Working Date'.Trim()))," +
            "$(Csv-Escape ($r.'Nurture Date'.Trim()))," +
            "$(Csv-Escape ($r.'Unqualified Date'.Trim()))," +
            "$(Csv-Escape ($r.'Converted Date'.Trim()))," +
            "$(Csv-Escape ($r.'In Nurture'.Trim()))," +
            "$(Csv-Escape ($r.'Recycled Reason'.Trim()))," +
            "$(Csv-Escape ($r.'Unqualified Reason'.Trim()))," +
            "$(Csv-Escape ($r.'Queue Name'.Trim()))," +
            "$(Csv-Escape ($r.'Relative Urgency'.Trim()))," +
            "$(Csv-Escape ($r.'Relative Score'.Trim()))"

    $writer.WriteLine($line)
}

$writer.Close()
$writer.Dispose()

Write-Host "`r  Pass 2 complete: $("{0:N0}" -f $written) rows in $([math]::Round($sw2.Elapsed.TotalSeconds))s   " -ForegroundColor Green

# ── WRITE AGGREGATES JSON ────────────────────────────────────────────────────

Write-Host "Writing aggregates JSON..." -ForegroundColor Yellow

$output = [ordered]@{
    meta = [ordered]@{
        exportDate   = $datePrefix
        totalRecords = $totalRows
        generatedAt  = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ss')
        sourceFile   = $csvFile.Name
    }
    aggregates = [ordered]@{
        byOrg             = $agg.byOrg
        byGbu             = $agg.byGbu
        byDeliverability  = $agg.byDeliverability
        byChannel         = $agg.byChannel
        bySfdcType        = $agg.bySfdcType
        byRegion          = $agg.byRegion
        byCountry         = $agg.byCountry
        byCreatedYear     = $agg.byCreatedYear
        byOptInYear       = $agg.byOptInYear
        byPersonStatus    = $agg.byPersonStatus
        byRoleDescription = $agg.byRoleDescription
        byVertical        = $agg.byVertical
        byLanguage        = $agg.byLanguage
        byRecordTypeA     = $agg.byRecordTypeA
        byLeadRecordType  = $agg.byLeadRecordType
    }
}

$output | ConvertTo-Json -Depth 4 -Compress | Set-Content $aggPath -Encoding UTF8

# ── SUMMARY ──────────────────────────────────────────────────────────────────

$slimMB = [math]::Round((Get-Item $slimPath).Length / 1MB, 1)
$aggKB  = [math]::Round((Get-Item $aggPath ).Length / 1KB, 1)
$total  = [math]::Round($sw.Elapsed.TotalSeconds + $sw2.Elapsed.TotalSeconds)

Write-Host ""
Write-Host "Done in $total seconds." -ForegroundColor Green
Write-Host "  $($csvFile.Name)  →  $inputMB MB (original)"  -ForegroundColor White
Write-Host "  _slim.csv          →  $slimMB MB ($([math]::Round((1 - $slimMB / $inputMB) * 100))% reduction)" -ForegroundColor Cyan
Write-Host "  _agg.json          →  $aggKB KB (instant load)"                                                  -ForegroundColor Cyan
Write-Host ""
Write-Host "Next step: update marketo-db-analysis.html to load _agg.json first," -ForegroundColor Gray
Write-Host "then _slim.csv in the background for filter support." -ForegroundColor Gray
