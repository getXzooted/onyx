#!/bin/bash
# CORE: Onyx Firmware Script
# Handles the phased firmware updating of Onyx Gateway.

# Flag Parsing (Positional arguments from CLI)
RESTORE_ONYX=true
RESTORE_RULES=true
RESTORE_ASSETS=true

for arg in "$@"; do
    case $arg in
        --fresh-onyx)    RESTORE_ONYX=false ;;
        --fresh-rules)    RESTORE_RULES=false ;;
        --fresh-assets)    RESTORE_ASSETS=false ;;
        --fresh-all)     RESTORE_ONYX=false; RESTORE_RULES=false; RESTORE_ASSETS=false ;;
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

if [[ "$RESTORE_ONYX" == "true" ]]; then
    [[ -f "$ONYX_BAK" ]] && mv "$ONYX_BAK" "$ONYX_YAML"
    log_info "Restored existing onyx.yml."
else
    log_warning "Fresh onyx.yml applied from repository (Backup at $ONYX_BAK)."
fi

if [[ "$RESTORE_RULES" == "true" ]]; then
    [[ -f "$HARD_BAK" ]] && mv "$HARD_BAK" "$HARDENING_YAML"
    log_info "Restored existing hardening.yml."
else
    log_warning "Fresh hardening.yml applied from repository (Backup at $HARD_BAK)."
fi

if [[ "$RESTORE_ASSETS" == "true" ]]; then
    [[ -f "$ASSETS_BAK" ]] && mv "$ASSETS_BAK" "$ASSETS_YAML"
    log_info "Restored existing assets.yml."
else
    log_warning "Fresh assets.yml applied from repository (Backup at $ASSETS_BAK)."
fi

# 5. Re-apply permissions and symlinks to ensure new scripts are executable
find "$ONYX_ROOT" -name "*.sh" -exec chmod +x {} \;
chmod +x "$ONYX_ROOT/bin/onyx"

log_success "Firmware update sequence complete."