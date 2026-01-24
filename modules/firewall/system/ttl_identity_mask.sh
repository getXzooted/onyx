function apply_ttl_identity_mask() {
    local INTENT=$1
    
    # 1. Always clear old rules first to prevent "Identity Bleed"
    iptables -t mangle -D POSTROUTING -j TTL --ttl-set 64 2>/dev/null
    iptables -t mangle -D POSTROUTING -j TTL --ttl-set 128 2>/dev/null
    iptables -t mangle -D POSTROUTING -j TTL --ttl-set 255 2>/dev/null

    if [[ "$INTENT" == "true" ]]; then
        local VAL=$(get_persona_value "ttl")
        log_step "Enforcing Persona TTL Identity: $VAL"
        
        build_rule POSTROUTING -t mangle -j TTL --ttl-set "$VAL" \
            -m comment --comment "ONYX_TTL_MASK"
    else
        log_warning "TTL Identity Masking Disabled."
    fi
}

function check_ttl_identity_mask() {
    local INTENT=$1
    local DESIRED_VAL=$(get_persona_value "ttl")
    
    # THE FIX: Auditor must specifically check the mangle table
    # We grep for the label to avoid the quoting/parsing issues
    iptables -t mangle -S POSTROUTING 2>/dev/null | grep -q "ONYX_TTL_MASK"
    local STATUS=$?

    if [[ "$INTENT" == "true" ]]; then
        [[ $STATUS -eq 0 ]] && return 0 || return 1
    fi
    
    if [[ "$INTENT" == "false" ]]; then
        [[ $STATUS -ne 0 ]] && return 0 || return 1
    fi
}