# Advanced CCTV Finder for Windows — Automatic Mode
# Discovers ALL cameras on your LAN, checks web ports, and opens login pages
# with credentials auto-embedded in the URL.
$ErrorActionPreference = "Stop"

# ─── Load Credentials ────────────────────────────────────────────────
$credFile = Join-Path $PSScriptRoot "camera_credentials.txt"
if (-not (Test-Path $credFile)) {
    Write-Host "Credentials file not found: $credFile" -ForegroundColor Red
    Write-Host "Create camera_credentials.txt with:" -ForegroundColor Yellow
    Write-Host "  username=YOUR_CAMERA_USERNAME"
    Write-Host "  password=YOUR_CAMERA_PASSWORD"
    Read-Host "Press Enter to exit"
    exit 1
}
$creds = @{}
Get-Content $credFile | ForEach-Object {
    $line = $_.Trim()
    if ($line -and -not $line.StartsWith('#')) {
        $parts = $line -split '=', 2
        if ($parts.Count -eq 2) { $creds[$parts[0].Trim()] = $parts[1].Trim() }
    }
}
$camUser = $creds['username']
$camPass = $creds['password']
if (-not $camUser -or -not $camPass) {
    Write-Host "Invalid credentials file. Ensure it contains username=... and password=..." -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

# ─── Check Nmap ───────────────────────────────────────────────────────
if (-not (Get-Command nmap.exe -ErrorAction SilentlyContinue)) {
    Write-Host "Nmap is required. Install Nmap for Windows, then reopen this tool." -ForegroundColor Yellow
    Write-Host "https://nmap.org/download.html"
    Read-Host "Press Enter to exit"
    exit 1
}

# ─── Detect Network ──────────────────────────────────────────────────
$adapter = Get-NetIPConfiguration |
    Where-Object { $_.IPv4DefaultGateway -and $_.IPv4Address } |
    Select-Object -First 1
if (-not $adapter) {
    Write-Host "No active network connection found. Connect to the same LAN/Wi-Fi as your camera." -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}
$ipInfo  = $adapter.IPv4Address | Select-Object -First 1
$ip      = [System.Net.IPAddress]::Parse($ipInfo.IPAddress)
$prefix  = [int]$ipInfo.PrefixLength
$ipBytes = $ip.GetAddressBytes()
[uint32]$ipNum   = ([uint32]$ipBytes[0] -shl 24) -bor ([uint32]$ipBytes[1] -shl 16) -bor ([uint32]$ipBytes[2] -shl 8) -bor [uint32]$ipBytes[3]
[uint32]$mask    = if ($prefix -eq 0) { 0 } else { [uint32]([uint64]0xFFFFFFFF -shl (32 - $prefix)) }
[uint32]$network = $ipNum -band $mask
$netBytes = [byte[]]@(
    [byte](($network -shr 24) -band 255),
    [byte](($network -shr 16) -band 255),
    [byte](($network -shr 8)  -band 255),
    [byte]( $network           -band 255)
)
$subnet = "$([System.Net.IPAddress]::new($netBytes))/$prefix"
$myIp   = $ipInfo.IPAddress
$gwIp   = $adapter.IPv4DefaultGateway.NextHop

# ─── Banner ───────────────────────────────────────────────────────────
Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║       CCTV Auto-Finder  (Advanced Mode)             ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host "  Interface : $($adapter.InterfaceAlias)"
Write-Host "  Your IP   : $myIp"
Write-Host "  Network   : $subnet"
Write-Host "  Credentials loaded from camera_credentials.txt" -ForegroundColor Green
Write-Host ""

# ─── Discover Hosts ───────────────────────────────────────────────────
Write-Host "[1/3] Scanning network for devices..." -ForegroundColor Yellow
$nmapOutput = & nmap.exe -sn -n $subnet 2>&1
if ($LASTEXITCODE -ne 0) {
    $nmapOutput | ForEach-Object { Write-Host $_ }
    Read-Host "Press Enter to exit"
    exit 1
}
$hosts = @()
foreach ($line in $nmapOutput) {
    if ("$line" -match '^Nmap scan report for (.+)$') {
        $candidate = $Matches[1].Trim()
        $foundIp = $null
        if ($candidate -match '^\d{1,3}(\.\d{1,3}){3}$') { $foundIp = $candidate }
        elseif ($candidate -match '\((\d{1,3}(\.\d{1,3}){3})\)') { $foundIp = $Matches[1] }
        # Skip our own IP and the gateway
        if ($foundIp -and $foundIp -ne $myIp -and $foundIp -ne $gwIp) {
            $hosts += $foundIp
        }
    }
}
$hosts = @($hosts | Select-Object -Unique)

if ($hosts.Count -eq 0) {
    Write-Host "No devices found (other than this machine and the gateway)." -ForegroundColor Yellow
    Read-Host "Press Enter to exit"
    exit 0
}
Write-Host "  Found $($hosts.Count) device(s):" -ForegroundColor Green
$hosts | ForEach-Object { Write-Host "    - $_" }
Write-Host ""

# ─── Port-Scan Each Host ─────────────────────────────────────────────
Write-Host "[2/3] Scanning all devices for web-interface ports (80, 443, 554, 8080, 8443, 37777)..." -ForegroundColor Yellow
$cameras = @()
foreach ($h in $hosts) {
    Write-Host "  Scanning $h ..." -NoNewline
    $portOutput = & nmap.exe -n -sT --open -p 80,443,554,8080,8443,37777 $h 2>&1
    $openPorts = @()
    foreach ($line in $portOutput) {
        if ("$line" -match '^\s*(\d+)/tcp\s+open') { $openPorts += [int]$Matches[1] }
    }
    $openPorts = @($openPorts | Select-Object -Unique)
    if ($openPorts.Count -gt 0) {
        Write-Host " CAMERA/NVR FOUND (ports: $($openPorts -join ', '))" -ForegroundColor Green
        $cameras += [PSCustomObject]@{ IP = $h; Ports = $openPorts }
    } else {
        Write-Host " no web ports" -ForegroundColor DarkGray
    }
}
Write-Host ""

if ($cameras.Count -eq 0) {
    Write-Host "No devices with open web-interface ports found." -ForegroundColor Yellow
    Read-Host "Press Enter to exit"
    exit 0
}

# ─── Build URLs & Open ───────────────────────────────────────────────
Write-Host "[3/3] Opening camera login pages with auto-credentials..." -ForegroundColor Yellow
Write-Host ""

# URL-encode username and password for safe embedding
Add-Type -AssemblyName System.Web
$encUser = [System.Web.HttpUtility]::UrlEncode($camUser)
$encPass = [System.Web.HttpUtility]::UrlEncode($camPass)

$allUrls = @()
foreach ($cam in $cameras) {
    Write-Host "  Camera: $($cam.IP)" -ForegroundColor Cyan
    foreach ($port in $cam.Ports) {
        if ($port -eq 554) {
            # RTSP stream — build rtsp:// URL
            $url      = "rtsp://${encUser}:${encPass}@$($cam.IP):$port/stream1"
            $plainUrl = "rtsp://$($cam.IP):$port"
            Write-Host "    RTSP stream: $plainUrl" -ForegroundColor Magenta
            Write-Host "      Full URL : $url"
            $allUrls += [PSCustomObject]@{ URL = $url; Type = "RTSP" }
        }
        elseif ($port -in @(443, 8443)) {
            $url      = "https://${encUser}:${encPass}@$($cam.IP):$port"
            $plainUrl = "https://$($cam.IP):$port"
            Write-Host "    Web login  : $plainUrl  ->  credentials embedded" -ForegroundColor Green
            $allUrls += [PSCustomObject]@{ URL = $url; Type = "HTTPS" }
        }
        else {
            $url      = "http://${encUser}:${encPass}@$($cam.IP):$port"
            $plainUrl = "http://$($cam.IP):$port"
            Write-Host "    Web login  : $plainUrl  ->  credentials embedded" -ForegroundColor Green
            $allUrls += [PSCustomObject]@{ URL = $url; Type = "HTTP" }
        }
    }
    Write-Host ""
}

# Open all HTTP/HTTPS URLs in the browser automatically
$webUrls = @($allUrls | Where-Object { $_.Type -ne "RTSP" })
if ($webUrls.Count -gt 0) {
    Write-Host "Opening $($webUrls.Count) camera login page(s) in your browser..." -ForegroundColor Green
    foreach ($entry in $webUrls) {
        Start-Process $entry.URL
        Start-Sleep -Milliseconds 800
    }
}

# Show RTSP summary
$rtspUrls = @($allUrls | Where-Object { $_.Type -eq "RTSP" })
if ($rtspUrls.Count -gt 0) {
    Write-Host ""
    Write-Host "RTSP streams found (open with VLC or media player):" -ForegroundColor Magenta
    foreach ($entry in $rtspUrls) { Write-Host "  $($entry.URL)" }
}

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  Scan complete!" -ForegroundColor Green
Write-Host "  Cameras found : $($cameras.Count)"
Write-Host "  URLs opened   : $($webUrls.Count)"
Write-Host "  RTSP streams  : $($rtspUrls.Count)"
Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
Write-Host "Credentials are embedded as http://user:pass@IP:port."
Write-Host "Most IP cameras and NVRs that use HTTP Basic Auth will log in automatically."
Write-Host "If a camera uses a custom form, paste credentials from camera_credentials.txt."
Read-Host "Press Enter to exit"
