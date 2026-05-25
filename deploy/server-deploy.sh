#!/usr/bin/env bash
set -euo pipefail

APP_NAME="ldc-shop"
IMAGE_NAME="${IMAGE_NAME:-saviour2411/ldc-shop:latest}"
DEPLOY_DIR="${DEPLOY_DIR:-/root/proj/ldc-shop}"
APP_PORT="${APP_PORT:-3000}"
DOMAIN="${DOMAIN:-shop.saviour.cc.cd}"
CF_ORIGIN_PORT="${CF_ORIGIN_PORT:-2087}"
CERT_DIR="${CERT_DIR:-/root/cert/saviour.cc.cd}"
CERT_FILE="${CERT_FILE:-${CERT_DIR}/saviour.cc.cd.pem}"
CERT_KEY_FILE="${CERT_KEY_FILE:-${CERT_DIR}/saviour.cc.cd.key}"
NGINX_AVAILABLE="${NGINX_AVAILABLE:-/etc/nginx/sites-available/${DOMAIN}}"
NGINX_ENABLED="${NGINX_ENABLED:-/etc/nginx/sites-enabled/${DOMAIN}}"

log() {
  printf '[deploy] %s\n' "$*"
}

fail() {
  printf '[deploy] ERROR: %s\n' "$*" >&2
  exit 1
}

command -v docker >/dev/null 2>&1 || fail "docker 未安装"
docker compose version >/dev/null 2>&1 || fail "docker compose 未安装或不可用"
command -v nginx >/dev/null 2>&1 || fail "nginx 未安装"

mkdir -p "$DEPLOY_DIR/data" "$DEPLOY_DIR/deploy"
chmod 777 "$DEPLOY_DIR/data"

[ -f "$DEPLOY_DIR/.env" ] || fail "缺少 ${DEPLOY_DIR}/.env，请先在服务器创建运行时密钥配置"
[ -f "$CERT_FILE" ] || fail "证书文件不存在: $CERT_FILE"
[ -f "$CERT_KEY_FILE" ] || fail "证书私钥不存在: $CERT_KEY_FILE"

if ss -ltn | awk '{print $4}' | grep -Eq "(^|:)${APP_PORT}$"; then
  if ! docker ps --format '{{.Names}}' | grep -qx "$APP_NAME"; then
    fail "127.0.0.1:${APP_PORT} 已被占用，且不是 ${APP_NAME} 容器"
  fi
fi

cat > "$DEPLOY_DIR/docker-compose.yml" <<COMPOSE
services:
  app:
    container_name: ${APP_NAME}
    image: ${IMAGE_NAME}
    restart: always
    ports:
      - "127.0.0.1:${APP_PORT}:3000"
    volumes:
      - ./data:/app/data
    env_file:
      - .env
COMPOSE

cat > "$NGINX_AVAILABLE" <<NGINX
server {
    listen ${CF_ORIGIN_PORT} ssl;
    http2 on;
    server_name ${DOMAIN};

    ssl_certificate ${CERT_FILE};
    ssl_certificate_key ${CERT_KEY_FILE};
    ssl_protocols TLSv1.2 TLSv1.3;

    client_max_body_size 64m;

    access_log /var/log/nginx/${APP_NAME}.access.log;
    error_log /var/log/nginx/${APP_NAME}.error.log;

    location / {
        proxy_pass http://127.0.0.1:${APP_PORT};
        proxy_http_version 1.1;

        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
        proxy_set_header X-Forwarded-Host \$host;

        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";

        proxy_read_timeout 3600s;
        proxy_send_timeout 3600s;
        proxy_buffering off;
    }
}
NGINX

ln -sfn "$NGINX_AVAILABLE" "$NGINX_ENABLED"
nginx -t
systemctl reload nginx

cd "$DEPLOY_DIR"
docker compose pull
docker compose up -d

docker ps --filter "name=^/${APP_NAME}$" --format '{{.Names}} {{.Image}} {{.Ports}}' | grep -q "$APP_NAME" || fail "${APP_NAME} 容器未运行"

log "部署完成: ${IMAGE_NAME}"
