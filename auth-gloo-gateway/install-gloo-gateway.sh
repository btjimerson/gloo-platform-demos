#!/bin/bash

# Text colors
blue="\033[0;34m"
nocolor="\033[0m"

# Use the GLOO_GATEWAY_VERSION environment variable if set, otherwise prompt the user
if [[ -z "$GLOO_GATEWAY_VERSION" ]]; then
  echo -e ${blue}
  read -p "Enter your Gloo Gateway version [1.18.1]: " version
  echo -e ${nocolor}
fi
version=${version:-1.18.1}

# Use the GLOO_GATEWAY_LICENSE_KEY environment variable if set, otherwise prompt the user
if [[ -z "${GLOO_GATEWAY_LICENSE_KEY}" ]]; then
  echo -e ${blue}
  read -p "Enter your Gloo Gateway license key: " license
  echo -e ${nocolor}
else
  license=$GLOO_GATEWAY_LICENSE_KEY
fi

# Use the GLOO_GATEWAY_HOSTNAME environment variable if set, otherwise prompt the user
if [[ -z "$GLOO_GATEWAY_HOSTNAME" ]]; then
  echo -e ${blue}
  read -p "Enter the hostname to use for the gateway [www.example.com]: " hostname
  echo -e ${nocolor}
else
  hostname=$GLOO_GATEWAY_HOSTNAME
fi
hostname=${hostname:-www.example.com}    

echo
echo -e "${blue}Installing Kubernetes Gateway CRDs${nocolor}"
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.0/standard-install.yaml

echo
echo -e "${blue}Installing Gloo Gateway Enterprise${nocolor}"
helm repo add glooe https://storage.googleapis.com/gloo-ee-helm
helm repo update
helm upgrade --install -n gloo-system gloo glooe/gloo-ee \
--create-namespace \
--version $version \
--set-string license_key=$license \
-f -<<EOF
gloo:
  discovery:
    enabled: false
  gatewayProxies:
    gatewayProxy:
      disabled: true
  kubeGateway:
    enabled: true
  gloo:
    disableLeaderElection: true
gloo-fed:
  enabled: false
  glooFedApiserver:
    enable: false
grafana:
  defaultInstallationEnabled: false
observability:
  enabled: false
prometheus:
  enabled: false
EOF

echo
echo -e "${blue}Waiting for Gloo Gateway Enterprise${nocolor}"
kubectl wait deploy --all -n gloo-system --for=condition=Available --timeout=120s

echo
echo -e "${blue}Creating Kubernetes Gateway${nocolor}"
kubectl apply -f- <<EOF
kind: Gateway
apiVersion: gateway.networking.k8s.io/v1
metadata:
  name: http
  namespace: gloo-system
spec:
  gatewayClassName: gloo-gateway
  listeners:
  - protocol: HTTP
    port: 8080
    name: http
    allowedRoutes:
      namespaces:
        from: All
EOF
echo
echo -e "${blue}Created Kubernetes Gateway${nocolor}"
kubectl describe gateway -n gloo-system http


echo
echo -e "${blue}Installing the httpbin application${nocolor}"
kubectl create namespace httpbin
kubectl apply -n httpbin -f https://raw.githubusercontent.com/solo-io/gloo-mesh-use-cases/main/policy-demo/httpbin.yaml
echo
echo -e "${blue}Waiting for httpbin application${nocolor}"
kubectl wait deploy --all -n httpbin --for=condition=Available --timeout=120s

echo
echo -e "${blue}Creating the HTTPRoute for the httpbin application${nocolor}"
kubectl apply -f- <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: httpbin
  namespace: gloo-system
  labels:
    example: httpbin-route
spec:
  parentRefs:
    - name: http
      namespace: gloo-system
  hostnames:
    - $hostname
  rules:
    - backendRefs:
        - name: httpbin
          namespace: httpbin
          port: 8000
---
apiVersion: gateway.networking.k8s.io/v1beta1
kind: ReferenceGrant
metadata:
  name: httpbin-grant
  namespace: httpbin
spec:
  from:
  - group: gateway.networking.k8s.io
    kind: HTTPRoute
    namespace: gloo-system
  to:
  - group: ""
    kind: Service
EOF
echo
echo -e "${blue}Created the HTTPRoute for the httpbin application${nocolor}"
kubectl describe httproute -n gloo-system httpbin

# Let everything catch up
echo
echo -e "${blue}Waiting 5 seconds for everything to start${nocolor}"
sleep 5

# Prompt user to update DNS
gateway=$(kubectl get gateway -n gloo-system http -o jsonpath='{.status.addresses[0].value}')
echo -e ${blue}
echo -e "Create a DNS record (or local hosts file) that points ${hostname} to ${gateway}"
read -p "Press enter to continue once the record is created..."
echo -e ${nocolor}

echo
echo -e "${blue}Checking httpbin application with curl -ik http://${hostname}:8080/status/200${nocolor}"
curl -ik http://${hostname}:8080/status/200

echo
echo -e "${blue}Installed Gloo Gateway and the sample httpbin application${nocolor}"
