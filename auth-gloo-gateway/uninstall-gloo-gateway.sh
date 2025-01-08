#!/bin/bash

# Text colors
blue="\033[0;34m"
nocolor="\033[0m"

# Remove all resources created in install-gge.sh
echo
echo -e "${blue}Cleaning up Gloo Gateway Enterprise resources${nocolor}"
kubectl delete referencegrant -n httpbin httpbin-grant
kubectl delete httproute -n gloo-system httpbin
kubectl delete -n httpbin -f https://raw.githubusercontent.com/solo-io/gloo-mesh-use-cases/main/policy-demo/httpbin.yaml
kubectl delete namespace httpbin
kubectl delete gateway -n gloo-system http
helm uninstall -n gloo-system gloo
kubectl delete namespace gloo-system
kubectl delete -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.0/standard-install.yaml
# Delete solo.io crds left behind by helm
kubectl get crd -o name | grep solo.io | xargs kubectl delete

echo
echo -e "${blue}Removed all Gloo Gateway Enterprise resources${nocolor}"