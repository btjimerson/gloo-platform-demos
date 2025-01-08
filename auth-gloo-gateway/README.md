# Gloo Gateway Authentication Demonstration

This demonstrates usage of Gloo Gateway authentication and authorization features like JWT and OPA policies, as well as header manipulation with JWT claims and custom values.

## Get Started

1. Create a new Kubernetes cluster and set the current kube context to that cluster.
2. Set these environment variables:

   `GLOO_GATEWAY_VERSION` - (Optional) The version of Gloo Gateway to install.

   `GLOO_GATEWAY_LICENSE_KEY` - The license key for Gloo Gateway.

   `GLOO_GATEWAY_HOSTNAME` -  (Optional) The hostname to use for the gateway. You should have the ability to create a DNS record or edit your local hosts file.

   Alternatively, the script will prompt you for these values.

3. Run the `install-gloo-gateway.sh` to install Gloo Gateway, httpbin, a Gateway, and an HTTPRoute for httpbin. The script will prompt you to create a DNS record for the Gateway endpoint; if you're using a local Kubernetes cluster, you can edit your `hosts` file and map the hostname to `127.0.0.1`.

## Run the Demonstration

Once you have Gloo Gateway and httpbin set up, you can run the demonstration script `jwt-ops-demo.sh`. This will walk through JWT authentication, claims validation, header injection, and OPA policy authorization. It will clean up all of the created resources once it's completed.

## Cleanup

To remove Gloo Gateway and httpbin, run the script `uninstall-gloo-gateway.sh`. This should return your Kubernetes cluster to its original state.

