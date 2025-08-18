#!/bin/bash

echo "[SEARXNG] Setting up SearXNG service..."

cd /home/ec2-user/docker/searxng

echo "[SEARXNG] Starting SearXNG service..."
sudo -u ec2-user docker-compose up -d --quiet-pull

echo "[SEARXNG] Setup completed!"