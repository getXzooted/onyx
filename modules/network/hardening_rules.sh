#!/bin/bash
# /opt/onyx/lib/hardening_rules.sh
# ONYX V2: Dedicated Security Rule Library

# --- FOUNDATION RULES ---
source $MODULES_DIR/firewall/rules.sh

function apply_use_zram() {

    # === MEMORY OPTIMIZATION FOR PI ZERO ===
    log_header "PHASE 1: MEMORY OPTIMIZATION"

    # Install ZRAM
    log_step "Installing ZRAM..."
    if ! command -v zramctl &> /dev/null; then
        apt-get update && apt-get install -y zram-tools bc
    fi

    # 3. SURGICAL STRIKE: Kill the built-in Trixie swap
    # This releases the 'Device or resource busy' error.
    log_info "Killing competing swap services..."
    systemctl stop rpi-swap zramswap 2>/dev/null
    systemctl mask rpi-swap 2>/dev/null # Permanent prevent
    sudo swapoff -a 2>/dev/null
    modprobe -r zram 2>/dev/null
    modprobe zram num_devices=1

    # DYNAMIC CALCULATION: Scale to 50% of RAM
    TOTAL_RAM=$(free -m | awk '/^Mem:/{print $2}')
    ZRAM_SIZE=$(echo "$TOTAL_RAM * 0.5" | bc | cut -d. -f1)

    # HARDWARE LOCK: Apply algorithm and dynamic size
    if [ -b /dev/zram0 ]; then
        log_step "Locking hardware: ${ZRAM_SIZE}M @ lz4..."
        # We use the successful --find flag with the new dynamic size
        sudo zramctl --find --size "${ZRAM_SIZE}M" --algorithm lz4
                
        # ACTIVATE: Manual setup to bypass service configuration
        sudo mkswap /dev/zram0
        sudo swapon /dev/zram0 -p 100
    fi

    # 5. Apply the Scalable Memory Configuration
    cat <<EOF | sudo tee /etc/default/zramswap
# Onyx Memory Guard - Scalable Config
# Automatically scales to 50% of available physical RAM
PERCENTAGE=50
# Force the high-performance algorithm for ARM processors
ALGO=lz4
# Ensure this swap is used first before any SD card overflow
PRIORITY=100
EOF

    # 6. Restart the service - this should now succeed without the "Busy" error
    # systemctl restart zramswap
    log_success "ZRAM Active (lz4 Compression, 50% RAM)"

}

function check_use_zram() {
    # 1. Verify zram0 device exists in the kernel
    if [[ ! -b /dev/zram0 ]]; then
        return 1
    fi
    
    # 2. Verify algorithm is lz4 (Tactical standard)
    local ALGO=$(zramctl --noheadings --output ALGORITHM /dev/zram0 2>/dev/null)
    if [[ "$ALGO" != "lz4" ]]; then
        return 1
    fi
    
    # 3. Verify standard RPi swap is disabled to prevent SD wear
    if systemctl is-active rpi-swap &>/dev/null; then
        return 1
    fi
    
    # 4. Verify it is actually being used as swap
    if ! swapon --show | grep -q "/dev/zram0"; then
        return 1
    fi

    return 0
}

function check_forensic_zero() {
    # Audit: Check if /var/log is actively a tmpfs mount
    if findmnt -n -o FSTYPE /var/log | grep -q "tmpfs"; then
        return 0
    fi
    return 1
}

function apply_forensic_zero() {
    if [[ "$1" == "true" ]]; then
        log_step "Applying Official log2ram (Forensic-Zero)..."

        # 1. DOCUMENTATION - TROUBLESHOOTING: Vacuum journal
        # This ensures existing logs don't exceed your RAM disk size on first mount.
        journalctl --vacuum-size=32M &>/dev/null
        
        # 2. DOCUMENTATION - TROUBLESHOOTING: Set SystemMaxUse
        if ! grep -q "SystemMaxUse=20M" /etc/systemd/journald.conf; then
            echo "SystemMaxUse=20M" >> /etc/systemd/journald.conf
            systemctl restart systemd-journald &>/dev/null
        fi

        # 3. DOCUMENTATION - MANUAL INSTALL
        if [[ ! -f "/usr/local/bin/log2ram" ]]; then
            curl -L https://github.com/azlux/log2ram/archive/master.tar.gz | tar zxf -
            cd log2ram-master
            # NEUTER LIVE START: Ensure the installer doesn't kill your session now.
            sed -i '/systemctl start log2ram/d' install.sh
            ./install.sh &>/dev/null
            cd .. && rm -rf log2ram-master
        fi

        # 4. APEX CALCULATION: 25% of RAM
        # On your 512MB Pi Zero 2W, this is ~128MB.
        local LOG_PERCENT="0.25"
        local TOTAL_RAM=$(free -m | awk '/^Mem:/{print $2}')
        local CALCULATED_SIZE=$(echo "$TOTAL_RAM * $LOG_PERCENT" | bc | cut -d. -f1)
        
        # 5. DOCUMENTATION - CUSTOMIZATION
        # Apply the dynamic size to the official config
        sed -i "s/SIZE=40M/SIZE=${CALCULATED_SIZE}M/" /etc/log2ram.conf
        sed -i 's/MAIL=true/MAIL=false/' /etc/log2ram.conf
        
        # 6. ENFORCE REBOOT
        # Enable for the next boot, but do not start it now.
        systemctl enable log2ram &>/dev/null
        log_success "Forensic-Zero: ${CALCULATED_SIZE}M configured. REBOOT MANDATORY."
    fi
}

function check_packet_padding() {
    # Instead of looking for '64', we look for the intent in hardening.yml
    local INTENT=$(yq e '.hardening.system.ttl_masking' "$HARDENING_YAML")
    case "$INTENT" in
        windows) VAL="128" ;;
        solaris) VAL="255" ;;
        *)       VAL="64"  ;;
    esac

    # Verify if the padding/jitter rule is present and matches the TTL mask
    iptables -t mangle -L POSTROUTING -n | grep -q "TTL set to $VAL" && return 0 || return 1
}

function apply_packet_padding() {
    if [[ "$1" == "true" ]]; then
        # 1. Fetch current TTL choice to remain consistent
        local MASK_MODE=$(yq e '.hardening.system.ttl_masking' "$HARDENING_YAML")
        case "$MASK_MODE" in
            windows) TTL_VAL="128" ;;
            solaris) TTL_VAL="255" ;;
            *)       TTL_VAL="64"  ;;
        esac

        log_step "Applying Smart Padding (Inherited TTL: $TTL_VAL)..."
        
        # Apply the jitter/mask consistent with the chosen identity
        iptables -t mangle -A POSTROUTING -o wg0 -j TTL --ttl-set "$TTL_VAL"
        
        # 2. Advanced Shape Obfuscation (IP ID Randomization)
        if modinfo xt_ID &>/dev/null; then
            iptables -t mangle -A POSTROUTING -o wg0 -j ID --id 0
            log_success "Packet Shape Obfuscated."
        else
            log_warning "Advanced Padding (xt_ID) skipped: Kernel module missing."
        fi
    fi
}

# --- UNBOUND FILTER WORKER (DNS SENTINEL) ---
function check_unbound_filtered() {
    # Check if the blocklist file generated by Asset Manager exists and has content
    [[ -s "/etc/unbound/unbound.conf.d/onyx-sentinel.conf" ]] && return 0 || return 1
}

function apply_unbound_filtered() {
    if [[ "$1" == "true" ]]; then
        log_step "Syncing Unbound Filtered Definitions..."
        source "$CORE_DIR/assets.sh"
        asset_sync # Triggers the download and processing from assets.yml
    fi
}


# --- GEOBLOCKING WORKER ---
function check_geo_blocking() {
    # Verify the set exists and the single iptables rule is present
    ipset list onyx_geoblock &>/dev/null && \
    iptables -L INPUT -n | grep -q "match-set onyx_geoblock src" && return 0
    return 1
}

function apply_geo_blocking() {
    local LIST="/etc/onyx/firewall/geo_block.list"
    if [[ "$1" == "true" ]] && [[ -f "$LIST" ]]; then
        log_step "Enforcing Sovereign Geoblock (Optimized via ipset)..."

        # 1. Ensure ipset is installed
        if ! command -v ipset &>/dev/null; then
            apt-get install -y ipset &>/dev/null
        fi

        # 2. Create the set (hash:net handles CIDR ranges)
        # -exist prevents errors if the set already exists
        ipset create onyx_geoblock hash:net -exist

        # 3. Flush and Load the set silently (The "High-Performance" way)
        ipset flush onyx_geoblock
        while read -r range; do
            [[ -z "$range" || "$range" == \#* ]] && continue
            # Add to the memory set, not the firewall chain
            ipset add onyx_geoblock "$range" -exist
        done < "$LIST"

        # 4. Inject ONE single rule to the firewall
        build_rule INPUT -m set --match-set onyx_geoblock src -j DROP
        log_success "Geoblock active: $(ipset list onyx_geoblock | grep -c '/') ranges loaded into memory."
    fi
}

# --- IDENTITY SCRUBBER: AUDIT WORKER ---
function check_browser_scrubbing() {
    # Is the engine running?
    ! systemctl is-active --quiet privoxy && return 1
    ! systemctl is-active --quiet nginx && return 1
    
    # Is the engine listening globally? (Ensures traffic can reach Privoxy)
    ! sudo netstat -tulpn | grep -q "0.0.0.0:8118" && return 1
    
    # Are the redirects present in the NAT table?
    local RULES=$(sudo iptables -t nat -S PREROUTING 2>/dev/null | grep -c "8118")
    [[ $RULES -lt 2 ]] && return 1
    
    return 0
}

# --- IDENTITY SCRUBBER: APPLY WORKER ---
function apply_browser_scrubbing() {
    if [[ "$1" == "true" ]]; then
        log_step "Engaging Sovereign Identity Scrubber (MITM)..."

        # 1. DEPENDENCIES & DIRECTORIES
        for pkg in privoxy nginx openssl; do
            command -v $pkg &>/dev/null || apt-get install -y -qq $pkg &>/dev/null
        done

        if [[ ! -d "/etc/privoxy/certs/" ]]; then
            mkdir -p /etc/privoxy/certs/
        fi

        if [[ ! -d "/var/www/onyx/" ]]; then
            mkdir -p "/var/www/onyx/"
        fi

        # 2. SOVEREIGN CERTIFICATE GENERATION
        if [[ ! -f "/etc/privoxy/certs/onyx-ca.crt" ]]; then
            log_info "Generating Sovereign Root CA..."
            openssl req -new -newkey rsa:2048 -sha256 -days 3650 -nodes -x509 \
                -keyout /etc/privoxy/certs/onyx-ca.key \
                -out /etc/privoxy/certs/onyx-ca.crt \
                -subj "/CN=Onyx Sovereign Root CA" &>/dev/null
            # Move to web root for download
            cp /etc/privoxy/certs/onyx-ca.crt /var/www/onyx/ca.crt
        fi

        # 3. PRIVOXY PERSONA SYNC (MAC/TTL/UA Alignment)
        local PERSONA=$(yq e '.hardening.persona' "$HARDENING_YAML")
        local UA="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
        [[ "$PERSONA" == "apple" ]] && UA="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"
        [[ "$PERSONA" == "windows" ]] && UA="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
        [[ "$PERSONA" == "linux" ]] && UA="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"


        # Configure Main Privoxy Engine
        cat <<EOF > /etc/privoxy/config
confdir /etc/privoxy
logdir /var/log/privoxy
filterfile default.filter
listen-address 0.0.0.0:8118
accept-intercepted-requests 1
ca-directory /etc/privoxy/certs
ca-cert-file onyx-ca.crt
ca-key-file onyx-ca.key
ca-password password
trusted-cas-file /etc/ssl/certs/ca-certificates.crt
https-inspection 1
EOF

        # Configure Scrubbing Rules (Referer, Headers, MITM)
        cat <<EOF > /etc/privoxy/user.action
{+https-inspection}
/
{ +hide-referrer{forge} +hide-user-agent{$UA} +hide-from-header{block} }
/
EOF
        systemctl restart privoxy

        # 4. NGINX WELCOME PAGE (Onboarding Portal)
        cat <<EOF > /etc/nginx/sites-available/default
server {
    listen 80 default_server;
    root /var/www/onyx;
    index index.html;
    # Required for Android/Apple detection to trigger the portal
    location /generate_204 { return 204; }
    location /ca.crt { default_type application/x-x509-ca-cert; }
}
EOF

        local DISPLAY_PERSONA="Unknown"
        [[ "$PERSONA" == "apple" ]] && DISPLAY_PERSONA="Apple / Safari"
        [[ "$PERSONA" == "windows" ]] && DISPLAY_PERSONA="Windows / Edge"
        [[ "$PERSONA" == "linux" ]] && DISPLAY_PERSONA="Linux / Chrome"

        cat <<EOF > /var/www/onyx/index.html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Onyx Sovereign Gateway</title>
    <style>
        :root { --onyx-blue: #007bff; --onyx-bg: #0a0a0a; --onyx-card: #161616; }
        body { font-family: 'Inter', -apple-system, sans-serif; background: var(--onyx-bg); color: #e0e0e0; display: flex; justify-content: center; align-items: center; min-height: 100vh; margin: 0; }
        .container { background: var(--onyx-card); padding: 2.5rem; border-radius: 12px; box-shadow: 0 10px 30px rgba(0,0,0,0.5); max-width: 450px; width: 90%; border: 1px solid #333; }
        h1 { font-size: 1.8rem; margin-bottom: 0.5rem; color: #fff; }
        .status-badge { background: #00ff0022; color: #00ff00; padding: 4px 12px; border-radius: 20px; font-size: 0.8rem; font-weight: bold; display: inline-block; margin-bottom: 1.5rem; }
        p { line-height: 1.6; color: #b0b0b0; }
        .persona-tag { color: var(--onyx-blue); font-weight: bold; }
        .btn { display: block; background: var(--onyx-blue); color: white; padding: 14px; text-decoration: none; border-radius: 6px; font-weight: bold; margin-top: 2rem; transition: background 0.2s; text-align: center; }
        .btn:hover { background: #0056b3; }
        .footer { margin-top: 2rem; font-size: 0.75rem; color: #555; text-align: center; }
    </style>
</head>
<body>
    <div class="container">
        <h1>Onyx Sovereign</h1>
        <div class="status-badge">● Identity Masking Active</div>
        <p>This network is currently masking your traffic using the <span class="persona-tag">$DISPLAY_PERSONA</span> Persona.</p>
        <p>To enable <strong>Day 1 Stealth</strong> (Full HTTPS Scrubber), you must trust the gateway certificate on this device.</p>
        <a href="/ca.crt" class="btn">Download Sovereign Certificate</a>
        <div class="footer">Sovereign Gateway v2.1.0 | Forensic-Zero | ZRAM-Optimized</div>
    </div>
</body>
</html>
EOF
        systemctl restart nginx

        # 5. FIREWALL: THE MULTI-TIER STACK
        log_info "Rebuilding Scrubber Firewall (Strict Order)..."

        # A. BLOCK QUIC LEAKS (UDP 443)
        # Force stop using UDP and use TCP Scrubber instead.
        sudo iptables -I FORWARD -p udp --dport 443 -j REJECT --reject-with icmp-port-unreachable

        # B. ALLOW HOTSPOT FORWARDING
        # Explicitly tells the Safety Net to allow scrubbed traffic from the hotspot (uap0) 
        # to reach the VPN (wg0). This fixes the "No Internet" warning.
        sudo iptables -I FORWARD -i uap0 -o wg0 -j ACCEPT
        sudo iptables -t mangle -I POSTROUTING -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu

        # A. Clear existing to prevent "Rule already exists" errors
        # We use || true to ensure the script continues even if rules are missing
        sudo iptables -t nat -D PREROUTING -i uap0 -p tcp --dport 80 -j REDIRECT --to-port 8118 2>/dev/null || true
        sudo iptables -t nat -D PREROUTING -i uap0 -p tcp --dport 443 -j REDIRECT --to-port 8118 2>/dev/null || true

        # B. Connectivity Bypass (Ensures Hotspot handshake works)
        for range in 8.8.8.8 8.8.4.4 216.58.0.0/16 172.217.0.0/16; do
            sudo iptables -t nat -I PREROUTING -i uap0 -d "$range" -j ACCEPT
        done

        # C. IoT Bypass (Insert at the TOP)
        local BYPASS_MACS=$(yq e '.hardening.iot_bypass[]' "$HARDENING_YAML" 2>/dev/null)
        for mac in $BYPASS_MACS; do
            sudo iptables -t nat -I PREROUTING -i uap0 -m mac --mac-source "$mac" -j ACCEPT
        done

        # D. The Main Redirection (With local exclusion)
        # ! -d 10.3.141.1 ensures the phone can reach the Welcome Page on the Pi
        sudo iptables -t nat -I PREROUTING -i uap0 -p tcp ! -d 10.3.141.1 --dport 80 -j REDIRECT --to-port 8118
        sudo iptables -t nat -I PREROUTING -i uap0 -p tcp ! -d 10.3.141.1 --dport 443 -j REDIRECT --to-port 8118
        log_success "Identity Scrubber Active."

        # B. Connectivity Bypass (Ensures Hotspot handshake works)
        for range in 8.8.8.8 8.8.4.4 216.58.0.0/16 172.217.0.0/16; do
            sudo iptables -t nat -I PREROUTING -i uap0 -d "$range" -j ACCEPT
        done
    fi
}


# --- HARDWARE TRIGGER WORKER ---

function check_hardware_reactive() {
    local RULE_FILE="/etc/udev/rules.d/99-onyx-hardware.rules"
    local TRIGGER='SUBSYSTEM=="net", ACTION=="add", RUN+="/opt/onyx/bin/onyx network repair"'

    # Check if file exists and contains the correct trigger path
    [[ -f "$RULE_FILE" ]] && grep -q "$TRIGGER" "$RULE_FILE" && return 0
    return 1
}

function apply_hardware_reactive() {
    local RULE_FILE="/etc/udev/rules.d/99-onyx-hardware.rules"
    local TRIGGER='SUBSYSTEM=="net", ACTION=="add", RUN+="/opt/onyx/bin/onyx network repair"'

    if [[ "$1" == "true" ]]; then
        log_step "Enabling Reactive Hardware Discovery (udev)..."
        echo "$TRIGGER" > "$RULE_FILE"
        udevadm control --reload-rules && udevadm trigger
        log_success "Hardware Trigger Active."
    else
        log_warning "Disabling Reactive Discovery..."
        rm -f "$RULE_FILE"
        udevadm control --reload-rules
    fi
}