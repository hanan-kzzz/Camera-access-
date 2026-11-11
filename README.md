# 📷 CCTV Auto-Finder (Advanced Mode)

A fully automatic network scanner that discovers IP cameras and NVRs on your local network, scans ports, **tests multiple username:password credentials**, and opens working cameras in your browser — all hands-free.

Works on **Windows**, **Ubuntu/Linux**, and **Termux (Android)**.

---

## ✨ Features

- 🔍 **Phase 1 — Network Scan** — discovers all live devices on your LAN
- 📡 **Phase 2 — Port Scan** — checks each device for camera ports (80, 443, 554, 8080, 8443, 37777)
- 🔑 **Phase 3 — Credential Check** — tests every `username:password` pair against each camera, shows ✓ SUCCESS or ✗ DENIED for each attempt
- 🌐 **Phase 4 — Auto-Open** — opens all working cameras in your browser with credentials pre-filled
- 🎥 **RTSP detection** — finds video streams with ready-to-use VLC URLs
- 📱 **Cross-platform** — dedicated scripts for Windows, Ubuntu/Linux, and Termux (Android)

---

## 🚀 Quick Start

### Step 1: Clone the Repository

```bash
git clone https://github.com/hanan-kzzz/Camera-access-.git
cd Camera-access-
```

### Step 2: Set Up Credentials

Edit `camera_credentials.txt` — add as many `username:password` pairs as you want, **one per line**:

```
admin:admin
admin:12345
admin:password
admin:123456
admin:admin123
root:root
root:admin
admin:
user:user
admin:888888
admin:666666
```

> 💡 The scanner tries **every pair** against each camera and shows you which one works.
>
> ⚠️ `camera_credentials.txt` is git-ignored and will never be committed.

### Step 3: Run the Scanner

<details>
<summary><b>🪟 Windows</b></summary>

**Requirements:** Nmap installed and in PATH ([download here](https://nmap.org/download.html))

**Option A** — Double-click:
```
cctv_finder_windows.bat
```

**Option B** — From PowerShell:
```powershell
powershell -ExecutionPolicy Bypass -File cctv_finder_windows.ps1
```
</details>

<details>
<summary><b>🐧 Ubuntu / Linux</b></summary>

**Install dependencies:**
```bash
sudo apt update && sudo apt install nmap iproute2 curl xdg-utils
```

**Run:**
```bash
chmod +x cctv_finder_ubuntu.sh
./cctv_finder_ubuntu.sh
```
</details>

<details>
<summary><b>📱 Termux (Android)</b></summary>

**One-time setup** (installs nmap, net-tools, curl, termux-api automatically):
```bash
chmod +x setup_termux.sh
./setup_termux.sh
```

Or install manually:
```bash
pkg update && pkg install nmap net-tools curl termux-api
```

**Run:**
```bash
chmod +x cctv_finder_termux.sh
./cctv_finder_termux.sh
```

> 💡 Make sure your phone is on the **same Wi-Fi** as your cameras.

</details>

---

## ⚙️ How It Works

```
┌──────────────────────────────────────────────────────────┐
│  PHASE 1: NETWORK SCAN                                   │
│  Discovers all live devices on your LAN using Nmap        │
│  Filters out your own IP and the gateway                  │
├──────────────────────────────────────────────────────────┤
│  PHASE 2: PORT SCAN                                      │
│  Checks each device for camera web-interface ports:       │
│  80, 443, 554 (RTSP), 8080, 8443, 37777 (Dahua)         │
├──────────────────────────────────────────────────────────┤
│  PHASE 3: CREDENTIAL CHECK                               │
│  Tests every username:password pair from your list        │
│  Shows ✓ SUCCESS or ✗ DENIED for each attempt            │
│  Stops on first working credential per port               │
├──────────────────────────────────────────────────────────┤
│  PHASE 4: RESULTS & AUTO-OPEN                            │
│  Opens all working cameras in your browser                │
│  Lists RTSP streams for VLC playback                      │
│  Shows summary with total tested/success count            │
└──────────────────────────────────────────────────────────┘
```

---

## 🖥️ Example Output

```
╔══════════════════════════════════════════════════════════╗
║   📷 CCTV Auto-Finder — Termux (Advanced)              ║
╠══════════════════════════════════════════════════════════╣
║  Interface : wlan0
║  Your IP   : 192.168.1.100
║  Network   : 192.168.1.0/24
║  Creds     : 11 username:password pairs loaded
╚══════════════════════════════════════════════════════════╝

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  PHASE 1: NETWORK SCAN
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  ✓ Found 5 device(s):
    [1] 192.168.1.10
    [2] 192.168.1.20
    [3] 192.168.1.30
    [4] 192.168.1.50
    [5] 192.168.1.64

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  PHASE 2: PORT SCAN
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Scanning 192.168.1.10 ... ✓ OPEN PORTS: 80, 554
  Scanning 192.168.1.20 ... ✓ OPEN PORTS: 80, 443
  Scanning 192.168.1.30 ... ✗ no camera ports
  Scanning 192.168.1.50 ... ✗ no camera ports
  Scanning 192.168.1.64 ... ✓ OPEN PORTS: 80, 37777

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  PHASE 3: CREDENTIAL CHECK
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  📷 Camera: 192.168.1.10
    🌐 Port 80 (http)
       Testing admin:admin ... ✗ DENIED (HTTP 401)
       Testing admin:12345 ... ✗ DENIED (HTTP 401)
       Testing admin:password ... ✓ SUCCESS (HTTP 200)
    🎥 Port 554 (RTSP stream)
       Testing admin:password ... listed

  📷 Camera: 192.168.1.20
    🌐 Port 80 (http)
       Testing admin:admin ... ✓ SUCCESS (HTTP 200)
    🔐 Port 443 (https)
       Testing admin:admin ... ✓ SUCCESS (HTTP 200)

  📷 Camera: 192.168.1.64
    🌐 Port 80 (http)
       Testing admin:admin ... ✗ DENIED (HTTP 401)
       Testing admin:12345 ... ✗ DENIED (HTTP 401)
       Testing admin:password ... ✗ DENIED (HTTP 401)
       Testing admin:123456 ... ✗ DENIED (HTTP 401)
       Testing admin:admin123 ... ✗ DENIED (HTTP 401)
       Testing root:root ... ✗ DENIED (HTTP 401)
       Testing root:admin ... ✗ DENIED (HTTP 401)
       Testing admin: ... ✗ DENIED (HTTP 401)
       Testing user:user ... ✗ DENIED (HTTP 401)
       Testing admin:888888 ... ✓ SUCCESS (HTTP 200)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  PHASE 4: RESULTS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  ✓ WORKING CAMERAS:

    📷 192.168.1.10:80
       Username: admin
       Password: password

    📷 192.168.1.20:80
       Username: admin
       Password: admin

    📷 192.168.1.64:80
       Username: admin
       Password: 888888

  Opening 3 camera(s) in browser...

  🎥 RTSP STREAMS:
    rtsp://admin:password@192.168.1.10:554/stream1

╔══════════════════════════════════════════════════════════╗
║  SCAN COMPLETE                                           ║
╠══════════════════════════════════════════════════════════╣
║  📡 Devices scanned   : 5
║  📷 Cameras found     : 3
║  🔑 Credentials tested: 25
║  ✅ Successful logins : 3
║  🎥 RTSP streams      : 1
╚══════════════════════════════════════════════════════════╝
```

---

## 🔑 Adding More Credentials

Edit `camera_credentials.txt` anytime — add as many pairs as you need:

```
# Common defaults
admin:admin
admin:12345
admin:password
admin:123456

# Brand-specific defaults
admin:888888       # Dahua
admin:666666       # Dahua
admin:1111111      # Hikvision
admin:hikadmin     # Hikvision

# Custom passwords
admin:MyCamera2024
operator:op123

# Empty password
admin:
```

The format is `username:password` — one per line. Lines starting with `#` are ignored.

---

## 📁 Project Files

| File | Platform | Description |
|------|----------|-------------|
| `cctv_finder_windows.ps1` | 🪟 Windows | Main PowerShell scanner |
| `cctv_finder_windows.bat` | 🪟 Windows | Double-click launcher |
| `cctv_finder_ubuntu.sh` | 🐧 Ubuntu/Linux | Main Bash scanner |
| `cctv_finder_termux.sh` | 📱 Android | Termux-optimized scanner |
| `setup_termux.sh` | 📱 Android | One-time setup (installs deps) |
| `camera_credentials.txt` | All | Your credential list — **git-ignored** |
| `camera_credentials.example.txt` | All | Template — copy to `camera_credentials.txt` |

---

## 📋 Requirements

| Platform | Required | Optional |
|----------|----------|----------|
| 🪟 Windows | PowerShell 5+, [Nmap](https://nmap.org/download.html) | — |
| 🐧 Ubuntu/Linux | `bash`, `nmap`, `iproute2`, `curl` | `xdg-utils` (auto-open browser) |
| 📱 Termux | `nmap`, `net-tools`, `curl` | `termux-api` (auto-open browser) |

---

## 🔒 Security Notes

- `camera_credentials.txt` is in `.gitignore` — it will **never** be committed
- Credentials in URLs may appear in browser history — clear after use if needed
- Special characters in passwords are URL-encoded automatically
- This tool is intended for accessing **your own** cameras on **your own** network

---

## 🎥 Playing RTSP Streams

**Desktop (VLC):**
```bash
vlc rtsp://admin:password@192.168.1.10:554/stream1
```

**Termux:**
```bash
pkg install vlc
cvlc rtsp://admin:password@192.168.1.10:554/stream1
```

**Android:** Open the RTSP URL in [VLC for Android](https://play.google.com/store/apps/details?id=org.videolan.vlc)

---

## 📜 License

This project is for **personal and educational use only**. Only use it on networks and devices you own or have explicit authorization to access.
