#!/bin/bash

echo "[PORTAINER] Setting up Portainer service..."

cd /home/ec2-user/docker/portainer

cat > docker-compose.yml << EOF
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

chown -R ec2-user:ec2-user /home/ec2-user/docker/portainer

echo "[PORTAINER] Starting Portainer service..."
sudo -u ec2-user docker-compose up -d --quiet-pull

echo "[PORTAINER] Setup completed!"