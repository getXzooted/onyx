#!/bin/bash
# CORE: Onyx Firmware Script
# Handles the phased firmware updating of Onyx Gateway.

# Flag Parsing (Positional arguments from CLI)
RESTORE_ONYX="RESTORE"
RESTORE_RULES="RESTORE"
RESTORE_ASSETS="RESTORE"

for arg in "$@"; do
    case $arg in
        --fresh-onyx)    RESTORE_ONYX="FRESH" ;;
        --fresh-rules)    RESTORE_RULES="FRESH" ;;
        --fresh-assets)    RESTORE_ASSETS="FRESH" ;;
        --fresh-all)     RESTORE_ONYX="FRESH"; RESTORE_RULES="FRESH"; RESTORE_ASSETS="FRESH" ;;
    esac
done

# 1. Define temporary backup locations
ONYX_BAK="/tmp/onyx.yml.bak"
HARD_BAK="/tmp/hardening.yml.bak"
ASSETS_BAK="/tmp/assets.yml.bak"

# 2. Backup current configurations
log_step "Backing up user configurations..."
cp "$ONYX_YAML" "$ONYX_BAK" 2>/dev/null
cp "$HARDENING_YAML" "$HARD_BAK" 2>/dev/null
cp "$ASSETS_YAML" "$ASSETS_BAK" 2>/dev/null

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

# 4. Conditional Restore configurations from backup
# This allows you to "Apply New Rules" by skipping the move-back
log_step "Finalizing configuration state..."

# --- ONYX.YML ---
if [[ "$RESTORE_ONYX" == "RESTORE" ]] && [[ -f "$ONYX_BAK" ]]; then
    mv -f "$ONYX_BAK" "$ONYX_YAML"
    log_info "Restored user onyx.yml"
elif [[ -f "$ONYX_BAK" ]]; then
    mv -f "$ONYX_BAK" "$ONYX_YAML.bak"
    log_warning "Fresh onyx.yml applied. Backup saved to config folder."
fi

# --- HARDENING.YML ---
if [[ "$RESTORE_RULES" == "RESTORE" ]] && [[ -f "$HARD_BAK" ]]; then
    mv -f "$HARD_BAK" "$HARDENING_YAML"
    log_info "Restored user hardening.yml"
elif [[ -f "$HARD_BAK" ]]; then
    mv -f "$HARD_BAK" "$HARDENING_YAML.bak"
    log_warning "Fresh hardening.yml applied. Backup saved to config folder."
fi

# --- ASSETS.YML ---
if [[ "$RESTORE_ASSETS" == "RESTORE" ]] && [[ -f "$ASSETS_BAK" ]]; then
    mv -f "$ASSETS_BAK" "$ASSETS_YAML"
    log_info "Restored user assets.yml"
elif [[ -f "$ASSETS_BAK" ]]; then
    mv -f "$ASSETS_BAK" "$ASSETS_YAML.bak"
    log_warning "Fresh assets.yml applied. Backup saved to config folder."
fi

# 5. Re-apply permissions and symlinks to ensure new scripts are executable
find "$ONYX_ROOT" -name "*.sh" -exec chmod +x {} \;
chmod +x "$ONYX_ROOT/bin/onyx"

log_success "Firmware update sequence complete."