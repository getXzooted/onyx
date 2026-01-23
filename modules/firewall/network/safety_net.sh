# modules/network/hardening_rules.sh

function apply_safety_net() {
    local INTENT=$1
    
    if [[ "$INTENT" == "true" ]]; then
        log_step "Enforcing Safety Net (Periodic Rules Persistence)..."
        
        # Ensure the script and service files are generated/updated
        # This calls your existing generator function
        network_safety_net
        
        # Activate the timer
        systemctl daemon-reload
        systemctl enable --now safety-net.timer &>/dev/null
        log_success "Safety Net active. Enforcement interval: ${ONYX_ENFORCEMENT_INTERVAL:-10min}"
    else
        log_warning "Deactivating Safety Net (Caution: Rules may drift)..."
        systemctl disable --now safety-net.timer &>/dev/null
        systemctl disable --now safety-net.service &>/dev/null
    fi
}

function check_safety_net() {
    local INTENT=$1
    
    # 1. Verify Service & Timer Existence
    local TIMER_ACTIVE=$(systemctl is-active safety-net.timer &>/dev/null && echo 0 || echo 1)
    
    if [[ "$INTENT" == "false" ]]; then
        [[ $TIMER_ACTIVE -eq 1 ]] && return 0 || return 1
    fi

    # 2. If Intent is True, we need to show the countdown
    if [[ $TIMER_ACTIVE -eq 0 ]]; then
        # Parse the 'NEXT' column from systemd-timers
        # We look specifically for the safety-net timer and grab the time string
        local NEXT_RUN_RAW=$(systemctl list-timers safety-net.timer --no-legend | awk '{print $4}')
        
        if [[ -n "$NEXT_RUN_RAW" ]]; then
            # systemctl usually gives '1min 30s' or '9min left'
            # To get strict HR:MN:SC, we calculate from the 'NEXT' timestamp (Unix time)
            local NEXT_UNIX=$(date -d "$(systemctl list-timers safety-net.timer --no-legend | awk '{print $1" "$2}')" +%s)
            local NOW_UNIX=$(date +%s)
            local DIFF=$((NEXT_UNIX - NOW_UNIX))

            if [ $DIFF -gt 0 ]; then
                local HRS=$((DIFF / 3600))
                local MINS=$(( (DIFF % 3600) / 60 ))
                local SECS=$((DIFF % 60))
                
                # We log this out so the user sees it in the audit table
                log_info "Next Enforcement: $(printf "%02d:%02d:%02d" $HRS $MINS $SECS) left"
                return 0
            fi
        fi
        return 0 # Still active, even if countdown parse failed
    fi

    return 1 # Timer is dead but should be alive
}