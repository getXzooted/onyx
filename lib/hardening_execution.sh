#!/bin/bash
# lib/hardening_execution.sh

function build_rule() {
    local CHAIN=$1; shift
    local RULE=$@
    if ! iptables -C "$CHAIN" $RULE 2>/dev/null; then
        iptables -I "$CHAIN" 1 $RULE
        log_success "Injected rule: $RULE"
    fi
}

function delete_rule() {
    local CHAIN=$1; shift
    local RULE=$@
    if iptables -C "$CHAIN" $RULE 2>/dev/null; then
        iptables -D "$CHAIN" $RULE
        log_success "Removed rule: $RULE"
    fi
}

function toggle_rule() {
    local KEY=$1; local STATE=$2
    yq -i ".hardening.$KEY = $STATE" "$CONFIG_DIR/hardening.yml"
    log_info "Toggled $KEY to $STATE in config."
}

function overwrite_rule() {
    local OLD_MATCH=$1; local NEW_RULE=$2
    iptables-save | grep "$OLD_MATCH" | while read -r line; do
        iptables -D ${line#-A }
    done
    build_rule $NEW_RULE
}