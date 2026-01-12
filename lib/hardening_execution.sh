#!/bin/bash
# lib/hardening_execution.sh

function old_build_rule() {
    local CHAIN=$1; shift
    local RULE=$@
    if ! iptables -C "$CHAIN" $RULE 2>/dev/null; then
        iptables -I "$CHAIN" 1 $RULE
        log_success "Injected rule: $RULE"
    fi
}

function build_rule() {
    local CHAIN=$1
    shift
    local RULE="$*"

    # 1. Check for a Label (Optional)
    # If the rule contains a comment, we check for that comment specifically.
    # This prevents duplication of complex rules like SYNPROXY.
    if [[ "$RULE" == *"--comment"* ]]; then
        local LABEL=$(echo "$RULE" | grep -oP '(?<=--comment ")[^"]+')
        if iptables -S "$CHAIN" | grep -q "$LABEL"; then
            return 0
        fi
    fi

    # 2. Standard Idempotency Check
    # We use -A (Append) because the Safety Net flushes the board first.
    # This preserves the Linear Order from the YAML file.
    if ! iptables -C "$CHAIN" $RULE 2>/dev/null; then
        iptables -A "$CHAIN" $RULE
        log_success "Injected rule: $RULE"
    else
        log_info "Rule already exists, skipping: $RULE"
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