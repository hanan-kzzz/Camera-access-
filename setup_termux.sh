#!/data/data/com.termux/files/usr/bin/bash
# ═══════════════════════════════════════════════════════════════════
#  CCTV Auto-Finder — Termux Setup
#  Run this once after cloning the repo.
#  Installs all dependencies and sets up credential file.
# ═══════════════════════════════════════════════════════════════════

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

echo ""
echo -e "${CYAN}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║   ${BOLD}CCTV Auto-Finder — Termux Setup${NC}${CYAN}                       ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""

# ─── Step 1: Update packages ─────────────────────────────────────
echo -e "${YELLOW}[1/5] Updating packages...${NC}"
pkg update -y 2>/dev/null
echo -e "${GREEN}  ✓ Done${NC}"

# ─── Step 2: Install dependencies ────────────────────────────────
echo ""
echo -e "${YELLOW}[2/5] Installing dependencies...${NC}"
echo "  → nmap (network scanner)"
echo "  → net-tools (ifconfig)"
echo "  → curl (credential testing)"
echo "  → termux-api (open browser)"
echo ""
pkg install -y nmap net-tools curl termux-api 2>/dev/null
if [[ $? -eq 0 ]]; then
    echo -e "${GREEN}  ✓ All packages installed${NC}"
else
    echo -e "${YELLOW}  ⚠ Some packages may have failed. Run manually:${NC}"
    echo "    pkg install nmap net-tools curl termux-api"
fi

# ─── Step 3: Make scripts executable ─────────────────────────────
echo ""
echo -e "${YELLOW}[3/5] Making scripts executable...${NC}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
chmod +x "$SCRIPT_DIR/cctv_finder_termux.sh" 2>/dev/null
chmod +x "$SCRIPT_DIR/cctv_finder_ubuntu.sh" 2>/dev/null
echo -e "${GREEN}  ✓ cctv_finder_termux.sh${NC}"
echo -e "${GREEN}  ✓ cctv_finder_ubuntu.sh${NC}"

# ─── Step 4: Setup credentials file ──────────────────────────────
echo ""
echo -e "${YELLOW}[4/5] Setting up credentials file...${NC}"
CRED_FILE="$SCRIPT_DIR/camera_credentials.txt"
if [[ ! -f "$CRED_FILE" ]]; then
    cat > "$CRED_FILE" << 'EOF'
# Camera Credentials List
# Add multiple username:password pairs, one per line.
# The scanner will try each one and show which works.
# Lines starting with # are ignored.

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
EOF
    echo -e "${GREEN}  ✓ Created camera_credentials.txt with 11 common defaults${NC}"
else
    # Count credential pairs
    COUNT=$(grep -v '^\s*#' "$CRED_FILE" | grep -v '^\s*$' | wc -l)
    echo -e "${GREEN}  ✓ camera_credentials.txt already exists ($COUNT credential pairs)${NC}"
fi

# ─── Step 5: Verify installation ─────────────────────────────────
echo ""
echo -e "${YELLOW}[5/5] Verifying installation...${NC}"
ALL_OK=true
for cmd in nmap curl; do
    if command -v "$cmd" >/dev/null 2>&1; then
        echo -e "  ${GREEN}✓ $cmd installed${NC}"
    else
        echo -e "  ${RED}✗ $cmd NOT found${NC}"
        ALL_OK=false
    fi
done
if command -v ifconfig >/dev/null 2>&1 || command -v ip >/dev/null 2>&1; then
    echo -e "  ${GREEN}✓ network tools installed${NC}"
else
    echo -e "  ${RED}✗ network tools NOT found${NC}"
    ALL_OK=false
fi
if command -v termux-open-url >/dev/null 2>&1; then
    echo -e "  ${GREEN}✓ termux-api installed (auto-open browser)${NC}"
else
    echo -e "  ${YELLOW}⚠ termux-api not found (URLs will be printed instead)${NC}"
fi

# ─── Done ─────────────────────────────────────────────────────────
echo ""
if [[ "$ALL_OK" == "true" ]]; then
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║  ${GREEN}${BOLD}Setup complete! ✅${NC}${CYAN}                                     ║${NC}"
    echo -e "${CYAN}╠══════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}  ${BOLD}Step 1:${NC} Edit your credentials (add more passwords):"
    echo -e "${CYAN}║${NC}    nano camera_credentials.txt"
    echo -e "${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}  ${BOLD}Step 2:${NC} Connect to same Wi-Fi as your cameras"
    echo -e "${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}  ${BOLD}Step 3:${NC} Run the scanner:"
    echo -e "${CYAN}║${NC}    ./cctv_finder_termux.sh"
    echo -e "${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}  The scanner will test every username:password pair"
    echo -e "${CYAN}║${NC}  against each camera and show which ones work."
    echo -e "${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════╝${NC}"
else
    echo -e "${RED}${BOLD}Setup incomplete — some packages failed to install.${NC}"
    echo "Run manually: pkg install nmap net-tools curl termux-api"
fi
echo ""
