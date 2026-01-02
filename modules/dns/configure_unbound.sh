#!/bin/bash
# MODULE: DNS > Unbound Configuration
# Installs Unbound and applies Pi Zero resource optimizations.

check_root
check_env

function dns_configure_unbound() {
    # 1. Check Config Variable
    # If ONYX_USE_UNBOUND is not "true", we skip this entirely.
    if [[ "$ONYX_USE_UNBOUND" != "true" ]]; then
        log_info "Unbound is disabled in config. Skipping."
        return 0
    fi

    log_header "CONFIGURING UNBOUND DNS"

    # 2. ROOT HINTS FOR RECURSION
    if [[ "$ONYX_DNS_RECURSIVE" == "true" ]]; then
        log_step "Mode: FULL RECURSION (Root Hints)"
        HINTS_FILE="/var/lib/unbound/root.hints"
        
        # Download hints if missing
        if [ ! -f "$HINTS_FILE" ]; then
            mkdir -p /var/lib/unbound/
            wget -q https://www.internic.net/domain/named.cache -O "$HINTS_FILE"
            chown unbound:unbound "$HINTS_FILE"
        fi
        
        # Add the root-hints pointer to the config
        HINTS_CONF="root-hints: \"$HINTS_FILE\""
    else
        log_step "Mode: FORWARDING (External DNS)"
        HINTS_CONF=""
    fi

    # 3. Apply Pi Zero Optimization Config (Strict Port from V1)
    CONFIG_FILE="/etc/unbound/unbound.conf.d/pi-zero.conf"
    log_step "Writing optimized config to $CONFIG_FILE..."

    mkdir -p /etc/unbound/unbound.conf.d
    
    cat <<EOF > "$CONFIG_FILE"
$(<"$ONYX_UNBOUND_TEMPLATE")
EOF

    # 4. Install Package (Idempotent)
    if ! command -v unbound &> /dev/null; then
        log_step "Installing Unbound..."
        apt-get install -y -qq unbound
    fi

    # 5. Unmask, Enable, Restart, and Verify
    # We unmask to prevent the specific "masked" error you encountered.
    log_step "Starting Unbound service..."
    systemctl unmask unbound &>/dev/null
    systemctl enable unbound &>/dev/null
    systemctl restart unbound

    # 6. Verify it is actually running so the next script trusts it
    if systemctl is-active unbound &>/dev/null; then
        log_success "Unbound configured and running (Port 5335)."
    else
        log_error "Unbound failed to start. Check 'sudo systemctl status unbound'."
        return 1
    fi
}

dns_configure_unbound