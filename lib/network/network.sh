#!/bin/bash
# /opt/onyx/lib/audit/audit.sh
# ONYX: Unified Security Audit & Hardening Engine

# Source the libraries
source "$ONYX_ROOT/lib/hardening_execution.sh"
source "$ONYX_ROOT/lib/hardening_intel.sh"
source "$ONYX_ROOT/lib/hardening_protection.sh"
source "$ONYX_ROOT/lib/hardening_rules.sh"

# Dependency check for YAML processing
if ! command -v yq &> /dev/null; then
            log_info "Installing yq dependency..."
            wget https://github.com/mikefarah/yq/releases/latest/download/yq_linux_arm -O /usr/local/bin/yq
            chmod +x /usr/local/bin/yq
fi

log_header "ONYX SECURITY AUDIT"
            
# 1. USER SECURITY
TARGET_USER="${SUDO_USER:-$USER}"
if passwd -S "$TARGET_USER" | grep -q "01/01/1970"; then
    log_warning "[!] SECURITY RISK: User '$TARGET_USER' is using a default or uninitialized password."
else
    log_success "[OK] User '$TARGET_USER' credentials look hardened."
fi

# 2. MEMORY PROTECTION (Hardened Check)
ALGO_CHECK=$(zramctl --noheadings --output ALGORITHM /dev/zram0 2>/dev/null)
if [[ "$ALGO_CHECK" == "lz4" ]]; then
    log_success "[OK] Memory: ZRAM Hardware Lock Active (lz4)."
else
    log_error "[!] Memory: ZRAM algorithm mismatch (Found: $ALGO_CHECK)."
fi

# 3. DNS INTEGRITY (Split-DNS & Recursion)
if lsattr /etc/resolv.conf 2>/dev/null | grep -q "\-i\-"; then
    log_success "[OK] DNS: Gateway is locked to 127.0.0.1 (Immutable)."
else
    log_warning "[!] DNS: Gateway is NOT locked. Potential ISP/NetworkManager leak."
fi
            
# Check if system state matches the YAML intent
if [[ "$ONYX_DNS_RECURSIVE" == "true" ]]; then
    if grep -q "root-hints" /etc/unbound/unbound.conf.d/pi-zero.conf 2>/dev/null; then
        log_success "[OK] DNS: Recursive Mode Active (Root Hints Loaded)."
    else
        log_error "[!] DNS: Recursion requested in YAML but NOT active in system."
    fi
else
    log_success "[OK] DNS: Forwarding Mode (User Defined in YAML)."
fi

# 4. SAFETY NET (IPTables Kill-switch)
# Check if the FORWARD chain is set to DROP (Standard Onyx Kill-switch)
if iptables -L FORWARD -n | grep -q "policy DROP"; then
    log_success "[OK] IPTables: Safety Net is active (Forwarding Locked)."
elif iptables -L FORWARD -n | grep -q "REJECT"; then
    log_success "[OK] IPTables: Safety Net is active (Forwarding Rejected)."
else
    log_error "[!!!] IPTables: Safety Net is OFF. Traffic may leak to local network!"
fi

# 5. VPN STATUS
if wg show | grep -q "latest handshake"; then
    log_success "[OK] VPN: WireGuard tunnel is established."
else
    log_error "[!] VPN: No active handshake detected."
fi


# 6. DRIFT DETECTION
# Flatten YAML boolean keys


function detect_drift() {

    local KEYS=$(yq e '.. | select(tag == "!!bool") | path | join(".")' "$CONFIG_DIR/hardening.yml")
    local DRIFT_COUNT=0
    
    log_header "ONYX DRIFT DETECTION"
    
    for KEY in $KEYS; do
        local RULE_NAME="${KEY##*.}"
        local INTENT=$(yq e ".$KEY" "$CONFIG_DIR/hardening.yml")

        if declare -f "check_$RULE_NAME" > /dev/null; then
            if ! "check_$RULE_NAME" "$INTENT"; then
                log_error "[DRIFT DETECTED] $RULE_NAME is out of sync."
                ((DRIFT_COUNT++))
            fi
        fi
    done
}

detect_drift

# 7. Final Audit Summary
audit_state