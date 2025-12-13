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
    # The firewall explicitly allows traffic to the VPN endpoint. 
    # If we don't have that IP, we can't create the rule.
    if [[ -z "$ONYX_VPN_ENDPOINT" || -z "$ONYX_VPN_PORT" ]]; then
        log_error "Missing VPN Endpoint/Port. Cannot generate firewall rules."
        return 1
    fi

    TARGET_SCRIPT="/usr/local/bin/safety-net.sh"
    SERVICE_FILE="/etc/systemd/system/safety-net.service"

    log_step "Generating firewall logic at $TARGET_SCRIPT..."

    # 2. GENERATE FIREWALL SCRIPT (Strict Port from V1)
    cat <<EOF > "$TARGET_SCRIPT"
#!/bin/bash
IPT="/usr/sbin/iptables"

# 1. DEFAULT POLICY: DROP (Universal Kill Switch)
\$IPT -P INPUT DROP
\$IPT -P FORWARD DROP
\$IPT -P OUTPUT DROP

# 2. FLUSH OLD RULES
\$IPT -F
\$IPT -X
\$IPT -t nat -F
\$IPT -t nat -X

# 3. ALLOW ESTABLISHED CONNECTIONS
\$IPT -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
\$IPT -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
\$IPT -A FORWARD -m state --state ESTABLISHED,RELATED -j ACCEPT

# 4. UNIVERSAL LOCAL ACCESS (LAN & Loopback)
\$IPT -A INPUT -s 10.0.0.0/8 -j ACCEPT
\$IPT -A OUTPUT -d 10.0.0.0/8 -j ACCEPT
\$IPT -A INPUT -s 172.16.0.0/12 -j ACCEPT
\$IPT -A OUTPUT -d 172.16.0.0/12 -j ACCEPT
\$IPT -A INPUT -s 192.168.0.0/16 -j ACCEPT
\$IPT -A OUTPUT -d 192.168.0.0/16 -j ACCEPT

\$IPT -A INPUT -i lo -j ACCEPT
\$IPT -A OUTPUT -o lo -j ACCEPT

# 5. ALLOW DHCP
\$IPT -A INPUT -p udp --dport 67:68 --sport 67:68 -j ACCEPT
\$IPT -A OUTPUT -p udp --dport 67:68 --sport 67:68 -j ACCEPT

# 6. ALLOW VPN TRANSPORT (The Only Way Out)
\$IPT -A OUTPUT -d $ONYX_VPN_ENDPOINT -p udp --dport $ONYX_VPN_PORT -j ACCEPT

# 7. ALLOW TUNNEL TRAFFIC (Inside the VPN)
\$IPT -A INPUT -i wg0 -j ACCEPT
\$IPT -A OUTPUT -o wg0 -j ACCEPT

# 8. ENABLE FORWARDING (Leak Fix)
\$IPT -A FORWARD -i wg0 -j ACCEPT
\$IPT -A FORWARD -o wg0 -j ACCEPT

# 9. NAT
\$IPT -t nat -A POSTROUTING -o wg0 -j MASQUERADE
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

    # 4. ENABLE SERVICE
    systemctl daemon-reload
    systemctl enable safety-net &> /dev/null
    log_success "Safety Net installed (Active on next reboot)."
}

network_safety_net