function apply_ttl_identity_mask() {
    local INTENT=$1
    
    # 1. Always clear old rules first to prevent "Identity Bleed"
    iptables -t mangle -D POSTROUTING -j TTL --ttl-set 64 2>/dev/null
    iptables -t mangle -D POSTROUTING -j TTL --ttl-set 128 2>/dev/null
    iptables -t mangle -D POSTROUTING -j TTL --ttl-set 255 2>/dev/null

    if [[ "$INTENT" == "true" ]]; then
        local VAL=$(get_persona_value "ttl")
        log_step "Enforcing Persona TTL Identity: $VAL"
        
        iptables -t mangle -A POSTROUTING -j TTL --ttl-set "$VAL" \
            -m comment --comment "ONYX_TTL_MASK"
    else
        log_warning "TTL Identity Masking Disabled."
    fi
}

function check_ttl_identity_mask() {
    local INTENT=$1
    local DESIRED_VAL=$(get_persona_value "ttl")
    local CURRENT_VAL=$(iptables -t mangle -S POSTROUTING 2>/dev/null | grep ONYX_TTL_MASK | awk '{print $NF}')

    if [[ "$INTENT" == "true" ]]; then
        [[ "$CURRENT_VAL" == "$DESIRED_VAL" ]] && return 0 || return 1
    fi
    
    # If intent is false, we are in sync only if CURRENT_VAL is empty
    [[ -z "$CURRENT_VAL" ]] && return 0 || return 1
}