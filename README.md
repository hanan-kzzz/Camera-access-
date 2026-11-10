# CCTV Finder for Ubuntu

A lightweight Bash utility for Ubuntu that helps you identify devices on your own local network, check common web-interface ports, and open a possible CCTV camera or NVR login page in your browser.

## Features

- Detects the active network interface and local IPv4 subnet automatically.
- Discovers responding devices on the detected local network using Nmap.
- Lets you select a device to inspect.
- Checks common web-interface ports: 80, 443, 8080, and 8443.
- Displays possible HTTP/HTTPS login URLs.
- Optionally opens the first detected URL using your default browser.

## Requirements

- Ubuntu or another Linux distribution with Bash.
- nmap
- iproute2 (provides the ip command)
- xdg-utils (optional, for opening the browser automatically)

## Installation

Install the required packages:

    sudo apt update
    sudo apt install nmap iproute2 xdg-utils

Clone the repository:

    git clone https://github.com/hanan-kzzz/Camera-access-.git
    cd Camera-access-

Make the script executable:

    chmod +x cctv_finder_ubuntu.sh

## Usage

1. Connect your Ubuntu computer to the same LAN/Wi-Fi as the camera, where the camera is reachable.
2. Run:

       ./cctv_finder_ubuntu.sh

3. Review the discovered IP addresses.
4. Select the IP address belonging to your own camera or NVR.
5. Review the open common web ports and possible browser URLs.
6. If prompted, choose whether to open the first URL in your default browser.
7. Sign in using your own authorized camera credentials.

If device discovery does not work, check that your computer and camera are on the same reachable network. Some NVRs use an isolated PoE network, and some cameras are only accessible through the NVR.

## Important limitations

- This is a basic discovery helper, not a complete CCTV security scanner.
- It checks only the four common web ports listed above. A camera may use a different port or may not provide a browser interface.
- A detected open port does not prove that the service is vulnerable or insecure.
- Device names and vendor details may not be available from a basic scan.
- HTTPS devices may show a browser certificate warning if they use a locally issued certificate. Verify that the address belongs to your device before proceeding.
- The script does not attempt passwords, bypass authentication, exploit devices, or modify camera settings.

## Authorized use

Use this tool only on networks and devices you own or are explicitly authorized to assess. Do not scan networks belonging to other people or organizations without permission.

## Troubleshooting

### nmap: command not found

Install Nmap:

    sudo apt update && sudo apt install nmap

### No devices are found

- Confirm that your computer and camera are connected to the same network.
- Check whether the router or camera network isolates wireless clients.
- If the camera is connected to an NVR's PoE ports, check the NVR's device list or documentation; the camera may not appear on your regular LAN.

### No web login URL is found

The camera may use a non-standard port, have its web interface disabled, or require the manufacturer's app/NVR interface. Consult the device manufacturer's documentation.

## License

No license has been specified yet. Unless a license is added, standard copyright applies and reuse or redistribution is not automatically permitted.