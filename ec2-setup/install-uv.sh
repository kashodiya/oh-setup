#!/bin/bash

echo "[UV] Installing uv Python package manager for ec2-user..."

# Switch to ec2-user and install uv
sudo -u ec2-user bash -c '
    cd /home/ec2-user
    curl -LsSf https://astral.sh/uv/install.sh | sh
    echo "export PATH=\"\$HOME/.cargo/bin:\$PATH\"" >> /home/ec2-user/.bashrc
'

echo "[UV] Installation completed."
echo "[UV] Testing uv installation..."
sudo -u ec2-user bash -c 'source /home/ec2-user/.bashrc && uv --version' || echo "uv not found in PATH"