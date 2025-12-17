#!/bin/bash
# MODULE: System > GUI SSL
# Installs Lighttpd, fixes permissions, and enables HTTPS/SSL.

function system_configure_gui() {
    log_header "CONFIGURING WEB INTERFACE"

    # 1. ENSURE LIGHTTPD IS INSTALLED
    # We check for the binary. If missing, we install it forcibly.
    if ! command -v lighttpd &> /dev/null; then
        log_warning "Lighttpd not found. Installing now..."
        apt-get update
        apt-get install -y lighttpd php-common php-cgi php-fpm
        
        # Enable PHP immediately
        lighttpd-enable-mod fastcgi-php
        service lighttpd force-reload
    else
        log_info "Lighttpd is already installed."
    fi

    # 2. FIX PERMISSIONS (403 Errors)
    log_step "Adjusting web directory permissions..."
    
    # Create the directory if it doesn't exist
    mkdir -p /var/www/html
    
    # Ensure the web user (www-data) owns the files
    chown -R www-data:www-data /var/www/html
    
    # Ensure directories are executable (755) and files are readable (644)
    find /var/www/html -type d -exec chmod 755 {} \;
    find /var/www/html -type f -exec chmod 644 {} \;
    
    # Add the 'pi' user (or current user) to www-data group
    REAL_USER=${SUDO_USER:-$(whoami)}
    usermod -a -G www-data "$REAL_USER"

    # 3. GENERATE SSL CERTIFICATE
    SSL_DIR="/etc/lighttpd/ssl"
    CERT_FILE="$SSL_DIR/onyx-gateway.pem"

    if [ ! -f "$CERT_FILE" ]; then
        log_step "Generating device certificate..."
        mkdir -p "$SSL_DIR"
        
        # Generate a 10-year self-signed cert
        openssl req -new -newkey rsa:2048 -nodes -days 3650 -x509 \
            -keyout "$CERT_FILE" -out "$CERT_FILE" \
            -subj "/C=US/ST=Onyx/L=Gateway/O=Onyx/CN=10.3.141.1" 2>/dev/null
            
        # Restrict access to root only
        chmod 400 "$CERT_FILE"
        chown root:root "$CERT_FILE"
        
        log_success "Certificate generated."
    fi

    # 4. CONFIGURE LIGHTTPD FOR HTTPS
    log_step "Enabling SSL on Lighttpd..."
    
    # Enable the SSL module
    lighttpd-enable-mod ssl &>/dev/null

    # Create the SSL Config Overlay
    cat <<EOF > "/etc/lighttpd/conf-available/10-ssl.conf"
# /usr/share/doc/lighttpd/ssl.txt

server.modules += ( "mod_openssl" )

\$SERVER["socket"] == "0.0.0.0:443" {
    ssl.engine  = "enable"
    ssl.pemfile = "$CERT_FILE"
    
    # Response Headers
    setenv.add-response-header = (
        "Strict-Transport-Security" => "max-age=63072000; includeSubDomains; preload",
        "X-Frame-Options" => "DENY",
        "X-Content-Type-Options" => "nosniff"
    )
}
EOF
    # Link it to enabled
    ln -sf /etc/lighttpd/conf-available/10-ssl.conf /etc/lighttpd/conf-enabled/10-ssl.conf

    # 5. RESTART SERVER
    log_step "Restarting Web Server..."
    systemctl restart lighttpd

    if systemctl is-active lighttpd &>/dev/null; then
        log_success "Web Interface is Ready (HTTPS Enabled)."
        log_info "Access at: https://10.3.141.1"
    else
        log_error "Web Server failed to restart. Check 'systemctl status lighttpd'."
    fi
}