#!/bin/bash

# Main orchestration script
echo "[MAIN] Starting main setup script..."
echo "[MAIN] Current user: $(whoami)"
echo "[MAIN] Current directory: $(pwd)"

# Update system packages once at the beginning
echo "[MAIN] Updating system packages..."
yum update -y
echo "[MAIN] System update completed with exit code: $?"

# Get project name - use hardcoded value since it's consistent
echo "[MAIN] Setting project name..."
PROJECT_NAME="oh"
echo "[MAIN] Project name: $PROJECT_NAME"

# Retrieve values from Parameter Store
echo "[MAIN] Retrieving configuration from Parameter Store..."
OPENHANDS_LITELLM_KEY=$(aws ssm get-parameter --name "/$PROJECT_NAME/litellm-key" --with-decryption --query "Parameter.Value" --output text --region us-east-1)
ADMIN_PASSWORD=$(aws ssm get-parameter --name "/$PROJECT_NAME/admin-password" --with-decryption --query "Parameter.Value" --output text --region us-east-1)

# Export variables for use in child scripts
export OPENHANDS_LITELLM_KEY
export ADMIN_PASSWORD

echo "[MAIN] Configuration retrieved successfully."
echo "[MAIN] LITELLM_KEY length: ${#OPENHANDS_LITELLM_KEY}"
echo "[MAIN] ADMIN_PASSWORD length: ${#ADMIN_PASSWORD}"

# Run installation scripts
echo "[MAIN] Running Docker installation..."
bash /home/ec2-user/source/ec2-setup/install-docker.sh
echo "[MAIN] Docker installation completed with exit code: $?"

echo "[MAIN] Creating Docker network..."
docker network create shared_network
echo "[MAIN] Docker network creation completed with exit code: $?"

echo "[MAIN] Running Docker Compose installation..."
bash /home/ec2-user/source/ec2-setup/install-docker-compose.sh
echo "[MAIN] Docker Compose installation completed with exit code: $?"

echo "[MAIN] Creating Docker directory structure..."
mkdir -p /home/ec2-user/docker/{openhands,litellm,portainer,open-webui,searxng}
chown -R ec2-user:ec2-user /home/ec2-user/docker

echo "[MAIN] Setting up OpenHands app..."
bash /home/ec2-user/source/ec2-setup/setup-openhands-app.sh
echo "[MAIN] OpenHands app setup completed with exit code: $?"

echo "[MAIN] Setting up LiteLLM..."
bash /home/ec2-user/source/ec2-setup/setup-litellm.sh
echo "[MAIN] LiteLLM setup completed with exit code: $?"

echo "[MAIN] Setting up Open WebUI..."
bash /home/ec2-user/source/ec2-setup/setup-open-webui.sh
echo "[MAIN] Open WebUI setup completed with exit code: $?"

echo "[MAIN] Setting up SearXNG..."
bash /home/ec2-user/source/ec2-setup/setup-searxng.sh
echo "[MAIN] SearXNG setup completed with exit code: $?"

echo "[MAIN] Setting up Portainer..."
bash /home/ec2-user/source/ec2-setup/setup-portainer.sh
echo "[MAIN] Portainer setup completed with exit code: $?"

echo "[MAIN] Installing VSCode Server..."
bash /home/ec2-user/source/ec2-setup/install-vscode-server.sh
echo "[MAIN] VSCode Server installation completed with exit code: $?"

echo "[MAIN] Installing Caddy..."
bash /home/ec2-user/source/ec2-setup/install-caddy.sh
echo "[MAIN] Caddy installation completed with exit code: $?"

echo "[MAIN] Main setup script completed successfully."