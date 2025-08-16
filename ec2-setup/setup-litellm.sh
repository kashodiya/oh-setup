#!/bin/bash

echo "[LITELLM] Setting up LiteLLM service..."

cd /home/ec2-user/docker/litellm

cat > docker-compose.yml << EOF
services:
  litellm:
    image: ghcr.io/berriai/litellm:main-latest
    container_name: litellm
    ports:
      - "5001:80"
    volumes:
      - ./litellm-config.yml:/app/config.yaml
    restart: unless-stopped
    environment:
      - LITELLM_API_KEY=${OPENHANDS_LITELLM_KEY}
      - AWS_REGION=us-east-1
      - PORT=80
    command: --config /app/config.yaml --detailed_debug
    networks:
      - shared_network

networks:
  shared_network:
    external: true
EOF

cat > litellm-config.yml << EOF
model_list:
  - model_name: Claude3
    litellm_params:
      model: anthropic.claude-3-haiku-20240307-v1:0
  - model_name: NovaPro1
    litellm_params:
      model: bedrock/amazon.nova-pro-v1:0
  - model_name: Claude3.7
    litellm_params:
      model: us.anthropic.claude-3-7-sonnet-20250219-v1:0
  - model_name: Claude4
    litellm_params:
      model: us.anthropic.claude-sonnet-4-20250514-v1:0
  - model_name: ClaudeOpus4.1
    litellm_params:
      model: us.anthropic.claude-opus-4-1-20250805-v1:0

litellm_settings:
  modify_params: True
  drop_params: true
EOF

chown -R ec2-user:ec2-user /home/ec2-user/docker/litellm

echo "[LITELLM] Starting LiteLLM service..."
sudo -u ec2-user docker-compose up -d --quiet-pull

echo "[LITELLM] Setup completed!"