function apply_string_telemetry_filter() {
    local INTENT=$1
    local SIGNATURES=("telemetry" "analytics" "metrics" "vortex.data")

    if [[ "$INTENT" == "true" ]]; then
        log_step "Enforcing Telemetry Blackout (L7 String Inspection)..."
        for SIG in "${SIGNATURES[@]}"; do
            # Block traffic passing through (Clients) and originating from (Gateway)
            build_rule FORWARD -m string --algo bm --string "$SIG" -j REJECT \
                -m comment --comment "ONYX_SIG_$SIG"
            build_rule OUTPUT -m string --algo bm --string "$SIG" -j REJECT \
                -m comment --comment "ONYX_SIG_$SIG"
        done
    else
        log_warning "Reverting Telemetry Blackout..."
        for SIG in "${SIGNATURES[@]}"; do
            delete_rule FORWARD -m string --algo bm --string "$SIG" -j REJECT \
                -m comment --comment "ONYX_SIG_$SIG"
            delete_rule OUTPUT -m string --algo bm --string "$SIG" -j REJECT \
                -m comment --comment "ONYX_SIG_$SIG"
        done
    fi
}

function check_string_telemetry_filter() {
    local INTENT=$1
    # We check the primary "telemetry" signature as the canary for the group
    iptables -C FORWARD -m string --algo bm --string "telemetry" -j REJECT &>/dev/null
    local STATUS=$?

    # SYNC LOGIC:
    # 1. Intent is 'true' and rule exists (STATUS 0) -> Sync (0)
    # 2. Intent is 'false' and rule is missing (STATUS non-zero) -> Sync (0)
    if [[ "$INTENT" == "true" && $STATUS -eq 0 ]]; then return 0; fi
    if [[ "$INTENT" == "false" && $STATUS -ne 0 ]]; then return 0; fi

    # Otherwise, system state has drifted from the desired YAML intent
    return 1
}