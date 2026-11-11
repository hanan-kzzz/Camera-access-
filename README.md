# 📷 CCTV Auto-Finder (Advanced Mode)

A fully automatic network scanner that discovers IP cameras and NVRs on your local network, checks web-interface ports, and opens login pages with your credentials pre-filled — **no manual selection needed**.

Works on **Windows**, **Ubuntu/Linux**, and **Termux (Android)**.

---

## ✨ Features

- 🔍 **Fully automatic** — scans your entire LAN, finds all cameras, and opens every login page
- 🔑 **Auto-login** — embeds your username & password into the URL so cameras log in instantly
- 🎥 **RTSP detection** — finds video streams (port 554) with ready-to-use VLC URLs
- 🛡️ **Smart filtering** — skips your own machine and gateway, only shows real devices
- 📡 **Extended port scanning** — checks ports 80, 443, 554, 8080, 8443, and 37777 (Dahua)
- 📱 **Cross-platform** — dedicated scripts for Windows, Ubuntu/Linux, and Termux (Android)

---

## 🚀 Quick Start

### Step 1: Clone the Repository

```bash
git clone https://github.com/hanan-kzzz/Camera-access-.git
cd Camera-access-
```

### Step 2: Set Up Credentials

Copy the example file and fill in your camera username and password:

```bash
cp camera_credentials.example.txt camera_credentials.txt
```

Edit `camera_credentials.txt`:

```
username=admin
password=YourCameraPassword
```

> ⚠️ **Note:** `camera_credentials.txt` is git-ignored and will never be committed to the repo.

### Step 3: Run the Scanner

Choose the right script for your platform:

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
sudo apt update && sudo apt install nmap iproute2 xdg-utils
```

**Run:**
```bash
chmod +x cctv_finder_ubuntu.sh
./cctv_finder_ubuntu.sh
```
</details>

<details>
<summary><b>📱 Termux (Android)</b></summary>

**One-time setup** (installs nmap, net-tools, termux-api automatically):
```bash
chmod +x setup_termux.sh
./setup_termux.sh
```

Or install manually:
```bash
pkg update && pkg install nmap net-tools termux-api
```

**Run:**
```bash
chmod +x cctv_finder_termux.sh
./cctv_finder_termux.sh
```

> 💡 **Tip:** Make sure your phone is connected to the **same Wi-Fi** network as your cameras.

</details>

---

## ⚙️ How It Works

```
┌─────────────────────────────────────────────────────┐
│  Step 1: Network Discovery                          │
│  Scans your entire LAN subnet using Nmap            │
│  Skips your own device and the gateway               │
├─────────────────────────────────────────────────────┤
│  Step 2: Port Scanning                              │
│  Checks each device for camera ports:               │
│  80, 443, 554 (RTSP), 8080, 8443, 37777 (Dahua)    │
├─────────────────────────────────────────────────────┤
│  Step 3: Auto-Login                                 │
│  Opens camera login pages in your browser with      │
│  credentials embedded: http://user:pass@IP:port     │
│  Lists RTSP streams for VLC playback                │
└─────────────────────────────────────────────────────┘
```

---

## 🖥️ Example Output

```
╔══════════════════════════════════════════════════════╗
║       CCTV Auto-Finder  (Advanced Mode)             ║
╚══════════════════════════════════════════════════════╝
  Interface : Wi-Fi
  Your IP   : 192.168.1.100
  Network   : 192.168.1.0/24
  Credentials loaded from camera_credentials.txt

[1/3] Scanning network for devices...
  Found 5 device(s):
    - 192.168.1.10
    - 192.168.1.20
    - 192.168.1.30
    - 192.168.1.50
    - 192.168.1.64

[2/3] Scanning for camera ports (80, 443, 554, 8080, 8443, 37777)...
  Scanning 192.168.1.10 ... CAMERA FOUND (ports: 80, 554)
  Scanning 192.168.1.20 ... CAMERA FOUND (ports: 80, 443)
  Scanning 192.168.1.30 ... no camera ports
  Scanning 192.168.1.50 ... no camera ports
  Scanning 192.168.1.64 ... CAMERA FOUND (ports: 37777, 80)

[3/3] Opening camera login pages with auto-credentials...

  📷 Camera: 192.168.1.10
    🌐 Web login  : http://192.168.1.10:80   →  credentials embedded
    🎥 RTSP stream: rtsp://192.168.1.10:554

  📷 Camera: 192.168.1.20
    🌐 Web login  : http://192.168.1.20:80   →  credentials embedded
    🔐 Web login  : https://192.168.1.20:443 →  credentials embedded

  📷 Camera: 192.168.1.64
    🌐 Web login  : http://192.168.1.64:80   →  credentials embedded

Opening 4 camera login page(s) in your browser...

🎥 RTSP streams (open with VLC):
  rtsp://admin:admin@192.168.1.10:554/stream1

═══════════════════════════════════════════════════════
  Scan complete!
  📷 Cameras found : 3
  🌐 URLs opened   : 4
  🎥 RTSP streams  : 1
═══════════════════════════════════════════════════════
```

---

## 🔑 How Auto-Login Works

Credentials are embedded in the URL using the standard `http://user:pass@host:port` format.

| Works Automatically ✅ | Needs Manual Login ⚠️ |
|------------------------|----------------------|
| HTTP Basic Auth cameras | Custom HTML login forms |
| Hikvision, Dahua, Reolink | Some newer web UIs |
| Amcrest, Foscam, TP-Link | Cloud-based cameras |
| Most NVR/DVR web panels | Two-factor auth cameras |

For cameras with custom login forms, the browser opens the page and your credentials are saved in `camera_credentials.txt` for easy copy-paste.

---

## 📁 Project Files

| File | Platform | Description |
|------|----------|-------------|
| `cctv_finder_windows.ps1` | 🪟 Windows | Main PowerShell scanner script |
| `cctv_finder_windows.bat` | 🪟 Windows | Double-click launcher for the PS1 script |
| `cctv_finder_ubuntu.sh` | 🐧 Ubuntu/Linux | Main Bash scanner script |
| `cctv_finder_termux.sh` | 📱 Android | Termux-optimized scanner with Android-specific features |
| `setup_termux.sh` | 📱 Android | One-time setup script (installs all dependencies) |
| `camera_credentials.txt` | All | Your credentials — **git-ignored**, never committed |
| `camera_credentials.example.txt` | All | Template file — copy to `camera_credentials.txt` |

---

## 📱 Termux-Specific Features

The Termux script is specially built for Android with:

- 📦 **Auto-installs dependencies** — detects missing packages and installs via `pkg`
- 📶 **Multiple network detection** — tries `ip` → `ifconfig` → `getprop` → manual input
- 🌐 **Android browser opening** — uses `termux-open-url` → `am start` → `xdg-open`
- 📡 **Wi-Fi aware** — defaults to `wlan0` interface (Android standard)
- 🎨 **Colored output** — emoji + ANSI colors for easy reading on small screens
- ✏️ **Auto-creates credentials** — generates `camera_credentials.txt` if missing

---

## 📋 Requirements Summary

| Platform | Required | Optional |
|----------|----------|----------|
| 🪟 Windows | PowerShell 5+, [Nmap](https://nmap.org/download.html) | — |
| 🐧 Ubuntu/Linux | `bash`, `nmap`, `iproute2` | `xdg-utils` (auto-open browser) |
| 📱 Termux | `nmap`, `net-tools` | `termux-api` (auto-open browser) |

---

## 🔒 Security Notes

- `camera_credentials.txt` is in `.gitignore` — it will **never** be committed
- Credentials in URLs may appear in browser history — clear history if needed
- Special characters in passwords are URL-encoded automatically
- This tool is intended for accessing **your own** cameras on **your own** network

---

## 🎥 Playing RTSP Streams

The scanner detects RTSP streams on port 554. To watch them:

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
