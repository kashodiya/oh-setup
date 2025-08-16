#!/bin/bash

echo "[COMPOSE] Checking if docker-compose is installed..."
if ! command -v docker-compose &> /dev/null; then
    echo "[COMPOSE] docker-compose not found. Installing docker-compose..."
    echo "[COMPOSE] Downloading docker-compose binary..."
    curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    echo "[COMPOSE] Setting executable permissions..."
    chmod +x /usr/local/bin/docker-compose
    echo "[COMPOSE] docker-compose installation completed."
else
    echo "[COMPOSE] docker-compose already installed, skipping installation."
fi
echo "[COMPOSE] docker-compose version: $(docker-compose --version 2>/dev/null || echo 'Failed to get version')"