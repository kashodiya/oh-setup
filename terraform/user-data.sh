#!/bin/bash

# Install Docker if not already installed
if ! command -v docker &> /dev/null; then
    yum update -y
    yum install -y docker
    systemctl start docker
    systemctl enable docker
    usermod -a -G docker ec2-user
    newgrp docker
fi

# Ensure Docker is running
systemctl start docker

# Install docker-compose if not already installed
if ! command -v docker-compose &> /dev/null; then
    curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
fi

# Create openhands directory and docker-compose.yml if they don't exist
if [ ! -d "/home/ec2-user/docker/openhands" ]; then
    mkdir -p /home/ec2-user/docker/openhands
    chown -R ec2-user:ec2-user /home/ec2-user/docker
fi

if [ ! -f "/home/ec2-user/docker/openhands/docker-compose.yml" ]; then
    cat > /home/ec2-user/docker/openhands/docker-compose.yml << 'EOF'
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
      - LITELLM_API_KEY=${LITELLM_API_KEY}
      - AWS_REGION=us-east-1
      - PORT=80
    command: --config /app/config.yaml --detailed_debug

  vscode-server:
    image: gitpod/openvscode-server
    init: true
    ports:
    - 3002:3000
    volumes:
    - type: bind
        source: .
        target: /home/workspace
        cached: true

EOF
    chown ec2-user:ec2-user /home/ec2-user/docker/openhands/docker-compose.yml
    cd /home/ec2-user/docker/openhands
    sudo -u ec2-user docker-compose up -d
fi
