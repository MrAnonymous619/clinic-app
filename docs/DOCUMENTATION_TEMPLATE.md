# Capstone Documentation (fill in your own words)

## 1. Application idea
- Problem: clinics often track appointments on paper or in chat, causing double bookings.
- Purpose: a simple web service where reception staff book and view appointments.
- Key features: book/list appointments, health endpoint, metrics endpoint, CPU stress endpoint for scaling tests.
- Intended users: clinic reception staff.

## 2. Architecture (insert diagram image)
Explain each component: Flask app, Docker image, Docker Hub, Kubernetes (Deployment, Service, HPA), Metrics Server.

## 3. CI/CD architecture (insert diagram image)
Explain: push to main -> GitHub Actions -> build -> Docker Hub (latest + SHA tags) -> WhatsApp message -> rollout.

## 4. Notification system
Explain how the last pipeline step calls the Twilio WhatsApp API with repository secrets, and that it runs only on success.

## 5. Monitoring architecture
Explain: node_exporter, cAdvisor, kube-state-metrics, app /metrics -> Prometheus (scrape and store) -> Grafana (visualize).
List each dashboard panel and what it tells you about resource pressure, workload changes and scaling.

## 6. HPA configuration
Target: CPU 50% of the requested 100m, min 2, max 6 replicas, scale-down window 60 s. Explain how scaling decisions are made.

## 7. Design decisions and troubleshooting
In-memory data, plain YAML, Minikube on EC2, downloaded Prometheus/Grafana, problems met and how they were fixed.
