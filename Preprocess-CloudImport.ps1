# Preprocess-CloudImport.ps1
# Reads the latest "YYYY-MM-DD Imports.csv" from Reports\omnichannel v2\
# Groups by all dimension columns and sums all metric columns.
# Writes "YYYY-MM-DD Imports_slim.csv" — small enough for browser loading.
#
# Run from the Marketo-Dashboard root:
#   powershell -ExecutionPolicy Bypass -File Preprocess-CloudImport.ps1

$folder = ".\Reports\omnichannel v2"

# ── Dimension columns to GROUP BY ─────────────────────────────────────────────
$DIM_COLS = @(
    'DATA_SOURCE_NAME',
    'PROGRAM_NAME', 'CUSTOM_IMPORTS_DATE',
    'GBU', 'REGION', 'PROGRAM_CHANNEL',
    'T_FISCAL_YEAR_CIMP', 'T_SUB_REGION_CIMP', 'T_LANDING_PAGE_TYPE_CIMP',
    'T_BRAND_SERVICE_CIMP', 'T_CAMPAIGN_OPEN_PRIMARY_FIELD_1_CIMP', 'T_CAMPAIGN_NAME_FIELD_2_CIMP',
    'T_VERTICAL_CIMP', 'T_CIMP_REGION', 'T_CHANNEL_CIMP',
    'OPPORTUNITY_STAGE', 'OPPORTUNITY_TYPE', 'OPPORTUNITY_CLOSED',
    'YEAR_FROM_FILE', 'OWNER'
)

# ── Metric columns to SUM ─────────────────────────────────────────────────────
$METRIC_COLS = @(
    'AMOUNT_USD_CREATED', 'AMOUNT_USD_WON',
    'FT_OPPORTUNITIES_CREATED', 'FT_OPPORTUNITIES_WON',
    'MEMBERS', 'MT_OPPORTUNITIES_CREATED', 'MT_OPPORTUNITIES_WON',
    'NEW_NAMES', 'QUALIFIED_MEMBERS', 'QUALIFIED_NEW_NAMES',
    'SUCCESS_NEW_NAMES', 'SUCCESS_TOTAL',
    'T_CIMP_USD_AGENCY_COSTS', 'T_CIMP_USD_OTHER_COSTS', 'T_CIMP_USD_SPENT_THIRD_PARTY_PUBLISHER'
)

# ── Locate latest input file ──────────────────────────────────────────────────
$inputFile = Get-ChildItem $folder -Filter "* Imports.csv" | Sort-Object Name -Descending | Select-Object -First 1
if (-not $inputFile) {
    Write-Error "No '* Imports.csv' found in '$folder'. Export the cloud table as CSV first."
    exit 1
}

$datePrefix  = $inputFile.Name.Substring(0, 10)
$resolvedOut = (Resolve-Path $folder).Path + '\' + $datePrefix + ' Imports_slim.csv'

Write-Host "Input  : $($inputFile.FullName)"
Write-Host "Output : $resolvedOut"

# ── Read CSV ──────────────────────────────────────────────────────────────────
Write-Host "Reading CSV (may take a moment)..."
$data = Import-Csv $inputFile.FullName

if (-not $data -or $data.Count -eq 0) {
    Write-Error "No data rows found"
    exit 1
}
Write-Host "Read   : $($data.Count) rows"

# ── Filter to last 4 years — convert DD-MM-YY → YYYY-MM-DD before comparing ──
$cutoff = (Get-Date).AddYears(-4).ToString('yyyy-MM-dd')
if ($data[0].PSObject.Properties['CUSTOM_IMPORTS_DATE']) {
    $before = $data.Count
    $data = $data | Where-Object {
        $parts = $_.CUSTOM_IMPORTS_DATE -split '-'
        if ($parts.Count -eq 3 -and $parts[2].Length -le 2) {
            # DD-MM-YY → YYYY-MM-DD for correct string comparison
            "20$($parts[2])-$($parts[1])-$($parts[0])" -ge $cutoff
        } else {
            # ISO or other format — compare directly
            $_.CUSTOM_IMPORTS_DATE -ge $cutoff
        }
    }
    Write-Host "Date filter (>= $cutoff): $($data.Count) rows (removed $($before - $data.Count))"
}

# ── Resolve available columns ─────────────────────────────────────────────────
$availCols     = $data[0].PSObject.Properties.Name
$actualDims    = $DIM_COLS    | Where-Object { $_ -in $availCols }
$actualMetrics = $METRIC_COLS | Where-Object { $_ -in $availCols }
$missingDims   = $DIM_COLS    | Where-Object { $_ -notin $availCols }
$missingMet    = $METRIC_COLS | Where-Object { $_ -notin $availCols }

if ($missingDims) { Write-Warning "Missing dimension columns (omitted): $($missingDims -join ', ')" }
if ($missingMet)  { Write-Warning "Missing metric columns (omitted): $($missingMet -join ', ')" }
Write-Host "Using  : $($actualDims.Count) dimension + $($actualMetrics.Count) metric columns"

# ── Aggregate via hashtable (fast for 300k+ rows) ─────────────────────────────
Write-Host "Aggregating..."
$agg = @{}

foreach ($row in $data) {
    $keyParts = foreach ($col in $actualDims) { $row.$col }
    $key = $keyParts -join '|~|'

    if (-not $agg.ContainsKey($key)) {
        $entry = @{}
        foreach ($col in $actualDims)    { $entry[$col] = $row.$col }
        foreach ($col in $actualMetrics) { $entry[$col] = 0.0 }
        $entry['TOTAL_OPP_COUNT'] = 0.0
        $agg[$key] = $entry
    }

    foreach ($col in $actualMetrics) {
        $raw = ($row.$col -replace '[^0-9.\-]', '').Trim()
        if ($raw -ne '' -and $raw -ne '-') {
            $agg[$key][$col] += [double]$raw
        }
    }
    $agg[$key]['TOTAL_OPP_COUNT'] += 1.0
}

Write-Host "Result : $($agg.Count) aggregated rows (from $($data.Count) source rows)"

# ── Write CSV using Set-Content (CLM-safe, no New-Object needed) ──────────────
Write-Host "Writing slim CSV..."
$allCols = $actualDims + $actualMetrics + @('TOTAL_OPP_COUNT')

# Collect data rows via foreach statement (PS auto-builds array — no += needed)
$csvRows = foreach ($entry in $agg.Values) {
    $parts = foreach ($col in $allCols) {
        $s = "$($entry[$col])"
        if ($s -match '[,"]') { '"' + $s.Replace('"', '""') + '"' } else { $s }
    }
    $parts -join ','
}

# Write to a temp file first, then move (avoids "file in use" errors when browser has it open)
$tempOut = $resolvedOut + '.tmp'
@($allCols -join ',') + $csvRows | Set-Content $tempOut -Encoding UTF8

if (Test-Path $resolvedOut) { Remove-Item $resolvedOut -Force }
Move-Item $tempOut $resolvedOut

Write-Host "Done   : $resolvedOut"
