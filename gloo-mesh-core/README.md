# Gloo Mesh Core Demonstration

This demonstrates the core features of Ambient in Gloo Mesh Core.

## Get Started

1. Create a new Kubernetes cluster and set the current kube context to that cluster.
2. Set these environment variables:

   `GLOO_MESH_LICENSE_KEY` - The license key for Gloo Mesh Core.

   `GLOO_MESH_GATEWAY_HOSTNAME` - (Optional) The hostname to use for the ingress gateway. You should have the ability to create a DNS record or edit your local hosts file.

   `GLOO_MESH_CLUSTER_NAME` - (Optional) The name of the cluster in Istio. This is an arbitrary value and is used to identify the cluster by Istio.

   `GLOO_MESH_VERSION` - (Optional) The version of Gloo Mesh Core to install.

   `GLOO_MESH_ISTIO_HUB` - The repository that contains Gloo builds of Istio.

   `GLOO_MESH_ISTIO_VERSION` - (Optional) The version of Istio to install.

   `GLOO_MESH_ISTIO_IMAGE` - (Optional) The image name of the Istio build to install.

   Alternatively, the script will prompt you for these values.

3. Run the `install-gloo-mesh-core.sh` to install Gloo Mesh Core, an ingress gateway, and sample applications for the demonstration. The script will prompt you to create a DNS record for the Ingress Gateway endpoint; if you're using a local Kubernetes cluster, you can edit your `hosts` file and map the hostname to `127.0.0.1`.

## Run the Demonstration

Once you have Gloo Mesh Core and the sample applications installed, you can run the demonstration script `gloo-mesh-core-demo.sh`. This will walk through various features of Gloo Mesh Core with Ambient, such as L4 and L7 policies, observability, and controlled egress. It will clean up all of the created resources once it's completed.

## Cleanup

To remove Gloo Mesh Core and the sample applications run the script `uninstall-gloo-mesh-core.sh`. This should return your Kubernetes cluster to its original state.

