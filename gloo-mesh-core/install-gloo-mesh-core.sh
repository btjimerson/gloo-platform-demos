#!/bin/bash

# Text colors
blue="\033[0;34m"
nocolor="\033[0m"

# Use the GLOO_LICENSE_KEY environment variable if set, otherwise prompt the user
if [[ -z "$GLOO_MESH_LICENSE_KEY" ]]; then
  echo -e ${blue}
  read -p "Enter your Gloo Mesh Core license key: " license
  echo -e ${nocolor}
else
  license=$GLOO_MESH_LICENSE_KEY
fi

# Use the GLOO_MESH_GATEWAY_HOSTNAME environment variable if set, otherwise prompt the user
if [[ -z "$GLOO_MESH_GATEWAY_HOSTNAME" ]]; then
  echo -e ${blue}
  read -p "Enter the hostname to use for the gateway [www.example.com]: " hostname
  echo -e ${nocolor}
else
  hostname=$GLOO_MESH_GATEWAY_HOSTNAME
fi
hostname=${hostname:-www.example.com}

# Use the GLOO_MESH_CLUSTER_NAME environment variable if set, otherwise prompt the user
if [[ -z "$GLOO_MESH_CLUSTER_NAME" ]]; then
  echo -e ${blue}
  read -p "Enter the cluster name [cluster1]: " cluster_name
  echo -e ${nocolor}
else
  cluster_name=$GLOO_MESH_CLUSTER_NAME
fi
cluster_name=${cluster_name:-cluster1}

# Use the GLOO_MESH_VERSION environment variable if set, otherwise prompt the user
if [[ -z "$GLOO_MESH_VERSION" ]]; then
  echo -e ${blue}
  read -p "Enter the version of Gloo Mesh [v2.6.6]: " version
  echo -e ${nocolor}
else
  version=${GLOO_MESH_VERSION}
fi
version=${version:-v2.6.6}

# Use the GLOO_MESH_ISTIO_HUB environment variable if set, otherwise prompt the user
if [[ -z "$GLOO_MESH_ISTIO_HUB" ]]; then
  echo -e ${blue}
  read -p "Enter the Gloo Mesh Istio hub: " istio_hub
  echo -e ${nocolor}
else
  istio_hub=$GLOO_MESH_ISTIO_HUB
fi

# Use the GLOO_MESH_ISTIO_VERSION environment variable if set, otherwise prompt the user
if [[ -z "$GLOO_MESH_ISTIO_VERSION" ]]; then
  echo -e ${blue}
  read -p "Enter the Gloo Mesh Istio version [1.24.1]: " istio_version
  echo -e ${nocolor}
else
  istio_version=$GLOO_MESH_ISTIO_VERSION
fi
istio_version=${istio_version:-1.24.1}

# Use the GLOO_MESH_ISTIO_IMAGE environment variable if set, otherwise prompt the user
if [[ -z "$GLOO_MESH_ISTIO_IMAGE" ]]; then
  echo -e ${blue}
  read -p "Enter the Gloo Mesh Istio image [1.24.1-solo]: " istio_image
  echo -e ${nocolor}
else
  istio_image=$GLOO_MESH_ISTIO_IMAGE
fi
istio_image=${istio_image:-1.24.1-solo}

# Gloo Mesh management plane
echo
echo -e "${blue}Installing Gloo Mesh Management Plane${nocolor}"
kubectl create namespace gloo-mesh
helm upgrade --install gloo-platform-crds gloo-platform-crds \
  --repo https://storage.googleapis.com/gloo-platform/helm-charts \
  --namespace gloo-mesh \
  --set featureGates.insightsConfiguration=true \
  --version $version
helm upgrade --install gloo-platform gloo-platform \
  --repo https://storage.googleapis.com/gloo-platform/helm-charts \
  --namespace gloo-mesh \
  --set common.cluster=$cluster_name \
  --version $version \
  -f -<<EOF
licensing:
  glooTrialLicenseKey: ${license}
glooAgent:
  enabled: true
  runAsSidecar: true
  relay:
    serverAddress: gloo-mesh-mgmt-server.gloo-mesh:9900
glooAnalyzer:
  enabled: true
glooMgmtServer:
  enabled: true
  registerCluster: true
  policyApis:
    enabled: false
glooInsightsEngine:
  enabled: true
glooUi:
  enabled: true
prometheus:
  enabled: true
redis:
  deployment:
    enabled: true
telemetryCollector:
  enabled: true
installEnterpriseCrds: false
featureGates:
  istioLifecycleAgent: true
EOF
kubectl wait deploy --all -n gloo-mesh --for=condition=Available--timeout=120s

# Meshctl check
echo
echo -e "${blue}Checking mesh status with meshctl check${nocolor}"
meshctl check

# Ingress gateway service
echo
echo -e "${blue}Creating a service for the Ingress Gateway${nocolor}"
kubectl create namespace istio-gateways
kubectl apply -f - <<EOF
apiVersion: v1
kind: Service
metadata:
  labels:
    app: istio-ingressgateway
    istio: ingressgateway
  name: istio-ingressgateway
  namespace: istio-gateways
spec:
  ports:
  - name: status-port
    port: 15021
    targetPort: 15021
  - name: http2
    port: 80
    protocol: TCP
    targetPort: 80
  - name: https
    port: 443
    protocol: TCP
    targetPort: 443
  selector:
    app: istio-ingressgateway
    istio: ingressgateway
  type: LoadBalancer
EOF

# Gateway CRDs
echo
echo -e "${blue}Installing Kubernetes Gateway CRDs${nocolor}"
kubectl get crd gateways.gateway.networking.k8s.io &> /dev/null || \
  { kubectl kustomize "github.com/kubernetes-sigs/gateway-api/config/crd?ref=v1.1.0" | kubectl apply -f -; }

# Istio control plane components
echo
echo -e "${blue}Installing istio base, istiod, istio cni, and ztunnel${nocolor}"
helm repo add istio https://istio-release.storage.googleapis.com/charts
helm repo update

helm upgrade --install istio-base istio/base \
--namespace istio-system \
--version $istio_version \
--create-namespace \
-f - <<EOF
defaultRevision: ""
profile: ambient
EOF
helm upgrade --install istiod istio/istiod \
--namespace istio-system \
--version $istio_version \
--create-namespace \
-f - <<EOF
global:
  hub: $istio_hub
  proxy:
    clusterDomain: cluster.local
  tag: $istio_image
  multiCluster:
    clusterName: $cluster_name
profile: ambient
istio_cni:
  enabled: true
meshConfig:
  accessLogFile: /dev/stdout
  defaultConfig:
    proxyMetadata:
      ISTIO_META_DNS_AUTO_ALLOCATE: "true"
      ISTIO_META_DNS_CAPTURE: "true"
  trustDomain: $cluster_name
pilot:
  enabled: true
  env:
    PILOT_ENABLE_IP_AUTOALLOCATE: "true"
    PILOT_ENABLE_K8S_SELECT_WORKLOAD_ENTRIES: "false"
    PILOT_SKIP_VALIDATE_TRUST_DOMAIN: "true"
EOF
helm upgrade --install istio-cni istio/cni \
--namespace kube-system \
--version $istio_version \
--create-namespace \
-f - <<EOF
global:
  hub: $istio_hub
  proxy: $istio_image
profile: ambient
cni:
  $CNI_CONFIG
  ambient:
    dnsCapture: true
  excludeNamespaces:
  - istio-system
  - kube-system
EOF
helm upgrade --install ztunnel istio/ztunnel \
--namespace istio-system \
--version $istio_version \
--create-namespace \
-f - <<EOF
configValidation: true
enabled: true
env:
  L7_ENABLED: "true"
hub: $istio_hub
istioNamespace: istio-system
multiCluster:
  clusterName: $cluster_name
namespace: istio-system
profile: ambient
proxy:
  clusterDomain: cluster.local
tag: $istio_image
terminationGracePeriodSeconds: 29
variant: distroless
EOF
helm upgrade --install istio-ingressgateway istio/gateway \
--namespace istio-gateways \
--version $istio_version \
--create-namespace \
-f - <<EOF
autoscaling:
  enabled: false
profile: ambient
imagePullPolicy: IfNotPresent
labels:
  app: istio-ingressgateway
  istio: ingressgateway
service:
  type: None
EOF

# Prompt user to update DNS
ingress=$(kubectl -n istio-gateways get svc -l istio=ingressgateway -o jsonpath='{.items[0].status.loadBalancer.ingress[0].*}')
echo -e ${blue}
echo -e "Create a DNS record (or local hosts file) that points ${hostname} to ${ingress}"
read -p "Press enter to continue once the record is created..."
echo -e ${nocolor}

# Bookinfo
echo
echo -e "${blue}Installing bookinfo application in the mesh${nocolor}"
kubectl create namespace bookinfo-frontends
kubectl create namespace bookinfo-backends
kubectl label namespace bookinfo-frontends istio.io/dataplane-mode=ambient
kubectl label namespace bookinfo-backends istio.io/dataplane-mode=ambient
kubectl -n bookinfo-frontends apply -f https://raw.githubusercontent.com/solo-io/workshops/refs/heads/master/gloo-mesh/core/2-6/ambient/data/steps/deploy-bookinfo/productpage-v1.yaml
kubectl -n bookinfo-backends apply \
  -f https://raw.githubusercontent.com/solo-io/workshops/refs/heads/master/gloo-mesh/core/2-6/ambient/data/steps/deploy-bookinfo/details-v1.yaml \
  -f https://raw.githubusercontent.com/solo-io/workshops/refs/heads/master/gloo-mesh/core/2-6/ambient/data/steps/deploy-bookinfo/ratings-v1.yaml \
  -f https://raw.githubusercontent.com/solo-io/workshops/refs/heads/master/gloo-mesh/core/2-6/ambient/data/steps/deploy-bookinfo/reviews-v1-v2.yaml
kubectl -n bookinfo-backends set env deploy/reviews-v1 cluster_name=${cluster_name}
kubectl -n bookinfo-backends set env deploy/reviews-v2 cluster_name=${cluster_name}

kubectl get pods -n bookinfo-frontends
kubectl get pods -n bookinfo-backends

# Httpbin
echo
echo -e "${blue}Installing httpbin application, not in the mesh${nocolor}"
kubectl create namespace httpbin
kubectl label namespace httpbin istio.io/dataplane-mode=ambient
kubectl apply -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: not-in-mesh
  namespace: httpbin
---
apiVersion: v1
kind: Service
metadata:
  name: not-in-mesh
  namespace: httpbin
  labels:
    app: not-in-mesh
    service: not-in-mesh
spec:
  ports:
  - name: http
    port: 8000
    targetPort: 80
  selector:
    app: not-in-mesh
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: not-in-mesh
  namespace: httpbin
spec:
  replicas: 1
  selector:
    matchLabels:
      app: not-in-mesh
      version: v1
  template:
    metadata:
      labels:
        app: not-in-mesh
        version: v1
        istio.io/dataplane-mode: none
    spec:
      serviceAccountName: not-in-mesh
      containers:
      - image: docker.io/kennethreitz/httpbin
        imagePullPolicy: IfNotPresent
        name: not-in-mesh
        ports:
        - name: http
          containerPort: 80
        livenessProbe:
          httpGet:
            path: /status/200
            port: http
        readinessProbe:
          httpGet:
            path: /status/200
            port: http

EOF
kubectl describe deployment -n httpbin not-in-mesh

echo
echo -e "${blue}Installing httpbin application, joined in the mesh${nocolor}"
kubectl apply -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: in-ambient
  namespace: httpbin
---
apiVersion: v1
kind: Service
metadata:
  name: in-ambient
  namespace: httpbin
  labels:
    app: in-ambient
    service: in-ambient
spec:
  ports:
  - name: http
    port: 8000
    targetPort: 80
  selector:
    app: in-ambient
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: in-ambient
  namespace: httpbin
spec:
  replicas: 1
  selector:
    matchLabels:
      app: in-ambient
      version: v1
  template:
    metadata:
      labels:
        app: in-ambient
        version: v1
        istio.io/dataplane-mode: ambient
    spec:
      serviceAccountName: in-ambient
      containers:
      - image: docker.io/kennethreitz/httpbin
        imagePullPolicy: IfNotPresent
        name: in-ambient
        ports:
        - name: http
          containerPort: 80
        livenessProbe:
          httpGet:
            path: /status/200
            port: http
        readinessProbe:
          httpGet:
            path: /status/200
            port: http
EOF
kubectl describe deployment -n httpbin in-ambient

# Service clients for testing
echo
echo -e "${blue}Creating service clients for testing${nocolor}"
kubectl create namespace clients

kubectl apply -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: not-in-mesh
  namespace: clients
---
apiVersion: v1
kind: Service
metadata:
  name: not-in-mesh
  namespace: clients
  labels:
    app: not-in-mesh
    service: not-in-mesh
spec:
  ports:
  - name: http
    port: 8000
    targetPort: 80
  selector:
    app: not-in-mesh
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: not-in-mesh
  namespace: clients
spec:
  replicas: 1
  selector:
    matchLabels:
      app: not-in-mesh
      version: v1
  template:
    metadata:
      labels:
        app: not-in-mesh
        version: v1
        istio.io/dataplane-mode: none
    spec:
      serviceAccountName: not-in-mesh
      containers:
      - image: nicolaka/netshoot:latest
        imagePullPolicy: IfNotPresent
        name: netshoot
        command: ["/bin/bash"]
        args: ["-c", "while true; do ping localhost; sleep 60;done"]
EOF
kubectl apply -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: in-ambient
  namespace: clients
---
apiVersion: v1
kind: Service
metadata:
  name: in-ambient
  namespace: clients
  labels:
    app: in-ambient
    service: in-ambient
spec:
  ports:
  - name: http
    port: 8000
    targetPort: 80
  selector:
    app: in-ambient
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: in-ambient
  namespace: clients
spec:
  replicas: 1
  selector:
    matchLabels:
      app: in-ambient
      version: v1
  template:
    metadata:
      labels:
        app: in-ambient
        version: v1
        istio.io/dataplane-mode: ambient
    spec:
      serviceAccountName: in-ambient
      containers:
      - image: nicolaka/netshoot:latest
        imagePullPolicy: IfNotPresent
        name: netshoot
        command: ["/bin/bash"]
        args: ["-c", "while true; do ping localhost; sleep 60;done"]
EOF
kubectl describe deployment -n clients not-in-mesh
kubectl describe deployment -n clients in-ambient

# Expose product page through ingress
echo
echo -e "${blue}Creating gateway for product page${nocolor}"
kubectl apply -f - <<EOF
apiVersion: networking.istio.io/v1beta1
kind: Gateway
metadata:
  name: bookinfo
  namespace: bookinfo-frontends
spec:
  selector:
    istio: ingressgateway
  servers:
  - port:
      number: 80
      name: http
      protocol: HTTP
    hosts:
    - ${hostname}
EOF
kubectl describe gateway.networking.istio.io -n bookinfo-frontends bookinfo

echo
echo -e "${blue}Creating virtual service for product page${nocolor}"
kubectl apply -f - <<EOF
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: bookinfo
  namespace: bookinfo-frontends
spec:
  hosts:
  - ${hostname}
  gateways:
  - bookinfo
  http:
  - match:
    - uri:
        prefix: /productpage
    - uri:
        prefix: /static
    route:
    - destination:
        port:
          number: 9080
        host: productpage
EOF
kubectl describe virtualservice -n bookinfo-frontends bookinfo

# Complete
echo
echo -e "${blue}Installed Gloo Mesh Core and the sample applications${nocolor}"
echo -e "${blue}You can access the product page service at http://${hostname}/productpage${nocolor}"