<#
.SYNOPSIS
    Local HTTP server for the Marketo Dashboard.
    Run via "Open Dashboard.bat" — do not run this file directly.
#>

$PORT = 3000
$ROOT = $PSScriptRoot

# ── CHECK IF PORT IS ALREADY IN USE ─────────────────────────────────────────
$inUse = Get-NetTCPConnection -LocalPort $PORT -State Listen -ErrorAction SilentlyContinue
if ($inUse) {
    Write-Host ""
    Write-Host "  Port $PORT is already in use." -ForegroundColor Yellow
    Write-Host "  The dashboard may already be running — check your browser at:"
    Write-Host "  http://localhost:$PORT" -ForegroundColor Cyan
    Write-Host ""
    Start-Process "http://localhost:$PORT"
    Read-Host "  Press Enter to exit"
    exit 0
}

# ── MIME TYPES ───────────────────────────────────────────────────────────────
$MIME = @{
    '.html' = 'text/html; charset=utf-8'
    '.css'  = 'text/css; charset=utf-8'
    '.js'   = 'application/javascript; charset=utf-8'
    '.json' = 'application/json; charset=utf-8'
    '.csv'  = 'text/csv; charset=utf-8'
    '.xlsx' = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
    '.png'  = 'image/png'
    '.jpg'  = 'image/jpeg'
    '.svg'  = 'image/svg+xml'
    '.ico'  = 'image/x-icon'
    '.woff2'= 'font/woff2'
    '.woff' = 'font/woff'
}

# ── START LISTENER ───────────────────────────────────────────────────────────
$listener = [System.Net.HttpListener]::new()
$listener.Prefixes.Add("http://localhost:$PORT/")

try {
    $listener.Start()
} catch {
    Write-Host ""
    Write-Host "  ERROR: Could not start the server." -ForegroundColor Red
    Write-Host "  $_" -ForegroundColor Red
    Write-Host ""
    Read-Host "  Press Enter to exit"
    exit 1
}

# ── OPEN BROWSER ─────────────────────────────────────────────────────────────
Start-Process "http://localhost:$PORT"

Write-Host ""
Write-Host "  ================================================" -ForegroundColor Cyan
Write-Host "   Marketo Dashboard is running!" -ForegroundColor Green
Write-Host "   http://localhost:$PORT" -ForegroundColor Cyan
Write-Host "  ================================================"
Write-Host ""
Write-Host "  Close this window to stop the server."
Write-Host ""

# ── REQUEST LOOP ─────────────────────────────────────────────────────────────
while ($listener.IsListening) {
    try {
        $ctx  = $listener.GetContext()
        $req  = $ctx.Request
        $resp = $ctx.Response

        # Decode URL (handles spaces and special chars in file names)
        $urlPath  = [System.Uri]::UnescapeDataString($req.Url.AbsolutePath)
        $filePath = Join-Path $ROOT ($urlPath.TrimStart('/').Replace('/', [System.IO.Path]::DirectorySeparatorChar))

        # Default to index.html for root
        if ($urlPath -eq '/' -or $urlPath -eq '') {
            $filePath = Join-Path $ROOT 'index.html'
        }

        if ([System.IO.File]::Exists($filePath)) {
            $ext         = [System.IO.Path]::GetExtension($filePath).ToLower()
            $contentType = if ($MIME.ContainsKey($ext)) { $MIME[$ext] } else { 'application/octet-stream' }

            $resp.StatusCode  = 200
            $resp.ContentType = $contentType

            if ($req.HttpMethod -eq 'HEAD') {
                # HEAD requests used by detectLatestExport() — return headers only
                $info = [System.IO.FileInfo]::new($filePath)
                $resp.ContentLength64 = $info.Length
                $resp.Close()
            } else {
                $bytes = [System.IO.File]::ReadAllBytes($filePath)
                $resp.ContentLength64 = $bytes.Length
                $resp.OutputStream.Write($bytes, 0, $bytes.Length)
                $resp.Close()
            }
        } else {
            $resp.StatusCode = 404
            $resp.Close()
        }
    } catch [System.Net.HttpListenerException] {
        # Listener was stopped (window closed) — exit cleanly
        break
    } catch {
        # Log other errors but keep running
        try { $ctx.Response.StatusCode = 500; $ctx.Response.Close() } catch {}
    }
}

$listener.Stop()
