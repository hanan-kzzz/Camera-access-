#!/data/data/com.termux/files/usr/bin/bash
# ═══════════════════════════════════════════════════════════════════
#  CCTV Auto-Finder for Termux (Advanced Mode)
#  • Scans network for devices
#  • Finds open camera ports
#  • Tests multiple username:password credentials
#  • Opens working login in browser
# ═══════════════════════════════════════════════════════════════════
set -Euo pipefail

# ─── Colors ───────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
GRAY='\033[1;30m'
BOLD='\033[1m'
WHITE='\033[1;37m'
NC='\033[0m'

# ─── Load Credential Pairs ───────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CRED_FILE="$SCRIPT_DIR/camera_credentials.txt"
if [[ ! -f "$CRED_FILE" ]]; then
    echo -e "${RED}Credentials file not found: $CRED_FILE${NC}"
    echo ""
    echo "Creating default credential list..."
    cat > "$CRED_FILE" << 'CRED_EOF'
# Camera Credentials List
# Add multiple username:password pairs, one per line.
# Format:  username:password

admin:admin
admin:12345
admin:password
admin:123456
root:root
root:admin
admin:
admin:888888
CRED_EOF
    echo -e "${GREEN}Created $CRED_FILE with common defaults${NC}"
fi

CRED_PAIRS=()
while IFS= read -r line; do
    line="$(echo "$line" | xargs 2>/dev/null || echo "$line")"
    [[ -z "$line" || "$line" == \#* ]] && continue
    CRED_PAIRS+=("$line")
done < "$CRED_FILE"

if (( ${#CRED_PAIRS[@]} == 0 )); then
    echo -e "${RED}No credentials found in $CRED_FILE${NC}"
    exit 1
fi

# ─── URL-encode ───────────────────────────────────────────────────
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

# ─── Check & Install Dependencies ────────────────────────────────
echo -e "${CYAN}Checking dependencies...${NC}"
MISSING=()
command -v nmap >/dev/null 2>&1 || MISSING+=("nmap")
command -v curl >/dev/null 2>&1 || MISSING+=("curl")
if ! command -v ifconfig >/dev/null 2>&1 && ! command -v ip >/dev/null 2>&1; then
    MISSING+=("net-tools")
fi

if (( ${#MISSING[@]} > 0 )); then
    echo -e "${YELLOW}Installing missing: ${MISSING[*]}${NC}"
    pkg update -y 2>/dev/null && pkg install -y "${MISSING[@]}" 2>/dev/null
fi

# ─── Detect Network ──────────────────────────────────────────────
MY_IP=""
CIDR=""
IFACE=""

if command -v ip >/dev/null 2>&1; then
    IFACE="$(ip route 2>/dev/null | awk '/default/ {print $5; exit}')"
    if [[ -n "$IFACE" ]]; then
        CIDR="$(ip -o -f inet addr show dev "$IFACE" 2>/dev/null | awk '{print $4; exit}')"
        MY_IP="$(echo "$CIDR" | cut -d/ -f1)"
    fi
fi

if [[ -z "$MY_IP" ]] && command -v ifconfig >/dev/null 2>&1; then
    for iface in wlan0 eth0 wlan1; do
        local_ip="$(ifconfig "$iface" 2>/dev/null | grep 'inet ' | awk '{print $2}' | sed 's/addr://')"
        if [[ -n "$local_ip" && "$local_ip" != "127.0.0.1" ]]; then
            MY_IP="$local_ip"
            IFACE="$iface"
            CIDR="${MY_IP}/24"
            break
        fi
    done
fi

if [[ -z "$MY_IP" ]]; then
    echo -e "${YELLOW}Could not detect network automatically.${NC}"
    read -r -p "Enter your phone's IP address (e.g. 192.168.1.100): " MY_IP
    if [[ -z "$MY_IP" ]]; then exit 1; fi
    CIDR="${MY_IP}/24"
    IFACE="manual"
fi

GW_IP=""
if command -v ip >/dev/null 2>&1; then
    GW_IP="$(ip route 2>/dev/null | awk '/default/ {print $3; exit}')"
fi
[[ -z "$GW_IP" ]] && GW_IP="$(echo "$MY_IP" | awk -F. '{print $1"."$2"."$3".1"}')"

# ─── Open URL helper ─────────────────────────────────────────────
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

# ═══════════════════════════════════════════════════════════════════
#  BANNER
# ═══════════════════════════════════════════════════════════════════
clear
echo ""
echo -e "${CYAN}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║   ${BOLD}${WHITE}📷 CCTV Auto-Finder — Termux (Advanced)${NC}${CYAN}              ║${NC}"
echo -e "${CYAN}╠══════════════════════════════════════════════════════════╣${NC}"
echo -e "${CYAN}║${NC}  Interface : ${BOLD}$IFACE${NC}"
echo -e "${CYAN}║${NC}  Your IP   : ${BOLD}$MY_IP${NC}"
echo -e "${CYAN}║${NC}  Network   : ${BOLD}$CIDR${NC}"
echo -e "${CYAN}║${NC}  Gateway   : ${BOLD}$GW_IP${NC}"
echo -e "${CYAN}║${NC}  Creds     : ${GREEN}${#CRED_PAIRS[@]} username:password pairs loaded${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""

# ═══════════════════════════════════════════════════════════════════
#  PHASE 1: NETWORK SCAN
# ═══════════════════════════════════════════════════════════════════
echo -e "${YELLOW}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}${BOLD}  PHASE 1: NETWORK SCAN${NC}"
echo -e "${YELLOW}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GRAY}  Scanning $CIDR for live devices...${NC}"
echo ""

SCAN="$(nmap -sn -n "$CIDR" 2>/dev/null)"
mapfile -t RAW_HOSTS < <(printf '%s\n' "$SCAN" | awk '/Nmap scan report for / {print $NF}' | tr -d '()')

HOSTS=()
for h in "${RAW_HOSTS[@]}"; do
    [[ "$h" == "$MY_IP" || "$h" == "$GW_IP" ]] && continue
    HOSTS+=("$h")
done

if (( ${#HOSTS[@]} == 0 )); then
    echo ""
    echo -e "${RED}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║  [!] NO OTHER DEVICES DETECTED ON THIS WI-FI            ║${NC}"
    echo -e "${RED}╚══════════════════════════════════════════════════════════╝${NC}"
    echo -e "${YELLOW}  No responding devices found on subnet: $CIDR${NC}"
    echo ""
    echo -e "${CYAN}  Troubleshooting:${NC}"
    echo "  1. Make sure your phone is connected to the same Wi-Fi as your camera."
    echo "  2. If using mobile hotspot or guest Wi-Fi, connect to your main home Wi-Fi."
    echo "  3. Check if your camera is powered on and connected."
    echo ""
    exit 0
fi

echo -e "  ${GREEN}✓ Found ${BOLD}${#HOSTS[@]}${NC}${GREEN} device(s) on network:${NC}"
echo ""
for i in "${!HOSTS[@]}"; do
    echo -e "    ${WHITE}[$((i+1))]${NC} ${HOSTS[$i]}"
done
echo ""

# ═══════════════════════════════════════════════════════════════════
#  PHASE 2: PORT SCAN
# ═══════════════════════════════════════════════════════════════════
echo -e "${YELLOW}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}${BOLD}  PHASE 2: PORT SCAN${NC}"
echo -e "${YELLOW}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GRAY}  Checking ports: 80, 443, 554, 8080, 8443, 37777${NC}"
echo ""

declare -A CAMERA_PORTS
CAMERA_LIST=()

for h in "${HOSTS[@]}"; do
    echo -ne "  Scanning ${WHITE}$h${NC} ..."
    RESULT="$(nmap -n -sT --open -p 80,443,554,8080,8443,37777 "$h" 2>/dev/null)"
    mapfile -t PORTS < <(printf '%s\n' "$RESULT" | awk '/^[0-9]+\/tcp[[:space:]]+open/ {split($1,p,"/"); print p[1]}')
    if (( ${#PORTS[@]} > 0 )); then
        PORT_LIST="$(IFS=', '; echo "${PORTS[*]}")"
        echo -e " ${GREEN}✓ OPEN PORTS: ${BOLD}$PORT_LIST${NC}"
        CAMERA_PORTS["$h"]="${PORTS[*]}"
        CAMERA_LIST+=("$h")
    else
        echo -e " ${GRAY}✗ no camera ports${NC}"
    fi
done
echo ""

if (( ${#CAMERA_LIST[@]} == 0 )); then
    echo ""
    echo -e "${RED}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║  [X] NO CAMERAS FOUND ON THIS WI-FI NETWORK             ║${NC}"
    echo -e "${RED}╚══════════════════════════════════════════════════════════╝${NC}"
    echo -e "${YELLOW}  Scanned ${#HOSTS[@]} device(s) on your Wi-Fi, but none of them${NC}"
    echo -e "${YELLOW}  have open CCTV / camera web ports (80, 443, 554, 8080, 8443, 37777).${NC}"
    echo ""
    echo -e "${CYAN}  Possible reasons:${NC}"
    echo "  1. Camera is connected to a different Wi-Fi network or frequency (2.4 GHz vs 5 GHz)."
    echo "  2. Camera is plugged into an isolated PoE NVR port."
    echo "  3. Camera is offline or using non-standard ports."
    echo "  4. Router has client isolation enabled (blocking phone-to-camera traffic)."
    echo ""
    exit 0
fi

echo -e "  ${GREEN}✓ ${BOLD}${#CAMERA_LIST[@]}${NC}${GREEN} potential camera(s) found${NC}"
echo ""

# ═══════════════════════════════════════════════════════════════════
#  PHASE 3: CREDENTIAL CHECK
# ═══════════════════════════════════════════════════════════════════
echo -e "${YELLOW}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}${BOLD}  PHASE 3: CREDENTIAL CHECK${NC}"
echo -e "${YELLOW}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GRAY}  Testing ${#CRED_PAIRS[@]} credential pairs against each camera...${NC}"
echo ""

WORKING_URLS=()
RTSP_URLS=()
TOTAL_TESTED=0
TOTAL_SUCCESS=0

for cam in "${CAMERA_LIST[@]}"; do
    echo -e "  ${CYAN}${BOLD}📷 Camera: $cam${NC}"
    read -ra ports <<< "${CAMERA_PORTS[$cam]}"

    for port in "${ports[@]}"; do
        if [[ "$port" == "554" ]]; then
            echo -e "    ${MAGENTA}🎥 Port $port (RTSP stream)${NC}"
            # Test RTSP credentials
            RTSP_FOUND=false
            for cred in "${CRED_PAIRS[@]}"; do
                user="${cred%%:*}"
                pass="${cred#*:}"
                enc_u="$(urlencode "$user")"
                enc_p="$(urlencode "$pass")"
                RTSP_URL="rtsp://${enc_u}:${enc_p}@${cam}:${port}/stream1"
                echo -ne "       Testing ${WHITE}${user}:${pass}${NC} ... "
                TOTAL_TESTED=$((TOTAL_TESTED + 1))
                # Can't easily test RTSP with curl, just list it
                echo -e "${YELLOW}listed${NC}"
                if [[ "$RTSP_FOUND" == "false" ]]; then
                    RTSP_URLS+=("$RTSP_URL|$user|$pass")
                    RTSP_FOUND=true
                fi
            done
            continue
        fi

        # Determine HTTP or HTTPS
        if [[ "$port" == "443" || "$port" == "8443" ]]; then
            SCHEME="https"
        else
            SCHEME="http"
        fi

        echo -e "    ${GREEN}🌐 Port $port ($SCHEME)${NC}"
        FOUND_WORKING=false

        for cred in "${CRED_PAIRS[@]}"; do
            user="${cred%%:*}"
            pass="${cred#*:}"
            TOTAL_TESTED=$((TOTAL_TESTED + 1))

            echo -ne "       Testing ${WHITE}${user}:${pass}${NC} ... "

            # Try HTTP Basic Auth with curl
            HTTP_CODE="$(curl -s -o /dev/null -w '%{http_code}' \
                --max-time 5 \
                --connect-timeout 3 \
                -u "${user}:${pass}" \
                -k \
                "${SCHEME}://${cam}:${port}/" 2>/dev/null || echo "000")"

            if [[ "$HTTP_CODE" == "200" || "$HTTP_CODE" == "301" || "$HTTP_CODE" == "302" || "$HTTP_CODE" == "304" ]]; then
                echo -e "${GREEN}${BOLD}✓ SUCCESS (HTTP $HTTP_CODE)${NC}"
                enc_u="$(urlencode "$user")"
                enc_p="$(urlencode "$pass")"
                WORKING_URLS+=("${SCHEME}://${enc_u}:${enc_p}@${cam}:${port}|$user|$pass")
                TOTAL_SUCCESS=$((TOTAL_SUCCESS + 1))
                FOUND_WORKING=true
                break  # Found working cred, stop testing this port
            elif [[ "$HTTP_CODE" == "401" || "$HTTP_CODE" == "403" ]]; then
                echo -e "${RED}✗ DENIED (HTTP $HTTP_CODE)${NC}"
            elif [[ "$HTTP_CODE" == "000" ]]; then
                echo -e "${GRAY}✗ NO RESPONSE${NC}"
            else
                echo -e "${YELLOW}? HTTP $HTTP_CODE${NC}"
            fi
        done

        if [[ "$FOUND_WORKING" == "false" ]]; then
            echo -e "       ${RED}${BOLD}✗ No working credentials found for port $port${NC}"
        fi
    done
    echo ""
done

# ═══════════════════════════════════════════════════════════════════
#  PHASE 4: RESULTS & AUTO-OPEN
# ═══════════════════════════════════════════════════════════════════
echo -e "${YELLOW}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}${BOLD}  PHASE 4: RESULTS${NC}"
echo -e "${YELLOW}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

if (( ${#WORKING_URLS[@]} > 0 )); then
    echo -e "  ${GREEN}${BOLD}✓ WORKING CAMERAS:${NC}"
    echo ""
    for entry in "${WORKING_URLS[@]}"; do
        url="${entry%%|*}"
        rest="${entry#*|}"
        user="${rest%%|*}"
        pass="${rest#*|}"
        # Extract IP:port from URL
        plain="$(echo "$url" | sed 's|.*@||')"
        echo -e "    ${GREEN}📷 ${BOLD}$plain${NC}"
        echo -e "       Username: ${WHITE}$user${NC}"
        echo -e "       Password: ${WHITE}$pass${NC}"
        echo -e "       URL: ${GRAY}$url${NC}"
        echo ""
    done

    echo -e "  ${GREEN}Opening ${#WORKING_URLS[@]} camera(s) in browser...${NC}"
    for entry in "${WORKING_URLS[@]}"; do
        url="${entry%%|*}"
        open_url "$url"
        sleep 1
    done
fi

if (( ${#RTSP_URLS[@]} > 0 )); then
    echo ""
    echo -e "  ${MAGENTA}${BOLD}🎥 RTSP STREAMS:${NC}"
    echo ""
    for entry in "${RTSP_URLS[@]}"; do
        url="${entry%%|*}"
        rest="${entry#*|}"
        user="${rest%%|*}"
        pass="${rest#*|}"
        echo -e "    ${MAGENTA}$url${NC}"
    done
    echo -e "    ${GRAY}Open with VLC: pkg install vlc${NC}"
fi

if (( ${#WORKING_URLS[@]} == 0 && ${#RTSP_URLS[@]} == 0 )); then
    echo -e "  ${RED}${BOLD}✗ No working credentials found for any camera.${NC}"
    echo -e "  ${YELLOW}Add more credentials to: camera_credentials.txt${NC}"
    echo -e "  ${YELLOW}Format: username:password (one per line)${NC}"
fi

# ─── Summary ─────────────────────────────────────────────────────
echo ""
echo -e "${CYAN}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║  ${BOLD}${WHITE}SCAN COMPLETE${NC}${CYAN}                                            ║${NC}"
echo -e "${CYAN}╠══════════════════════════════════════════════════════════╣${NC}"
echo -e "${CYAN}║${NC}  📡 Devices scanned   : ${BOLD}${#HOSTS[@]}${NC}"
echo -e "${CYAN}║${NC}  📷 Cameras found     : ${BOLD}${#CAMERA_LIST[@]}${NC}"
echo -e "${CYAN}║${NC}  🔑 Credentials tested: ${BOLD}$TOTAL_TESTED${NC}"
echo -e "${CYAN}║${NC}  ✅ Successful logins : ${BOLD}${GREEN}$TOTAL_SUCCESS${NC}"
echo -e "${CYAN}║${NC}  🎥 RTSP streams      : ${BOLD}${#RTSP_URLS[@]}${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""
