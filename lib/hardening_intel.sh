#!/bin/bash
# lib/hardening_intel.sh

function audit_state() {
    log_header "AUDITING SECURITY STATE"
    # Example: Check isolation barrier if YAML says true
    local ISOLATE=$(yq '.hardening.network.isolation_barrier' "$ONYX_ROOT/etc/hardening.yml")
    if [[ "$ISOLATE" == "true" ]]; then
        if iptables -L FORWARD -n | grep -q "DROP.*vlan20.*uap0"; then
            log_success "Audit: Isolation Barrier is SECURE."
        else
            log_error "Audit: Isolation Barrier is OPEN (Drift Detected)."
        fi
    fi
}

function repair_state() {
    log_info "Repairing security drift..."
    # Add logic here to re-apply rules based on audit findings
}

function simulate_rule() {
    echo "DRY RUN: iptables -I $@"
}

function export_live() {
    iptables-save > "$ONYX_ROOT/etc/live_snapshot.rules"
    log_success "Live ruleset exported to etc/live_snapshot.rules"
}