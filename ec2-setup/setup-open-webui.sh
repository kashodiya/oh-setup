#!/bin/bash

echo "[OPEN-WEBUI] Setting up Open WebUI service..."

cd /home/ec2-user/docker/open-webui

# Substitute environment variables in template
sudo -u ec2-user envsubst < .env.template > .env

echo "[OPEN-WEBUI] Starting Open WebUI service..."
sudo -u ec2-user docker-compose up -d --quiet-pull

echo "[OPEN-WEBUI] Setup completed!"