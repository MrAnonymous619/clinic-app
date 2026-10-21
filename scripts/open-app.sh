#!/bin/bash
# (Re)opens the tunnel from the EC2 public port 8080 to the app. Run it after any pod restart/rollout,
# because kubectl port-forward is tied to one pod and stops when that pod is replaced.
pkill -f "port-forward --address 0.0.0.0 svc/clinic-svc" 2>/dev/null
mkdir -p "$HOME/logs"
nohup kubectl port-forward --address 0.0.0.0 svc/clinic-svc 8080:5000 -n clinic > "$HOME/logs/pf-app.log" 2>&1 &
sleep 2
echo "App tunnel ready on port 8080"
