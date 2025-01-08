#!/bin/bash

# Text colors
blue="\033[0;34m"
nocolor="\033[0m"

echo
echo -e "${blue}*** Cleaning up all Gloo Mesh Core and sample application resources ***${nocolor}"
kubectl delete serviceaccount -n clients in-ambient
kubectl delete service -n clients in-ambient
kubectl delete deployment -n clients in-ambient
kubectl delete serviceaccount -n clients not-in-mesh
kubectl delete service -n clients not-in-mesh
kubectl delete deployment -n clients not-in-mesh
kubectl delete namespace clients
kubectl delete serviceaccount -n httpbin in-ambient
kubectl delete service -n httpbin in-ambient
kubectl delete deployment -n httpbin in-ambient
kubectl delete serviceaccount -n httpbin not-in-mesh
kubectl delete service -n httpbin not-in-mesh
kubectl delete deployment -n httpbin not-in-mesh
kubectl delete namespace httpbin
kubectl delete virtualservice -n bookinfo-frontends bookinfo
kubectl delete gateway.networking.istio.io -n bookinfo-frontends bookinfo
kubectl delete -n bookinfo-backends -f https://raw.githubusercontent.com/solo-io/workshops/refs/heads/master/gloo-mesh/core/2-6/ambient/data/steps/deploy-bookinfo/details-v1.yaml
kubectl delete -n bookinfo-backends -f https://raw.githubusercontent.com/solo-io/workshops/refs/heads/master/gloo-mesh/core/2-6/ambient/data/steps/deploy-bookinfo/ratings-v1.yaml
kubectl delete -n bookinfo-backends -f https://raw.githubusercontent.com/solo-io/workshops/refs/heads/master/gloo-mesh/core/2-6/ambient/data/steps/deploy-bookinfo/reviews-v1-v2.yaml
kubectl delete -n bookinfo-frontends -f https://raw.githubusercontent.com/solo-io/workshops/refs/heads/master/gloo-mesh/core/2-6/ambient/data/steps/deploy-bookinfo/productpage-v1.yaml
kubectl delete namespace bookinfo-backends
kubectl delete namespace bookinfo-frontends
unset INGRESS_GATEWAY
helm uninstall -n istio-gateways istio-ingressgateway
helm uninstall -n istio-system ztunnel
helm uninstall -n kube-system istio-cni
helm uninstall -n istio-system istiod
helm uninstall -n istio-system istio-base
kubectl get crd -o name | grep istio.io | xargs kubectl delete
kubectl delete namespace istio-system
kubectl delete service -n istio-gateways istio-ingressgateway
kubectl delete namespace istio-gateways
helm uninstall -n gloo-mesh gloo-platform
helm uninstall -n gloo-mesh gloo-platform-crds
kubectl delete namespace gloo-mesh

# Complete
echo
echo -e "${blue}*** Cleaned up Gloo Mesh Core and the sample applications ***${nocolor}"
