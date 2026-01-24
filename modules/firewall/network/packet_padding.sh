# modules/firewall/network/packet_padding.sh

function apply_packet_padding() {
    local INTENT=$1
    local IFACE="${ONYX_VPN_IFACE:-wg0}"
    
    # 1. Identity Sync: Inherit the Persona's TTL
    local TTL_VAL=$(get_persona_value "ttl")

    if [[ "$INTENT" == "true" ]]; then
        log_step "Enforcing Packet Shape Obfuscation (Smart Padding)..."
        
        # 2. TTL Consistency (Ensures padding packets don't leak original OS signature)
        build_rule POSTROUTING -t mangle -o "$IFACE" -j TTL --ttl-set "$TTL_VAL" \
            -m comment --comment "ONYX_PADDING_TTL"

        # 3. Shape Obfuscation: IP ID Randomization
        # We use the Asset Engine to ensure the module is available
        if modinfo xt_ID &>/dev/null || asset_get "xtables_addons"; then
            build_rule POSTROUTING -t mangle -o "$IFACE" -j ID --id 0 \
                -m comment --comment "ONYX_SHAPE_OBFUSCATION"
            log_success "Advanced Packet Padding active on $IFACE."
        else
            log_warning "Shape Obfuscation (xt_ID) skipped: Kernel module unavailable."
        fi
    else
        log_warning "Deactivating Packet Padding..."
        delete_rule POSTROUTING -t mangle -o "$IFACE" -j TTL --ttl-set "$TTL_VAL" \
            -m comment --comment "ONYX_PADDING_TTL"
        delete_rule POSTROUTING -t mangle -o "$IFACE" -j ID --id 0 \
            -m comment --comment "ONYX_SHAPE_OBFUSCATION"
    fi
}

function check_packet_padding() {
    local INTENT=$1
    local IFACE="${ONYX_VPN_IFACE:-wg0}"
    
    # Search for our custom labels in the mangle table
    local STATUS_TTL=$(iptables -t mangle -S POSTROUTING 2>/dev/null | grep -q "ONYX_PADDING_TTL" && echo 0 || echo 1)
    local STATUS_ID=$(iptables -t mangle -S POSTROUTING 2>/dev/null | grep -q "ONYX_SHAPE_OBFUSCATION" && echo 0 || echo 1)

    # SYNC LOGIC:
    if [[ "$INTENT" == "true" ]]; then
        # We consider 'Sync' if at least the TTL rule is there (ID is a 'best-effort' upgrade)
        [[ $STATUS_TTL -eq 0 ]] && return 0 || return 1
    fi

    if [[ "$INTENT" == "false" ]]; then
        [[ $STATUS_TTL -ne 0 && $STATUS_ID -ne 0 ]] && return 0 || return 1
    fi

    return 1
}