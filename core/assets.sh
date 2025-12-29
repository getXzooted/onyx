#!/bin/bash
# CORE: Universal Asset Manager
# Handles downloading and updating of various asset types.

function asset_sync() {
    local MANIFEST="$ONYX_ROOT/config/assets.yml"
    log_header "ONYX SENTINEL: ASSET SYNC"

    # 1. Iterate through asset keys
    local ASSET_KEYS=$(yq e '.assets | keys | .[]' "$MANIFEST")

    for KEY in $ASSET_KEYS; do
        local URL=$(yq e ".assets.$KEY.source" "$MANIFEST")
        local TARGET=$(yq e ".assets.$KEY.path" "$MANIFEST")
        local TYPE=$(yq e ".assets.$KEY.type" "$MANIFEST")
        local ACTION=$(yq e ".assets.$KEY.action" "$MANIFEST")

        log_step "Checking $KEY..."

        # 2. Idempotent Download (Only if newer than local)
        if curl -sSL -z "$TARGET" "$URL" -o "$TARGET.tmp"; then
            if [ -f "$TARGET.tmp" ]; then
                log_info "New version detected for $KEY. Applying..."
                
                case "$TYPE" in
                    binary)
                        mv "$TARGET.tmp" "$TARGET"
                        chmod +x "$TARGET"
                        ;;
                    unbound_filter)
                        # Process raw hosts into Unbound 'refuse' rules
                        echo "server:" > "$TARGET"
                        grep "^0.0.0.0" "$TARGET.tmp" | awk '{print "    local-zone: \""$2"\" refuse"}' >> "$TARGET"
                        rm "$TARGET.tmp"
                        ;;
                    *)
                        mv "$TARGET.tmp" "$TARGET"
                        ;;
                esac

                # Trigger Post-Update Action
                [[ "$ACTION" != "null" ]] && eval "$ACTION"
                log_success "$KEY updated."
            else
                log_success "$KEY is current."
            fi
        fi
    done
}