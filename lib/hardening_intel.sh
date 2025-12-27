#!/bin/bash
# lib/hardening_intel.sh

function audit_state() {
    local KEYS=$(yq e '.. | select(tag == "!!bool") | path | join(".")' "$HARDENING_YAML")
    local DRIFT_COUNT=0
    
    log_header "ONYX DRIFT DETECTION"
    
    for KEY in $KEYS; do
        local RULE_NAME="${KEY##*.}"
        local INTENT=$(yq e ".$KEY" "$HARDENING_YAML")

        if declare -f "check_$RULE_NAME" > /dev/null; then
            if ! "check_$RULE_NAME" "$INTENT"; then
                log_error "[DRIFT DETECTED] $RULE_NAME is out of sync."
                ((DRIFT_COUNT++))
            else
                log_success "[OK] $RULE_NAME is in sync."
            fi
        else
            log_warning "No audit worker found for rule: $RULE_NAME (Skipping)"
        fi
    done
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