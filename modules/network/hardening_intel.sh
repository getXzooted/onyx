#!/bin/bash
# lib/hardening_intel.sh

# lib/hardening_intel.sh

function audit_state() {
    # 1. Use the EXACT same ordered key extraction as repair_state
    local KEYS=$(yq e '.. | select(tag == "!!bool" or tag == "!!str") | path | join(".")' "$HARDENING_YAML")
    local DRIFT_COUNT=0
    
    log_header "ONYX DRIFT DETECTION"
    
    for KEY in $KEYS; do
        local RULE_NAME="${KEY##*.}"
        local INTENT=$(yq e ".$KEY" "$HARDENING_YAML")

        # 2. Check for the audit worker
        if declare -f "check_$RULE_NAME" > /dev/null; then
            if ! "check_$RULE_NAME" "$INTENT"; then
                log_error "[DRIFT DETECTED] $RULE_NAME is out of sync."
                ((DRIFT_COUNT++))
            else
                log_success "[OK] $RULE_NAME is in sync."
            fi
        else
            # 3. Inform the user if a rule in YAML has no worker yet
            log_warning "No audit worker found for rule: $RULE_NAME"
        fi
    done

    # 4. FINAL SUMMARY: This makes it "Teaser Ready"
    echo "--------------------------------------"
    if [ "$DRIFT_COUNT" -eq 0 ]; then
        log_success "AUDIT COMPLETE: System is in the desired state."
        return 0
    else
        log_error "AUDIT COMPLETE: Found $DRIFT_COUNT drifted rules."
        return 1
    fi
}

function repair_state() {
    log_header "ONYX SECURITY ENFORCEMENT"

    # 1. THE FAIL-CLOSED LOCK: Set default policy to DROP before flushing
    # This prevents internet access while we work.
#    log_step "Locking gates (Fail-Closed)..."
#    iptables -P INPUT DROP
#    iptables -P FORWARD DROP
#    iptables -P OUTPUT DROP

    # 2. THE NUCLEAR FLUSH: Wipe existing rules to guarantee order
#    log_step "Flushing chains to prevent rule-drift disorder..."
#    iptables -F
#    iptables -t nat -F
#    iptables -t mangle -F

    # 3. LOCAL LOOPBACK: Prevent local system deadlocks
#    iptables -A INPUT -i lo -j ACCEPT
#    iptables -A OUTPUT -o lo -j ACCEPT
    
    # 4. Extract keys in their exact file order
    # Using '.. | path' ensures we traverse the YAML tree top-to-bottom
    local KEYS=$(yq e '.. | select(tag == "!!bool" or tag == "!!str") | path | join(".")' "$HARDENING_YAML")

    for KEY in $KEYS; do
        # Extract the specific rule name (e.g., foundation.established_related -> established_related)
        local RULE_NAME="${KEY##*.}"
        
        # Get the intended state (true/false/value)
        local INTENT=$(yq e ".$KEY" "$HARDENING_YAML")

        # Sequential Execution
        # We check if an apply_ function exists for this specific rule
        if declare -f "apply_$RULE_NAME" > /dev/null; then
            # Execute the rule. Because $KEYS is ordered, this happens line-by-line.
            "apply_$RULE_NAME" "$INTENT"
        else
            log_warning "No worker found for rule: $RULE_NAME (Skipping)"
        fi
    done
    
    log_success "Ordered hardening sequence complete."
}

function simulate_rule() {
    echo "DRY RUN: iptables -I $@"
}

function export_live() {
    iptables-save > "$CONFIG_DIR/live_snapshot.rules"
    log_success "Live ruleset exported to $CONFIG_DIR/live_snapshot.rules"
}