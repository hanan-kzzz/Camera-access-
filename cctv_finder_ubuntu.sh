#!/usr/bin/env bash
# CCTV Finder for Ubuntu: discover devices on your own LAN and check common web ports.
set -Eeuo pipefail

for cmd in nmap ip; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "$cmd is required. Install with: sudo apt update && sudo apt install nmap iproute2"
    exit 1
  fi
done

IFACE="$(ip route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="dev"){print $(i+1); exit}}')"
if [[ -z "$IFACE" ]]; then
  echo "No active network interface found. Connect to the same LAN/Wi-Fi as your camera."
  exit 1
fi
CIDR="$(ip -o -f inet addr show dev "$IFACE" | awk '{print $4; exit}')"
if [[ -z "$CIDR" ]]; then
  echo "Could not determine the IPv4 network range."
  exit 1
fi

echo "CCTV Finder for Ubuntu"
echo "Interface: $IFACE | Network: $CIDR"
echo "Discovering devices on your local network..."
SCAN="$(nmap -sn -n "$CIDR")"
mapfile -t HOSTS < <(printf '%s\n' "$SCAN" | awk '/Nmap scan report for / {print $NF}' | tr -d '()')

if (("${#HOSTS[@]}" == 0)); then
  echo "No responding devices found."
  exit 0
fi

echo
echo "Devices found:"
for i in "${!HOSTS[@]}"; do
  printf "  %2d) %s\n" "$((i+1))" "${HOSTS[$i]}"
done

echo
read -r -p "Select the number of your own camera/NVR (0 to exit): " PICK
[[ "$PICK" == "0" ]] && exit 0
if ! [[ "$PICK" =~ ^[0-9]+$ ]] || (( PICK < 1 || PICK > ${#HOSTS[@]} )); then
  echo "Invalid selection."
  exit 1
fi

IP="${HOSTS[$((PICK-1))]}"
echo
echo "Checking common web-interface ports on $IP..."
RESULT="$(nmap -n -sT -sV --version-light -p 80,443,8080,8443 "$IP")"
printf '%s\n' "$RESULT"
mapfile -t PORTS < <(printf '%s\n' "$RESULT" | awk '/^[0-9]+\/tcp[[:space:]]+open/ {split($1,p,"/"); print p[1]}')

if (("${#PORTS[@]}" == 0)); then
  echo "No common web-login port found. The device may use another port or an NVR/app."
  exit 0
fi

echo
echo "Possible browser addresses:"
URLS=()
for p in "${PORTS[@]}"; do
  if [[ "$p" == "443" || "$p" == "8443" ]]; then
    URL="https://$IP:$p"
  else
    URL="http://$IP:$p"
  fi
  URLS+=("$URL")
  echo "  $URL"
done

read -r -p "Open the first address in your browser? [y/N] " OPEN
if [[ "$OPEN" =~ ^[Yy]$ ]]; then
  if command -v xdg-open >/dev/null 2>&1; then
    xdg-open "${URLS[0]}" >/dev/null 2>&1 &
  else
    echo "Open this address manually: ${URLS[0]}"
  fi
fi

echo
echo "Done. This script only discovers devices and checks common ports."
echo "It does not guess passwords, bypass authentication, or change camera settings."
