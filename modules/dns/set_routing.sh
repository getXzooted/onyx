#!/bin/bash
# MODULE: DNS > Routing Strategy
# Configures dnsmasq to use either Unbound or the VPN DNS.

if [ -z "$ONYX_ROOT" ]; then
    echo "Error: This module must be run via the Onyx CLI."
    exit 1
fi

function dns_set_routing() {
    log_header "DNS ROUTING SETUP"
    
    DNSMASQ_CONF="/etc/dnsmasq.d/02-vpn-dns.conf"

    # PATH A: USE UNBOUND
    if [[ "$ONYX_USE_UNBOUND" == "true" ]]; then
        log_step "Strategy: Local Unbound Resolver"
        
        # Write strict forwarding rule
        echo -e "no-resolv\nserver=127.0.0.1#5335" > "$DNSMASQ_CONF"
        
        # Cleanup old auto-dns script if it exists
        rm -f /usr/local/bin/auto-dns.sh
        
        log_success "DNS routing set to Unbound (Localhost:5335)."

    # PATH B: USE VPN DNS (Auto-DNS)
    else
        log_step "Strategy: VPN Provider DNS (Auto-Discovery)"
        
        # 1. Create the Auto-DNS Script (Strict Port from V1)
        AUTO_SCRIPT="/usr/local/bin/auto-dns.sh"
        
        cat <<'EOF' > "$AUTO_SCRIPT"
#!/bin/bash
# ONYX AUTO-DNS
# Discovers the upstream WireGuard gateway and sets it as the DNS server.
sleep 2
WG_IP=$(ip -o -4 addr list wg0 | awk '{print $4}' | cut -d/ -f1)
# Assumes Gateway is always x.x.x.1 (Standard WireGuard topology)
WG_GATEWAY=$(echo $WG_IP | awk -F. '{print $1"."$2"."$3".1"}')

echo -e "no-resolv\nserver=$WG_GATEWAY" > /etc/dnsmasq.d/02-vpn-dns.conf
systemctl restart dnsmasq
EOF

        chmod +x "$AUTO_SCRIPT"
        log_success "Auto-DNS script created at $AUTO_SCRIPT"
        
        # Note: In the final Provision module, we need to ensure this script 
        # runs whenever WireGuard connects (via PostUp).
    fi
    
    # Reload dnsmasq to apply changes
    systemctl restart dnsmasq &> /dev/null || log_warning "dnsmasq not running (install RaspAP first?)"
}

dns_set_routing