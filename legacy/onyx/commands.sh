# ==============================================================================
#                             ONYX CLI CONTROLLER
#                 The central command hub for the Onyx Gateway.
# ==============================================================================

COMMAND="$1"

case "$COMMAND" in

    boot)
        # Check if the boot script exists
        BOOT_SCRIPT="$ONYX_ROOT/lib/boot/boot.sh"
        
        if [ -f "$BOOT_SCRIPT" ]; then
            source "$BOOT_SCRIPT"
        else
            log_error "Boot module not found at $BOOT_SCRIPT"
            log_info "Please ensure lib/boot/boot.sh exists."
        fi
        
        ;;

    install)
        # Check if the installation script exists
        STATUS_SCRIPT="$ONYX_ROOT/lib/install/install.sh"
        
        if [ -f "$STATUS_SCRIPT" ]; then
            source "$STATUS_SCRIPT"
        else
            log_error "Install module not found at $STATUS_SCRIPT"
            log_info "Please ensure lib/install/install.sh exists."
        fi
        
        ;;
        
    provision)
        # Check if the provisioning script exists
        STATUS_SCRIPT="$ONYX_ROOT/lib/provision/provision.sh"

        if [ -f "$STATUS_SCRIPT" ]; then
            source "$STATUS_SCRIPT"
        else
            log_error "Install module not found at $STATUS_SCRIPT"
            log_info "Please ensure lib/provision/provision.sh exists."
        fi
        ;;

    config)
        # Check if the config script exists
        STATUS_SCRIPT="$ONYX_ROOT/lib/config/config.sh"

        if [ -f "$STATUS_SCRIPT" ]; then
            source "$STATUS_SCRIPT"
        else
            log_error "Install module not found at $STATUS_SCRIPT"
            log_info "Please ensure lib/config/config.sh exists."
        fi
        ;;

    firmware)
        # Check if the firmware script exists
        STATUS_SCRIPT="$ONYX_ROOT/lib/firmware/firmware.sh"

        if [ -f "$STATUS_SCRIPT" ]; then
            # Pass all flags (e.g., --fresh-hard) to the script
            source "$STATUS_SCRIPT" "${@:2}"
        else
            log_error "Firmware module not found at $STATUS_SCRIPT"
            log_info "Please ensure lib/firmware/firmware.sh exists."
        fi
        ;;

    status)
        # 1. Check if the diagnostic tool exists
        STATUS_SCRIPT="$ONYX_ROOT/lib/status/onyx_status.sh"

        if [ -f "$STATUS_SCRIPT" ]; then
            # 2. Handoff control to the diagnostic engine
            # We execute it directly (instead of source) to keep its variables isolated
            sudo "$STATUS_SCRIPT"
        else
            log_error "Status module not found at $STATUS_SCRIPT"
            log_info "Please ensure lib/status/onyx_status.sh exists and is executable."
        fi
        ;;

    vlan)
        STATUS_SCRIPT="$ONYX_ROOT/lib/vlan/vlan.sh"
        if [ -f "$STATUS_SCRIPT" ]; then
            source "$STATUS_SCRIPT" "${@:2}"
        else
            log_error "VLAN module not found."
        fi
        ;;

    update)
        log_header "RUNNING UPDATE MANAGER"
        source "$ONYX_ROOT/core/update.sh"
        core_update "$2"
        ;;

    # === INSTALL DASHBOARD ===
    dashboard)
        source "$MODULES_DIR/system/dashboard.sh"
        system_install_dashboard
        ;;

    # === RUN MONITOR ===
    monitor)
        # Verify it is installed before trying to run it
        if [ -f "/usr/local/bin/onyx-dash" ]; then
            /usr/local/bin/onyx-dash
        else
            log_error "Dashboard not found. Run 'sudo onyx dashboard' first."
        fi
        ;;

    ssh)
        case "$2" in
            on|enable)
                systemctl enable --now ssh
                log_success "SSH Service Enabled."
                ;;
            off|disable)
                systemctl disable --now ssh
                log_warning "SSH Service Disabled. Remote access locked."
                ;;
            *)
                echo "Usage: sudo onyx ssh [on|off]"
                ;;
        esac
        ;;

    network)
        source "$ONYX_ROOT/lib/network/network.sh"
        case "$2" in
            repair)  repair_state ;;
            panic)   panic_lock ;;
            build)   build_rule "${@:3}" ;;
            delete)  delete_rule "${@:3}" ;;
            toggle)  toggle_rule "$3" "$4" ;;
            ""|audit) ;;
            *)       echo "Usage: sudo onyx audit {repair|panic|build|delete|toggle}" ;;
        esac
        ;;

    qr)
        log_header "WIREGUARD ONBOARDING (QR)"
        if [ -f "/etc/wireguard/wg0.conf" ]; then
            # Displays the Pi's VPN config as a QR code in the terminal
            qrencode -t ansiutf8 < /etc/wireguard/wg0.conf
            log_info "Scan this with the WireGuard mobile app to clone the tunnel."
        else
            log_error "No WireGuard config found at /etc/wireguard/wg0.conf"
        fi
        ;;

    graph)
        # Check for dependencies
        if ! command -v nload &>/dev/null; then
            apt-get install -y nload bmon &>/dev/null
        fi

        # The "Live" View: ASCII Graphs of the WireGuard Tunnel
        # This flexes on the commercial GUIs by being 100% SSH-native.
        nload -u M -i 1024 -o 1024 wg0
        ;;

    *)
        show_usage
        exit 1
        ;;
esac