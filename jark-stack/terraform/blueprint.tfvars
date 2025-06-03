name                             = "jark-stack"
enable_aws_efs_csi_driver        = true
enable_jupyterhub                = true
enable_kuberay_operator          = true
enable_argo_workflows            = true
enable_argo_events               = true
enable_argocd                    = true
enable_ai_ml_observability_stack = true
region                           = "us-east-1"
eks_cluster_version              = "1.32"

# -------------------------------------------------------------------------------------
# EKS Addons Configuration
#
# These are the EKS Cluster Addons managed by Terrafrom stack.
# You can enable or disable any addon by setting the value to `true` or `false`.
#
# If you need to add a new addon that isn't listed here:
# 1. Add the addon name to the `enable_cluster_addons` variable in `base/terraform/variables.tf`
# 2. Update the `locals.cluster_addons` logic in `eks.tf` to include any required configuration
#
# -------------------------------------------------------------------------------------

enable_cluster_addons = {
  coredns                         = true
  kube-proxy                      = true
  vpc-cni                         = true
  eks-pod-identity-agent          = true
  aws-ebs-csi-driver              = true
  metrics-server                  = true
  eks-node-monitoring-agent       = false
  amazon-cloudwatch-observability = true
}