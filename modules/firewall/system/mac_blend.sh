# modules/hardware/stealth_rules.sh

function apply_mac_blend() {
    local INTENT=$1
    local IFACE="${ONYX_LAN_IFACE:-uap0}"
    # Consult the Mapper for the OUI
    local OUI=$(get_persona_value "oui")

    # Always start with a clean slate (Hardware Reset)
    systemctl stop hostapd dnsmasq &>/dev/null
    ip link set "$IFACE" down
    macchanger -p "$IFACE" &>/dev/null

    if [[ "$INTENT" == "true" ]]; then
        log_step "Enforcing Persona MAC Identity..."
        
        if [[ "$OUI" == "RANDOM" ]]; then
            macchanger -r "$IFACE" &>/dev/null
        else
            # Construct the persona-specific MAC
            local NEW_MAC="${OUI}:$(printf '%02x:%02x:%02x' $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)))"
            ip link set dev "$IFACE" address "$NEW_MAC"
            log_info "MAC rotated to match persona OUI: $OUI"
        fi
    else
        log_warning "MAC Blend deactivated. Permanent hardware MAC restored."
    fi

    ip link set "$IFACE" up
    systemctl start dnsmasq hostapd &>/dev/null
}

function check_mac_blend() {
    local INTENT=$1
    local IFACE="${ONYX_LAN_IFACE:-uap0}"
    local OUI=$(get_persona_value "oui")
    local CURRENT_MAC=$(cat /sys/class/net/"$IFACE"/address 2>/dev/null | tr '[:upper:]' '[:lower:]')

    # 1. Handle "OFF" state: Current MAC must match Permanent Hardware MAC
    if [[ "$INTENT" == "false" ]]; then
        # If current matches permanent, we are in sync (0)
        macchanger -s "$IFACE" | grep -qi "current" | grep -qi "permanent" && return 0 || return 1
    fi

    # 2. Handle "ON" state: Current MAC must match Persona OUI
    if [[ "$INTENT" == "true" ]]; then
        # If the persona is 'random', any non-hardware MAC passes
        if [[ "$OUI" == "RANDOM" ]]; then
            macchanger -s "$IFACE" | grep -qi "current" | grep -qv "permanent" && return 0 || return 1
        fi

        # If persona has a fixed OUI, verify the prefix
        [[ "$CURRENT_MAC" =~ ^(${OUI,,}) ]] && return 0 || return 1
    fi

    return 1
}