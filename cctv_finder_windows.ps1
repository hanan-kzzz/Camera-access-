# CCTV Finder for Windows
# Discover devices on your own LAN and inspect common web-interface ports.
$ErrorActionPreference = "Stop"

if (-not (Get-Command nmap.exe -ErrorAction SilentlyContinue)) {
    Write-Host "Nmap is required. Install Nmap for Windows, then reopen this tool." -ForegroundColor Yellow
    Write-Host "https://nmap.org/download.html"
    Read-Host "Press Enter to exit"
    exit 1
}

$adapter = Get-NetIPConfiguration | Where-Object { $_.IPv4DefaultGateway -and $_.IPv4Address } | Select-Object -First 1
if (-not $adapter) {
    Write-Host "No active network connection found. Connect to the same LAN/Wi-Fi as your camera." -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

$ipInfo = $adapter.IPv4Address | Select-Object -First 1
$ip = [System.Net.IPAddress]::Parse($ipInfo.IPAddress)
$prefix = [int]$ipInfo.PrefixLength
$ipBytes = $ip.GetAddressBytes()
[uint32]$ipNum = ([uint32]$ipBytes[0] -shl 24) -bor ([uint32]$ipBytes[1] -shl 16) -bor ([uint32]$ipBytes[2] -shl 8) -bor [uint32]$ipBytes[3]
[uint32]$mask = if ($prefix -eq 0) { 0 } else { [uint32]([uint64]0xFFFFFFFF -shl (32 - $prefix)) }
[uint32]$network = $ipNum -band $mask
$netBytes = [byte[]]@(
    [byte](($network -shr 24) -band 255),
    [byte](($network -shr 16) -band 255),
    [byte](($network -shr 8) -band 255),
    [byte]($network -band 255)
)
$subnet = "$([System.Net.IPAddress]::new($netBytes))/$prefix"

Write-Host ""
Write-Host "CCTV Finder for Windows" -ForegroundColor Cyan
Write-Host "Interface: $($adapter.InterfaceAlias) | Network: $subnet"
Write-Host "Discovering devices on your local network..."
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
        if ($candidate -match '^\d{1,3}(\.\d{1,3}){3}$') { $hosts += $candidate }
        elseif ($candidate -match '\((\d{1,3}(\.\d{1,3}){3})\)') { $hosts += $Matches[1] }
    }
}
$hosts = @($hosts | Select-Object -Unique)

if ($hosts.Count -eq 0) {
    Write-Host "No responding devices found." -ForegroundColor Yellow
    Read-Host "Press Enter to exit"
    exit 0
}

Write-Host ""
Write-Host "Devices found:"
for ($i = 0; $i -lt $hosts.Count; $i++) { Write-Host ("  {0}) {1}" -f ($i + 1), $hosts[$i]) }
$choice = Read-Host "Select the number of your own camera/NVR (0 to exit)"
if ($choice -eq "0") { exit 0 }
$number = 0
if (-not [int]::TryParse($choice, [ref]$number) -or $number -lt 1 -or $number -gt $hosts.Count) {
    Write-Host "Invalid selection." -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

$cameraIp = $hosts[$number - 1]
Write-Host ""
Write-Host "Checking common web-interface ports on $cameraIp..."
$portOutput = & nmap.exe -n -sT -sV --version-light -p 80,443,8080,8443 $cameraIp 2>&1
$portOutput | ForEach-Object { Write-Host $_ }
$openPorts = @()
foreach ($line in $portOutput) {
    if ("$line" -match '^\s*(\d+)/tcp\s+open') { $openPorts += [int]$Matches[1] }
}
$openPorts = @($openPorts | Select-Object -Unique)

if ($openPorts.Count -eq 0) {
    Write-Host "No common web-login port found. The device may use another port or an NVR/app." -ForegroundColor Yellow
    Read-Host "Press Enter to exit"
    exit 0
}

$urls = @()
Write-Host ""
Write-Host "Possible browser addresses:"
foreach ($port in $openPorts) {
    if ($port -in @(443, 8443)) { $url = "https://\${cameraIp}:$port" }
    else { $url = "http://\${cameraIp}:$port" }
    $urls += $url
    Write-Host "  $url"
}

$open = Read-Host "Open the first address in your default browser? [y/N]"
if ($open -match '^[Yy]$') { Start-Process $urls[0] }

Write-Host ""
Write-Host "Done. This tool discovers devices and checks common web ports only."
Write-Host "It does not guess passwords, bypass authentication, or change camera settings."
Read-Host "Press Enter to exit"
