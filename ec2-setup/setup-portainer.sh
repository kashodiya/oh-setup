#!/bin/bash

echo "[PORTAINER] Setting up Portainer service..."

cd /home/ec2-user/docker/portainer

sudo -u ec2-user cat > docker-compose.yml << EOF
services:
  portainer:
    image: portainer/portainer-ce
    container_name: portainer
    restart: always
    ports:
      - "3003:9443"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - portainer_data:/data
    networks:
      - shared_network

volumes:
  portainer_data:

networks:
  shared_network:
    external: true
EOF

echo "[PORTAINER] Starting Portainer service..."
sudo -u ec2-user docker-compose up -d --quiet-pull

echo "[PORTAINER] Setup completed!"