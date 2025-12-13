#!/bin/bash
# MODULE: DNS > Unbound Configuration
# Installs Unbound and applies Pi Zero resource optimizations.

if [ -z "$ONYX_ROOT" ]; then
    echo "Error: This module must be run via the Onyx CLI."
    exit 1
fi

function dns_configure_unbound() {
    # 1. Check Config Variable
    # If ONYX_USE_UNBOUND is not "true", we skip this entirely.
    if [[ "$ONYX_USE_UNBOUND" != "true" ]]; then
        log_info "Unbound is disabled in config. Skipping."
        return 0
    fi

    log_header "CONFIGURING UNBOUND DNS"

    # 2. Install Package (Idempotent)
    if ! command -v unbound &> /dev/null; then
        log_step "Installing Unbound..."
        apt-get install -y -qq unbound
    fi

    # 3. Apply Pi Zero Optimization Config (Strict Port from V1)
    CONFIG_FILE="/etc/unbound/unbound.conf.d/pi-zero.conf"
    log_step "Writing optimized config to $CONFIG_FILE..."

    cat <<EOF > "$CONFIG_FILE"
server:
    # Listening Info
    verbosity: 0
    interface: 127.0.0.1
    port: 5335
    do-ip4: yes
    do-udp: yes
    do-tcp: yes
    
    # Privacy & Security
    do-ip6: no
    access-control: 0.0.0.0/0 refuse
    access-control: 127.0.0.0/8 allow
    harden-glue: yes
    harden-dnssec-stripped: yes
    use-caps-for-id: no
    edns-buffer-size: 1232
    prefetch: yes
    
    # Pi Zero Resource Limits (Low RAM)
    num-threads: 1
    msg-cache-slabs: 2
    rrset-cache-slabs: 2
    infra-cache-slabs: 2
    key-cache-slabs: 2
    rrset-cache-size: 50m
    msg-cache-size: 25m
    so-rcvbuf: 1m
EOF

    # 4. Restart Service
    systemctl restart unbound
    systemctl enable unbound &> /dev/null
    log_success "Unbound configured and running."
}

dns_configure_unbound