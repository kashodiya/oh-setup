#!/bin/bash

echo "[PORTAINER] Setting up Portainer service..."

cd /home/ec2-user/docker/portainer

echo "[PORTAINER] Starting Portainer service..."
sudo -u ec2-user docker-compose up -d --quiet-pull

echo "[PORTAINER] Setup completed!"