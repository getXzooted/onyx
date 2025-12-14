#!/bin/bash
# MODULE: System > Uplink DNS Security Tuning
# Applies DNS leak prevention by securing uplink connections.

# Secure Uplink DNS (Dynamic Detection)
# Finds ANY active internet connection (wlan0, eth0, etc.) and locks it down.
function system_secure_uplink() {
    log_header "SECURING UPLINK (PREVENT DNS LEAKS)"
    
    # 1. Dynamic Detection
    # Get all active connections, but exclude our internal interfaces:
    # - uap0 (Hotspot)
    # - wg0 (VPN)
    # - lo (Loopback)
    # - docker (If present)
    local CONN=$(nmcli -t -f NAME,DEVICE connection show --active \
        | grep -v ":uap0" \
        | grep -v ":wg0" \
        | grep -v ":lo" \
        | grep -v ":docker" \
        | cut -d: -f1 | head -n 1)

    if [ -n "$CONN" ]; then
        log_step "Locking down active uplink: '$CONN'"
        
        # 2. Ignore the Router/ISP DNS (The Leak Source)
        nmcli connection modify "$CONN" ipv4.ignore-auto-dns yes
        
        # 3. Force Safe DNS (Forces traffic into the VPN Tunnel)
        # 1.1.1.1 is safe because it is routed through the tunnel once established.
        nmcli connection modify "$CONN" ipv4.dns "1.1.1.1"
        
        # 4. Apply (Reload settings non-destructively)
        nmcli connection up "$CONN" &>/dev/null
        
        log_success "Uplink Secured. ISP DNS ignored."
    else
        log_warning "No active uplink found. Skipping DNS lock."
    fi
}

# Run automatically if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    system_secure_uplink
fi