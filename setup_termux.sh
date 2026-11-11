#!/data/data/com.termux/files/usr/bin/bash
# Quick setup script for CCTV Finder on Termux
# Run this once after cloning the repo.

echo "╔══════════════════════════════════════════════════════╗"
echo "║     CCTV Auto-Finder — Termux Setup                 ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""

echo "[1/4] Updating packages..."
pkg update -y

echo ""
echo "[2/4] Installing dependencies (nmap, net-tools, termux-api)..."
pkg install -y nmap net-tools termux-api

echo ""
echo "[3/4] Making scripts executable..."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
chmod +x "$SCRIPT_DIR/cctv_finder_termux.sh"
chmod +x "$SCRIPT_DIR/cctv_finder_ubuntu.sh"

echo ""
echo "[4/4] Setting up credentials file..."
CRED_FILE="$SCRIPT_DIR/camera_credentials.txt"
if [[ ! -f "$CRED_FILE" ]]; then
    cat > "$CRED_FILE" << 'EOF'
# Camera Credentials
# Fill in your camera username and password below.

username=admin
password=admin
EOF
    echo "Created camera_credentials.txt with default admin/admin"
    echo "Edit with: nano $CRED_FILE"
else
    echo "camera_credentials.txt already exists — skipping."
fi

echo ""
echo "═══════════════════════════════════════════════════════"
echo "  Setup complete! ✅"
echo ""
echo "  1. Edit credentials:"
echo "     nano camera_credentials.txt"
echo ""
echo "  2. Connect to same Wi-Fi as your cameras"
echo ""
echo "  3. Run the scanner:"
echo "     ./cctv_finder_termux.sh"
echo "═══════════════════════════════════════════════════════"
