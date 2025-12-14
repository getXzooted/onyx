#!/bin/bash
# MODULE: VPN > WireGuard > Configure
# Generates the wg0.conf file from user settings.

if [ -z "$ONYX_ROOT" ]; then
    echo "Error: This module must be run via the Onyx CLI."
    exit 1
fi

function vpn_wireguard_configure() {
    log_header "CONFIGURING WIREGUARD"

    # 1. DEFINE PATHS
    WG_CONF="/etc/wireguard/wg0.conf"

    # --- AGGRESSIVE KEY REPAIR ---
    # 2. Strip all spaces, newlines, and invisible characters first.
    local RAW_KEY=$(echo "$ONYX_VPN_PRIVATE_KEY" | tr -d ' \n\r')
    
    # 3. Check if the key ends with '='. If not, append it.
    if [[ "$RAW_KEY" != *"=" ]]; then
        log_warning "Key missing trailing '='. Auto-repairing..."
        ONYX_VPN_PRIVATE_KEY="${RAW_KEY}="
    else
        ONYX_VPN_PRIVATE_KEY="$RAW_KEY"
    fi
    
    # 4. CHECK FOR REQUIRED VARIABLES
    # In V2, these will come from the parsed 'onyx.yml'
    # For now, we will assume they are exported as env vars by the CLI Controller
    if [[ -z "$ONYX_VPN_PRIVATE_KEY" || -z "$ONYX_VPN_ENDPOINT" || -z "$ONYX_VPN_PORT" || -z "$ONYX_VPN_PUBKEY" ]]; then
        log_error "Missing required VPN variables. Cannot generate config."
        return 1
    fi

    log_step "Generating $WG_CONF..."

    # 5. WRITE THE CONFIG (The Bash version of your Jinja2 template)
    # We set umask to ensure the file is created with 600 permissions (root read/write only)
    (
        umask 077
        cat <<EOF > "$WG_CONF"
[Interface]
# The internal IP of the Pi within the VPN tunnel
Address = 10.100.0.2/24
PrivateKey = $ONYX_VPN_PRIVATE_KEY

# DNS is handled by Unbound/Dnsmasq locally, but we define it here just in case
# DNS = 1.1.1.1 

[Peer]
# The VPN Server you are connecting to
PublicKey = $ONYX_VPN_PUBKEY
Endpoint = $ONYX_VPN_ENDPOINT:$ONYX_VPN_PORT
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25
EOF
    )

    if [ -f "$WG_CONF" ]; then
        log_success "WireGuard configuration generated."
        chmod 600 "$WG_CONF" # Double check permissions
    else
        log_error "Failed to create WireGuard config."
        exit 1
    fi
    
    # 6. ENABLE SERVICE
    log_step "Enabling WireGuard service..."
    systemctl enable wg-quick@wg0 &> /dev/null
    
    # We don't start it yet because we might be offline/installing
    log_success "WireGuard service enabled (will start on reboot)."
}


vpn_wireguard_configure
