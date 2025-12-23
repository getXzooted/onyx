#!/bin/bash
# ==============================================================================
# MODULE: System > USB Gadget Manager (Script 2 Library)
# PURPOSE: Configures the Pi to behave as a USB hardware peripheral.
# ==============================================================================

if [ -z "$ONYX_ROOT" ]; then exit 1; fi

# ------------------------------------------------------------------------------
# FUNCTION: system_enable_usb_gadget
# DESCRIPTION: Modifies boot configs to enable the dwc2 USB driver.
# ------------------------------------------------------------------------------
function system_enable_usb_gadget() {
    log_header "CONFIGURING USB GADGET MODE"
    
    local BOOT_CONF="/boot/firmware/config.txt"
    if [ ! -f "$BOOT_CONF" ]; then BOOT_CONF="/boot/config.txt"; fi

    # 1. Enable dwc2 overlay in config.txt
    if ! grep -q "dtoverlay=dwc2" "$BOOT_CONF"; then
        log_step "Adding dwc2 overlay to boot config..."
        echo "dtoverlay=dwc2" >> "$BOOT_CONF"
    fi

    # 2. Add dwc2 to modules
    if ! grep -q "dwc2" /etc/modules; then
        log_step "Enabling dwc2 kernel module..."
        echo "dwc2" >> /etc/modules
    fi

    log_success "USB Gadget hardware enabled. Reboot required for kernel changes."
}