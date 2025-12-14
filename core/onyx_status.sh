#!/bin/bash
# CORE: Onyx Status & Diagnostic Tool
# Displays real-time health, security status, and leak checks.

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "\n${BLUE}::: ONYX GATEWAY STATUS :::${NC}"

# === 1. SERVICE HEALTH ===
echo -e "\n${GREEN}=== 1. SERVICE HEALTH ===${NC}"

# Unbound
echo -n "• Unbound DNS:    "
if systemctl is-active unbound &>/dev/null; then
    echo -e "${GREEN}ACTIVE (Port 5335)${NC}"
else
    echo -e "${RED}FAILED / INACTIVE${NC}"
fi

# WireGuard
echo -n "• WireGuard VPN:  "
if systemctl is-active wg-quick@wg0 &>/dev/null; then
    echo -e "${GREEN}ACTIVE (Encrypted)${NC}"
else
    echo -e "${RED}FAILED / INACTIVE${NC}"
fi

# Hostapd
echo -n "• WiFi Hotspot:   "
if systemctl is-active hostapd &>/dev/null; then
    echo -e "${GREEN}ACTIVE (uap0)${NC}"
else
    echo -e "${RED}FAILED / INACTIVE${NC}"
fi


# === 2. SECURITY ARCHITECTURE ===
echo -e "\n${GREEN}=== 2. SECURITY CONFIGURATION ===${NC}"

# CLIENT SECURITY (What connected phones use)
echo -n "• Client DNS:     "
if grep -q "127.0.0.1#5335" /etc/dnsmasq.d/090_raspap.conf 2>/dev/null; then
    echo -e "${GREEN}SECURE (Unbound - Privacy)${NC}"
elif grep -q "1.1.1.1" /etc/dnsmasq.d/090_raspap.conf 2>/dev/null; then
    echo -e "${YELLOW}FALLBACK (Cloudflare - Secure)${NC}"
else
    echo -e "${RED}UNKNOWN / LEAK RISK${NC}"
fi

# ROUTER SECURITY (What the Pi itself uses - The "Split Brain" Check)
echo -n "• Router DNS:     "
RESOLV_CHECK=$(cat /etc/resolv.conf | grep nameserver | head -n 1 | awk '{print $2}')
if [[ "$RESOLV_CHECK" == "127.0.0.1" ]]; then
     echo -e "${GREEN}SECURE (Unbound)${NC}"
elif [[ "$RESOLV_CHECK" == "1.1.1.1" ]]; then
     echo -e "${GREEN}SECURE (Cloudflare)${NC}"
elif [[ "$RESOLV_CHECK" =~ ^192\.168\..* ]]; then
     echo -e "${RED}LEAKING ($RESOLV_CHECK - ISP/Hotel)${NC}"
else
     echo -e "${YELLOW}CUSTOM ($RESOLV_CHECK)${NC}"
fi


# === 3. CONNECTIVITY ===
echo -e "\n${GREEN}=== 3. NETWORK STATUS ===${NC}"

# Ping Check
echo -n "• Connectivity:   "
if ping -c 1 1.1.1.1 &>/dev/null; then
    echo -e "${GREEN}ONLINE${NC}"
else
    echo -e "${RED}OFFLINE${NC}"
fi

# Public IP (The External View)
echo -n "• Public IP:      "
JSON=$(curl -s --max-time 4 https://ipinfo.io/json)
CURRENT_IP=$(echo "$JSON" | grep '"ip":' | cut -d'"' -f4)
COUNTRY=$(echo "$JSON" | grep '"country":' | cut -d'"' -f4)
ORG=$(echo "$JSON" | grep '"org":' | cut -d'"' -f4)

if [ -n "$CURRENT_IP" ]; then
    echo -e "${GREEN}$CURRENT_IP ($COUNTRY)${NC}"
    echo -e "  └─ Provider:    $ORG"
else
    echo -e "${RED}Check Failed (VPN or Firewall blocking)${NC}"
fi

# === 4. RAW DEBUG DATA (For Advanced Users) ===
echo -e "\n${GREEN}=== 4. RAW DEBUG INFO ===${NC}"
echo -e "${BLUE}[Route Table for 1.1.1.1]${NC}"
ip route get 1.1.1.1

echo -e "\n${BLUE}[VPN Connection Check]${NC}"
# Checks Mullvad specific API, valid only for Mullvad users but good to have
curl -s --max-time 3 https://am.i.mullvad.net/connected || echo "Not using Mullvad or Check Failed"

echo -e "\n${GREEN}=== MANUAL VERIFICATION ===${NC}"
echo "Connect a phone to 'Onyx_Gateway' and visit:"
echo "1. https://ipleak.net (Check for no ISP leaks)"
echo "2. https://dnsleaktest.com (Extended Test)"
echo ""