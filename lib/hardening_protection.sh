#!/bin/bash
# lib/hardening_protection.sh

function flush_rule() {
    iptables -F "$1"
    log_warning "Flushed all rules in chain: $1"
}

function panic_lock() {
    iptables -P FORWARD DROP
    iptables -F FORWARD
    log_error "PANIC LOCK ACTIVE: All forwarding killed."
}

function checkpoint_save() {
    cp "$CONFIG_DIR/hardening.yml" "$CONFIG_DIR/hardening.yml.$(date +%s).bak"
}

function verify_checksum() {
    sha256sum "$CONFIG_DIR/hardening.yml"
}