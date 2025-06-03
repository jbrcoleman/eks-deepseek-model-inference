# EKS DeepSeek Model Inference

A comprehensive infrastructure blueprint for deploying DeepSeek-R1-Distill-Llama-8B model inference using Ray with vLLM backend on Amazon EKS.

> This implementation is based on the [AI on EKS - Ray vLLM DeepSeek Blueprint](https://awslabs.github.io/ai-on-eks/docs/blueprints/inference/GPUs/ray-vllm-deepseek).

## 🏗️ Architecture Overview

This repository provides a complete infrastructure-as-code solution for running large language model inference on Amazon EKS with the following key components:

- **Amazon EKS Cluster** with GPU-enabled worker nodes
- **Ray Serve** for distributed model serving
- **vLLM** as the high-performance inference backend
- **DeepSeek-R1-Distill-Llama-8B** model for efficient inference
- **Karpenter** for intelligent node autoscaling
- **Monitoring & Observability** with Prometheus, Grafana, and Ray dashboards
- **JupyterHub** for interactive model development

## 📂 Repository Structure

```
├── base/terraform/          # Core Terraform infrastructure modules
│   ├── addons.tf           # EKS addons configuration
│   ├── eks.tf              # EKS cluster configuration
│   ├── vpc.tf              # VPC and networking setup
│   ├── karpenter.tf        # Karpenter autoscaler
│   ├── monitoring/         # Grafana dashboards and monitoring
│   └── helm-values/        # Helm chart configurations
├── jark-stack/             # Example application stack
│   ├── terraform/          # Stack-specific Terraform configuration
│   └── src/                # Sample applications (Dogbooth demo)
└── vllm-ray-gpu-deepseek/  # DeepSeek model deployment manifests
    ├── ray-vllm-deepseek.yml  # Ray Service configuration
    └── open-webui.yaml        # Web UI for model interaction
```

## 🚀 Quick Start

### Prerequisites

- AWS CLI configured with appropriate permissions
- Terraform >= 1.0.0
- kubectl
- Helm
- Docker (for custom image builds)

### 1. Deploy the Infrastructure

```bash
# Clone the repository
git clone <repository-url>
cd eks-deepseek-model-inference

# Deploy the base infrastructure
cd jark-stack/ && chmod +x install.sh
./install.sh
```

### 2. Configure kubectl and verification

```bash
# Get the kubectl configuration command from Terraform output
terraform output configure_kubectl

# Example output:
aws eks --region us-west-2 update-kubeconfig --name ai-stack

# Verify the Karpenter autoscaler nodepools :
kubectl get nodepools

# Verify the NVIDIA Device plugin
kubectl get pods -n nvidia-device-plugin

# Verify Kuberay Operator which is used to create Ray Clusters
kubectl get pods -n kuberay-operator
```

### 3. Deploy the DeepSeek Model

```bash
# Set your Hugging Face token (required for model access)
export HUGGING_FACE_HUB_TOKEN="your_hf_token_here"

# Encode the token for Kubernetes secret
echo -n "$HUGGING_FACE_HUB_TOKEN" | base64

# Update the secret in ray-vllm-deepseek.yml and deploy
kubectl apply -f vllm-ray-gpu-deepseek/ray-vllm-deepseek.yml

#Setup port forwarding to test model locally
kubectl -n rayserve-vllm port-forward svc/vllm-serve-svc 8000:8000

# Test inference
curl -X POST http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model": "deepseek-ai/DeepSeek-R1-Distill-Llama-8B", "messages": [{"role": "user", "content": "Explain about DeepSeek model?"}], "stream": false}'
```

### 4. Deploy Open WebUI (Optional)

```bash
# Deploy the web interface for interacting with the model
kubectl apply -f vllm-ray-gpu-deepseek/open-webui.yaml

# Setup port forward to test locally
kubectl -n open-webui port-forward svc/open-webui 8080:80
```

### 5. Cleanup
```bash
# Delete the RayCluster
cd vllm-ray-gpu-deepseek

kubectl delete -f open-webui.yaml

kubectl delete -f ray-vllm-deepseek.yml

# Delete Infra
cd jark-stack/terraform/_LOCAL/ && chmod +x cleanup.sh
./cleanup.sh
```

## 🛠️ Infrastructure Components

### EKS Cluster Configuration

The infrastructure includes:

- **EKS Version**: 1.32
- **Node Groups**: 
  - Core node group (m5.xlarge) for system workloads
  - GPU-enabled Karpenter node pools (g5, g6 instances)
  - CPU-only Karpenter pools for non-GPU workloads
- **Networking**: VPC with public/private subnets, secondary CIDR for pod networking
- **Storage**: EFS for shared storage, GP3 as default storage class

### Key Add-ons Enabled

- **Karpenter**: Intelligent node autoscaling
- **AWS Load Balancer Controller**: For ingress management
- **EFS CSI Driver**: Shared persistent storage
- **NVIDIA Device Plugin**: GPU resource management
- **Prometheus & Grafana**: Monitoring and observability
- **ArgoCD**: GitOps deployment management
- **JupyterHub**: Interactive development environment

### Ray Service Configuration

The DeepSeek model is deployed using Ray Serve with:

- **Model**: `deepseek-ai/DeepSeek-R1-Distill-Llama-8B`
- **Backend**: vLLM for optimized inference
- **Autoscaling**: 1-4 replicas based on request load
- **GPU Requirements**: 1 GPU per replica
- **OpenAI-Compatible API**: Standard chat completions endpoint

## 📊 Monitoring & Observability

### Accessing Dashboards

1. **Grafana Dashboard**:
   ```bash
   # Port forward to access Grafana
   kubectl port-forward svc/kube-prometheus-stack-grafana 3000:80 -n kube-prometheus-stack
   # Access at http://localhost:3000
   # Get admin password:
   terraform output grafana_secret_name
   aws secretsmanager get-secret-value --secret-id <secret-name> --query SecretString --output text
   ```

2. **Ray Dashboard**:
   ```bash
   # Port forward to Ray dashboard
   kubectl port-forward svc/vllm-head-svc 8265:8265 -n rayserve-vllm
   # Access at http://localhost:8265
   ```

3. **JupyterHub** (if enabled):
   ```bash
   # Get the JupyterHub service endpoint
   kubectl get svc -n jupyterhub
   ```

### Available Metrics

The infrastructure includes comprehensive monitoring for:
- Ray cluster health and performance
- GPU utilization and memory usage
- Model inference latency and throughput
- Kubernetes cluster metrics
- Custom Ray Serve metrics

## 🔧 Configuration Options

### Model Configuration

Modify the Ray Service configuration in `ray-vllm-deepseek.yml`:

```yaml
env_vars:
  MODEL_ID: "deepseek-ai/DeepSeek-R1-Distill-Llama-8B"  # Change model here
  GPU_MEMORY_UTILIZATION: "0.9"
  MAX_MODEL_LEN: "8192"
  MAX_NUM_SEQS: "4"
  TENSOR_PARALLEL_SIZE: "1"
```

### Infrastructure Customization

Update `blueprint.tfvars` to customize:

```hcl
name                             = "your-cluster-name"
region                          = "us-west-2"
eks_cluster_version             = "1.32"
enable_jupyterhub               = true
enable_kube_prometheus_stack    = true
enable_kuberay_operator         = true
```

## 🧪 Example Usage

### Using the OpenAI-Compatible API

```python
import openai

# Configure the client to use your deployed model
client = openai.OpenAI(
    base_url="http://your-service-url/v1",
    api_key="dummy"  # vLLM doesn't require a real API key
)

# Generate a response
response = client.chat.completions.create(
    model="deepseek-ai/DeepSeek-R1-Distill-Llama-8B",
    messages=[
        {"role": "user", "content": "Explain quantum computing in simple terms."}
    ],
    max_tokens=500,
    temperature=0.7
)

print(response.choices[0].message.content)
```

### Using curl

```bash
curl -X POST "http://your-service-url/v1/chat/completions" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "deepseek-ai/DeepSeek-R1-Distill-Llama-8B",
    "messages": [
      {"role": "user", "content": "Hello, how are you?"}
    ],
    "max_tokens": 100,
    "temperature": 0.7
  }'
```

## 🔒 Security Considerations

- **Network Security**: Private subnets for worker nodes, security groups for controlled access
- **IAM Roles**: Least-privilege service accounts with IRSA (IAM Roles for Service Accounts)
- **Secrets Management**: AWS Secrets Manager for sensitive configuration
- **Encryption**: EBS volumes and EFS file systems encrypted at rest

## 💰 Cost Optimization

- **Karpenter**: Automatic node scaling based on workload demands
- **Spot Instances**: Configured for cost-effective GPU instances
- **Resource Limits**: Proper resource requests and limits for efficient scheduling
- **Auto-shutdown**: Idle resources automatically scaled down

## 🛠️ Troubleshooting

### Common Issues

1. **Model Download Failures**:
   - Verify Hugging Face token is correctly set
   - Check internet connectivity from worker nodes
   - Ensure sufficient disk space for model storage

2. **GPU Resource Issues**:
   - Verify NVIDIA device plugin is running
   - Check node labels and taints
   - Confirm GPU availability in the selected region

3. **Ray Service Not Starting**:
   - Check pod logs: `kubectl logs -n rayserve-vllm -l app.kubernetes.io/name=kuberay`
   - Verify resource requests match available node capacity
   - Check for image pull errors

### Debug Commands

```bash
# Check cluster status
kubectl get nodes
kubectl get pods -A

# Check Ray cluster status
kubectl get rayservice -n rayserve-vllm
kubectl describe rayservice vllm -n rayserve-vllm

# Check GPU availability
kubectl describe nodes | grep nvidia.com/gpu

# View logs
kubectl logs -f deployment/vllm-head -n rayserve-vllm
```

## 🔄 Cleanup

To destroy the infrastructure:

```bash
# Delete Ray services first
kubectl delete -f vllm-ray-gpu-deepseek/ray-vllm-deepseek.yml
kubectl delete -f vllm-ray-gpu-deepseek/open-webui.yaml

# Destroy Terraform infrastructure
cd base/terraform
terraform destroy -var-file="../blueprint.tfvars"
```

## 🔗 Related Resources

- [AI on EKS Blueprints](https://github.com/awslabs/ai-on-eks)
- [Ray Documentation](https://docs.ray.io/)
- [vLLM Documentation](https://docs.vllm.ai/)
- [DeepSeek Model Cards](https://huggingface.co/deepseek-ai)
- [Amazon EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)