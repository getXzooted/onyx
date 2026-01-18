#!/bin/bash
# CORE: ONYX COMMAND DISPATCHER
# Purpose: Dispatches commands to their respective modules.

# 1. Grab the command, default to help if empty
CMD="${1:-help}"
shift

# 2. Verify the shim exists
if [[ -f "$LIB_DIR/$CMD" ]]; then
    source "$LIB_DIR/$CMD"
    # Call the standard function name 'onyx_COMMAND'
    "onyx_$CMD" "$@"
else
    echo "Onyx: '$CMD' is not a valid command."
    source "$LIB_DIR/help"
    onyx_help
    exit 1
fi