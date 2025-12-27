#!/bin/bash
# MODULE: Network > Safety Net (Firewall)
# Generates the 'Kill Switch' firewall script and service.

if [ -z "$ONYX_ROOT" ]; then
    echo "Error: This module must be run via the Onyx CLI."
    exit 1
fi

function network_safety_net() {
    log_header "CONFIGURING SAFETY NET (FIREWALL)"

    # 1. CHECK VARIABLES
    if [[ -z "$ONYX_VPN_ENDPOINT" || -z "$ONYX_VPN_PORT" ]]; then
        log_error "Missing VPN Endpoint/Port. Cannot generate firewall rules."
        return 1
    fi

    TARGET_SCRIPT="/usr/local/bin/safety-net.sh"
    SERVICE_FILE="/etc/systemd/system/safety-net.service"

    log_step "Generating firewall logic at $TARGET_SCRIPT..."

    # 2. GENERATE MINIMAL ENFORCER SCRIPT
    # Instead of a massive block of strings, this script now sources 
    # your core Onyx libraries to apply rules dynamically.
    cat <<EOF > "$TARGET_SCRIPT"
#!/bin/bash
# ONYX Boot-time Safety Net
source "$ONYX_ROOT/vars.sh"
source "$ONYX_ROOT/core/logger.sh"
source "$ONYX_ROOT/lib/hardening_execution.sh"

# 1. Flush and Set Default Deny
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT DROP
iptables -F
iptables -t nat -F

# 2. Re-apply Desired State via Library Functions
# Established/Related
build_rule INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
build_rule OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
build_rule FORWARD -m state --state ESTABLISHED,RELATED -j ACCEPT

# DHCP: Essential for Hotspot Clients
build_rule INPUT -p udp --dport 67:68 --sport 67:68 -j ACCEPT
build_rule OUTPUT -p udp --dport 67:68 --sport 67:68 -j ACCEPT

# Universal Local Access (RFC1918)
# LAN Access: Full RFC1918 Coverage
build_rule INPUT -s 10.0.0.0/8 -j ACCEPT
build_rule OUTPUT -d 10.0.0.0/8 -j ACCEPT
build_rule INPUT -s 172.16.0.0/12 -j ACCEPT
build_rule OUTPUT -d 172.16.0.0/12 -j ACCEPT
build_rule INPUT -s 192.168.0.0/16 -j ACCEPT
build_rule OUTPUT -d 192.168.0.0/16 -j ACCEPT

# Localhost
build_rule INPUT -i lo -j ACCEPT
build_rule OUTPUT -o lo -j ACCEPT

# VPN Transport (The Only Way Out)
build_rule OUTPUT -d $ONYX_VPN_ENDPOINT -p udp --dport $ONYX_VPN_PORT -j ACCEPT

# Tunnel Traffic (Allow Pi to use the VPN)
build_rule INPUT -i wg0 -j ACCEPT
build_rule OUTPUT -o wg0 -j ACCEPT

# NAT & Tunnel Forwarding
iptables -t nat -A POSTROUTING -o wg0 -j MASQUERADE
build_rule FORWARD -i wg0 -j ACCEPT
build_rule FORWARD -o wg0 -j ACCEPT
EOF

    chmod +x "$TARGET_SCRIPT"

    # 3. GENERATE SYSTEMD SERVICE
    log_step "Creating systemd service..."
    cat <<EOF > "$SERVICE_FILE"
[Unit]
Description=Safety Net Firewall Rules
After=network.target

[Service]
Type=oneshot
ExecStart=$TARGET_SCRIPT
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable safety-net &> /dev/null
    log_success "Safety Net refactored and service enabled."
}

network_safety_net