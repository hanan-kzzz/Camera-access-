#!/usr/bin/env bash
# Advanced CCTV Finder for Ubuntu — Automatic Mode
# Discovers ALL cameras on your LAN, checks web ports, and opens login pages
# with credentials auto-embedded in the URL.
set -Eeuo pipefail

# ─── Load Credentials ────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CRED_FILE="$SCRIPT_DIR/camera_credentials.txt"
if [[ ! -f "$CRED_FILE" ]]; then
    echo "Credentials file not found: $CRED_FILE"
    echo "Create camera_credentials.txt with:"
    echo "  username=YOUR_CAMERA_USERNAME"
    echo "  password=YOUR_CAMERA_PASSWORD"
    exit 1
fi
CAM_USER=""
CAM_PASS=""
while IFS='=' read -r key value; do
    key="$(echo "$key" | xargs)"
    value="$(echo "$value" | xargs)"
    [[ -z "$key" || "$key" == \#* ]] && continue
    case "$key" in
        username) CAM_USER="$value" ;;
        password) CAM_PASS="$value" ;;
    esac
done < "$CRED_FILE"
if [[ -z "$CAM_USER" || -z "$CAM_PASS" ]]; then
    echo "Invalid credentials file. Ensure it contains username=... and password=..."
    exit 1
fi

# URL-encode a string (for embedding in URLs safely)
urlencode() {
    local string="$1" length="${#1}" i c
    for (( i = 0; i < length; i++ )); do
        c="${string:i:1}"
        case "$c" in
            [a-zA-Z0-9.~_-]) printf '%s' "$c" ;;
            *) printf '%%%02X' "'$c" ;;
        esac
    done
}
ENC_USER="$(urlencode "$CAM_USER")"
ENC_PASS="$(urlencode "$CAM_PASS")"

# ─── Check Dependencies ──────────────────────────────────────────────
for cmd in nmap ip; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "$cmd is required. Install with: sudo apt update && sudo apt install nmap iproute2"
        exit 1
    fi
done

# ─── Detect Network ──────────────────────────────────────────────────
IFACE="$(ip route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="dev"){print $(i+1); exit}}')"
if [[ -z "$IFACE" ]]; then
    echo "No active network interface found. Connect to the same LAN/Wi-Fi as your camera."
    exit 1
fi
CIDR="$(ip -o -f inet addr show dev "$IFACE" | awk '{print $4; exit}')"
MY_IP="$(echo "$CIDR" | cut -d/ -f1)"
GW_IP="$(ip route | awk '/default/ {print $3; exit}')"
if [[ -z "$CIDR" ]]; then
    echo "Could not determine the IPv4 network range."
    exit 1
fi

# ─── Banner ───────────────────────────────────────────────────────────
echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║       CCTV Auto-Finder  (Advanced Mode)             ║"
echo "╚══════════════════════════════════════════════════════╝"
echo "  Interface : $IFACE"
echo "  Your IP   : $MY_IP"
echo "  Network   : $CIDR"
echo "  Credentials loaded from camera_credentials.txt"
echo ""

# ─── Discover Hosts ───────────────────────────────────────────────────
echo "[1/3] Scanning network for devices..."
SCAN="$(nmap -sn -n "$CIDR")"
mapfile -t RAW_HOSTS < <(printf '%s\n' "$SCAN" | awk '/Nmap scan report for / {print $NF}' | tr -d '()')

# Filter out our own IP and the gateway
HOSTS=()
for h in "${RAW_HOSTS[@]}"; do
    [[ "$h" == "$MY_IP" || "$h" == "$GW_IP" ]] && continue
    HOSTS+=("$h")
done

if (( ${#HOSTS[@]} == 0 )); then
    echo "No devices found (other than this machine and the gateway)."
    exit 0
fi
echo "  Found ${#HOSTS[@]} device(s):"
for h in "${HOSTS[@]}"; do echo "    - $h"; done
echo ""

# ─── Port-Scan Each Host ─────────────────────────────────────────────
echo "[2/3] Scanning all devices for web-interface ports (80, 443, 554, 8080, 8443, 37777)..."
declare -A CAMERA_PORTS
CAMERA_LIST=()
for h in "${HOSTS[@]}"; do
    printf "  Scanning %s ..." "$h"
    RESULT="$(nmap -n -sT --open -p 80,443,554,8080,8443,37777 "$h" 2>/dev/null)"
    mapfile -t PORTS < <(printf '%s\n' "$RESULT" | awk '/^[0-9]+\/tcp[[:space:]]+open/ {split($1,p,"/"); print p[1]}')
    if (( ${#PORTS[@]} > 0 )); then
        echo " CAMERA/NVR FOUND (ports: $(IFS=,; echo "${PORTS[*]}"))"
        CAMERA_PORTS["$h"]="${PORTS[*]}"
        CAMERA_LIST+=("$h")
    else
        echo " no web ports"
    fi
done
echo ""

if (( ${#CAMERA_LIST[@]} == 0 )); then
    echo "No devices with open web-interface ports found."
    exit 0
fi

# ─── Build URLs & Open ───────────────────────────────────────────────
echo "[3/3] Opening camera login pages with auto-credentials..."
echo ""

WEB_COUNT=0
RTSP_URLS=()

for cam in "${CAMERA_LIST[@]}"; do
    echo "  Camera: $cam"
    read -ra ports <<< "${CAMERA_PORTS[$cam]}"
    for port in "${ports[@]}"; do
        if [[ "$port" == "554" ]]; then
            URL="rtsp://${ENC_USER}:${ENC_PASS}@${cam}:${port}/stream1"
            echo "    RTSP stream: rtsp://${cam}:${port}"
            echo "      Full URL : $URL"
            RTSP_URLS+=("$URL")
        elif [[ "$port" == "443" || "$port" == "8443" ]]; then
            URL="https://${ENC_USER}:${ENC_PASS}@${cam}:${port}"
            echo "    Web login  : https://${cam}:${port}  ->  credentials embedded"
            if command -v xdg-open >/dev/null 2>&1; then
                xdg-open "$URL" >/dev/null 2>&1 &
            else
                echo "      (open manually: $URL)"
            fi
            WEB_COUNT=$((WEB_COUNT + 1))
            sleep 0.8
        else
            URL="http://${ENC_USER}:${ENC_PASS}@${cam}:${port}"
            echo "    Web login  : http://${cam}:${port}  ->  credentials embedded"
            if command -v xdg-open >/dev/null 2>&1; then
                xdg-open "$URL" >/dev/null 2>&1 &
            else
                echo "      (open manually: $URL)"
            fi
            WEB_COUNT=$((WEB_COUNT + 1))
            sleep 0.8
        fi
    done
    echo ""
done

# RTSP summary
if (( ${#RTSP_URLS[@]} > 0 )); then
    echo ""
    echo "RTSP streams found (open with VLC or media player):"
    for u in "${RTSP_URLS[@]}"; do echo "  $u"; done
fi

echo ""
echo "═══════════════════════════════════════════════════════"
echo "  Scan complete!"
echo "  Cameras found : ${#CAMERA_LIST[@]}"
echo "  URLs opened   : $WEB_COUNT"
echo "  RTSP streams  : ${#RTSP_URLS[@]}"
echo "═══════════════════════════════════════════════════════"
echo ""
echo "Credentials are embedded as http://user:pass@IP:port."
echo "Most IP cameras and NVRs that use HTTP Basic Auth will log in automatically."
echo "If a camera uses a custom form, paste credentials from camera_credentials.txt."
