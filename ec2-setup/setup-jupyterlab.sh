#!/bin/bash

echo "[JUPYTERLAB] Setting up JupyterLab..."

# Install Python3 and pip if not already installed
echo "[JUPYTERLAB] Installing Python3 and pip..."
yum install -y python3 python3-pip

# Create jupyter directory
echo "[JUPYTERLAB] Creating jupyter directory..."
mkdir -p /home/ec2-user/jupyter
chown -R ec2-user:ec2-user /home/ec2-user/jupyter

# Install JupyterLab using pip as ec2-user
echo "[JUPYTERLAB] Installing JupyterLab with pip..."
sudo -u ec2-user bash -c 'cd /home/ec2-user/jupyter && pip3 install --user --quiet jupyterlab'

# Create JupyterLab configuration
echo "[JUPYTERLAB] Creating JupyterLab configuration..."
sudo -u ec2-user mkdir -p /home/ec2-user/.jupyter
cat > /home/ec2-user/.jupyter/jupyter_lab_config.py << 'EOF'
c.ServerApp.ip = '0.0.0.0'
c.ServerApp.port = 3006
c.ServerApp.open_browser = False
c.ServerApp.allow_root = False
c.ServerApp.token = ''
c.ServerApp.password = ''
c.ServerApp.disable_check_xsrf = True
EOF
chown ec2-user:ec2-user /home/ec2-user/.jupyter/jupyter_lab_config.py

# Create systemd service
echo "[JUPYTERLAB] Creating systemd service..."
cat > /etc/systemd/system/jupyterlab.service << 'EOF'
[Unit]
Description=JupyterLab
After=network.target

[Service]
Type=simple
User=ec2-user
WorkingDirectory=/home/ec2-user/jupyter
Environment=PATH=/home/ec2-user/.local/bin:/usr/local/bin:/usr/bin:/bin
ExecStart=/home/ec2-user/.local/bin/jupyter lab
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Enable and start service
echo "[JUPYTERLAB] Enabling and starting JupyterLab service..."
systemctl daemon-reload
systemctl enable jupyterlab
systemctl start jupyterlab

echo "[JUPYTERLAB] JupyterLab setup completed."
echo "[JUPYTERLAB] Service status: $(systemctl is-active jupyterlab)"