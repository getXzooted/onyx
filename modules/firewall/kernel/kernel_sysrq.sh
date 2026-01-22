# modules/network/hardening_rules.sh

function apply_kernel_sysrq() {
    local INTENT=$1
    
    # SysRq: 0 is disabled (Onyx Default), 438 is the typical Linux 'all enabled' value
    # Panic: 1 is reboot immediately (Onyx Default), 0 is wait forever (Linux Default)
    local SYSRQ_VAL=$([[ "$INTENT" == "true" ]] && echo "0" || echo "438")
    local PANIC_VAL=$([[ "$INTENT" == "true" ]] && echo "1" || echo "0")

    if [[ "$INTENT" == "true" ]]; then
        log_step "Enforcing Kernel Lockdown (SysRq: 0, Panic: 1)..."
    else
        log_warning "Reverting Kernel Lockdown to Linux Defaults (SysRq: 438, Panic: 0)..."
    fi

    sysctl -w kernel.sysrq=$SYSRQ_VAL > /dev/null
    sysctl -w kernel.panic=$PANIC_VAL > /dev/null
}

function check_kernel_sysrq() {
    local INTENT=$1
    
    local CUR_SYSRQ=$(sysctl -n kernel.sysrq)
    local CUR_PANIC=$(sysctl -n kernel.panic)

    # SYNC LOGIC:
    # 1. Intent is 'true' and both are in lockdown state -> Sync (0)
    if [[ "$INTENT" == "true" && "$CUR_SYSRQ" == "0" && "$CUR_PANIC" == "1" ]]; then return 0; fi
    
    # 2. Intent is 'false' and SysRq is enabled (non-zero) or Panic is 0 -> Sync (0)
    # Note: We check if SysRq > 0 since many distros use different bitmasks
    if [[ "$INTENT" == "false" && "$CUR_SYSRQ" != "0" && "$CUR_PANIC" == "0" ]]; then return 0; fi

    # Otherwise, system state has drifted from the desired YAML intent
    return 1
}