#!/bin/bash
# CORE: Onyx Boot Script
# Handles the boot phase of Onyx Gateway installation.

check_root
check_env

log_header " --- BOOTING SYSTEM --- "

# --- PERSISTENT MEMORY LOCK (Post-Reboot) ---
# Ensures hardware is re-locked on every boot to fight Trixie's auto-generators
if [[ "$(zramctl --noheadings --output ALGORITHM /dev/zram0 2>/dev/null)" != "lz4" ]]; then
    log_info "Memory Guard: Fixing hardware algorithm mismatch..."
        
    # Release locks
    sudo systemctl stop rpi-swap zramswap 2>/dev/null
    sudo systemctl mask rpi-swap zramswap 2>/dev/null
    sudo swapoff -a 2>/dev/null
        
    # Nuclear Release and Reload
    sudo modprobe -r zram 2>/dev/null
    sudo modprobe zram num_devices=1
        
    # Dynamic Scaling (50% RAM)
    TOTAL_MEM=$(free -m | awk '/^Mem:/{print $2}')
    ZRAM_SIZE=$((TOTAL_MEM / 2))M
        
    # Hardware Inject
    sudo zramctl --find --size "$ZRAM_SIZE" --algorithm lz4
    sudo mkswap /dev/zram0 && sudo swapon /dev/zram0 -p 100
    log_success "Memory Guard: Hardware Locked ($ZRAM_SIZE @ lz4)."
fi