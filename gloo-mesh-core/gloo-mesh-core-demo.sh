#!/bin/bash

# Text colors
blue="\033[0;34m"
nocolor="\033[0m"

if [[ -z "$GLOO_GATEWAY_HOSTNAME" ]]; then
  echo -e ${blue}
  read -p "Enter the ingress gateway hostname [www.example.com]: " hostname
  echo -e ${nocolor}
else
  hostname=$GLOO_GATEWAY_HOSTNAME
fi
hostname=${hostname:-www.example.com}

echo
echo -e "${blue}Using gateway hostname ${hostname}${nocolor}"

echo
echo -e "${blue}*** Testing AuthorizationPolicies ***${nocolor}"

# Set up authorization policy to block all
echo -e ${blue}
read -p "Configuring L4 AuthorizationPolicy. Press enter to continue..."
echo -e ${nocolor}
kubectl apply -f - <<EOF
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: policy
  namespace: bookinfo-backends
spec:
  action: ALLOW
  rules:
  - from:
    - source:
        principals:
        - "cluster1/ns/bookinfo-backends/sa/*"
EOF
echo
echo -e "${blue}Applied L4 AuthorizationPolicy${nocolor}"
kubectl describe authorizationpolicy -n bookinfo-backends policy
echo
echo -e "${blue}Open http://${hostname}/productpage. You should see the backend services not available${nocolor}"

# Set up authorization policy to allow bookinfo-frontends
echo -e ${blue}
read -p "Reconfiguring L4 AuthorizationPolicy to allow bookinfo-frontends. Press enter to continue..."
echo -e ${nocolor}
kubectl apply -f - <<EOF
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: policy
  namespace: bookinfo-backends
spec:
  action: ALLOW
  rules:
  - from:
    - source:
        principals:
        - "cluster1/ns/bookinfo-frontends/sa/bookinfo-productpage"
        - "cluster1/ns/bookinfo-backends/sa/*"
EOF
echo
echo -e "${blue}Reconfigured L4 AuthorizationPolicy${nocolor}"
kubectl describe authorizationpolicy -n bookinfo-backends policy
echo
echo -e "${blue}Open http://${hostname}/productpage. It should work now${nocolor}"

# Set up L7 authorization policy to allow bookinfo-frontends
echo -e ${blue}
read -p "Reconfiguring AuthorizationPolicy with L7 rule. Press enter to continue..."
echo -e ${nocolor}
kubectl apply -f - <<EOF
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: policy
  namespace: bookinfo-backends
spec:
  action: ALLOW
  rules:
  - from:
    - source:
        principals:
        - "cluster1/ns/bookinfo-frontends/sa/bookinfo-productpage"
        - "cluster1/ns/bookinfo-backends/sa/*"
    to:
    - operation:
        methods: ["GET"]
EOF
echo
echo -e "${blue}Reconfigured AuthorizationPolicy for L7${nocolor}"
kubectl describe authorizationpolicy -n bookinfo-backends policy
echo
echo -e "${blue}Open http://${hostname}/productpage. There's no waypoint proxy for L7, so it should fail${nocolor}"

# Install waypoint proxy
echo -e ${blue}
read -p "Installing waypoint proxy. Press enter to continue..."
echo -e ${nocolor}
kubectl apply -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: waypoint
  namespace: bookinfo-backends
spec:
  gatewayClassName: istio-waypoint
  listeners:
  - name: mesh
    allowedRoutes:
      namespaces:
        from: Same
    port: 15008
    protocol: HBONE
EOF
kubectl -n bookinfo-backends label ns bookinfo-backends istio.io/use-waypoint=waypoint
kubectl apply -f - <<EOF
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: policy
  namespace: bookinfo-backends
spec:
  targetRefs:
  - kind: Gateway
    group: gateway.networking.k8s.io
    name: waypoint
  action: ALLOW
  rules:
  - from:
    - source:
        principals:
        - "cluster1/ns/bookinfo-frontends/sa/bookinfo-productpage"
        - "cluster1/ns/bookinfo-backends/sa/*"
    to:
    - operation:
        methods: ["GET"]
EOF
echo
echo -e "${blue}Installed waypoint proxy${nocolor}"
kubectl describe gateway -n bookinfo-backends waypoint
kubectl describe authorizationpolicy -n bookinfo-backends policy
kubectl get namespace bookinfo-backends -L istio.io/use-waypoint
echo
echo -e "${blue}Open http://${hostname}/productpage. It should work with the waypoint proxy${nocolor}"

echo -e ${blue}
read -p "Removing resources. Press enter to continue..."
echo -e ${nocolor}
kubectl delete authorizationpolicy -n bookinfo-backends policy
kubectl delete gateway -n bookinfo-backends waypoint
echo -e "${blue}Removed waypoint and authorization policy${nocolor}"

# Observability
echo 
echo -e "${blue}*** Demonstrate L4 and L7 observability metrics ***${nocolor}"
echo -e ${blue}
read -p "Generating traffic for productpage. Press enter to continue..."
echo -e ${nocolor}
for i in {1..20}; do  curl -k "http://${hostname}/productpage" -I; done

echo -e ${blue}
echo "A number of requests were sent to the product page."
read -p "Let's look at some L4 metrics. Press enter to continue..."
echo -e ${nocolor}
node=$(kubectl -n bookinfo-frontends get pods -l app=productpage -o jsonpath='{.items[0].spec.nodeName}')
pod=$(kubectl -n istio-system get pods -l app=ztunnel -o json | jq -r ".items[] | select(.spec.nodeName==\"${node}\") | .metadata.name" | tail -1)
kubectl debug -n istio-system "$pod" -it --profile=general --image=curlimages/curl  -- curl http://localhost:15020/metrics | grep istio_tcp_sent_bytes_total

echo -e ${blue}
read -p "Let's look at L7 metrics, even with no waypoint. Press enter to continue..."
echo -e ${nocolor}
kubectl debug -n istio-system "$pod" -it --profile=general --image=curlimages/curl  -- curl http://localhost:15020/metrics | grep istio_request_

# Dashboard
echo -e ${blue}
echo "In a separate shell, run meshctl dashboard."
read -p "View the graph under 'Observability -> Graph'. Press enter to continue..."
echo
echo "Click on 'Dashboard -> Warnings', and view the Insights. View the details for 'Gateway host is not namespaced'"
read -p "We can suppress Insight BP0002. Press enter to continue..."
echo -e ${nocolor}
kubectl apply -f - <<EOF
apiVersion: admin.gloo.solo.io/v2alpha1
kind: InsightsConfig
metadata:
  name: insights-config
  namespace: gloo-mesh
spec:
  disabledInsights:
    - BP0002
EOF
kubectl describe insightsconfig -n gloo-mesh insights-config
echo -e ${blue}
read -p "The warning should be gone in the dashboard now. Press enter to continue..."
echo -e ${nocolor}

echo -e ${blue}
echo "Click on 'Dashboard -> Warnings', and view the Insights. View the details for 'The exportTo field in this VirtualService'"
read -p "We can update the VirtualService to fix this. Press enter to continue..."
echo -e ${nocolor}
kubectl apply -f - <<EOF
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: bookinfo
  namespace: bookinfo-frontends
spec:
  hosts:
  - ${hostname}
  exportTo:
  - istio-gateways
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
echo -e ${blue}
read -p "The warning should be gone in the dashboard now. Press enter to continue..."
echo -e ${nocolor}

# Controlled egress
echo
echo -e "${blue}*** Controlled Egress ***${nocolor}"
echo -e ${blue}
read -p "Creating a NetworkPolicy that restricts all egress traffic from clients namespace. Press enter to continue..."
echo -e ${nocolor}
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: restricted-namespace-policy
  namespace: clients
spec:
  podSelector: {}  # This applies to all pods in the namespace
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - {}  # Allow all ingress traffic
  egress:
  - to:
    - namespaceSelector: {}  # Allow egress to all namespaces
    - podSelector: {}  # Allow egress to all pods within the cluster
EOF
kubectl describe networkpolicy -n clients restricted-namespace-policy

echo -e ${blue}
read -p "Verify egress is not allowed. Press enter to continue..."
echo -e ${nocolor}
echo -e "${blue}>> kubectl -n clients exec deploy/in-ambient -- curl -I httpbin.org/get${nocolor}"
kubectl -n clients exec deploy/in-ambient -- curl -I httpbin.org/get

echo -e ${blue}
read -p "Creating a dedicted egress namespace with a waypoint proxy. Press enter to continue..."
echo -e ${nocolor}
kubectl apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  labels:
    istio.io/dataplane-mode: ambient
    istio.io/use-waypoint: waypoint
  name: egress
---
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: waypoint
  namespace: egress
spec:
  gatewayClassName: istio-waypoint
  listeners:
  - name: mesh
    port: 15008
    protocol: HBONE
    allowedRoutes:
      namespaces:
        from: All
EOF
kubectl get namespace egress -L istio.io/dataplane-mode -L istio.io/use-waypoint
kubectl describe gateway -n egress waypoint

echo -e ${blue}
read -p "Creating a ServiceEntry for egress to httpbin.org. Press enter to continue..."
echo -e ${nocolor}
kubectl apply -f - <<EOF
apiVersion: networking.istio.io/v1
kind: ServiceEntry
metadata:
  annotations:
  labels:
    istio.io/use-waypoint: waypoint
  name: httpbin.org
  namespace: egress
spec:
  hosts:
  - httpbin.org
  ports:
  - name: http
    number: 80
    protocol: HTTP
  resolution: DNS
EOF
kubectl describe serviceentry -n egress httpbin.org

echo -e ${blue}
read -p "Verify egress to httpbin.org is allowed now. Press enter to continue..."
echo -e ${nocolor}
echo -e "${blue}>> kubectl -n clients exec deploy/in-ambient -- curl -sI httpbin.org/get${nocolor}"
kubectl -n clients exec deploy/in-ambient -- curl -sI httpbin.org/get

echo -e ${blue}
read -p "Adding a custom header to outbound requests to httpbin.org. Press enter to continue..."
echo -e ${nocolor}
kubectl apply -f - <<EOF
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: httpbin
  namespace: egress
spec:
  hosts:
  - httpbin.org
  http:
  - route:
    - destination:
        host: httpbin.org
    headers:
      request:
        add:
          current-state: gloo-mesh-rules
EOF
kubectl describe virtualservice -n egress httpbin

echo -e ${blue}
read -p "Verify the custom header is added. Press enter to continue..."
echo -e ${nocolor}
echo -e "${blue}>> kubectl -n clients exec deploy/in-ambient -- curl -s httpbin.org/get${nocolor}"
kubectl -n clients exec deploy/in-ambient -- curl -s httpbin.org/get

echo -e ${blue}
read -p "Enforcing TLS for egress traffic. Press enter to continue..."
echo -e ${nocolor}
kubectl apply -f - <<EOF
apiVersion: networking.istio.io/v1
kind: ServiceEntry
metadata:
  annotations:
  labels:
    istio.io/use-waypoint: waypoint
  name: httpbin.org
  namespace: egress
spec:
  hosts:
  - httpbin.org
  ports:
  - number: 80
    name: http
    protocol: HTTP
    targetPort: 443 # New: send traffic originally for port 80 to port 443
  resolution: DNS
---
apiVersion: networking.istio.io/v1
kind: DestinationRule
metadata:
  name: httpbin.org-tls
  namespace: egress
spec:
  host: httpbin.org
  trafficPolicy:
    tls:
      mode: SIMPLE
EOF
kubectl describe serviceentry -n egress httpbin.org
kubectl describe destinationrule -n egress httpbin.org-tls

echo -e ${blue}
read -p "Verify egress traffic is encrypted (check the url header). Press enter to continue..."
echo -e ${nocolor}
echo -e "${blue}>> kubectl -n clients exec deploy/in-ambient -- curl -s httpbin.org/get${nocolor}"
kubectl -n clients exec deploy/in-ambient -- curl -s httpbin.org/get

echo -e ${blue}
read -p "Applying an AuthorizationPolicy to only allow GET to httpbin.org. Press enter to continue..."
echo -e ${nocolor}
kubectl apply -f - <<EOF
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: httpbin
  namespace: egress
spec:
  targetRefs:
  - kind: Gateway
    name: waypoint
    group: gateway.networking.k8s.io
  action: ALLOW
  rules:
  - to:
    - operation:
        hosts: ["httpbin.org"]
        methods: ["GET"]
        paths: ["/get"]
EOF
kubectl describe authorizationpolicy -n egress httpbin

echo -e ${blue}
read -p "Verify that only GET is allowed. Press enter to continue..."
echo -e ${nocolor}
echo -e "${blue}>> kubectl -n clients exec deploy/in-ambient -- curl -s -I httpbin.org/post${nocolor}"
kubectl -n clients exec deploy/in-ambient -- curl -s -I httpbin.org/post

# Cleanup demo resources
echo -e ${blue}
read -p "Cleanup demo resources. Press enter to continue..."
echo -e ${nocolor}
kubectl delete authorizationpolicy -n egress httpbin
kubectl delete destinationrule -n egress httpbin.org-tls
kubectl delete serviceentry -n egress httpbin.org
kubectl delete virtualservice -n egress httpbin
kubectl delete gateway -n egress waypoint
kubectl delete namespace egress
kubectl delete networkpolicy -n clients restricted-namespace-policy
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
kubectl delete insightsconfig -n gloo-mesh insights-config

