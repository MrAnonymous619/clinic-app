#!/bin/bash
# Starts 2 load-generator pods inside the cluster that call /work in a loop.
for n in load1 load2; do
  kubectl run "$n" --image=busybox:1.36 --restart=Never -n clinic -- \
    /bin/sh -c "while true; do wget -q -O- http://clinic-svc:5000/work > /dev/null; done"
done
echo "Load started. Watch:  kubectl get hpa -n clinic -w   and   kubectl get pods -n clinic -w"
