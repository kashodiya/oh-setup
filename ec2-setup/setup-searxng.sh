#!/bin/bash

echo "[SEARXNG] Setting up SearXNG service..."

cd /home/ec2-user/docker/searxng

# Create searxng config directory
sudo -u ec2-user mkdir -p searxng

# Create settings.yml for SearXNG
sudo -u ec2-user cat > searxng/settings.yml << 'SETTINGS_EOF'
general:
  debug: false
  instance_name: "SearXNG"
  privacypolicy_url: false
  donation_url: false
  contact_url: false
  enable_metrics: true
  open_metrics: ''

search:
  safe_search: 0
  autocomplete: ""
  autocomplete_min: 4
  favicon_resolver: ""
  default_lang: "auto"
  default_doi_resolver: "oadoi.org"
  ban_time_on_fail: 5
  max_ban_time_on_fail: 120
  formats:
    - html
    - json

server:
  port: 8888
  bind_address: "127.0.0.1"
  base_url: /
  limiter: false
  public_instance: false
  secret_key: "lpm2L6cbxNsZXbMCPqFGYQ6640GPVil"
  image_proxy: false
  http_protocol_version: "1.0"
  method: "POST"

ui:
  static_path: ""
  static_use_hash: false
  templates_path: ""
  query_in_title: false
  infinite_scroll: false
  default_theme: simple
  center_alignment: false
  default_locale: ""
  theme_args:
    simple_style: auto
  search_on_category_select: true
  hotkeys: default
  url_formatting: pretty

outgoing:
  request_timeout: 3.0
  useragent_suffix: ""
  pool_connections: 100
  pool_maxsize: 20
  enable_http2: true

engines:
  - name: google
    engine: google
    shortcut: go
  - name: bing
    engine: bing
    shortcut: bi
  - name: duckduckgo
    engine: duckduckgo
    shortcut: ddg
SETTINGS_EOF

sudo -u ec2-user cat > docker-compose.yml << EOF
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

echo "[SEARXNG] Starting SearXNG service..."
sudo -u ec2-user docker-compose up -d --quiet-pull

echo "[SEARXNG] Setup completed!"