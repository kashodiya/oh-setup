#!/bin/bash

echo "[OPENHANDS-APP] Setting up OpenHands application..."

cd /home/ec2-user/docker/openhands

# Substitute environment variables in templates
sudo -u ec2-user envsubst < .env.template > .env
sudo -u ec2-user envsubst < .openhands/settings.json.template > .openhands/settings.json

echo "[OPENHANDS-APP] Pulling runtime image..."
docker pull -q docker.all-hands.dev/all-hands-ai/runtime:0.50-nikolaik

echo "[OPENHANDS-APP] Starting OpenHands app..."
sudo -u ec2-user docker-compose up -d --quiet-pull

echo "[OPENHANDS-APP] Setup completed!"