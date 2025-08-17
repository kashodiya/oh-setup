#!/bin/bash

echo "[OPEN-WEBUI] Setting up Open WebUI service..."

cd /home/ec2-user/docker/open-webui

sudo -u ec2-user cat > docker-compose.yml << EOF
services:
  open-webui:
    image: ghcr.io/open-webui/open-webui:main
    container_name: open-webui
    extra_hosts:
      - "host.docker.internal:host-gateway"    
    volumes:
      - open-webui:/app/backend/data
    environment:
      - CODE_EXECUTION_ENGINE=jupyter
      - CODE_EXECUTION_JUPYTER_URL=http://host.docker.internal:3006
      # - CODE_EXECUTION_JUPYTER_AUTH=token
      - OPENAI_API_BASE_URLS=http://litellm
      - OPENAI_API_KEYS=\${OPENHANDS_LITELLM_KEY}
      - GLOBAL_LOG_LEVEL=DEBUG
      - ENV=dev
      - ENABLE_RAG_WEB_SEARCH=True
      - RAG_WEB_SEARCH_ENGINE="searxng"
      - RAG_WEB_SEARCH_RESULT_COUNT=3
      - RAG_WEB_SEARCH_CONCURRENT_REQUESTS=10
      - ENABLE_WEB_SEARCH=True
      - WEB_SEARCH_ENGINE=searxng
      - SEARXNG_QUERY_URL=http://searxng:8080/search?q=<query>
      - DEFAULT_USER_ROLE=admin
      - ENABLE_SIGNUP=False
      - WEBUI_AUTH=False
    ports:
      - "8101:8080"
    restart: always
    networks:
      - shared_network

volumes:
  open-webui:

networks:
  shared_network:
    external: true
EOF

sudo -u ec2-user cat > .env << EOF
OPENHANDS_LITELLM_KEY=${OPENHANDS_LITELLM_KEY}
EOF

echo "[OPEN-WEBUI] Starting Open WebUI service..."
sudo -u ec2-user docker-compose up -d --quiet-pull

echo "[OPEN-WEBUI] Setup completed!"