#!/bin/bash

echo "[SEARXNG] Setting up SearXNG service..."

cd /home/ec2-user/docker/searxng

cat > docker-compose.yml << EOF
services:
  searxng:
    container_name: searxng
    image: docker.io/searxng/searxng:latest
    restart: unless-stopped
    volumes:
      - ./searxng:/etc/searxng:rw
    environment:
      - SEARXNG_HOSTNAME=localhost:8080/
    ports:
      - "3005:8080"
    logging:
      driver: "json-file"
      options:
        max-size: "1m"
        max-file: "1"
    networks:
      - shared_network

networks:
  shared_network:
    external: true
EOF

chown -R ec2-user:ec2-user /home/ec2-user/docker/searxng

echo "[SEARXNG] Starting SearXNG service..."
sudo -u ec2-user docker-compose up -d --quiet-pull

echo "[SEARXNG] Setup completed!"