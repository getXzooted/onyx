#!/bin/bash
# CORE: ONYX QR MODULE
# Purpose: Generates QR codes for various Onyx functionalities.

log_header "WIREGUARD ONBOARDING (QR)"
if [ -f "/etc/wireguard/wg0.conf" ]; then
    # Displays the Pi's VPN config as a QR code in the terminal
    qrencode -t ansiutf8 < /etc/wireguard/wg0.conf
    log_info "Scan this with the WireGuard mobile app to clone the tunnel."
else
    log_error "No WireGuard config found at /etc/wireguard/wg0.conf"
fi