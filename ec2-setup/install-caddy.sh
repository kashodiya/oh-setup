#!/bin/bash

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

generate_caddy_users() {
    if [[ -z "$ADMIN_PASSWORD" ]]; then
        echo "[CADDY] Error: ADMIN_PASSWORD not set"
        return 1
    fi
    
    echo "[CADDY] Installing expect..."
    sudo yum install expect -y
    echo "[CADDY] Generating admin password hash..."
    export PASSWORD="$ADMIN_PASSWORD"
    export VERIFICATION_PASSWORD="$ADMIN_PASSWORD"
    
    EXPECT_SCRIPT=$(mktemp)
    cat > "$EXPECT_SCRIPT" << 'EOF'
#!/usr/bin/expect
set timeout 10
spawn caddy hash-password
expect "Enter password:"
send "$env(PASSWORD)\r"
expect "Confirm password:"
send "$env(VERIFICATION_PASSWORD)\r"
expect {
    "Passwords do not match" {
        puts "Error: Passwords do not match"
        exit 1
    }
    eof
}
EOF
    chmod +x "$EXPECT_SCRIPT"
    
    OUTPUT=$(expect "$EXPECT_SCRIPT")
    HASH=$(echo "$OUTPUT" | awk '{lines[NR]=$0} END{print lines[NR-1]}')
    echo "[CADDY] Generated hash: $HASH"
    
    rm "$EXPECT_SCRIPT"
    
    # Only add admin user if users.txt doesn't already exist or doesn't contain admin
    if ! sudo grep -q "^admin " /etc/caddy/users.txt 2>/dev/null; then
        echo "admin $HASH" | sudo tee -a /etc/caddy/users.txt
        echo "[CADDY] Admin user added to /etc/caddy/users.txt"
    else
        echo "[CADDY] Admin user already exists in /etc/caddy/users.txt"
    fi
}

echo "[CADDY] Checking if Caddy is installed..."
if command_exists caddy; then
    echo "[CADDY] Caddy is already installed."
else
    echo "[CADDY] Now Installing Caddy..."
    cd /tmp
    echo "[CADDY] Current directory: $(pwd)"
    echo "[CADDY] Downloading Caddy binary..."
    wget -q https://github.com/caddyserver/caddy/releases/download/v2.9.1/caddy_2.9.1_linux_amd64.tar.gz
    echo "[CADDY] Download completed with exit code: $?"
    echo "[CADDY] Extracting Caddy..."
    tar xzf caddy_2.9.1_linux_amd64.tar.gz
    echo "[CADDY] Moving to /usr/local/bin/..."
    sudo mv caddy /usr/local/bin/
    sudo chmod +x /usr/local/bin/caddy
    echo "[CADDY] Caddy version: $(caddy version)"
    echo "[CADDY] Creating certificates directory..."
    sudo mkdir -p /etc/caddy/certs

    CERT_DIR="/etc/caddy/certs"
    DOMAIN="localhost"
    DAYS_VALID=365
    echo "[CADDY] Getting public IP address..."
    IP_ADDRESS=$(curl -s https://api.ipify.org)
    echo "[CADDY] Public IP: $IP_ADDRESS"

    sudo mkdir -p $CERT_DIR

    sudo openssl genrsa -out $CERT_DIR/server.key 2048

    cat << EOF > $CERT_DIR/server.cnf
[req]
default_bits = 2048
prompt = no
default_md = sha256
distinguished_name = dn
x509_extensions = v3_req

[dn]
C = US
ST = State
L = City
O = Organization
OU = OrganizationalUnit
CN = $DOMAIN

[v3_req]
subjectAltName = @alt_names

[alt_names]
DNS.1 = $DOMAIN
IP.1 = $IP_ADDRESS
EOF

    sudo openssl req -x509 -nodes -days $DAYS_VALID \
        -keyout $CERT_DIR/server.key \
        -out $CERT_DIR/server.crt \
        -config $CERT_DIR/server.cnf

    sudo useradd --system --home /var/lib/caddy --create-home --shell /bin/false caddy
    sudo chown caddy:caddy $CERT_DIR/server.key $CERT_DIR/server.crt
    sudo chmod 600 $CERT_DIR/server.key
    sudo chmod 644 $CERT_DIR/server.crt

    sudo rm $CERT_DIR/server.cnf

    echo "[CADDY] Self-signed certificate created for $DOMAIN and IP $IP_ADDRESS"
    echo "[CADDY] Certificate location: $CERT_DIR/server.crt"
    echo "[CADDY] Private key location: $CERT_DIR/server.key"

    echo "[CADDY] Copying Caddyfile, users.txt and apps folder to /etc/caddy"
    
    # Create /etc/caddy directory if it doesn't exist
    sudo mkdir -p /etc/caddy
    
    if [ -f "/home/ec2-user/source/caddy/Caddyfile" ]; then
        sudo cp /home/ec2-user/source/caddy/Caddyfile /etc/caddy/
        echo "[CADDY] Caddyfile copied successfully"
    else
        echo "[CADDY] Warning: /home/ec2-user/source/caddy/Caddyfile not found"
    fi
    
    if [ -f "/home/ec2-user/source/caddy/users.txt" ]; then
        sudo cp /home/ec2-user/source/caddy/users.txt /etc/caddy/
        echo "[CADDY] users.txt copied successfully"
    else
        echo "[CADDY] Warning: /home/ec2-user/source/caddy/users.txt not found"
    fi
    
    if [ -d "/home/ec2-user/source/caddy/apps" ]; then
        sudo cp -R /home/ec2-user/source/caddy/apps /etc/caddy/
        echo "[CADDY] Apps folder copied successfully"
    else
        echo "[CADDY] Warning: /home/ec2-user/source/caddy/apps directory not found"
    fi

    cat << EOF > /etc/systemd/system/caddy.service
[Unit]
Description=Caddy
After=network.target

[Service]
ExecStart=/usr/local/bin/caddy run --config /etc/caddy/Caddyfile
ExecReload=/usr/local/bin/caddy reload --config /etc/caddy/Caddyfile
TimeoutStopSec=5
LimitNOFILE=1048576
LimitNPROC=512
PrivateTmp=true
ProtectSystem=full
AmbientCapabilities=CAP_NET_BIND_SERVICE

[Install]
WantedBy=multi-user.target
EOF
    echo "[CADDY] Reloading systemd and starting Caddy service..."
    sudo systemctl daemon-reload
    sudo systemctl start caddy
    sudo systemctl enable caddy
    echo "[CADDY] Service status: $(systemctl is-active caddy)"
    
    generate_caddy_users
    
    echo "[CADDY] Caddy installation completed"
fi