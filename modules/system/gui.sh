#!/bin/bash
# MODULE: System > Web GUI Activator
# OPTIONAL: Installs the visual dashboard and web server.
# Run this ONLY if you want the visual graphs and management UI.

function system_activate_gui() {
    log_header "ACTIVATING WEB DASHBOARD"

    # 1. INSTALL WEB SERVER (The "Missing Engine")
    if ! command -v lighttpd &> /dev/null; then
        log_step "Installing Lighttpd & PHP..."
        apt-get update
        apt-get install -y lighttpd php-common php-cgi php-fpm git
        
        # Enable PHP
        lighttpd-enable-mod fastcgi-php
        service lighttpd force-reload
    fi

    # 2. DOWNLOAD WEB FILES (The "Empty Folder" Fix)
    log_step "Downloading Dashboard Interface..."
    # Clean first to ensure git doesn't fail on the existing empty folder
    rm -rf /var/www/html/*
    git clone https://github.com/raspap/raspap-webgui.git /var/www/html

    # 3. CREATE CONFIG STRUCTURE
    # Required for the GUI to save settings to the backend
    mkdir -p /etc/raspap/networking
    mkdir -p /etc/raspap/hostapd
    mkdir -p /etc/raspap/lighttpd
    
    # Restore default config if available
    if [ -f "/var/www/html/raspap.php" ]; then
        cp /var/www/html/raspap.php /etc/raspap/
    fi

    # 4. FIX PERMISSIONS (The 403 Forbidden Fix)
    log_step "Applying Security Permissions..."
    chown -R www-data:www-data /var/www/html
    chown -R www-data:www-data /etc/raspap
    
    # Set correct modes
    find /var/www/html -type d -exec chmod 755 {} \;
    find /var/www/html -type f -exec chmod 644 {} \;
    
    # Allow maintenance access
    usermod -a -G www-data ${SUDO_USER:-$(whoami)}

    # 5. START SERVER
    systemctl restart lighttpd
    
    log_success "Web Dashboard Active."
    log_info "Access at http://10.3.141.1"
}