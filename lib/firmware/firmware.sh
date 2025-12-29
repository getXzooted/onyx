#!/bin/bash
# CORE: Onyx Firmware Script
# Handles the phased firmware updating of Onyx Gateway.

# Ensure environment is loaded in root context
check_root
check_env


log_header "--- ONYX FIRMWARE UPDATE ---"

# 1. Define temporary backup locations
ONYX_BAK="/tmp/onyx.yml.bak"
HARD_BAK="/tmp/hardening.yml.bak"

# 2. Backup current configurations
log_step "Backing up user configurations..."
cp "$ONYX_YAML" "$ONYX_BAK" 2>/dev/null
cp "$HARDENING_YAML" "$HARD_BAK" 2>/dev/null

# 3. Pull latest code from Git
log_step "Pulling updates from repository..."
cd "$ONYX_ROOT" || { log_error "Could not access $ONYX_ROOT"; exit 1; }

# Fetch latest and force reset to match origin
git fetch --all &>/dev/null
CURRENT_BRANCH=$(git branch --show-current)

if git reset --hard "origin/$CURRENT_BRANCH"; then
    log_success "Core logic reset to latest version ($CURRENT_BRANCH)."
else
    log_error "Update failed. Check internet connection or git remote."
    exit 1
fi

# 4. Restore configurations from backup
log_step "Restoring user configurations..."
[[ -f "$ONYX_BAK" ]] && mv "$ONYX_BAK" "$ONYX_YAML"
[[ -f "$HARD_BAK" ]] && mv "$HARD_BAK" "$HARDENING_YAML"

# 5. Re-apply permissions and symlinks to ensure new scripts are executable
find "$ONYX_ROOT" -name "*.sh" -exec chmod +x {} \;
chmod +x "$ONYX_ROOT/bin/onyx"

log_success "Firmware update sequence complete."