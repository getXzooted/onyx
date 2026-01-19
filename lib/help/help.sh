#!/bin/bash
# CORE: ONYX HELP COMMAND
# Purpose: Dynamically builds help menus from the command shims.

function onyx_help() {
    local TARGET_CMD="$1"

    # CASE: Specific Command Help (e.g., sudo onyx help network)
    if [[ -n "$TARGET_CMD" ]]; then
        if [ -f "$LIB_DIR/$TARGET_CMD" ]; then
            source "$LIB_DIR/$TARGET_CMD"
            echo "Command: onyx $TARGET_CMD"
            echo "Usage:   $($("onyx_$TARGET_CMD" --usage))"
            return 0
        else
            log_error "Command '$TARGET_CMD' not found in library."
        fi
    fi

    # CASE: General Help (sudo onyx help)
    log_header "ONYX COMMAND HUB"
    for shim in "$LIB_DIR"/*; do
        [[ -d "$shim" || "$(basename "$shim")" == "help" ]] && continue
        
        source "$shim"
        local name=$(basename "$shim")
        local desc=$("onyx_$name" --usage 2>/dev/null)
        
        printf "  %-12s %s\n" "$name" "${desc:-(No description found)}"
    done
}