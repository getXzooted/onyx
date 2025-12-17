#!/bin/bash
# MODULE: System > Web GUI Activator
# OPTIONAL: Installs the visual dashboard and web server.
# Run this ONLY if you want the visual graphs and management UI.

function system_activate_gui() {
    log_header "ACTIVATING WEB DASHBOARD"

    # 1. INSTALL WEB SERVER (The Engine)
    if ! command -v lighttpd &> /dev/null; then
        log_step "Installing Lighttpd & PHP..."
        apt-get update
        apt-get install -y lighttpd php-common php-cgi php-fpm git curl
        
        # Enable PHP
        lighttpd-enable-mod fastcgi-php
        service lighttpd force-reload
    fi

    # 2. GRANT SUDO PERMISSIONS (The "500 Error" Fix Part 1)
    # The web user needs permission to control system networking.
    # Without this file, the dashboard crashes or can't save settings.
    log_step "Granting Sudo Permissions to Web User..."
    
    # Download the official RaspAP sudoers file
    curl -o /etc/sudoers.d/090_raspap https://raw.githubusercontent.com/raspap/raspap-webgui/master/installers/raspap.sudoers
    
    # Secure the file so it works
    chmod 0440 /etc/sudoers.d/090_raspap
    
    # 3. DOWNLOAD WEB FILES (The "500 Error" Fix Part 2)
    log_step "Downloading Dashboard Interface..."
    
    # NUKE THE DIRECTORY: We clear it completely to fix the "missing includes" error.
    rm -rf /var/www/html/*
    rm -rf /var/www/html/.* 2>/dev/null
    
    # Clone fresh
    git clone https://github.com/raspap/raspap-webgui.git /var/www/html

    # 4. CREATE CONFIG STRUCTURE
    mkdir -p /etc/raspap/networking
    mkdir -p /etc/raspap/hostapd
    mkdir -p /etc/raspap/lighttpd
    
    # Restore default config
    if [ -f "/var/www/html/raspap.php" ]; then
        cp /var/www/html/raspap.php /etc/raspap/
    fi

    # 5. FIX PERMISSIONS (Crucial)
    log_step "Applying Security Permissions..."
    chown -R www-data:www-data /var/www/html
    chown -R www-data:www-data /etc/raspap
    
    # Set correct modes
    find /var/www/html -type d -exec chmod 755 {} \;
    find /var/www/html -type f -exec chmod 644 {} \;
    
    # Allow maintenance access
    usermod -a -G www-data ${SUDO_USER:-$(whoami)}

    # 6. RESTART EVERYTHING
    systemctl restart lighttpd
    
    log_success "Web Dashboard Active."
    log_info "Access at http://10.3.141.1"
}