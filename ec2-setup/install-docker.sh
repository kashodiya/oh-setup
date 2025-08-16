#!/bin/bash

echo "[DOCKER] Checking if Docker is installed..."
if ! command -v docker &> /dev/null; then
    echo "[DOCKER] Docker not found. Installing Docker..."
    echo "[DOCKER] Installing Docker package..."
    yum install -y docker
    echo "[DOCKER] Starting Docker service..."
    systemctl start docker
    echo "[DOCKER] Enabling Docker service..."
    systemctl enable docker
    echo "[DOCKER] Adding ec2-user to docker group..."
    usermod -a -G docker ec2-user
    newgrp docker
    echo "[DOCKER] Docker installation completed."
else
    echo "[DOCKER] Docker already installed, skipping installation."
fi

echo "[DOCKER] Starting Docker service..."
systemctl start docker
echo "[DOCKER] Docker service status: $(systemctl is-active docker)"
echo "[DOCKER] Docker version: $(docker --version 2>/dev/null || echo 'Failed to get version')"