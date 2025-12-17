#!/bin/bash
# MODULE: System > Terminal Dashboard
# PURPOSE: specific module for the 'onyx monitor' command.

function system_install_dashboard() {
    log_header "INSTALLING CLI DASHBOARD"

    # 1. Install Dependencies
    # ifstat: Network speed monitoring
    # bc: Calculator for math operations
    log_step "Installing metrics tools..."
    apt-get install -y ifstat bc

    # 2. Generate the Dashboard Script
    log_step "Generating dashboard script..."
    
    # We write the script directly to /usr/local/bin so it's in the PATH
    cat << 'EOF' > /usr/local/bin/onyx-dash
#!/bin/bash
# Onyx Live Dashboard

# Colors for the HUD
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

# --- INTERFACE SETTINGS ---
# WAN: Auto-detect the internet source (eth0, end0, or usb0)
WAN_IFACE=$(ip route | grep default | awk '{print $5}' | head -n1)

# VPN: The WireGuard Interface
VPN_IFACE="wg0"

# LAN: Your specific AP interface
LAN_IFACE="uap0" 

# Fallback: If auto-detect fails, default to eth0
if [ -z "$WAN_IFACE" ]; then WAN_IFACE="eth0"; fi

while true; do
    clear
    echo -e "${BLUE}======================================${NC}"
    echo -e "${BLUE}       ONYX SOVEREIGN GATEWAY         ${NC}"
    echo -e "${BLUE}======================================${NC}"

    # --- VITALS ---
    # CPU Temp (Critical for Pi Zero in an enclosure)
    TEMP=$(vcgencmd measure_temp | cut -d= -f2)
    # System Load
    LOAD=$(cat /proc/loadavg | awk '{print $1}')
    # RAM Usage
    MEM=$(free -m | awk 'NR==2{printf "%.0f%%", $3*100/$2 }')
    
    echo -e "SYSTEM : Temp: ${TEMP} | Load: ${LOAD} | RAM: ${MEM}"
    echo "--------------------------------------"

    # --- PRIVACY STATUS ---
    # Checks if the WireGuard interface (wg0) is up and has an IP
    if ip addr show $VPN_IFACE > /dev/null 2>&1; then
        VPN_IP=$(ip -4 addr show $VPN_IFACE | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
        echo -e "VPN    : ${GREEN}SECURE${NC} (Tunnel Active)"
        echo -e "IP     : $VPN_IP"
    else
        echo -e "VPN    : ${RED}UNSECURED / OFFLINE${NC}"
    fi
    echo "--------------------------------------"

    # --- NETWORK TRAFFIC ---
    # Get raw KB/s
    STATS=$(ifstat -i $WAN_IFACE 1 1 | tail -n 1)
    RX_RAW=$(echo $STATS | awk '{print $1}')
    TX_RAW=$(echo $STATS | awk '{print $2}')

    # Logic: If > 1024, show MB. If < 1024, show KB.
    if (( $(echo "$RX_RAW > 1024" | bc -l) )); then
        RX=$(echo "scale=2; $RX_RAW / 1024" | bc)
        RX_UNIT="MB/s"
    else
        RX=$RX_RAW
        RX_UNIT="KB/s"
    fi

    if (( $(echo "$TX_RAW > 1024" | bc -l) )); then
        TX=$(echo "scale=2; $TX_RAW / 1024" | bc)
        TX_UNIT="MB/s"
    else
        TX=$TX_RAW
        TX_UNIT="KB/s"
    fi
    
    echo -e "TRAFFIC: Down: ${GREEN}${RX} ${RX_UNIT}${NC} | Up: ${YELLOW}${TX} ${TX_UNIT}${NC}"
    # --- CLIENTS ---
    # Counts devices connected to the local hotspot
    CLIENTS=$(ip neigh show dev $LAN_IFACE | grep "REACHABLE" | wc -l)
    echo -e "CLIENTS: ${CLIENTS} Active Devices"
    
    echo "--------------------------------------"
    echo -e "Press [CTRL+C] to exit"
    
    sleep 2
done
EOF

    # 3. Make it executable
    chmod +x /usr/local/bin/onyx-dash
    
    log_success "Dashboard Installed."
}