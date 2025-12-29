#!/bin/bash
# MODULE: Install Dependencies
# Installs core dependencies and updates the OS.

# 1. Check for root and environment
check_root
check_env

# 2. Update Repositories
log_step "Updating package lists..."
apt-get update -qq

# 3. Install Core Dependencies
# - bc: Arbitrary precision calculator
# - wireguard: VPN protocol
# - iptables: Firewall management
# - unbound: Recursive DNS resolver
# - curl/git: Utilities
# - qrencode: For generating QR codes in terminal (cool feature for later)
# - dnsmasq: Lightweight DHCP and DNS server
# - hostapd: WiFi access point management
# - macchanger: Change MAC addresses for privacy
# - ethtool: Ethernet device settings
# - xtables-addons-common: Additional iptables modules (when kernel 6.12 supported)
DEPENDENCIES=(bc wireguard iptables unbound curl git qrencode dnsmasq hostapd macchanger ethtool )

log_step "Installing dependencies: ${DEPENDENCIES[*]}..."

# DEBIAN_FRONTEND=noninteractive prevents popups during install
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "${DEPENDENCIES[@]}"

# 4. Check for installation success
if [ $? -eq 0 ]; then
    log_success "All core dependencies installed."
else
    log_error "Failed to install dependencies. Check internet connection."
    exit 1
fi