#!/bin/bash
# MODULE: Provisioning > Ingest
# Checks boot partition for 'onyx.yml' OR 'wg0.conf'.
# Supports both Advanced (YAML) and Easy (WireGuard file) modes.

# Define Paths
if [ -d "/boot/firmware" ]; then
    BOOT_DIR="/boot/firmware"
else
    BOOT_DIR="/boot"
fi

CONFIG_SOURCE="$BOOT_DIR/onyx.yml"
WG_SOURCE="$BOOT_DIR/wg0.conf"
TARGET_CONFIG="$ONYX_ROOT/config/onyx.yml"

function parse_wg_file() {
    local source_file="$1"
    log_info "Parsing WireGuard config from $source_file..."

    # Extract values using grep/awk (Robust against spaces)
    local priv_key=$(grep -m1 "^PrivateKey" "$source_file" | cut -d '=' -f2 | xargs)
    local address=$(grep -m1 "^Address" "$source_file" | cut -d '=' -f2 | xargs)
    local pub_key=$(grep -m1 "^PublicKey" "$source_file" | cut -d '=' -f2 | xargs)
    
    # Repair Keys (add '=' back if missing)
    local priv_key=$(repair_key "$priv_key")
    local pub_key=$(repair_key "$pub_key")
    
    # Endpoint often has host:port, we need to split them usually, 
    # but our config parser expects endpoint and port separately or together.
    # Let's handle the split for safety.
    local full_endpoint=$(grep -m1 "^Endpoint" "$source_file" | cut -d '=' -f2 | xargs)
    local endpoint_ip=$(echo "$full_endpoint" | cut -d ':' -f1)
    local endpoint_port=$(echo "$full_endpoint" | cut -d ':' -f2)

    if [[ -z "$priv_key" || -z "$full_endpoint" ]]; then
        log_error "Failed to parse required fields from wg0.conf"
        return 1
    fi

    # Create a fresh onyx.yml with these values
    log_step "Converting to onyx.yml..."
    cat <<EOF > "$TARGET_CONFIG"
# Auto-Generated from wg0.conf drop-in
vpn_private_key: $priv_key
vpn_pubkey: $pub_key
vpn_endpoint: $endpoint_ip
vpn_port: $endpoint_port
vpn_address: $address
use_unbound: true # Default to secure mode
dns_recursive: true # Default to secure mode

EOF

    return 0
}

function provision_ingest() {

    # --- PERSISTENT MEMORY LOCK (Post-Reboot) ---
    # Ensures hardware is re-locked on every boot to fight Trixie's auto-generators
    if [[ "$(zramctl --noheadings --output ALGORITHM /dev/zram0 2>/dev/null)" != "lz4" ]]; then
        log_info "Memory Guard: Fixing hardware algorithm mismatch..."
        
        # Release locks
        sudo systemctl stop rpi-swap zramswap 2>/dev/null
        sudo systemctl mask rpi-swap zramswap 2>/dev/null
        sudo swapoff -a 2>/dev/null
        
        # Nuclear Release and Reload
        sudo modprobe -r zram 2>/dev/null
        sudo modprobe zram num_devices=1
        
        # Dynamic Scaling (50% RAM)
        TOTAL_MEM=$(free -m | awk '/^Mem:/{print $2}')
        ZRAM_SIZE=$((TOTAL_MEM / 2))M
        
        # Hardware Inject
        sudo zramctl --find --size "$ZRAM_SIZE" --algorithm lz4
        sudo mkswap /dev/zram0 && sudo swapon /dev/zram0 -p 100
        log_success "Memory Guard: Hardware Locked ($ZRAM_SIZE @ lz4)."
    fi
    
    # This logic sets the variables that the rest of the function uses.
    if [ -n "$1" ]; then
        if [[ "$1" == *".yml" ]]; then
            CONFIG_SOURCE="$1"
            WG_SOURCE="" 
        else
            WG_SOURCE="$1"
            CONFIG_SOURCE="" 
        fi
    fi

    local PROVISION_NEEDED=false

    # SCENARIO A: User dropped a full onyx.yml
    if [ -f "$CONFIG_SOURCE" ]; then
        log_header "NEW ONYX CONFIG DETECTED"
        mv "$CONFIG_SOURCE" "$TARGET_CONFIG"
        PROVISION_NEEDED=true
    fi

    # SCENARIO B: User dropped a raw wg0.conf (Proton/Mullvad style)
    if [ -f "$WG_SOURCE" ]; then
        log_header "NEW WIREGUARD FILE DETECTED"
        parse_wg_file "$WG_SOURCE"
        if [ $? -eq 0 ]; then
            mv "$WG_SOURCE" "$WG_SOURCE.bak" # Rename source so we don't loop
            PROVISION_NEEDED=true
        fi
    fi

    # If nothing new found, exit
    if [ "$PROVISION_NEEDED" = false ]; then
        return 0
    fi

    # --- EXECUTE PROVISIONING ---
    chmod 600 "$TARGET_CONFIG"
    log_step "Running Provisioning Sequence..."
    
    $ONYX_ROOT/bin/onyx provision
    
    if [ $? -eq 0 ]; then
        log_success "Provisioning successful."
        
        # Success Blink (3 Fast)
        for i in {1..3}; do
            echo 1 > /sys/class/leds/ACT/brightness; sleep 0.1
            echo 0 > /sys/class/leds/ACT/brightness; sleep 0.1
        done
        echo heartbeat > /sys/class/leds/ACT/trigger

        log_info "Rebooting system..."
        reboot
    else
        log_error "Provisioning failed."
        # Error Blink (5 Slow)
        for i in {1..5}; do
             echo 1 > /sys/class/leds/ACT/brightness; sleep 0.5
             echo 0 > /sys/class/leds/ACT/brightness; sleep 0.5
        done
    fi
}

provision_ingest