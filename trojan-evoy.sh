#!/bin/bash
set -euo pipefail

# Updated credentials & config
PASSWORD="virgozki"
REGION="us-central1"
SERVICE_NAME="trojan-envoy"

rm -rf ~/trojan-envoy && mkdir -p ~/trojan-envoy && cd ~/trojan-envoy

# config.json: removed impostor path, new password
cat <<'EOF' > config.json
{"log":{"loglevel":"warn"},"inbounds":[{"port":10000,"listen":"127.0.0.1","protocol":"trojan","settings":{"clients":[{"password":"virgozki"}]},"streamSettings":{"network":"ws","wsSettings":{"path":"/trojan"}}}],"outbounds":[{"protocol":"freedom"}]}
EOF

# envoy.yaml: updated path from /impostor-trojan to /trojan
cat <<'EOF' > envoy.yaml
static_resources:
  listeners:
  - name: listener_0
    address:
      socket_address:
        address: 0.0.0.0
        port_value: 8080
    filter_chains:
    - filters:
      - name: envoy.filters.network.http_connection_manager
        typed_config:
          "@type": type.googleapis.com/envoy.extensions.filters.network.http_connection_manager.v3.HttpConnectionManager
          stat_prefix: ingress_http
          route_config:
            name: local_route
            virtual_hosts:
            - name: local_service
              domains: ["*"]
              routes:
              - match:
                  prefix: "/trojan"
                route:
                  cluster: xray_trojan
                  upgrade_configs:
                  - upgrade_type: websocket
          http_filters:
          - name: envoy.filters.http.router
            typed_config:
              "@type": type.googleapis.com/envoy.extensions.filters.http.router.v3.Router
  clusters:
  - name: xray_trojan
    connect_timeout: 1s
    type: STRICT_DNS
    lb_policy: ROUND_ROBIN
    load_assignment:
      cluster_name: xray_trojan
      endpoints:
      - lb_endpoints:
        - endpoint:
            address:
              socket_address:
                address: 127.0.0.1
                port_value: 10000
EOF

# Dockerfile: no changes needed here
cat <<'EOF' > Dockerfile
FROM teddysun/xray:latest AS xray-bin
FROM envoyproxy/envoy:v1.31.10
COPY --from=xray-bin /usr/bin/xray /usr/local/bin/
COPY config.json /etc/xray.json
COPY envoy.yaml /etc/envoy/envoy.yaml
EXPOSE 8080
CMD ["/bin/sh", "-c", "xray run -c /etc/xray.json & sleep 3 && exec envoy -c /etc/envoy/envoy.yaml --log-level warn"]
EOF

# Deploy to GCP Cloud Run
gcloud services enable run.googleapis.com cloudbuild.googleapis.com --quiet
gcloud run deploy $SERVICE_NAME \
  --source . \
  --region $REGION \
  --platform managed \
  --allow-unauthenticated \
  --memory 1Gi --cpu 1 --port 8080 --execution-environment=gen2

# Show result
echo -e "\n✅ Deployment complete."
SVC_URL=$(gcloud run services describe $SERVICE_NAME --region $REGION --format="value(status.url)")
echo "🔗 Service URL: $SVC_URL"
echo "🔑 Password: virgozki"
echo "🛤️ WS Path: /trojan"
gcloud run services describe $SERVICE_NAME --region $REGION --format="table[box](name,status.url,status.conditions[0].status,status.conditions[0].message)"
