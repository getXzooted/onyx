#!/bin/bash
# ==============================================================================
# MODULE: Network > Discovery & Enrollment
# PURPOSE: Hardware-agnostic role assignment and Zero-Trust enrollment.
# ==============================================================================

# Ensure the library is running within the Onyx environment
if [ -z "$ONYX_ROOT" ]; then
    echo "CRITICAL ERROR: This library must be sourced by the Onyx CLI."
    exit 1
fi

# ------------------------------------------------------------------------------
# FUNCTION: discover_hardware
# DESCRIPTION: Probes physical interfaces to identify the active WAN uplink.
# ------------------------------------------------------------------------------
function discover_hardware() {
    log_header "HARDWARE DISCOVERY"
    
    # 1. Enumerate all physical interfaces (excluding virtual lo, wg, etc.)
    local ALL_PHYS=$(ls /sys/class/net | grep -E '^(eth|en|wl)')
    export ONYX_WAN_IFACE=""
    export ONYX_LAN_POOL=()

    for IFACE in $ALL_PHYS; do
        # Skip if the link is physically down
        [[ "$(cat /sys/class/net/$IFACE/operstate)" != "up" ]] && continue

        # 2. Probe for Internet (WAN Scavenger)
        # We attempt a surgical ping through this specific interface (-I)
        if ping -c 1 -W 2 -I "$IFACE" 1.1.1.1 &>/dev/null; then
            if [[ -z "$ONYX_WAN_IFACE" ]]; then
                log_success "UPLINK DETECTED: $IFACE is now WAN."
                export ONYX_WAN_IFACE="$IFACE"
            else
                # If multiple have internet, the first remains WAN, others join LAN pool
                ONYX_LAN_POOL+=("$IFACE")
            fi
        else
            # Link is up but no internet detected; it's a LAN candidate
            ONYX_LAN_POOL+=("$IFACE")
        fi
    done

    # 3. Handle Fallback (Default to first physical NIC if no internet is found)
    if [[ -z "$ONYX_WAN_IFACE" ]]; then
        export ONYX_WAN_IFACE=$(echo "$ALL_PHYS" | head -n 1)
        log_warning "No internet path found. Defaulting WAN to $ONYX_WAN_IFACE."
    fi
}

# ------------------------------------------------------------------------------
# FUNCTION: enroll_hardware
# DESCRIPTION: Compares discovered hardware against hardening.yml and adds 
#              unknown interfaces as 'off' (Zero-Trust Enrollment).
# ------------------------------------------------------------------------------
function enroll_hardware() {
    log_header "SOVEREIGN HARDWARE ENROLLMENT"
    
    # 1. Ensure we have the latest discovery data
    discover_hardware

    # 2. Iterate through all physical interfaces
    local ALL_PHYS=$(ls /sys/class/net | grep -E '^(eth|en|wl)')

    for IFACE in $ALL_PHYS; do
        # 3. Skip the discovered WAN interface (handled by routing/VPN)
        [[ "$IFACE" == "$ONYX_WAN_IFACE" ]] && continue

        # 4. LAN Enrollment (The "Smart" Sync)
        # Use yq to check if this NIC is already present in your hardening configuration
        if ! yq e ".hardening.interfaces | has(\"$IFACE\")" "$HARDENING_YAML" | grep -q "true"; then
            log_step "NEW HARDWARE DETECTED: Enrolling $IFACE (Default: OFF)..."
            
            # Inject the new interface into hardening.yml set to 'off'
            # This forces you to explicitly 'approve' new ports via the toggle rule.
            yq e -i ".hardening.interfaces.\"$IFACE\" = \"off\"" "$HARDENING_YAML"
        fi
    done
}