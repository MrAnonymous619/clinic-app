#!/bin/bash
# Starts everything after the EC2 instance was stopped and started again.
# Run from anywhere:  bash ~/clinic-app/scripts/start-all.sh
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LOGS="$HOME/logs"
mkdir -p "$LOGS"
NODE_EXP=$(ls -d "$HOME"/node_exporter-*/ | head -1)
PROM=$(ls -d "$HOME"/prometheus-*/ | head -1)
GRAF=$(ls -d "$HOME"/grafana-*/ | head -1)

minikube start --driver=docker --cpus=2 --memory=4500
nohup kubectl proxy --port=8001 > "$LOGS/proxy.log" 2>&1 &
(cd "$NODE_EXP" && nohup ./node_exporter > "$LOGS/node.log" 2>&1 &)
(cd "$PROM" && nohup ./prometheus --config.file="$ROOT/monitoring/prometheus.yml" > "$LOGS/prom.log" 2>&1 &)
(cd "$GRAF" && nohup ./bin/grafana server > "$LOGS/grafana.log" 2>&1 &)
nohup kubectl port-forward --address 0.0.0.0 svc/clinic-svc 8080:5000 -n clinic > "$LOGS/pf-app.log" 2>&1 &
sleep 3
echo "Started. App :8080  Prometheus :9090  Grafana :3000  (public IP has changed after a restart)"
