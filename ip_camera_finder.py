#!/usr/bin/env python3
"""
IP Camera Finder — authorized local-network discovery only.

Checks only RTSP ports 554 and 8554 on a user-supplied private IPv4 subnet.
It does not attempt logins, guess passwords, enumerate stream paths, or access video.
"""
import concurrent.futures
import ipaddress
import platform
import re
import socket
import subprocess
import sys

RTSP_PORTS = (554, 8554)
MAX_HOSTS = 254

def run_cmd(args):
    try:
        return subprocess.run(args, capture_output=True, text=True, timeout=5).stdout
    except Exception:
        return ""

def detect_network():
    system = platform.system().lower()
    if "windows" in system:
        out = run_cmd(["ipconfig"])
        ip_match = re.search(r"IPv4 Address[ .]*:\s*([\d.]+)", out, re.I)
        mask_match = re.search(r"Subnet Mask[ .]*:\s*([\d.]+)", out, re.I)
        if ip_match and mask_match:
            try:
                return str(ipaddress.IPv4Network(
                    f"{ip_match.group(1)}/{mask_match.group(1)}", strict=False))
            except ValueError:
                pass
    elif "android" in system or "linux" in system:
        ip = run_cmd(["getprop", "dhcp.wlan0.ipaddress"]).strip()
        if not ip:
            found = run_cmd(["sh", "-c", "hostname -I 2>/dev/null"]).strip().split()
            ip = found[0] if found else ""
        if ip:
            try:
                return str(ipaddress.IPv4Network(f"{ip}/24", strict=False))
            except ValueError:
                pass
    else:
        out = run_cmd(["ifconfig"])
        match = re.search(r"\binet\s+(\d+\.\d+\.\d+\.\d+)", out)
        if match:
            try:
                return str(ipaddress.IPv4Network(f"{match.group(1)}/24", strict=False))
            except ValueError:
                pass
    return None

def check_host(ip):
    found = []
    for port in RTSP_PORTS:
        try:
            with socket.create_connection((str(ip), port), timeout=0.35):
                found.append(port)
        except OSError:
            pass
    return str(ip), found

def main():
    print("=" * 58)
    print("             IP CAMERA FINDER")
    print("       Windows | Linux | Ubuntu | Termux | macOS")
    print("=" * 58)
    print("\nThis tool checks ONLY RTSP ports 554 and 8554 on a")
    print("private IPv4 subnet that you specify.")
    print("It does not log in, guess passwords, or open camera feeds.\n")

    detected = detect_network()
    if detected:
        print(f"Possible local network detected: {detected}")
    else:
        print("Could not detect the network automatically.")
        print("On Android, check Settings > Wi-Fi > Connected network.")
        print("On Windows, run ipconfig; on Linux, check network settings.")

    subnet_text = input(
        "\nEnter your private Wi-Fi subnet (example 192.168.1.0/24)"
        + (f" [{detected}]" if detected else "")
        + ": "
    ).strip() or (detected or "")

    try:
        network = ipaddress.ip_network(subnet_text, strict=False)
        if not isinstance(network, ipaddress.IPv4Network):
            raise ValueError("IPv4 only")
        if not network.is_private:
            print("For safety, only private IPv4 networks are allowed.")
            return
        if network.num_addresses > MAX_HOSTS + 2:
            print("Subnet is too large. Please enter a /24 or smaller network.")
            return
    except ValueError as exc:
        print(f"Invalid subnet: {exc}")
        return

    print(f"\nSelected network: {network}")
    confirm = input(
        "Do you own this network or have permission to scan it? Type YES: "
    ).strip()
    if confirm != "YES":
        print("Permission not confirmed. Scan cancelled.")
        return

    hosts = list(network.hosts())
    print(f"\nChecking {len(hosts)} addresses on ports {RTSP_PORTS}...")
    results = []
    with concurrent.futures.ThreadPoolExecutor(max_workers=64) as pool:
        for ip, ports in pool.map(check_host, hosts):
            if ports:
                results.append((ip, ports))
                print(f"[RTSP PORT RESPONDS] {ip}  ports: {', '.join(map(str, ports))}")

    print("\n" + "=" * 58)
    if not results:
        print("No devices responded on the checked RTSP ports.")
        print("The camera may use another port, be on another network,")
        print("or have RTSP disabled. This result does not prove no camera exists.")
    else:
        print("Possible RTSP devices:")
        for ip, ports in results:
            print(f"  IP: {ip} | RTSP port(s): {', '.join(map(str, ports))}")
        print("\nVLC URL TEMPLATE (fill in the camera's documented details):")
        print("  rtsp://USERNAME:PASSWORD@CAMERA_IP:554/DOCUMENTED_STREAM_PATH")
        print("\nUse only credentials and stream paths supplied by the camera")
        print("owner/manufacturer. Do not share URLs containing passwords.")
    print("=" * 58)

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\nScan cancelled.")
        sys.exit(130)
