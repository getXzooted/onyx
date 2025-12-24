#!/bin/bash
# lib/hardening_intel.sh

function audit_state() {
    log_header "ONYX SECURITY AUDIT"
    local DRIFT_COUNT=0
    
    # Extract all keys from hardening.yml
    local KEYS=$(yq e '.. | select(tag == "!!bool") | path | join(".")' "$ONYX_ROOT/config/hardening.yml")

    for KEY in $KEYS; do
        local RULE_NAME="${KEY##*.}"
        local INTENT=$(yq e ".$KEY" "$ONYX_ROOT/config/hardening.yml")

        if declare -f "check_$RULE_NAME" > /dev/null; then
            if ! "check_$RULE_NAME" "$INTENT"; then
                log_error "[DRIFT] $RULE_NAME is NOT in the desired state."
                ((DRIFT_COUNT++))
            fi
        fi
    done
    [[ $DRIFT_COUNT -eq 0 ]] && log_success "Audit PASSED." || return 1
}

function repair_state() {
    log_header "ONYX SECURITY REPAIR"
    local KEYS=$(yq e '.. | select(tag == "!!bool") | path | join(".")' "$ONYX_ROOT/config/hardening.yml")

    for KEY in $KEYS; do
        local RULE_NAME="${KEY##*.}"
        local INTENT=$(yq e ".$KEY" "$ONYX_ROOT/config/hardening.yml")

        if declare -f "apply_$RULE_NAME" > /dev/null; then
            "apply_$RULE_NAME" "$INTENT"
        fi
    done
}

function simulate_rule() {
    echo "DRY RUN: iptables -I $@"
}

function export_live() {
    iptables-save > "$CONFIG_DIR/live_snapshot.rules"
    log_success "Live ruleset exported to $CONFIG_DIR/live_snapshot.rules"
}