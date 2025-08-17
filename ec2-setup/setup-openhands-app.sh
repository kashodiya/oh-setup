#!/bin/bash

echo "[OPENHANDS-APP] Setting up OpenHands application..."

cd /home/ec2-user/docker/openhands

sudo -u ec2-user cat > docker-compose.yml << EOF
services:
  openhands-app:
    image: docker.all-hands.dev/all-hands-ai/openhands:0.50
    container_name: openhands-app
    pull_policy: always
    stdin_open: true
    tty: true
    environment:
      - SANDBOX_RUNTIME_CONTAINER_IMAGE=docker.all-hands.dev/all-hands-ai/runtime:0.50-nikolaik
      - LOG_ALL_EVENTS=true
      - OPENHANDS_BACKEND_HOST=0.0.0.0
    volumes:
      - ./.openhands:/.openhands
      - /var/run/docker.sock:/var/run/docker.sock
    ports:
      - "3000:3000"
    extra_hosts:
      - "host.docker.internal:host-gateway"
    networks:
      - shared_network

networks:
  shared_network:
    external: true
EOF

sudo -u ec2-user cat > .env << EOF
OPENHANDS_LITELLM_KEY=${OPENHANDS_LITELLM_KEY}
OPENHANDS_VSCODE_TOKEN=${OPENHANDS_VSCODE_TOKEN}
EOF

sudo -u ec2-user mkdir -p .openhands
sudo -u ec2-user cat > .openhands/settings.json << EOF
{
  "language": "en",
  "agent": "CodeActAgent",
  "max_iterations": null,
  "security_analyzer": null,
  "confirmation_mode": false,
  "llm_model": "litellm_proxy/Claude4",
  "llm_api_key": "${OPENHANDS_LITELLM_KEY}",
  "llm_base_url": "http://litellm",
  "remote_runtime_resource_factor": 1,
  "secrets_store": {
    "provider_tokens": {}
  },
  "enable_default_condenser": true,
  "enable_sound_notifications": false,
  "enable_proactive_conversation_starters": false,
  "user_consents_to_analytics": false,
  "sandbox_base_container_image": null,
  "sandbox_runtime_container_image": null,
  "mcp_config": {
    "sse_servers": [],
    "stdio_servers": [],
    "shttp_servers": []
  },
  "search_api_key": "",
  "sandbox_api_key": null,
  "max_budget_per_task": null,
  "email": null,
  "email_verified": null
}
EOF

echo "[OPENHANDS-APP] Pulling runtime image..."
docker pull -q docker.all-hands.dev/all-hands-ai/runtime:0.50-nikolaik

echo "[OPENHANDS-APP] Starting OpenHands app..."
sudo -u ec2-user docker-compose up -d --quiet-pull

echo "[OPENHANDS-APP] Setup completed!"