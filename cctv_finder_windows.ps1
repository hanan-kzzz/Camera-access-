# ═══════════════════════════════════════════════════════════════════
#  CCTV Auto-Finder for Windows (Advanced Mode)
#  • Scans network for devices
#  • Finds open camera ports
#  • Tests multiple username:password credentials
#  • Opens working login in browser
# ═══════════════════════════════════════════════════════════════════
$ErrorActionPreference = "Stop"

# ─── Load Credential Pairs ───────────────────────────────────────
$credFile = Join-Path $PSScriptRoot "camera_credentials.txt"
if (-not (Test-Path $credFile)) {
    Write-Host "Credentials file not found: $credFile" -ForegroundColor Red
    Write-Host "Create camera_credentials.txt with username:password pairs (one per line)." -ForegroundColor Yellow
    Write-Host "Example:"
    Write-Host "  admin:admin"
    Write-Host "  admin:12345"
    Read-Host "Press Enter to exit"
    exit 1
}
$credPairs = @()
Get-Content $credFile | ForEach-Object {
    $line = $_.Trim()
    if ($line -and -not $line.StartsWith('#') -and $line.Contains(':')) {
        $credPairs += $line
    }
}
if ($credPairs.Count -eq 0) {
    Write-Host "No credentials found in $credFile" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

# ─── Check Nmap ───────────────────────────────────────────────────
if (-not (Get-Command nmap.exe -ErrorAction SilentlyContinue)) {
    Write-Host "Nmap is required. Install from: https://nmap.org/download.html" -ForegroundColor Yellow
    Read-Host "Press Enter to exit"
    exit 1
}

# ─── Detect Network ──────────────────────────────────────────────
$adapter = Get-NetIPConfiguration |
    Where-Object { $_.IPv4DefaultGateway -and $_.IPv4Address } |
    Select-Object -First 1
if (-not $adapter) {
    Write-Host "No active network connection found." -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}
$ipInfo  = $adapter.IPv4Address | Select-Object -First 1
$ip      = [System.Net.IPAddress]::Parse($ipInfo.IPAddress)
$prefix  = [int]$ipInfo.PrefixLength
$ipBytes = $ip.GetAddressBytes()
[uint32]$ipNum   = ([uint32]$ipBytes[0] -shl 24) -bor ([uint32]$ipBytes[1] -shl 16) -bor ([uint32]$ipBytes[2] -shl 8) -bor [uint32]$ipBytes[3]
[uint32]$mask    = if ($prefix -eq 0) { [uint32]0 } elseif ($prefix -ge 32) { [uint32]::MaxValue } else { [uint32]::MaxValue -shl (32 - $prefix) }
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

Add-Type -AssemblyName System.Web

# ─── Banner ───────────────────────────────────────────────────────
Clear-Host
Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║   CCTV Auto-Finder — Windows (Advanced)                 ║" -ForegroundColor Cyan
Write-Host "╠══════════════════════════════════════════════════════════╣" -ForegroundColor Cyan
Write-Host "  Interface : $($adapter.InterfaceAlias)"
Write-Host "  Your IP   : $myIp"
Write-Host "  Network   : $subnet"
Write-Host "  Gateway   : $gwIp"
Write-Host "  Creds     : $($credPairs.Count) username:password pairs loaded" -ForegroundColor Green
Write-Host "╚══════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# ═══════════════════════════════════════════════════════════════════
#  PHASE 1: NETWORK SCAN
# ═══════════════════════════════════════════════════════════════════
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Yellow
Write-Host "  PHASE 1: NETWORK SCAN" -ForegroundColor Yellow
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Yellow
Write-Host "  Scanning $subnet for live devices..." -ForegroundColor DarkGray
Write-Host ""

$nmapOutput = & nmap.exe -sn -n $subnet 2>&1
$hosts = @()
foreach ($line in $nmapOutput) {
    if ("$line" -match '^Nmap scan report for (.+)$') {
        $candidate = $Matches[1].Trim()
        $foundIp = $null
        if ($candidate -match '^\d{1,3}(\.\d{1,3}){3}$') { $foundIp = $candidate }
        elseif ($candidate -match '\((\d{1,3}(\.\d{1,3}){3})\)') { $foundIp = $Matches[1] }
        if ($foundIp -and $foundIp -ne $myIp -and $foundIp -ne $gwIp) {
            $hosts += $foundIp
        }
    }
}
$hosts = @($hosts | Select-Object -Unique)

if ($hosts.Count -eq 0) {
    Write-Host ""
    Write-Host "╔══════════════════════════════════════════════════════════╗" -ForegroundColor Red
    Write-Host "║  [!] NO OTHER DEVICES DETECTED ON THIS WI-FI            ║" -ForegroundColor Red
    Write-Host "╚══════════════════════════════════════════════════════════╝" -ForegroundColor Red
    Write-Host "  No responding devices found on subnet: $subnet" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  Troubleshooting:" -ForegroundColor Cyan
    Write-Host "  1. Make sure your computer is on the same Wi-Fi as your camera."
    Write-Host "  2. If your router has 'AP Isolation' or 'Guest Mode' enabled, disable it."
    Write-Host "  3. Check if the camera is powered on and connected."
    Write-Host ""
    Read-Host "Press Enter to exit"
    exit 0
}

Write-Host "  [OK] Found $($hosts.Count) device(s):" -ForegroundColor Green
Write-Host ""
for ($i = 0; $i -lt $hosts.Count; $i++) {
    Write-Host ("    [{0}] {1}" -f ($i + 1), $hosts[$i])
}
Write-Host ""

# ═══════════════════════════════════════════════════════════════════
#  PHASE 2: PORT SCAN
# ═══════════════════════════════════════════════════════════════════
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Yellow
Write-Host "  PHASE 2: PORT SCAN" -ForegroundColor Yellow
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Yellow
Write-Host "  Checking ports: 80, 443, 554, 8080, 8443, 37777" -ForegroundColor DarkGray
Write-Host ""

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
        Write-Host " [OK] OPEN PORTS: $($openPorts -join ', ')" -ForegroundColor Green
        $cameras += [PSCustomObject]@{ IP = $h; Ports = $openPorts }
    } else {
        Write-Host " X no camera ports" -ForegroundColor DarkGray
    }
}
Write-Host ""

if ($cameras.Count -eq 0) {
    Write-Host ""
    Write-Host "╔══════════════════════════════════════════════════════════╗" -ForegroundColor Red
    Write-Host "║  [X] NO CAMERAS FOUND ON THIS WI-FI NETWORK             ║" -ForegroundColor Red
    Write-Host "╚══════════════════════════════════════════════════════════╝" -ForegroundColor Red
    Write-Host "  Scanned $($hosts.Count) device(s) on your Wi-Fi, but none of them" -ForegroundColor Yellow
    Write-Host "  have open CCTV / camera web ports (80, 443, 554, 8080, 8443, 37777)." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  Possible reasons:" -ForegroundColor Cyan
    Write-Host "  1. Camera is connected to a different Wi-Fi network or frequency (2.4 GHz vs 5 GHz)."
    Write-Host "  2. Camera is plugged into an isolated PoE NVR port."
    Write-Host "  3. Camera is offline or using non-standard ports."
    Write-Host "  4. Router has client isolation enabled (blocking device-to-device traffic)."
    Write-Host ""
    Read-Host "Press Enter to exit"
    exit 0
}

Write-Host "  [OK] $($cameras.Count) potential camera(s) found" -ForegroundColor Green
Write-Host ""

# ═══════════════════════════════════════════════════════════════════
#  PHASE 3: CREDENTIAL CHECK
# ═══════════════════════════════════════════════════════════════════
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Yellow
Write-Host "  PHASE 3: CREDENTIAL CHECK" -ForegroundColor Yellow
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Yellow
Write-Host "  Testing $($credPairs.Count) credential pairs against each camera..." -ForegroundColor DarkGray
Write-Host ""

# Disable SSL certificate validation for self-signed certs
Add-Type @"
using System.Net;
using System.Net.Security;
using System.Security.Cryptography.X509Certificates;
public class TrustAll {
    public static void Enable() {
        ServicePointManager.ServerCertificateValidationCallback =
            delegate { return true; };
    }
}
"@
[TrustAll]::Enable()

$workingUrls = @()
$rtspUrls    = @()
$totalTested = 0
$totalSuccess = 0

foreach ($cam in $cameras) {
    Write-Host "  Camera: $($cam.IP)" -ForegroundColor Cyan
    foreach ($port in $cam.Ports) {
        if ($port -eq 554) {
            Write-Host "    RTSP Port $port" -ForegroundColor Magenta
            $first = $true
            foreach ($cred in $credPairs) {
                $parts = $cred -split ':', 2
                $user = $parts[0]; $pass = if ($parts.Count -gt 1) { $parts[1] } else { "" }
                $encU = [System.Web.HttpUtility]::UrlEncode($user)
                $encP = [System.Web.HttpUtility]::UrlEncode($pass)
                $rtspUrl = "rtsp://${encU}:${encP}@$($cam.IP):${port}/stream1"
                Write-Host "       Testing $user`:$pass ... " -NoNewline
                $totalTested++
                Write-Host "listed" -ForegroundColor Yellow
                if ($first) {
                    $rtspUrls += [PSCustomObject]@{ URL = $rtspUrl; User = $user; Pass = $pass }
                    $first = $false
                }
            }
            continue
        }

        if ($port -in @(443, 8443)) { $scheme = "https" } else { $scheme = "http" }
        Write-Host "    Web Port $port ($scheme)" -ForegroundColor Green
        $foundWorking = $false

        foreach ($cred in $credPairs) {
            $parts = $cred -split ':', 2
            $user = $parts[0]; $pass = if ($parts.Count -gt 1) { $parts[1] } else { "" }
            $totalTested++

            Write-Host "       Testing $user`:$pass ... " -NoNewline

            try {
                $secPass = ConvertTo-SecureString $pass -AsPlainText -Force
                $psCred  = New-Object System.Management.Automation.PSCredential($user, $secPass)
                $response = Invoke-WebRequest -Uri "${scheme}://$($cam.IP):${port}/" `
                    -Credential $psCred `
                    -TimeoutSec 5 `
                    -UseBasicParsing `
                    -MaximumRedirection 0 `
                    -ErrorAction Stop
                $code = [int]$response.StatusCode
            } catch {
                if ($_.Exception.Response) {
                    $code = [int]$_.Exception.Response.StatusCode
                } else {
                    $code = 0
                }
            }

            if ($code -in @(200, 301, 302, 304)) {
                Write-Host "[OK] SUCCESS (HTTP $code)" -ForegroundColor Green
                $encU = [System.Web.HttpUtility]::UrlEncode($user)
                $encP = [System.Web.HttpUtility]::UrlEncode($pass)
                $workingUrls += [PSCustomObject]@{
                    URL  = "${scheme}://${encU}:${encP}@$($cam.IP):${port}"
                    User = $user
                    Pass = $pass
                    Plain = "$($cam.IP):$port"
                }
                $totalSuccess++
                $foundWorking = $true
                break
            } elseif ($code -in @(401, 403)) {
                Write-Host "X DENIED (HTTP $code)" -ForegroundColor Red
            } elseif ($code -eq 0) {
                Write-Host "X NO RESPONSE" -ForegroundColor DarkGray
            } else {
                Write-Host "? HTTP $code" -ForegroundColor Yellow
            }
        }

        if (-not $foundWorking) {
            Write-Host "       X No working credentials for port $port" -ForegroundColor Red
        }
    }
    Write-Host ""
}

# ═══════════════════════════════════════════════════════════════════
#  PHASE 4: RESULTS & AUTO-OPEN
# ═══════════════════════════════════════════════════════════════════
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Yellow
Write-Host "  PHASE 4: RESULTS" -ForegroundColor Yellow
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Yellow
Write-Host ""

if ($workingUrls.Count -gt 0) {
    Write-Host "  [OK] WORKING CAMERAS:" -ForegroundColor Green
    Write-Host ""
    foreach ($entry in $workingUrls) {
        Write-Host "    Camera: $($entry.Plain)" -ForegroundColor Green
        Write-Host "       Username: $($entry.User)"
        Write-Host "       Password: $($entry.Pass)"
        Write-Host "       URL: $($entry.URL)" -ForegroundColor DarkGray
        Write-Host ""
    }
    Write-Host "  Opening $($workingUrls.Count) camera(s) in browser..." -ForegroundColor Green
    foreach ($entry in $workingUrls) {
        Start-Process $entry.URL
        Start-Sleep -Milliseconds 800
    }
}

if ($rtspUrls.Count -gt 0) {
    Write-Host ""
    Write-Host "  RTSP STREAMS:" -ForegroundColor Magenta
    Write-Host ""
    foreach ($entry in $rtspUrls) {
        Write-Host "    $($entry.URL)" -ForegroundColor Magenta
    }
    Write-Host "    Open with VLC Media Player" -ForegroundColor DarkGray
}

if ($workingUrls.Count -eq 0 -and $rtspUrls.Count -eq 0) {
    Write-Host "  X No working credentials found for any camera." -ForegroundColor Red
    Write-Host "  Add more credentials to: camera_credentials.txt" -ForegroundColor Yellow
    Write-Host "  Format: username:password (one per line)" -ForegroundColor Yellow
}

# ─── Summary ─────────────────────────────────────────────────────
Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║  SCAN COMPLETE                                           ║" -ForegroundColor Cyan
Write-Host "╠══════════════════════════════════════════════════════════╣" -ForegroundColor Cyan
Write-Host "  Devices scanned   : $($hosts.Count)"
Write-Host "  Cameras found     : $($cameras.Count)"
Write-Host "  Credentials tested: $totalTested"
Write-Host "  Successful logins : $totalSuccess" -ForegroundColor Green
Write-Host "  RTSP streams      : $($rtspUrls.Count)"
Write-Host "╚══════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""
Read-Host "Press Enter to exit"
