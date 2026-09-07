#!/bin/bash
set -euo pipefail

# ✅ Lahat nakapangalan na sa virgozki
PASSWORD="virgozki"
REGION="us-central1"
SERVICE_NAME="virgozki"
WSPATH="/virgozki"
DOMAIN="www.google.com"

rm -rf ~/openresty-fix && mkdir -p ~/openresty-fix && cd ~/openresty-fix

# config.json: Password at path = virgozki
cat <<EOF > config.json
{"log":{"loglevel":"none"},"inbounds":[{"port":10000,"listen":"127.0.0.1","protocol":"trojan","settings":{"clients":[{"password":"$PASSWORD"}]},"streamSettings":{"network":"ws","wsSettings":{"path":"$WSPATH"}}}],"outbounds":[{"protocol":"freedom"}]}
EOF

# nginx.conf: Tamang proxy at path alignment
cat <<EOF > nginx.conf
worker_processes 1;
events { worker_connections 1024; }
http {
    server {
        listen 8080;
        # Decoy site
        location / {
            proxy_pass https://$DOMAIN;
            proxy_set_header Host $DOMAIN;
            proxy_ssl_server_name on;
        }
        # Trojan WS endpoint
        location $WSPATH {
            proxy_pass http://127.0.0.1:10000;
            proxy_http_version 1.1;
            proxy_set_header Upgrade \$http_upgrade;
            proxy_set_header Connection "upgrade";
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
        }
    }
}
EOF

# Dockerfile: Fixed process order para hindi biglang magsara
cat <<EOF > Dockerfile
FROM teddysun/xray:latest AS xray-bin
FROM openresty/openresty:alpine-fat
COPY --from=xray-bin /usr/bin/xray /usr/local/bin/xray
COPY config.json /etc/xray.json
COPY nginx.conf /usr/local/openresty/nginx/conf/nginx.conf
EXPOSE 8080
CMD ["/bin/sh", "-c", "xray run -c /etc/xray.json & sleep 2 && exec /usr/local/openresty/bin/openresty -g 'daemon off;'"]
EOF

# Deploy to GCP Cloud Run
gcloud run deploy $SERVICE_NAME \
  --source . \
  --region $REGION \
  --platform managed \
  --allow-unauthenticated \
  --memory 512Mi --cpu 1 --port 8080

# Ipakita ang detalye pagkatapos
echo -e "\n✅ Deployment Done!"
SVC_URL=$(gcloud run services describe $SERVICE_NAME --region $REGION --format="value(status.url)")
echo "🔗 Service URL: $SVC_URL"
echo "🔑 Password: virgozki"
echo "🛤️ WS Path: /virgozki"
echo "🎭 Decoy Domain: google.com"
