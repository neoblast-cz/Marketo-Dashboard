# mkto-proxy.ps1 — Marketo CORS Proxy
# Run: powershell -ExecutionPolicy Bypass -File mkto-proxy.ps1
# Keep this window open while using the DQ Fix feature in the dashboard.

# ── Admin check ─────────────────────────────────────────────────────────────
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator
)
if (-not $isAdmin) {
    Write-Host ""
    Write-Host "  [ERROR] This proxy must be run as Administrator." -ForegroundColor Red
    Write-Host ""
    Write-Host "  Fix: right-click PowerShell → 'Run as Administrator', then re-run:" -ForegroundColor Yellow
    Write-Host "  powershell -ExecutionPolicy Bypass -File mkto-proxy.ps1" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  (Alternatively, register the URL once without admin rights:)" -ForegroundColor DarkGray
    Write-Host "  netsh http add urlacl url=http://localhost:3791/ user=Everyone" -ForegroundColor DarkGray
    Write-Host ""
    Read-Host "Press Enter to exit"
    exit 1
}

$port = 3791

# ── Create listener ──────────────────────────────────────────────────────────
try {
    $listener = New-Object System.Net.HttpListener
    $listener.Prefixes.Add("http://localhost:$port/")
    $listener.Start()
} catch {
    Write-Host ""
    Write-Host "  [ERROR] Could not start listener on port $port" -ForegroundColor Red
    Write-Host "  $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    Write-Host "  The port may already be in use. Check with:" -ForegroundColor Yellow
    Write-Host "  netstat -ano | findstr :$port" -ForegroundColor Yellow
    Write-Host ""
    Read-Host "Press Enter to exit"
    exit 1
}

Write-Host ""
Write-Host "  ==============================================" -ForegroundColor Cyan
Write-Host "   Marketo CORS Proxy" -ForegroundColor Cyan
Write-Host "   http://localhost:$port" -ForegroundColor Green
Write-Host "  ==============================================" -ForegroundColor Cyan
Write-Host "   Keep this window open while using the" -ForegroundColor Yellow
Write-Host "   Marketo DQ Fix feature in the dashboard." -ForegroundColor Yellow
Write-Host "   Press Ctrl+C to stop." -ForegroundColor Yellow
Write-Host ""

try {
    while ($listener.IsListening) {
        $context = $listener.GetContext()
        $req     = $context.Request
        $res     = $context.Response

        # CORS headers — allow any local origin (file:// sends null origin)
        $res.Headers.Add("Access-Control-Allow-Origin",  "*")
        $res.Headers.Add("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        $res.Headers.Add("Access-Control-Allow-Headers", "Content-Type, Authorization, X-Target-Url")

        # Pre-flight
        if ($req.HttpMethod -eq "OPTIONS") {
            $res.StatusCode = 204
            $res.Close()
            continue
        }

        $targetUrl = $req.Headers["X-Target-Url"]

        if (-not $targetUrl) {
            $res.StatusCode  = 400
            $res.ContentType = "application/json"
            $bytes = [System.Text.Encoding]::UTF8.GetBytes('{"error":"Missing X-Target-Url header"}')
            $res.OutputStream.Write($bytes, 0, $bytes.Length)
            $res.Close()
            Write-Host "  [400] Missing X-Target-Url header" -ForegroundColor Red
            continue
        }

        Write-Host "  --> $($req.HttpMethod) $targetUrl" -ForegroundColor DarkGray

        try {
            $webReq = [System.Net.WebRequest]::Create($targetUrl)
            $webReq.Method = $req.HttpMethod

            if ($req.Headers["Authorization"]) {
                $webReq.Headers.Add("Authorization", $req.Headers["Authorization"])
            }

            if ($req.HttpMethod -eq "POST") {
                $webReq.ContentType = $req.ContentType
                $body      = [System.IO.StreamReader]::new($req.InputStream).ReadToEnd()
                $bodyBytes = [System.Text.Encoding]::UTF8.GetBytes($body)
                $webReq.ContentLength = $bodyBytes.Length
                $stream = $webReq.GetRequestStream()
                $stream.Write($bodyBytes, 0, $bodyBytes.Length)
                $stream.Close()
            }

            $resBody    = $null
            $statusCode = 200

            try {
                $webRes  = $webReq.GetResponse()
                $resBody = [System.IO.StreamReader]::new($webRes.GetResponseStream()).ReadToEnd()
                $webRes.Close()
                Write-Host "  <-- 200 OK" -ForegroundColor Green
            } catch [System.Net.WebException] {
                $errRes = $_.Exception.Response
                if ($errRes) {
                    $resBody    = [System.IO.StreamReader]::new($errRes.GetResponseStream()).ReadToEnd()
                    $statusCode = [int]$errRes.StatusCode
                    $errRes.Close()
                } else {
                    $resBody    = '{"error":"No response from Marketo"}'
                    $statusCode = 502
                }
                Write-Host "  <-- $statusCode" -ForegroundColor Yellow
            }

            $res.StatusCode  = $statusCode
            $res.ContentType = "application/json"
            $bytes = [System.Text.Encoding]::UTF8.GetBytes($resBody)
            $res.OutputStream.Write($bytes, 0, $bytes.Length)

        } catch {
            $safe  = ($_.Exception.Message -replace '"', "'")
            $bytes = [System.Text.Encoding]::UTF8.GetBytes("{`"error`":`"$safe`"}")
            $res.StatusCode  = 502
            $res.ContentType = "application/json"
            $res.OutputStream.Write($bytes, 0, $bytes.Length)
            Write-Host "  [!] $($_.Exception.Message)" -ForegroundColor Red
        }

        $res.Close()
    }
} finally {
    $listener.Stop()
    Write-Host "Proxy stopped." -ForegroundColor Gray
}
