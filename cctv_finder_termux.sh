#!/data/data/com.termux/files/usr/bin/bash
# Advanced CCTV Finder for Termux (Android)
# Discovers ALL cameras on your LAN, checks web ports, and opens login pages
# with credentials auto-embedded in the URL.
set -Eeuo pipefail

# ─── Colors ───────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
GRAY='\033[1;30m'
BOLD='\033[1m'
NC='\033[0m'

# ─── Load Credentials ────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CRED_FILE="$SCRIPT_DIR/camera_credentials.txt"
if [[ ! -f "$CRED_FILE" ]]; then
    echo -e "${RED}Credentials file not found: $CRED_FILE${NC}"
    echo ""
    echo "Create it now? A template will be generated."
    read -r -p "Create camera_credentials.txt? [Y/n] " CREATE
    if [[ ! "$CREATE" =~ ^[Nn]$ ]]; then
        cat > "$CRED_FILE" << 'CRED_EOF'
# Camera Credentials
# Fill in your camera username and password below.

username=admin
password=admin
CRED_EOF
        echo -e "${GREEN}Created $CRED_FILE with default admin/admin${NC}"
        echo -e "${YELLOW}Edit it with: nano $CRED_FILE${NC}"
        echo ""
    else
        echo "Create camera_credentials.txt with:"
        echo "  username=YOUR_CAMERA_USERNAME"
        echo "  password=YOUR_CAMERA_PASSWORD"
        exit 1
    fi
fi

CAM_USER=""
CAM_PASS=""
while IFS='=' read -r key value; do
    key="$(echo "$key" | xargs 2>/dev/null || echo "$key")"
    value="$(echo "$value" | xargs 2>/dev/null || echo "$value")"
    [[ -z "$key" || "$key" == \#* ]] && continue
    case "$key" in
        username) CAM_USER="$value" ;;
        password) CAM_PASS="$value" ;;
    esac
done < "$CRED_FILE"
if [[ -z "$CAM_USER" || -z "$CAM_PASS" ]]; then
    echo -e "${RED}Invalid credentials file. Ensure it contains username=... and password=...${NC}"
    exit 1
fi

# ─── URL-encode function ─────────────────────────────────────────────
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

# ─── Check & Install Dependencies ────────────────────────────────────
echo -e "${CYAN}Checking dependencies...${NC}"
MISSING=()
if ! command -v nmap >/dev/null 2>&1; then MISSING+=("nmap"); fi
if ! command -v ifconfig >/dev/null 2>&1 && ! command -v ip >/dev/null 2>&1; then
    MISSING+=("net-tools")
fi

if (( ${#MISSING[@]} > 0 )); then
    echo -e "${YELLOW}Missing packages: ${MISSING[*]}${NC}"
    echo "Installing..."
    pkg update -y 2>/dev/null && pkg install -y "${MISSING[@]}" 2>/dev/null
    if [[ $? -ne 0 ]]; then
        echo -e "${RED}Failed to install. Run manually:${NC}"
        echo "  pkg update && pkg install ${MISSING[*]}"
        exit 1
    fi
    echo -e "${GREEN}Dependencies installed!${NC}"
fi

# Check for termux-open-url (from termux-api)
HAS_OPEN=false
if command -v termux-open-url >/dev/null 2>&1; then
    HAS_OPEN=true
elif command -v xdg-open >/dev/null 2>&1; then
    HAS_OPEN=true
elif command -v am >/dev/null 2>&1; then
    # Android 'am' command as fallback
    HAS_OPEN=true
fi

# ─── Detect Network ──────────────────────────────────────────────────
MY_IP=""
CIDR=""
IFACE=""

# Method 1: ip command (if iproute2 is installed)
if command -v ip >/dev/null 2>&1; then
    IFACE="$(ip route 2>/dev/null | awk '/default/ {print $5; exit}')"
    if [[ -n "$IFACE" ]]; then
        CIDR="$(ip -o -f inet addr show dev "$IFACE" 2>/dev/null | awk '{print $4; exit}')"
        MY_IP="$(echo "$CIDR" | cut -d/ -f1)"
    fi
fi

# Method 2: ifconfig fallback (net-tools)
if [[ -z "$MY_IP" ]] && command -v ifconfig >/dev/null 2>&1; then
    # Try wlan0 first (Wi-Fi on Android), then any interface with an IP
    for iface in wlan0 eth0 wlan1; do
        local_ip="$(ifconfig "$iface" 2>/dev/null | grep 'inet ' | awk '{print $2}' | sed 's/addr://')"
        if [[ -n "$local_ip" && "$local_ip" != "127.0.0.1" ]]; then
            MY_IP="$local_ip"
            IFACE="$iface"
            # Assume /24 subnet if we can't determine prefix
            CIDR="${MY_IP}/24"
            break
        fi
    done
fi

# Method 3: Parse /proc/net/route + getprop
if [[ -z "$MY_IP" ]]; then
    # Try Android getprop for Wi-Fi
    if command -v getprop >/dev/null 2>&1; then
        MY_IP="$(getprop dhcp.wlan0.ipaddress 2>/dev/null || echo "")"
        if [[ -n "$MY_IP" ]]; then
            IFACE="wlan0"
            CIDR="${MY_IP}/24"
        fi
    fi
fi

if [[ -z "$MY_IP" || -z "$CIDR" ]]; then
    echo -e "${RED}Could not detect your network.${NC}"
    echo "Make sure you are connected to Wi-Fi."
    echo ""
    read -r -p "Enter your phone's IP address manually (e.g. 192.168.1.100): " MY_IP
    if [[ -z "$MY_IP" ]]; then exit 1; fi
    CIDR="${MY_IP}/24"
    IFACE="manual"
fi

# Calculate gateway (assume .1 if we can't find it)
GW_IP=""
if command -v ip >/dev/null 2>&1; then
    GW_IP="$(ip route 2>/dev/null | awk '/default/ {print $3; exit}')"
fi
if [[ -z "$GW_IP" ]]; then
    GW_IP="$(echo "$MY_IP" | awk -F. '{print $1"."$2"."$3".1"}')"
fi

# ─── Banner ───────────────────────────────────────────────────────────
echo ""
echo -e "${CYAN}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║     ${BOLD}CCTV Auto-Finder — Termux (Advanced)${NC}${CYAN}          ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════╝${NC}"
echo -e "  Interface : ${BOLD}$IFACE${NC}"
echo -e "  Your IP   : ${BOLD}$MY_IP${NC}"
echo -e "  Network   : ${BOLD}$CIDR${NC}"
echo -e "  Gateway   : ${BOLD}$GW_IP${NC}"
echo -e "  Creds     : ${GREEN}loaded from camera_credentials.txt${NC}"
echo ""

# ─── Open URL helper ─────────────────────────────────────────────────
open_url() {
    local url="$1"
    if command -v termux-open-url >/dev/null 2>&1; then
        termux-open-url "$url" 2>/dev/null &
    elif command -v am >/dev/null 2>&1; then
        am start -a android.intent.action.VIEW -d "$url" >/dev/null 2>&1 &
    elif command -v xdg-open >/dev/null 2>&1; then
        xdg-open "$url" >/dev/null 2>&1 &
    else
        return 1
    fi
    return 0
}

# ─── Discover Hosts ───────────────────────────────────────────────────
echo -e "${YELLOW}[1/3] Scanning network for devices...${NC}"
echo -e "${GRAY}       (this may take 15-30 seconds on Wi-Fi)${NC}"
SCAN="$(nmap -sn -n "$CIDR" 2>/dev/null)"
mapfile -t RAW_HOSTS < <(printf '%s\n' "$SCAN" | awk '/Nmap scan report for / {print $NF}' | tr -d '()')

# Filter out our own IP and the gateway
HOSTS=()
for h in "${RAW_HOSTS[@]}"; do
    [[ "$h" == "$MY_IP" || "$h" == "$GW_IP" ]] && continue
    HOSTS+=("$h")
done

if (( ${#HOSTS[@]} == 0 )); then
    echo -e "${YELLOW}No devices found (other than this phone and the gateway).${NC}"
    echo "Make sure your phone and cameras are on the same Wi-Fi network."
    exit 0
fi
echo -e "  ${GREEN}Found ${#HOSTS[@]} device(s):${NC}"
for h in "${HOSTS[@]}"; do echo "    - $h"; done
echo ""

# ─── Port-Scan Each Host ─────────────────────────────────────────────
echo -e "${YELLOW}[2/3] Scanning for camera ports (80, 443, 554, 8080, 8443, 37777)...${NC}"
declare -A CAMERA_PORTS
CAMERA_LIST=()
for h in "${HOSTS[@]}"; do
    printf "  Scanning %s ..." "$h"
    RESULT="$(nmap -n -sT --open -p 80,443,554,8080,8443,37777 "$h" 2>/dev/null)"
    mapfile -t PORTS < <(printf '%s\n' "$RESULT" | awk '/^[0-9]+\/tcp[[:space:]]+open/ {split($1,p,"/"); print p[1]}')
    if (( ${#PORTS[@]} > 0 )); then
        echo -e " ${GREEN}CAMERA FOUND (ports: $(IFS=,; echo "${PORTS[*]}"))${NC}"
        CAMERA_PORTS["$h"]="${PORTS[*]}"
        CAMERA_LIST+=("$h")
    else
        echo -e " ${GRAY}no camera ports${NC}"
    fi
done
echo ""

if (( ${#CAMERA_LIST[@]} == 0 )); then
    echo -e "${YELLOW}No devices with camera web-interface ports found.${NC}"
    exit 0
fi

# ─── Build URLs & Open ───────────────────────────────────────────────
echo -e "${YELLOW}[3/3] Opening camera login pages with auto-credentials...${NC}"
echo ""

WEB_COUNT=0
RTSP_URLS=()
ALL_WEB_URLS=()

for cam in "${CAMERA_LIST[@]}"; do
    echo -e "  ${CYAN}📷 Camera: $cam${NC}"
    read -ra ports <<< "${CAMERA_PORTS[$cam]}"
    for port in "${ports[@]}"; do
        if [[ "$port" == "554" ]]; then
            URL="rtsp://${ENC_USER}:${ENC_PASS}@${cam}:${port}/stream1"
            echo -e "    ${MAGENTA}🎥 RTSP stream: rtsp://${cam}:${port}${NC}"
            echo "      Full URL : $URL"
            RTSP_URLS+=("$URL")
        elif [[ "$port" == "443" || "$port" == "8443" ]]; then
            URL="https://${ENC_USER}:${ENC_PASS}@${cam}:${port}"
            PLAIN="https://${cam}:${port}"
            echo -e "    ${GREEN}🔐 Web login: $PLAIN  →  credentials embedded${NC}"
            ALL_WEB_URLS+=("$URL")
            WEB_COUNT=$((WEB_COUNT + 1))
        else
            URL="http://${ENC_USER}:${ENC_PASS}@${cam}:${port}"
            PLAIN="http://${cam}:${port}"
            echo -e "    ${GREEN}🌐 Web login: $PLAIN  →  credentials embedded${NC}"
            ALL_WEB_URLS+=("$URL")
            WEB_COUNT=$((WEB_COUNT + 1))
        fi
    done
    echo ""
done

# Open all web URLs in Android browser
if (( ${#ALL_WEB_URLS[@]} > 0 )); then
    if [[ "$HAS_OPEN" == "true" ]]; then
        echo -e "${GREEN}Opening $WEB_COUNT camera page(s) in your browser...${NC}"
        for url in "${ALL_WEB_URLS[@]}"; do
            open_url "$url"
            sleep 1
        done
    else
        echo -e "${YELLOW}Could not auto-open browser. Install termux-api for auto-open:${NC}"
        echo "  pkg install termux-api"
        echo ""
        echo "Open these URLs manually in your browser:"
        for url in "${ALL_WEB_URLS[@]}"; do
            echo "  $url"
        done
    fi
fi

# RTSP summary
if (( ${#RTSP_URLS[@]} > 0 )); then
    echo ""
    echo -e "${MAGENTA}🎥 RTSP streams (open with VLC for Android):${NC}"
    for u in "${RTSP_URLS[@]}"; do echo "  $u"; done
fi

# ─── Summary ─────────────────────────────────────────────────────────
echo ""
echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
echo -e "  ${GREEN}${BOLD}Scan complete!${NC}"
echo -e "  📷 Cameras found : ${BOLD}${#CAMERA_LIST[@]}${NC}"
echo -e "  🌐 URLs opened   : ${BOLD}$WEB_COUNT${NC}"
echo -e "  🎥 RTSP streams  : ${BOLD}${#RTSP_URLS[@]}${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
echo ""
echo "Credentials are embedded as http://user:pass@IP:port."
echo "Most cameras using HTTP Basic Auth will log in automatically."
echo ""
echo -e "${GRAY}Tip: For RTSP streams, install VLC: pkg install vlc${NC}"
echo -e "${GRAY}     Play with: cvlc rtsp://user:pass@IP:554/stream1${NC}"
