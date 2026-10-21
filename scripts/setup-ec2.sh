#!/bin/bash
# Run once on a fresh Ubuntu EC2 instance: installs Docker, kubectl and minikube.
set -e
sudo apt update
sudo apt install -y docker.io git curl wget conntrack
sudo usermod -aG docker "$USER"
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube
sudo snap install kubectl --classic
echo "Done. LOG OUT and log back in (so the docker group applies), then run:"
echo "  minikube start --driver=docker --cpus=2 --memory=4500"
