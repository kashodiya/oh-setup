#!/bin/bash

echo "[OPENHANDS-APP] Setting up OpenHands application..."

cd /home/ec2-user/docker/openhands

cat > docker-compose.yml << EOF
services:
  openhands-app:
    image: docker.all-hands.dev/all-hands-ai/openhands:0.50
    container_name: openhands-app
    pull_policy: always
    stdin_open: true
    tty: true
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
    networks:
      - shared_network

networks:
  shared_network:
    external: true
EOF

cat > .env << EOF
OPENHANDS_LITELLM_KEY=${OPENHANDS_LITELLM_KEY}
OPENHANDS_VSCODE_TOKEN=${OPENHANDS_VSCODE_TOKEN}
EOF

chown -R ec2-user:ec2-user /home/ec2-user/docker/openhands

echo "[OPENHANDS-APP] Pulling runtime image..."
docker pull -q docker.all-hands.dev/all-hands-ai/runtime:0.50-nikolaik

echo "[OPENHANDS-APP] Starting OpenHands app..."
sudo -u ec2-user docker-compose up -d --quiet-pull

echo "[OPENHANDS-APP] Setup completed!"