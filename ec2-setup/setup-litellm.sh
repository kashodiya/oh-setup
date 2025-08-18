#!/bin/bash

echo "[LITELLM] Setting up LiteLLM service..."

cd /home/ec2-user/docker/litellm

echo "[LITELLM] Starting LiteLLM service..."
sudo -u ec2-user docker-compose up -d --quiet-pull

echo "[LITELLM] Setup completed!"