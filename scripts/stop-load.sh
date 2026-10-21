#!/bin/bash
kubectl delete pod load1 load2 -n clinic --ignore-not-found
echo "Load stopped. The HPA scales back down after about 1-2 minutes."
