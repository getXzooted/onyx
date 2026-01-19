#!/bin/bash
# CORE: ONYX GRAPH SCRIPT
# Purpose: Displays live ASCII graphs of the WireGuard tunnel.

function onyx_graph() {

    # Check if the graph script exists
    local GRAPH_SCRIPT="$MODULES_DIR/system/graph.sh"

    if [ -f "$GRAPH_SCRIPT" ]; then
        log_header " --- LOADING GRAPH --- "
        source "$GRAPH_SCRIPT"
        return 0
    else
        log_error "Graph module not found at $GRAPH_SCRIPT"
        log_info "Please ensure $MODULES_DIR/system/graph.sh exists."
        return 1
    fi

}