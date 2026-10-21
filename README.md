# Clinic Appointments - Cloud-Native DevOps Capstone

A small Flask web app for booking clinic appointments, used to demonstrate a full cloud-native delivery workflow:
GitHub push -> GitHub Actions -> Docker Hub -> WhatsApp notification -> Kubernetes (Minikube on EC2) ->
Prometheus + Grafana monitoring -> automatic scaling with the Horizontal Pod Autoscaler (HPA).

> Status: these files were drafted but NOT yet run on a live cluster. Test each step and fix anything that differs
> (service names, metric names, download links). You must understand every file before presenting: each one has comments.

## Architecture

```
Developer --git push--> GitHub repo
                           |
                     GitHub Actions (on push to main)
                       1. checkout  2. docker build
                       3. push to Docker Hub (tags: latest + commit SHA)
                       4. WhatsApp message (only on success)
                           |
                      Docker Hub  <------ image pulled by the cluster
                           |
AWS EC2 host (Ubuntu t3.large, us-east-1)
  Programs on the host: node_exporter :9100, Prometheus :9090, Grafana :3000, kubectl proxy :8001
  Minikube (single node)
    namespace clinic:      clinic-app Deployment (2-6 pods, HPA CPU 50%) + Service
    namespace kube-system: Metrics Server (feeds HPA), kube-state-metrics
Prometheus scrapes node_exporter directly and, through kubectl proxy, cAdvisor, kube-state-metrics and the app /metrics.
Grafana reads from Prometheus.  Browser -> EC2 public IP :8080 (app), :3000 (Grafana), :9090 (Prometheus)
```

## Files

| Path | Purpose |
|---|---|
| app.py, requirements.txt | The Flask application (endpoints: /, /appointments, DELETE /appointments/id, /health, /metrics, /work, /version) |
| static/index.html | The whole user interface in one HTML file (served by Flask at /) |
| Dockerfile, .dockerignore | Container image |
| .github/workflows/ci.yml | Push-triggered pipeline: build, push to Docker Hub, WhatsApp message |
| k8s/ | Namespace, Deployment (2 replicas, CPU requests, probes), Service, HPA (CPU 50%, min 2, max 6) |
| monitoring/prometheus.yml | Prometheus scrape configuration |
| scripts/setup-ec2.sh | Installs Docker, kubectl, minikube on a fresh Ubuntu EC2 |
| scripts/install-monitoring.sh | Downloads node_exporter, Prometheus, Grafana (web downloads) |
| scripts/start-all.sh | Starts everything after the instance restarts |
| scripts/open-app.sh | Reopens the app tunnel (port 8080); run it after any rollout restart |
| scripts/load-test.sh, stop-load.sh | Start/stop the load generators for the HPA demo |
| docs/ | Handoff guide PDF and a documentation template |

## Before you start: replace these values

1. In `k8s/deployment.yaml` replace `DOCKERHUB_USERNAME` with your Docker Hub username:
   `sed -i 's/DOCKERHUB_USERNAME/YOUR_USERNAME/' k8s/deployment.yaml`
2. In the GitHub repo: Settings, Secrets and variables, Actions, add these secrets:
   `DOCKERHUB_USERNAME`, `DOCKERHUB_TOKEN` (Docker Hub access token), `TWILIO_ACCOUNT_SID`, `TWILIO_AUTH_TOKEN`,
   `TWILIO_WHATSAPP_FROM` (sandbox number, e.g. +14155238886), `TWILIO_WHATSAPP_TO` (your number with country code).
   WhatsApp sandbox: Twilio console, WhatsApp Sandbox, send "join" plus the shown code from your WhatsApp.
   Re-join about every 72 hours and test the day before the demo.

## Build order

1. Local test (Git Bash): `docker build -t clinic-app:v1 .` then `docker run -p 5000:5000 clinic-app:v1`, open http://localhost:5000
2. Push the project to your GitHub repo (branch main). Check Actions run, Docker Hub tags, WhatsApp message.
3. Launch EC2: Ubuntu, t3.large, 30 GB, region us-east-1, name ARNMK-capstone-ec2, security group inbound 22, 8080, 3000, 9090 from My IP.
4. On EC2: `git clone` your repo, run `bash scripts/setup-ec2.sh`, log out and in, then
   `minikube start --driver=docker --cpus=2 --memory=4500`
5. Deploy: `kubectl apply -f k8s/namespace.yaml -f k8s/deployment.yaml -f k8s/service.yaml`, check `kubectl get pods -n clinic`, then
   `nohup kubectl port-forward --address 0.0.0.0 svc/clinic-svc 8080:5000 -n clinic > pf.log 2>&1 &` and open http://EC2-PUBLIC-IP:8080
6. HPA: `minikube addons enable metrics-server`, wait 1-2 minutes, `kubectl top pods -n clinic`, `kubectl apply -f k8s/hpa.yaml`,
   `kubectl get hpa -n clinic` (TARGETS must show a percentage, not unknown).
7. Monitoring: `git clone https://github.com/kubernetes/kube-state-metrics.git` then
   `kubectl apply -f kube-state-metrics/examples/standard`; `bash scripts/install-monitoring.sh`; `nohup kubectl proxy --port=8001 > proxy.log 2>&1 &`;
   start node_exporter, Prometheus (`--config.file` = monitoring/prometheus.yml) and Grafana (`./bin/grafana server`), or just run `bash scripts/start-all.sh`.
   Prometheus: http://EC2-PUBLIC-IP:9090 Status, Targets (all UP). Grafana: http://EC2-PUBLIC-IP:3000 (admin/admin),
   add data source Prometheus with URL http://localhost:9090, then build the dashboard below.
8. Rehearse the demo (next section) at least twice.

## Live demo script

1. Change `VERSION = "v1"` to `"v2"` in app.py, commit, push to main.
2. Show GitHub Actions running, the new tag in Docker Hub, and the WhatsApp message.
3. On EC2: `kubectl rollout restart deployment/clinic-app -n clinic`, wait for Running pods, then `bash scripts/open-app.sh` (the old tunnel dies with the old pod), refresh the app: it shows v2 and the pod name.
4. Show the HPA config (`kubectl get hpa -n clinic`, `k8s/hpa.yaml`): CPU target 50%, min 2, max 6.
5. Open Grafana. Run `bash scripts/load-test.sh`. Watch `kubectl get hpa -n clinic -w` and the pods scale out; show the dashboard.
6. Run `bash scripts/stop-load.sh` and watch scale-down.

## Grafana dashboard panels (PromQL)

| Panel | Query |
|---|---|
| Pod CPU | `sum(rate(container_cpu_usage_seconds_total{namespace="clinic",container!=""}[2m])) by (pod)` |
| Pod memory | `sum(container_memory_working_set_bytes{namespace="clinic",container!=""}) by (pod)` |
| Pod status | `sum(kube_pod_status_phase{namespace="clinic"}) by (phase)` |
| Pod restarts | `sum(kube_pod_container_status_restarts_total{namespace="clinic"}) by (pod)` |
| HPA replicas | `kube_horizontalpodautoscaler_status_current_replicas{namespace="clinic"}` and `..._desired_replicas` |
| HPA min / max | `kube_horizontalpodautoscaler_spec_min_replicas`, `kube_horizontalpodautoscaler_spec_max_replicas` |
| Node CPU % | `100 - (avg(rate(node_cpu_seconds_total{mode="idle"}[2m])) * 100)` |
| Node memory % | `(1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) * 100` |
| Request rate (approx.) | `sum(rate(clinic_http_requests_total[1m]))` |
| p95 latency (approx.) | `histogram_quantile(0.95, sum(rate(clinic_request_latency_seconds_bucket[2m])) by (le))` |

App-level panels are approximate with several pods because each scrape through the Service reaches one random pod.

## Troubleshooting

| Symptom | Check |
|---|---|
| ImagePullBackOff | Image name/tag, Docker Hub repo is public, `kubectl describe pod` |
| HPA TARGETS unknown | Metrics Server ready? CPU requests set in the Deployment? |
| No scaling | Load pods Running? `kubectl top pods -n clinic` while load runs |
| Prometheus target down | `kubectl proxy` running? Test with curl on localhost:8001 using the same path |
| Cannot open app/Grafana | Security group port, public IP changed after restart, port-forward running |
| No WhatsApp message | Sandbox join expired, number format, secrets, Twilio logs |
| Old version after push | `kubectl rollout restart deployment/clinic-app -n clinic`, then `bash scripts/open-app.sh` |
| App page stops loading after a restart | `bash scripts/open-app.sh` |

## Limitations (explain these honestly)

- Appointments live in memory: each pod has its own list and a restart loses data (no database, by design for this scope).
- The new image is rolled out with a manual `kubectl rollout restart`; the pipeline builds, pushes and notifies.
- Single-node Minikube on one EC2 instance, so node-level scaling is out of scope; pod-level scaling is demonstrated.
