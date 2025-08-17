#!/bin/bash

echo "[VSCODE] Checking if OpenVSCode Server is installed..."
if [ ! -d "/opt/openvscode-server" ]; then
    echo "[VSCODE] OpenVSCode Server not found. Installing..."
    cd /tmp
    echo "[VSCODE] Current directory: $(pwd)"
    echo "[VSCODE] Fetching latest release information..."
    LATEST_RELEASE=$(curl -s https://api.github.com/repos/gitpod-io/openvscode-server/releases/latest | grep '"tag_name"' | cut -d'"' -f4)
    echo "[VSCODE] Latest release: $LATEST_RELEASE"
    echo "[VSCODE] Downloading OpenVSCode Server..."
    wget -q "https://github.com/gitpod-io/openvscode-server/releases/download/${LATEST_RELEASE}/${LATEST_RELEASE}-linux-x64.tar.gz"
    echo "[VSCODE] Download completed with exit code: $?"
    echo "[VSCODE] Extracting archive..."
    tar -xzf "${LATEST_RELEASE}-linux-x64.tar.gz"
    echo "[VSCODE] Extraction completed with exit code: $?"
    echo "[VSCODE] Moving to /opt/openvscode-server..."
    sudo mv "${LATEST_RELEASE}-linux-x64" /opt/openvscode-server
    echo "[VSCODE] Setting ownership..."
    sudo chown -R ec2-user:ec2-user /opt/openvscode-server
    echo "[VSCODE] OpenVSCode Server files installed."
    
    # Create systemd service
    echo "[VSCODE] Creating systemd service..."
    cat > /etc/systemd/system/openvscode-server.service << EOF
[Unit]
Description=OpenVSCode Server
After=network.target

[Service]
Type=simple
User=ec2-user
WorkingDirectory=/opt/openvscode-server
ExecStart=/opt/openvscode-server/bin/openvscode-server --host 0.0.0.0 --port 3002 --without-connection-token
Restart=always
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF
    
    echo "[VSCODE] Reloading systemd and starting OpenVSCode Server service..."
    systemctl daemon-reload
    systemctl enable openvscode-server
    systemctl start openvscode-server
    echo "[VSCODE] Service status: $(systemctl is-active openvscode-server)"
    echo "[VSCODE] OpenVSCode Server service started and enabled."
else
    echo "[VSCODE] OpenVSCode Server already installed, skipping installation."
fi