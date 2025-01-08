#!/bin/bash

# Text colors
blue="\033[0;34m"
nocolor="\033[0m"

# JWTs
alice_token="eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiAic29sby5pbyIsIm9yZyI6ICJzb2xvLmlvIiwic3ViIjogImFsaWNlIiwidGVhbSI6ICJkZXYifQ.qSCARI8Xf-7D5hWdHT71Rov-4zQGMjUz9HV04OctS6oWpTrmVBKb0JcMiiDf2rpI5NQXXk5SdLTdokC-_VXXE67EwAKMYwa4qaSFcrJIfwkOb_gSV3KqMYYYKQCCxYeHOuGaR4xdqFdMAoeGFTa7BmKWq2ZLY6c3-uWPFuW2MX1Y6SCFJXAI803FMInZcTvvjRka3WejlI-CHUw_2ZESXUf6MA0shY9aoICPjI_TrukUVoxRzu6oc0JjvcHJuqRxY-MoGberBYqWezIFlOGjWnfqvAEEp0VI-g-dMNZ7_eBFathSKD3Em7gt33T3OIDKuqkZ8i4W7WzhMIhNlSFWlA"
bob_token="eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiAic29sby5pbyIsIm9yZyI6ICJzb2xvLmlvIiwic3ViIjogImJvYiIsInRlYW0iOiAib3BzIn0.M681liG4wW1DYmVwyjvAUIr4yJqZSaqODoWDSGd3egt5tuWN9ZBZLHh5odU-Y5EK8Nfq3fVzLSJtizVUWXtvMNAUUpzlfGHd99m6xdvZN9tkBWHXKTnT1vGnJ0Z9TRAlNvenSd2FZDChz7k2HW0E8IBvxMTtgPq-pMBEum2zWZIW1Bs9d8hWbEysYng7C-LdrBTj82dTps-FdPLNofigELozm8S2GQoZ5_2e42cBgngtYIcHpGJKPckPm_ZdMIujdN-5PxhLy91UX7dEI6B-O7tQyWxXV9quMEoAic67T1Np_b6ApnSXPkDspDZwUKhM6_ToiQhZqC2SwA4il9h62Q"

alice_payload_decoded=$(echo $alice_token | tr "." " " | awk '{print $2}' | base64 -d)
bob_payload_decoded=$(echo $bob_token | tr "." " " | awk '{print $2}' | base64 -d)

# Use the GLOO_GATEWAY_HOSTNAME environment variable if set, otherwise prompt the user
if [[ -z "$GLOO_GATEWAY_HOSTNAME" ]]; then
  echo -e ${blue}
  read -p "Enter the hostname to use for the gateway [www.example.com]: " hostname
  echo -e ${nocolor}
else
  export hostname=$GLOO_GATEWAY_HOSTNAME
fi
hostname=${hostname:-www.example.com}

echo
echo -e "${blue}Using gateway hostname ${hostname}${nocolor}"
echo -e "${blue}Alice's token payload = ${alice_payload_decoded}${nocolor}"
echo -e "${blue}Bob's token payload = ${bob_payload_decoded}${nocolor}"

# Set up JWT authentication
echo -e ${blue}
read -p "Configuring access control to restrict access to JWTs. Press enter to continue..."
echo -e ${nocolor}


kubectl apply -f- <<EOF
apiVersion: gateway.solo.io/v1
kind: VirtualHostOption
metadata:
  name: jwt-provider
  namespace: gloo-system
spec:
  targetRefs:
  - group: gateway.networking.k8s.io
    kind: Gateway
    name: http
  options:
    jwt:
      providers:
        selfminted:
          issuer: solo.io
          claimsToHeaders:
          - claim: "sub"
            header: "jwt-subject"
          - claim: "org"
            header: "jwt-organization"
          - claim: "team"
            header: "jwt-team"
          jwks:
            local:
              key: |
                -----BEGIN PUBLIC KEY-----
                MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAzgEPg3jVs5HPICKB2fz2
                wUkfMIMD7GYaBhrHAQlMccneU0PWkPOctJyziMPwZTdSPIKQpZhkIa+z1FP29bbn
                hpsW0GgTLowraelvXop06IqFbHL6vHL4rewyBOV9mbQJ2NbJDYXUpk3vXgLW2mpb
                T5LAs3HzMtQmp6RMFgBjRUQmZUQI99Vx5OjnoZOEMStOzgrdhacCqvfbCrVSaYF4
                X15Hfh4A9TKQSrQhHrScWHRDYWhqVjX0dP/h7yMKrA65cjwyoPiDcP8+9PJkjU7t
                hhmly+OT46l/a/fyeqxWBe0N8SKBPyhBPbOYzDY0fsYLVl6IBGISwp50ah2ICTVS
                GQIDAQAB
                -----END PUBLIC KEY-----     
    headerManipulation:
      requestHeadersToAdd:
      - header:
          key: MyHeader
          value: "my-customer-header"
EOF
echo
echo -e "${blue}Applied VirtualHostOption${nocolor}"
kubectl describe virtualhostoption -n gloo-system jwt-provider

# Test the JWT authentication / rejection
echo -e ${blue}
read -p "Test the gateway without JWT to verify access control. Press enter to continue..."
echo -e ${nocolor}
echo -e "${blue}>> curl -ik http://${hostname}:8080/headers${nocolor}"
curl -ik http://${hostname}:8080/headers
echo 
echo -e "${blue}The request should have returned a 401 HTTP response code, indicating that JWT is missing.${nocolor}"
echo -e "${blue}Access control configured successfully.${nocolor}"

# Test that requests with JWT works
echo -e ${blue}
read -p "Test Alice's JWT. Press enter to continue..."
echo -e ${nocolor}
echo -e "${blue}>> curl -ik http://${hostname}:8080/headers -H 'Authorization: Bearer $alice_token'${nocolor}"
curl -ik http://${hostname}:8080/headers -H "Authorization: Bearer $alice_token"
echo
echo -e "${blue}Alice's request should have succeeded with a 200 HTTP response code.${nocolor}"

echo -e ${blue}
read -p "Test Bob's JWT. Press enter to continue..."
echo -e ${nocolor}
echo -e "${blue}>> curl -ik http://${hostname}:8080/headers -H 'Authorization: Bearer $bob_token'${nocolor}"
curl -ik http://${hostname}:8080/headers -H "Authorization: Bearer $bob_token"
echo
echo -e "${blue}Bob's request should have succeeded with a 200 HTTP response code.${nocolor}"

# Apply RBAC
echo -e ${blue}
read -p "Configure RBAC to enforce team-based access. Press enter to continue..."
echo -e ${nocolor}
kubectl apply -f- <<EOF
apiVersion: gateway.solo.io/v1
kind: RouteOption
metadata:
  name: httpbin-rbac-route-option
  namespace: gloo-system
spec:
  targetRefs:
  - group: gateway.networking.k8s.io
    kind: HTTPRoute
    name: httpbin
    namespace: gloo-system
  options:
    rbac:
      policies:
        viewer:
          nestedClaimDelimiter: .
          principals:
          - jwtPrincipal:
              claims:
                "org": "solo.io"
                "team": "dev"
EOF
echo
echo -e "${blue}Applied RouteOption${nocolor}"
kubectl describe routeoption -n gloo-system httpbin-rbac-route-option

# Test the RBAC RouteOption
echo -e ${blue}
read -p "Test Alice's JWT. Press enter to continue..."
echo -e ${nocolor}
echo -e "${blue}curl -ik http://${hostname}:8080/headers -H 'Authorization: Bearer $alice_token'${nocolor}"
curl -ik http://${hostname}:8080/headers -H "Authorization: Bearer $alice_token"
echo
echo -e "${blue}Alice's request should have succeeded because she belongs to the dev team.${nocolor}"

echo -e ${blue}
read -p "Test Bob's JWT. Press enter to continue..."
echo -e ${nocolor}
echo -e "${blue}>> curl -ik http://${hostname}:8080/headers -H 'Authorization: Bearer $bob_token'${nocolor}" 
curl -ik http://${hostname}:8080/headers -H "Authorization: Bearer $bob_token"
echo
echo -e "${blue}Bob's request should have failed because he is not part of the dev team.${nocolor}"


# Cleanup JWT resources
echo -e ${blue}
read -p "Cleanup demo JWT resources. Press enter to continue..."
echo -e ${nocolor}
kubectl delete routeoption -n gloo-system httpbin-rbac-route-option
kubectl delete virtualhostoption -n gloo-system jwt-provider

echo -e ${blue}
read -p "Creating the OPA rego policy. Press enter to continue..."
echo -e ${nocolor}

# Create rego rule
cat <<EOF > policy.rego
package test

default allow = false
allow {
    startswith(input.http_request.path, "/anything")
    input.http_request.method == "GET"
}
allow {
    input.http_request.path == "/status/200"
    any({input.http_request.method == "GET",
        input.http_request.method == "DELETE"
    })
}
EOF
kubectl -n httpbin create configmap allow-get-users --from-file=policy.rego
rm -rf policy.rego
echo
echo -e "${blue}Applied rego ConfigMap${nocolor}"
kubectl describe configmap -n httpbin allow-get-users


# Create OPA AuthConfig and associated resources
echo -e ${blue}
read -p "Creating the OPA AuthConfig and RouteOption. Press enter to continue..."
echo -e ${nocolor}
kubectl apply -f- <<EOF
apiVersion: enterprise.gloo.solo.io/v1
kind: AuthConfig
metadata:
  name: opa-auth
  namespace: httpbin
spec:
  configs:
  - opaAuth:
      modules:
      - name: allow-get-users
        namespace: httpbin
      query: "data.test.allow == true"
---
apiVersion: gateway.solo.io/v1
kind: RouteOption
metadata:
  name: opa-auth
  namespace: gloo-system
spec:
  options:
    extauth:
      configRef:
        name: opa-auth
        namespace: httpbin
EOF
echo
echo -e "${blue}Applied the AuthConfig and RouteOption for the rego rules${nocolor}"
kubectl describe authconfig -n httpbin opa-auth
echo "---"
kubectl describe routeoption -n gloo-system opa-auth

# Update the HttpRoute
echo -e ${blue}
read -p "Updating the HTTPRoute to use the new OPA policy. Press enter to continue..."
echo -e ${nocolor}
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
    - filters:
        - type: ExtensionRef
          extensionRef:
            group: gateway.solo.io
            kind: RouteOption
            name: opa-auth
      backendRefs:
        - name: httpbin
          namespace: httpbin
          port: 8000
EOF
echo
echo -e "${blue}Updated the HTTPRoute to use the OPA policy${nocolor}"
kubectl describe httproute -n gloo-system httpbin

# Demonstrate policy
echo -e ${blue}
read -p "Test the gateway with a path that IS NOT allowed by the OPA policy. Press enter to continue..."
echo -e ${nocolor}
echo -e "${blue}>> curl -ik http://${hostname}:8080/headers${nocolor}"
curl -ik http://${hostname}:8080/headers

echo
echo 
echo -e "${blue}The request should have returned a 403 HTTP response code.${nocolor}"

echo -e ${blue}
read -p "Test the gateway with a path that IS allowed by the OPA policy. Press enter to continue..."
echo -e ${nocolor}
echo -e "${blue}>> curl -ik http://${hostname}:8080/status/200${nocolor}"
curl -ik http://${hostname}:8080/status/200

echo
echo 
echo -e "${blue}The request should have returned a 200 HTTP response code.${nocolor}"

# Set up JWT authentication again
echo -e ${blue}
read -p "Configuring JWT access control in combination with OPA policies. Press enter to continue..."
echo -e ${nocolor}

kubectl apply -f- <<EOF
apiVersion: gateway.solo.io/v1
kind: VirtualHostOption
metadata:
  name: jwt-provider
  namespace: gloo-system
spec:
  targetRefs:
  - group: gateway.networking.k8s.io
    kind: Gateway
    name: http
  options:
    jwt:
      providers:
        selfminted:
          issuer: solo.io
          claimsToHeaders:
          - claim: "sub"
            header: "jwt-subject"
          - claim: "org"
            header: "jwt-organization"
          - claim: "team"
            header: "jwt-team"
          jwks:
            local:
              key: |
                -----BEGIN PUBLIC KEY-----
                MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAzgEPg3jVs5HPICKB2fz2
                wUkfMIMD7GYaBhrHAQlMccneU0PWkPOctJyziMPwZTdSPIKQpZhkIa+z1FP29bbn
                hpsW0GgTLowraelvXop06IqFbHL6vHL4rewyBOV9mbQJ2NbJDYXUpk3vXgLW2mpb
                T5LAs3HzMtQmp6RMFgBjRUQmZUQI99Vx5OjnoZOEMStOzgrdhacCqvfbCrVSaYF4
                X15Hfh4A9TKQSrQhHrScWHRDYWhqVjX0dP/h7yMKrA65cjwyoPiDcP8+9PJkjU7t
                hhmly+OT46l/a/fyeqxWBe0N8SKBPyhBPbOYzDY0fsYLVl6IBGISwp50ah2ICTVS
                GQIDAQAB
                -----END PUBLIC KEY-----
    headerManipulation:
      requestHeadersToAdd:
      - header:
          key: MyHeader
          value: "my-customer-header"
EOF
echo
echo -e "${blue}Applied VirtualHostOption${nocolor}"
kubectl describe virtualhostoption -n gloo-system jwt-provider

# Demonstrate policy with JWT
echo -e ${blue}
read -p "Test the gateway with a path that IS NOT allowed by the OPA policy. Press enter to continue..."
echo -e ${nocolor}
echo -e "${blue}>> curl -ik http://${hostname}:8080/headers${nocolor}"
curl -ik http://${hostname}:8080/headers
echo
echo 
echo -e "${blue}The request should have returned a 403 HTTP response code.${nocolor}"

echo -e ${blue}
read -p "Test the gateway with a path that IS allowed by the OPA policy but without a JWT. Press enter to continue..."
echo -e ${nocolor}
echo -e "${blue}>> curl -ik http://${hostname}:8080/status/200${nocolor}"
curl -ik http://${hostname}:8080/status/200
echo
echo 
echo -e "${blue}The request should have returned a 401 HTTP response code because there's no JWT.${nocolor}"

echo -e ${blue}
read -p "Test the gateway with a path that IS allowed by the OPA policy with a JWT. Press enter to continue..."
echo -e ${nocolor}
echo -e "${blue}>> curl -ik http://${hostname}:8080/status/200 -H 'Authorization: Bearer $alice_token'${nocolor}"
curl -ik http://${hostname}:8080/status/200 -H "Authorization: Bearer $alice_token"
echo 
echo -e "${blue}The request should have returned a 200 HTTP response code.${nocolor}"

# Cleanup OPA resources
echo -e ${blue}
read -p "Cleanup demo OPA resources. Press enter to continue..."
echo -e ${nocolor}
kubectl delete virtualhostoption -n gloo-system jwt-provider
kubectl delete routeoption -n gloo-system opa-auth
kubectl delete authconfig -n httpbin opa-auth
kubectl delete configmap -n httpbin allow-get-users
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
EOF
