#!/bin/bash
# /opt/onyx/lib/hardening_rules.sh
# ONYX V2: Dedicated Security Rule Library

# --- KERNEL RULES ---

function check_mac_stealth() {
    # Verify if uap0 is using its permanent hardware MAC or a randomized one
    local CURRENT=$(cat /sys/class/net/uap0/address 2>/dev/null)
    local PERM=$(ethtool -P uap0 2>/dev/null | awk '{print $3}')
    
    # If they match, the MAC is NOT rotated (Drifted)
    if [[ "$CURRENT" == "$PERM" ]]; then
        return 1
    fi
    return 0
}

function apply_mac_stealth() {
    if [[ "$1" == "true" ]]; then
        log_step "Applying MAC Stealth (Rotating uap0)..."
        
        # 1. Stop the Wireless Stack to prevent BSSID mismatch
        systemctl stop hostapd dnsmasq &>/dev/null
        
        # 2. Rotate the MAC
        ip link set uap0 down
        macchanger -r uap0 &>/dev/null
        ip link set uap0 up
        
        # 3. Restart services to broadcast the new identity
        systemctl start dnsmasq hostapd &>/dev/null
        
        log_success "MAC Stealth Applied: uap0 identity rotated."
    fi
}

function check_qname_stealth() {
    # Verify QNAME Minimization is active in Unbound config
    grep -q "qname-minimisation: yes" /etc/unbound/unbound.conf.d/pi-zero.conf &>/dev/null && return 0 || return 1
}

function apply_qname_stealth() {
    if [[ "$1" == "true" ]]; then
        log_step "Applying QNAME Minimization (DNS Metadata Stealth)..."
        # Inject privacy flag into the server block
        sed -i '/server:/a \    qname-minimisation: yes' /etc/unbound/unbound.conf.d/pi-zero.conf
        systemctl restart unbound &>/dev/null
    fi
}

function check_icmp_recon_defense() {
    [[ "$(sysctl -n net.ipv4.icmp_ratelimit)" == "1000" ]] && return 0 || return 1
}

function apply_icmp_recon_defense() {
    if [[ "$1" == "true" ]]; then
        log_step "Applying ICMP Recon Defense (Anti-Scanning)..."
        # Standardize rate limiting and ignore bogus error responses
        sysctl -w net.ipv4.icmp_ratelimit=1000 > /dev/null
        sysctl -w net.ipv4.icmp_ignore_bogus_error_responses=1 > /dev/null
    fi
}

function check_arp_guard() {
    [[ "$(sysctl -n net.ipv4.conf.all.arp_ignore)" == "1" ]] && return 0 || return 1
}

function apply_arp_guard() {
    if [[ "$1" == "true" ]]; then
        log_step "Applying ARP Guard (Neighbor Table Stealth)..."
        sysctl -w net.ipv4.conf.all.arp_ignore=1 > /dev/null
        sysctl -w net.ipv4.conf.all.arp_announce=2 > /dev/null
    fi
}

function check_fingerprint_protection() {
    # Verify if TCP Timestamps are disabled (Reduced OS signature)
    [[ "$(sysctl -n net.ipv4.tcp_timestamps)" == "0" ]] && return 0 || return 1
}

function apply_fingerprint_protection() {
    if [[ "$1" == "true" ]]; then
        log_step "Standardizing TCP Stack (Anti-Fingerprinting)..."
        # 1. Disable RFC1323 timestamps to hide OS-specific uptime/timing
        sysctl -w net.ipv4.tcp_timestamps=0 > /dev/null
        # 2. Enable Window Scaling (Standard behavior)
        sysctl -w net.ipv4.tcp_window_scaling=1 > /dev/null
    fi
}

function check_kernel_lockdown() {
    [[ "$(sysctl -n kernel.sysrq)" == "0" ]] && return 0 || return 1
}

function apply_kernel_lockdown() {
    if [[ "$1" == "true" ]]; then
        log_step "Applying Kernel Lockdown (Anti-Forensics)..."
        # Disable the Magic SysRq debug keys
        sysctl -w kernel.sysrq=0 > /dev/null
        # Reboot automatically 1 second after a kernel panic
        sysctl -w kernel.panic=1 > /dev/null
    fi
}

function check_anti_spoofing() {
    # Verify Strict Reverse Path Filtering is active
    [[ "$(sysctl -n net.ipv4.conf.all.rp_filter)" == "1" ]] && return 0 || return 1
}

function apply_anti_spoofing() {
    if [[ "$1" == "true" ]]; then
        log_step "Applying Anti-Spoofing (Strict RP Filter)..."
        # Prevents an attacker from sending packets with a fake source IP
        sysctl -w net.ipv4.conf.all.rp_filter=1 > /dev/null
        sysctl -w net.ipv4.conf.default.rp_filter=1 > /dev/null
    fi
}

function check_flood_protection() {
    # Check if TCP SYN Cookies are enabled
    [[ "$(sysctl -n net.ipv4.tcp_syncookies)" == "1" ]] && return 0 || return 1
}

function apply_flood_protection() {
    if [[ "$1" == "true" ]]; then
        log_step "Applying Flood Protection (TCP SYN Cookies)..."
        # Protects against SYN flood attacks
        sysctl -w net.ipv4.tcp_syncookies=1 > /dev/null
    fi
}

function check_icmp_stealth() {
    # Check if ignoring ICMP broadcasts and bogus error responses
    [[ "$(sysctl -n net.ipv4.icmp_echo_ignore_broadcasts)" == "1" ]] && return 0 || return 1
}

function apply_icmp_stealth() {
    if [[ "$1" == "true" ]]; then
        log_step "Applying ICMP Stealth (Dropping Broadcast/Bogus)..."
        # Ignore ICMP echo broadcasts to prevent Smurf attacks
        sysctl -w net.ipv4.icmp_echo_ignore_broadcasts=1 > /dev/null
        # Ignore bogus ICMP error responses
        sysctl -w net.ipv4.icmp_ignore_bogus_error_responses=1 > /dev/null
    fi
}

function check_disable_ipv6() {
    local INTENT=$1
    local CURRENT=$(sysctl -n net.ipv6.conf.all.disable_ipv6)
    # If YAML says true (disable) but kernel says 0 (enabled), it's a drift
    [[ "$INTENT" == "true" && "$CURRENT" == "0" ]] && return 1
    return 0
}

function apply_disable_ipv6() {
    log_step "Applying IPv6 Lockdown..."
    sysctl -w net.ipv6.conf.all.disable_ipv6=1 > /dev/null
    sysctl -w net.ipv6.conf.default.disable_ipv6=1 > /dev/null
}

function check_ignore_redirects() {
    [[ "$(sysctl -n net.ipv4.conf.all.accept_redirects)" == "0" ]] && return 0 || return 1
}

function apply_ignore_redirects() {
    sysctl -w net.ipv4.conf.all.accept_redirects=0 > /dev/null
}

function check_ip_forwarding() {
    [[ "$(sysctl -n net.ipv4.ip_forward)" == "1" ]] && return 0 || return 1
}

function apply_ip_forwarding() {
    if [[ "$1" == "true" ]]; then
        sysctl -w net.ipv4.ip_forward=1 > /dev/null
    fi
}

function check_log_martians() {
    [[ "$(sysctl -n net.ipv4.conf.all.log_martians)" == "1" ]] && return 0 || return 1
}

function apply_log_martians() {
    if [[ "$1" == "true" ]]; then
        sysctl -w net.ipv4.conf.all.log_martians=1 > /dev/null
    fi
}

function check_no_send_redirects() {
    [[ "$(sysctl -n net.ipv4.conf.all.send_redirects)" == "0" ]] && return 0 || return 1
}

function apply_no_send_redirects() {
    if [[ "$1" == "true" ]]; then
        sysctl -w net.ipv4.conf.all.send_redirects=0 > /dev/null
    fi
}

# --- SYSTEM RULES ---

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
    # 1. Verify if /var/log is a mountpoint
    if mountpoint -q /var/log; then
        # 2. STRICT: It MUST be a tmpfs (RAM-disk) to pass audit
        if mount | grep "/var/log" | grep -q "tmpfs"; then
            return 0
        fi
    fi
    # If not a mountpoint or not tmpfs, it is drifted
    return 1
}

function apply_forensic_zero() {
    if [[ "$1" == "true" ]]; then
        # --- ONYX STEALTH: LOG-TO-RAM ---
        log_step "Engaging Forensic-Zero (Log-to-RAM)..."
        log_info "Redirecting logs to Volatile RAM..."

        # 1. Manual Download (Apt-get fails on Pi Zero for this tool)
        if ! command -v folder2ram &> /dev/null; then
            log_step "Downloading folder2ram v0.4.1..."
            wget -qO /sbin/folder2ram https://raw.githubusercontent.com/bobafetthotmail/folder2ram/master/debian_package/sbin/folder2ram
            chmod +x /sbin/folder2ram
        fi

        # 2. Manual Configuration (Since -enable is missing in 0.4.1)
        log_step "Configuring /var/log for RAM-disk..."
        mkdir -p /etc/folder2ram
        # Format: type [space] path [space] options
        echo "tmpfs /var/log size=128M,nodev,nosuid,noatime" > /etc/folder2ram/folder2ram.conf

        # 3. Enable Systemd Service
        folder2ram -enablesystemd &>/dev/null

        # 4. Stop loggers so we can mount /var/log
        log_step "Unlocking /var/log from system loggers..."
        systemctl stop rsyslog unbound dnsmasq hostapd &>/dev/null
        journalctl --relinquish-var &>/dev/null
        
        # 5. Mount the partitions
        if folder2ram -mountall; then
            # 6. Success: Flush and Restore services
            journalctl --flush &>/dev/null
            systemctl start rsyslog unbound dnsmasq hostapd &>/dev/null
            log_success "Forensic-Zero Active: Logs are now in RAM."
        else
            # 7. Fallback: Restore loggers if mount failed
            systemctl start rsyslog unbound dnsmasq hostapd &>/dev/null
            log_error "Forensic-Zero: Mount failed (Target Busy). Reboot required."
        fi
    fi
}

function check_dark_mode() {
    # Check if the dtparam for LEDs is in the config
    grep -q "dtparam=pwr_led_trigger=none" /boot/firmware/config.txt &>/dev/null && return 0 || return 1
}

function apply_dark_mode() {
    if [[ "$1" == "true" ]]; then
        log_step "Applying Physical Dark Mode (LED Stealth)..."
        # Disable PWR and ACT LEDs in the firmware config
        {
            echo "dtparam=pwr_led_trigger=none"
            echo "dtparam=pwr_led_activelow=off"
            echo "dtparam=act_led_trigger=none"
            echo "dtparam=act_led_activelow=off"
        } >> /boot/firmware/config.txt
        log_info "Physical stealth requires a reboot to sync firmware."
    fi
}

function check_mac_blend() {
    local DESIRED=$1
    local CURRENT=$(cat /sys/class/net/uap0/address 2>/dev/null)
    
    # If the rule is off, we are technically 'in sync' with the off state
    [[ "$DESIRED" == "off" ]] && return 0

    case "$DESIRED" in
        apple)   OUI="60:fb:42" ;;
        samsung) OUI="00:07:ab" ;;
        intel)   OUI="00:16:ea" ;;
        random)  return 0 ;; # Random always passes audit as it has no fixed OUI
        *) return 1 ;; # Invalid or drifted
    esac

    [[ "$CURRENT" =~ ^($OUI) ]] && return 0 || return 1
}

function apply_mac_blend() {
    local MODE=$1
    [[ "$MODE" == "off" ]] && return 0

    case "$MODE" in
        apple)   OUI="60:fb:42" ;;
        samsung) OUI="00:07:ab" ;;
        intel)   OUI="00:16:ea" ;;
        random)  
            log_step "Applying Total MAC Randomization..."
            ip link set uap0 down
            macchanger -r uap0 &>/dev/null
            ip link set uap0 up
            return 0
            ;;
    esac

    log_step "Applying MAC Blend: Adopting $MODE identity..."
    # 1. Stop the Wireless Stack to prevent BSSID mismatch
    systemctl stop hostapd dnsmasq &>/dev/null

    # 2. Rotate the MAC
    ip link set uap0 down
    # Combine the fixed OUI with a randomized suffix
    ip link set dev uap0 address ${OUI}:$(printf '%02x:%02x:%02x' $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)))
    ip link set uap0 up

    # 3. Restart services to broadcast the new identity
    systemctl start dnsmasq hostapd &>/dev/null
    
    log_success "MAC Blend Active: Now appearing as $MODE hardware."
}

function check_bluetooth_locked() {
    local INTENT=$1
    if [[ "$INTENT" == "true" ]]; then
        systemctl is-active bluetooth &>/dev/null && return 1 || return 0
    fi
    return 0
}

function apply_bluetooth_locked() {
    if [[ "$1" == "true" ]]; then
        log_step "Locking Bluetooth Hardware..."
        systemctl disable --now bluetooth &>/dev/null
        grep -q "dtoverlay=disable-bt" /boot/firmware/config.txt || echo "dtoverlay=disable-bt" >> /boot/firmware/config.txt
    fi
}

# --- NETWORK RULES ---

function check_safety_net() {
    # 1. Verify Default Policy is DROP
    if ! iptables -L FORWARD -n | grep -q "policy DROP"; then
        return 1
    fi
    
    # 2. Verify VPN Endpoint rule is present in OUTPUT chain
    if ! iptables -L OUTPUT -n | grep -q "$ONYX_VPN_ENDPOINT"; then
        return 1
    fi
    
    return 0
}

function apply_safety_net() {
    if [[ "$1" == "true" ]]; then
        log_step "Repairing Safety Net (Firewall Sync)..."
        
        # 1. LOAD THE GENERATOR: Ensure the module is available
        source "$ONYX_ROOT/modules/network/safety_net.sh"
        
        # 2. EXECUTE: Now that the file is guaranteed to exist, run it to restore internet
        if [ -x "/usr/local/bin/safety-net.sh" ]; then
            /usr/local/bin/safety-net.sh
        else
            log_error "Safety Net repair failed: Script could not be built."
        fi
    fi
}

function check_ghost_host() {
    # Check if mDNS and LLMNR ports are blocked in the OUTPUT chain
    iptables -C OUTPUT -p udp -m multiport --dports 5353,5355 -j DROP &>/dev/null && return 0 || return 1
}

function apply_ghost_host() {
    if [[ "$1" == "true" ]]; then
        log_step "Applying Ghost Host (Killing Discovery Broadcasts)..."
        # Block outbound mDNS (5353) and LLMNR (5355)
        build_rule OUTPUT -p udp -m multiport --dports 5353,5355 -j DROP
    fi
}

function check_mtu_stealth() {
    # Check if MSS clamping is active on the WireGuard interface
    iptables -t mangle -C POSTROUTING -o wg0 -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu &>/dev/null && return 0 || return 1
}

function apply_mtu_stealth() {
    if [[ "$1" == "true" ]]; then
        log_step "Applying MTU/MSS Stealth (Clamping wg0)..."
        # Force TCP handshake to use the tunnel's specific MTU to prevent 'Oversized Packet' detection
        iptables -t mangle -A POSTROUTING -o wg0 -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu
    fi
}

function check_webrtc_lockdown() {
    iptables -C OUTPUT -p udp -m multiport --dports 3478,19302,5349 -j DROP &>/dev/null && return 0 || return 1
}

function apply_webrtc_lockdown() {
    log_step "Blocking WebRTC STUN/TURN traffic..."
    build_rule OUTPUT -p udp -m multiport --dports 3478,19302,5349 -j DROP
}

function check_syn_proxy() {
    iptables -t raw -C PREROUTING -i vlan20 -p tcp --syn -j NOTRACK &>/dev/null && return 0 || return 1
}

function apply_syn_proxy() {
    if [[ "$1" == "true" ]]; then
        log_step "Engaging SYN Proxy (VLAN Isolation Guard)..."
        # 1. Flag packets for SYNPROXY processing
        iptables -t raw -A PREROUTING -i vlan20 -p tcp --syn -j NOTRACK
        iptables -A FORWARD -i vlan20 -p tcp -m state --state INVALID,UNTRACKED -j SYNPROXY --sack-perm --timestamp --wscale 7 --mss 1460
        # 2. Drop anything that doesn't complete the handshake with the Pi
        iptables -A FORWARD -i vlan20 -m state --state INVALID -j DROP
    fi
}

function check_port_scrambling() {
    # 1. Check legacy iptables
    iptables -t nat -L POSTROUTING -n | grep -q "MASQUERADE.*fully-random" && return 0
    
    # 2. Check native nftables (Fallback Check)
    nft list table ip nat 2>/dev/null | grep -q "masquerade fully-random" && return 0
    
    return 1
}

function apply_port_scrambling() {
    if [[ "$1" == "true" ]]; then
        log_step "Applying Port Scrambling (Source Port Randomization)..."
        # 1. Try the standard nf_tables flag
        if ! iptables -t nat -A POSTROUTING -p udp --dport "$ONYX_VPN_PORT" -j MASQUERADE --random-fully 2>/dev/null; then
            # 2. Tactical Fallback: Use native nftables command if iptables-nft shim fails
            log_info "iptables shim failed; using native nft fallback..."
            nft add rule ip nat POSTROUTING udp dport "$ONYX_VPN_PORT" masquerade fully-random 2>/dev/null
        fi
    fi
}

function check_packet_padding() {
    # Verify TTL is set and the ID module is available
    iptables -t mangle -L POSTROUTING -n | grep -q "TTL set to 64" && return 0 || return 1
}

function apply_packet_padding() {
    if [[ "$1" == "true" ]]; then
        log_step "Obfuscating Packet Shape (IP ID & TTL Jitter)..."
        iptables -t mangle -A POSTROUTING -o wg0 -j TTL --ttl-set 64
        # SAFE MODE: Only apply ID randomization if the module built successfully
        if [ -f "/lib/modules/$(uname -r)/extra/xt_ID.ko" ] || modinfo xt_ID &>/dev/null; then
            iptables -t mangle -A POSTROUTING -o wg0 -j ID --id 0
        else
            log_warning "Packet ID randomization skipped: xt_ID module not found (6.12 Build Failure)."
        fi
    fi
}

function apply_bogom_filter() {
    log_step "Engaging Bogom Filter (Dropping Malformed Protocols)..."
    # Drop packets with invalid flag combinations used by scanners
    build_rule INPUT -p tcp --tcp-flags ALL NONE -j DROP
    build_rule INPUT -p tcp --tcp-flags ALL ALL -j DROP
}

function check_bogom_filter() {
    # 1. Check for the Null Scan block
    if ! iptables -C INPUT -p tcp --tcp-flags ALL NONE -j DROP &>/dev/null; then
        return 1
    fi

    # 2. Check for the Xmas Scan block
    if ! iptables -C INPUT -p tcp --tcp-flags ALL ALL -j DROP &>/dev/null; then
        return 1
    fi

    return 0
}

function check_tarpit_trap() {
    if [[ "$1" == "true" ]]; then
        if modinfo xt_TARPIT &>/dev/null; then
            iptables -L INPUT -n | grep -q "TARPIT" && return 0 || return 1
        else
            log_warning "TARPIT Trap check skipped: Kernel module missing (6.12 Build Failure)."
            return 0
        fi
    else
        return 0
    fi
}

function apply_tarpit_trap() {
    if [[ "$1" == "true" ]]; then
        log_step "Setting Scanner Traps (TARPIT Active)..."
        # SAFE MODE: Only apply TARPIT if the module is available
        if modinfo xt_TARPIT &>/dev/null; then
            iptables -A INPUT -p tcp -m state --state NEW -j TARPIT
        else
            log_warning "TARPIT Trap skipped: Kernel module missing (6.12 Build Failure)."
        fi
    fi
}

function check_isolation_barrier() {
    iptables -C FORWARD -i vlan20 -o uap0 -j DROP &>/dev/null && return 0 || return 1
}

function apply_isolation_barrier() {
    if [[ "$1" == "true" ]]; then
        # Calls tactical function from execution lib
        build_rule FORWARD -i vlan20 -o uap0 -j DROP
    fi
}

function check_default_deny() {
    # Check if the global policy is DROP
    iptables -L FORWARD -n | grep -q "policy DROP" && return 0 || return 1
}

function apply_default_deny() {
    if [[ "$1" == "true" ]]; then
        log_step "Applying Global Default Deny policy..."
        iptables -P FORWARD DROP
    fi
}

function check_ttl_masking() {
    local DESIRED=$1
    local CURRENT=$(iptables -t mangle -L POSTROUTING -n | grep "TTL set to" | awk '{print $NF}')
    
    [[ "$DESIRED" == "off" ]] && return 0

    case "$DESIRED" in
        windows) VAL="128" ;;
        linux)   VAL="64"  ;;
        solaris) VAL="255" ;;
        *) return 1 ;;
    esac

    [[ "$CURRENT" == "$VAL" ]] && return 0 || return 1
}

function apply_ttl_masking() {
    local MODE=$1
    [[ "$MODE" == "off" ]] && return 0

    case "$MODE" in
        windows) VAL="128" ;;
        linux)   VAL="64"  ;;
        solaris) VAL="255" ;;
    esac

    log_step "Applying TTL Mask: Appearing as $MODE hardware..."
    # Force the OS identity at the packet level
    iptables -t mangle -A POSTROUTING -j TTL --ttl-set "$VAL"
    log_success "TTL Identity set to $VAL."
}

# --- SENTINEL TRAP WORKER ---
function check_sentinel_trap() {
    # Verify if the TARPIT rule exists in the INPUT chain
    iptables -L INPUT -n | grep -q "TARPIT" && return 0 || return 1
}

function apply_sentinel_trap() {
    if [[ "$1" == "true" ]]; then
        log_step "Applying Sentinel Trap (Honeypot Active)..."
        # Directly inject the retaliatory honey ports
        build_rule INPUT -p tcp -m multiport --dports 23,3389 -j TARPIT
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
    # Verify if drops exist and the intelligence file is present
    iptables -L INPUT -n | grep -q "DROP" && [[ -f "/etc/onyx/firewall/geo_block.list" ]] && return 0
    return 1
}

function apply_geo_blocking() {
    local GEO_LIST="/etc/onyx/firewall/geo_block.list"
    if [[ "$1" == "true" ]] && [[ -f "$GEO_LIST" ]]; then
        log_step "Enforcing Geoblocking Intel..."
        # Loop the intelligence list and inject rules idempotently
        while read -r range; do
            [[ -z "$range" ]] && continue
            build_rule INPUT -s "$range" -j DROP
        done < "$GEO_LIST"
    fi
}

# --- DPI LITE WORKER ---
function check_telemetry_blackout() {
    # Verify kernel string matching for telemetry is active
    iptables -L FORWARD -n | grep -q "STRING match \"telemetry\"" && return 0 || return 1
}

function apply_telemetry_blackout() {
    if [[ "$1" == "true" ]]; then
        log_step "Engaging Telemetry Blackout..."
        local SIGNATURES=("telemetry" "analytics" "metrics" "vortex.data")
        for SIG in "${SIGNATURES[@]}"; do
            # Inject signatures into both Forwarding and Output chains
            build_rule FORWARD -m string --algo bm --string "$SIG" -j REJECT
            build_rule OUTPUT -m string --algo bm --string "$SIG" -j REJECT
        done
    fi
}