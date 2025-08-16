#!/bin/bash

# Redirect all output to log file and console
exec > >(tee /var/log/user-data.log) 2>&1

echo "Starting user data script execution..."

# Retrieve values from Parameter Store
echo "Retrieving configuration from Parameter Store..."
OPENHANDS_LITELLM_KEY=$(aws ssm get-parameter --name "/openhands/litellm-key" --with-decryption --query "Parameter.Value" --output text --region us-east-1)
OPENHANDS_VSCODE_TOKEN=$(aws ssm get-parameter --name "/openhands/vscode-token" --with-decryption --query "Parameter.Value" --output text --region us-east-1)
# ELASTIC_IP=$(aws ssm get-parameter --name "openhands_elastic_ip" --query "Parameter.Value" --output text --region us-east-1)
echo "Configuration retrieved successfully."

# Install Docker if not already installed
echo "Checking if Docker is installed..."
if ! command -v docker &> /dev/null; then
    echo "Docker not found. Installing Docker..."
    yum update -y
    yum install -y docker
    systemctl start docker
    systemctl enable docker
    usermod -a -G docker ec2-user
    newgrp docker
    echo "Docker installation completed."
else
    echo "Docker already installed, skipping installation."
fi

# Ensure Docker is running
echo "Starting Docker service..."
systemctl start docker

# Install docker-compose if not already installed
echo "Checking if docker-compose is installed..."
if ! command -v docker-compose &> /dev/null; then
    echo "docker-compose not found. Installing docker-compose..."
    curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    echo "docker-compose installation completed."
else
    echo "docker-compose already installed, skipping installation."
fi

# Create openhands directory and docker-compose.yml if they don't exist
echo "Checking openhands directory..."
if [ ! -d "/home/ec2-user/docker/openhands" ]; then
    echo "Creating openhands directory..."
    mkdir -p /home/ec2-user/docker/openhands
    chown -R ec2-user:ec2-user /home/ec2-user/docker
    echo "Openhands directory created."
else
    echo "Openhands directory already exists."
fi

echo "Checking docker-compose.yml file..."
if [ ! -f "/home/ec2-user/docker/openhands/docker-compose.yml" ]; then
    echo "Creating docker-compose.yml file..."
    cat > /home/ec2-user/docker/openhands/docker-compose.yml << EOF
services:
  openhands-app:
    image: docker.all-hands.dev/all-hands-ai/openhands:0.50
    container_name: openhands-app
    pull_policy: always
    stdin_open: true  # equivalent to -i
    tty: true  # equivalent to -t
    environment:
      - SANDBOX_RUNTIME_CONTAINER_IMAGE=docker.all-hands.dev/all-hands-ai/runtime:0.50-nikolaik
      - LOG_ALL_EVENTS=true
      - OPENHANDS_BACKEND_HOST=0.0.0.0
    volumes:
      - ./.openhands:/.openhands
      - /var/run/docker.sock:/var/run/docker.sock
    ports:
      - "3000:3000"
    extra_hosts:
      - "host.docker.internal:host-gateway"

  litellm:
    image: ghcr.io/berriai/litellm:main-latest
    container_name: litellm
    ports:
      - "3001:3000"
    volumes:
      - ./litellm-config.yml:/app/config.yaml
    restart: unless-stopped
    environment:
      - LITELLM_API_KEY=${OPENHANDS_LITELLM_KEY}
      - AWS_REGION=us-east-1
      - PORT=80
    command: --config /app/config.yaml --detailed_debug

  portainer:
    image: portainer/portainer-ce
    container_name: portainer
    restart: always
    ports:
      - "3003:9443"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - portainer_data:/data    

volumes:
  portainer_data:
  
EOF
    chown ec2-user:ec2-user /home/ec2-user/docker/openhands/docker-compose.yml
    
    echo "Creating litellm-config.yml file..."
    cat > /home/ec2-user/docker/openhands/litellm-config.yml << EOF
model_list:
  - model_name: Claude3
    litellm_params:
      model: anthropic.claude-3-haiku-20240307-v1:0
  - model_name: NovaPro1
    litellm_params:
      model: bedrock/amazon.nova-pro-v1:0
  - model_name: Claude3.7
    litellm_params:
      model: us.anthropic.claude-3-7-sonnet-20250219-v1:0
  - model_name: Claude4
    litellm_params:
      model: us.anthropic.claude-sonnet-4-20250514-v1:0
  - model_name: ClaudeOpus4.1
    litellm_params:
      model: us.anthropic.claude-opus-4-1-20250805-v1:0

litellm_settings:
  modify_params: True
  drop_params: true
EOF
    chown ec2-user:ec2-user /home/ec2-user/docker/openhands/litellm-config.yml


    echo "Pulling OpenHands runtime image..."
    docker pull docker.all-hands.dev/all-hands-ai/runtime:0.50-nikolaik

    echo "Starting OpenHands containers..."
    cd /home/ec2-user/docker/openhands
    sudo -u ec2-user docker-compose up -d
    echo "OpenHands containers started."
else
    echo "docker-compose.yml already exists, skipping creation."
fi

# Install OpenVSCode Server if not already installed
echo "Checking if OpenVSCode Server is installed..."
if [ ! -d "/opt/openvscode-server" ]; then
    echo "OpenVSCode Server not found. Installing..."
    cd /tmp
    echo "Fetching latest release information..."
    LATEST_RELEASE=$(curl -s https://api.github.com/repos/gitpod-io/openvscode-server/releases/latest | grep '"tag_name"' | cut -d'"' -f4)
    echo "Latest release: $LATEST_RELEASE"
    echo "Downloading OpenVSCode Server..."
    wget "https://github.com/gitpod-io/openvscode-server/releases/download/${LATEST_RELEASE}/${LATEST_RELEASE}-linux-x64.tar.gz"
    echo "Extracting archive..."
    tar -xzf "${LATEST_RELEASE}-linux-x64.tar.gz"
    echo "Moving to /opt/openvscode-server..."
    mv "${LATEST_RELEASE}-linux-x64" /opt/openvscode-server
    chown -R ec2-user:ec2-user /opt/openvscode-server
    echo "OpenVSCode Server files installed."
    
    # Create systemd service
    echo "Creating systemd service..."
    cat > /etc/systemd/system/openvscode-server.service << EOF
[Unit]
Description=OpenVSCode Server
After=network.target

[Service]
Type=simple
User=ec2-user
WorkingDirectory=/opt/openvscode-server
ExecStart=/opt/openvscode-server/bin/openvscode-server --host 0.0.0.0 --port 3002 --connection-token ${OPENHANDS_VSCODE_TOKEN}
Restart=always
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF
    
    echo "Reloading systemd and starting OpenVSCode Server service..."
    systemctl daemon-reload
    systemctl enable openvscode-server
    systemctl start openvscode-server
    echo "OpenVSCode Server service started and enabled."
else
    echo "OpenVSCode Server already installed, skipping installation."
fi

echo "User data script execution completed."
echo "Log saved to /var/log/user-data.log"
