# GKE OnlineBoutique Deployment & Optimization Playbook

## Overview

This comprehensive playbook guides you through deploying and optimizing the OnlineBoutique microservices application on Google Kubernetes Engine (GKE). You'll learn about cluster management, resource optimization, zero-downtime deployments, and autoscaling strategies.

### Architecture Overview

The OnlineBoutique application is a cloud-native microservices demo consisting of 11 services:
- **Frontend**: Web UI serving the store interface
- **ProductCatalogService**: Product inventory management
- **CartService**: Shopping cart functionality
- **CheckoutService**: Order processing
- **PaymentService**: Payment processing simulation
- **EmailService**: Order confirmation emails
- **ShippingService**: Shipping cost calculation
- **CurrencyService**: Multi-currency support
- **AdService**: Contextual advertisements
- **RecommendationService**: Product recommendations
- **LoadGenerator**: Synthetic traffic generation

---

## Task 1: Create Cluster and Deploy Application

### Architectural Concepts

**Google Kubernetes Engine (GKE)** provides managed Kubernetes clusters in Google Cloud. A zonal cluster places all nodes in a single zone, offering simplicity and cost efficiency for development environments.

**Namespaces** provide logical isolation within a cluster, enabling resource segregation between environments (dev/prod) while sharing the same underlying infrastructure.

### Implementation

#### Step 1: Create GKE Cluster

```bash
gcloud container clusters create onlineboutique-cluster-673 \
    --zone=us-east1-d \
    --machine-type=e2-standard-2 \
    --num-nodes=2 \
    --release-channel=rapid
```

**Concepts Explained:**
- **Zonal Cluster**: Single-zone deployment reduces cross-zone network costs and latency
- **e2-standard-2**: Cost-optimized machine type with 2 vCPU and 8GB RAM
- **Release Channel**: `rapid` provides latest Kubernetes features and faster updates
- **Node Count**: Starting with 2 nodes provides basic high availability

#### Step 2: Configure kubectl Access

```bash
gcloud container clusters get-credentials onlineboutique-cluster-673 --zone=us-east1-d
```

**Concepts Explained:**
- Downloads cluster credentials and configures kubectl context
- Enables secure communication with the Kubernetes API server
- Sets up authentication using Google Cloud IAM

#### Step 3: Create Namespaces

```bash
# Create dev namespace
kubectl create namespace dev

# Create prod namespace  
kubectl create namespace prod

# Verify namespaces were created
kubectl get namespaces
```

**Concepts Explained:**
- **Namespaces** provide scope for resource names and enable RBAC policies
- **Environment Separation**: Isolates dev and prod workloads on the same cluster
- **Resource Quotas**: Namespaces enable setting limits per environment

#### Step 4: Deploy Application

```bash
git clone https://github.com/GoogleCloudPlatform/microservices-demo.git &&
cd microservices-demo && kubectl apply -f ./release/kubernetes-manifests.yaml --namespace dev
```

**Concepts Explained:**
- **Declarative Deployment**: YAML manifests describe desired state
- **Microservices Architecture**: Each service deployed as separate Deployment
- **Service Discovery**: Services communicate via Kubernetes Service objects
- **Load Balancing**: LoadBalancer type service exposes frontend externally

#### Step 5: Verify Deployment

```bash
# Check pod status
kubectl get pods --namespace dev

# Get external IP for frontend
kubectl get service frontend-external --namespace dev

# Monitor service availability
kubectl get service frontend-external --namespace dev --watch
```

**Concepts Explained:**
- **Pod Lifecycle**: Containers grouped in pods share network and storage
- **Service Types**: LoadBalancer provisions cloud load balancer with external IP
- **Health Checks**: Kubernetes monitors pod readiness and liveness

---

## Task 2: Migrate to Optimized Node Pool

### Architectural Concepts

**Node Pools** enable heterogeneous clusters with different machine types optimized for specific workloads. **Resource Right-sizing** involves matching compute resources to actual application requirements.

**Custom Machine Types** allow precise CPU/memory ratios, eliminating over-provisioning and reducing costs.

### Implementation

#### Step 1: Analyze Current Resource Usage

```bash
# Examine node resource allocation
kubectl describe nodes

# Check resource utilization
kubectl top nodes
kubectl top pods --namespace dev

# Review resource requests vs limits
kubectl get pods --namespace dev -o yaml | grep -A 5 resources
```

**Concepts Explained:**
- **Resource Requests**: Guaranteed CPU/memory for scheduling decisions
- **Resource Limits**: Maximum CPU/memory a container can consume
- **Node Pressure**: Monitoring prevents resource exhaustion

#### Step 2: Create Optimized Node Pool

```bash
gcloud container node-pools create optimized-pool-7664 \
    --cluster=onlineboutique-cluster-673 \
    --zone=us-east1-d \
    --machine-type=custom-2-3584 \
    --num-nodes=2
```

**Concepts Explained:**
- **custom-2-3584**: 2 vCPU, 3.5GB RAM (vs 8GB in e2-standard-2)
- **Cost Optimization**: 56% memory reduction while maintaining CPU capacity
- **Workload Analysis**: Based on observed 100m CPU per replica scaling pattern

#### Step 3: Verify Node Pool Creation

```bash
# List all node pools
gcloud container node-pools list --cluster=onlineboutique-cluster-673 --zone=us-east1-d

# Check node readiness
kubectl get nodes -o wide
```

#### Step 4: Migrate Workloads Safely

```bash
# Identify default pool nodes
kubectl get nodes --selector=cloud.google.com/gke-nodepool=default-pool

# Cordon nodes (prevent new pod scheduling)
kubectl cordon $(kubectl get nodes --selector=cloud.google.com/gke-nodepool=default-pool -o jsonpath='{.items[*].metadata.name}')

# Drain nodes (gracefully evict pods)
kubectl drain $(kubectl get nodes --selector=cloud.google.com/gke-nodepool=default-pool -o jsonpath='{.items[*].metadata.name}') \
    --ignore-daemonsets \
    --delete-emptydir-data \
    --force
```

**Concepts Explained:**
- **Cordoning**: Marks nodes as unschedulable without affecting running pods
- **Draining**: Gracefully terminates pods, respecting PodDisruptionBudgets
- **Node Selectors**: Target operations to specific node pools
- **DaemonSets**: System pods ignored during drain operations

#### Step 5: Complete Migration

```bash
# Verify pod migration
kubectl get pods --namespace dev -o wide

# Remove old node pool
gcloud container node-pools delete default-pool \
    --cluster=onlineboutique-cluster-673 \
    --zone=us-east1-d

# Final verification
gcloud container node-pools list --cluster=onlineboutique-cluster-673 --zone=us-east1-d
```

**Concepts Explained:**
- **Pod Rescheduling**: Kubernetes automatically places evicted pods on available nodes
- **Node Pool Deletion**: Permanently removes compute resources
- **Cost Impact**: Immediate cost reduction from optimized machine types

---

## Task 3: Apply Frontend Update with Zero Downtime

### Architectural Concepts

**PodDisruptionBudgets (PDB)** ensure minimum availability during voluntary disruptions. **Rolling Updates** deploy new versions incrementally, maintaining service availability.

**Container Image Management** involves versioning strategies and pull policies for consistent deployments.

### Implementation

#### Step 1: Create Pod Disruption Budget

```bash
cat <<EOF | kubectl apply -f - --namespace dev
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: onlineboutique-frontend-pdb
  namespace: dev
spec:
  minAvailable: 1
  selector:
    matchLabels:
      app: frontend
EOF
```

**Concepts Explained:**
- **minAvailable: 1**: Ensures at least one frontend pod remains during updates
- **Label Selectors**: Targets PDB to specific deployment pods
- **Voluntary Disruptions**: Protects against maintenance, scaling, updates

#### Step 2: Verify PDB Configuration

```bash
# Check PDB status
kubectl get pdb --namespace dev

# Detailed PDB information
kubectl describe pdb onlineboutique-frontend-pdb --namespace dev
```

#### Step 3: Examine Current Deployment

```bash
# Current deployment configuration
kubectl get deployment frontend --namespace dev -o yaml

# Check current image
kubectl get deployment frontend --namespace dev -o jsonpath='{.spec.template.spec.containers[0].image}'
```

#### Step 4: Apply Rolling Update

```bash
kubectl patch deployment frontend --namespace dev --type='merge' -p='
{
  "spec": {
    "template": {
      "spec": {
        "containers": [
          {
            "name": "server",
            "image": "gcr.io/qwiklabs-resources/onlineboutique-frontend:v2.1",
            "imagePullPolicy": "Always"
          }
        ]
      }
    }
  }
}'
```

**Concepts Explained:**
- **Strategic Merge Patch**: Updates specific fields without replacing entire object
- **Image Versioning**: v2.1 represents updated application code
- **imagePullPolicy: Always**: Forces fresh image pull, ensuring latest version
- **Rolling Update Strategy**: Default behavior replaces pods incrementally

#### Step 5: Monitor Update Progress

```bash
# Watch rollout status
kubectl rollout status deployment/frontend --namespace dev

# Monitor pod lifecycle
kubectl get pods --namespace dev -l app=frontend --watch

# Verify PDB enforcement
kubectl get pdb onlineboutique-frontend-pdb --namespace dev
```

**Concepts Explained:**
- **Rollout Status**: Tracks deployment progress and health
- **Pod States**: Terminating → Pending → Running transition
- **PDB Protection**: Prevents termination if minimum availability violated

#### Step 6: Validate Update Success

```bash
# Confirm new image deployment
kubectl get deployment frontend --namespace dev -o jsonpath='{.spec.template.spec.containers[0].image}'

# Verify pull policy
kubectl get deployment frontend --namespace dev -o jsonpath='{.spec.template.spec.containers[0].imagePullPolicy}'

# Check service accessibility
kubectl get service frontend-external --namespace dev
```

---

## Task 4: Configure Autoscaling for Traffic Surges

### Architectural Concepts

**Horizontal Pod Autoscaler (HPA)** automatically scales pod replicas based on resource utilization. **Cluster Autoscaler** provisions additional nodes when pod scheduling fails due to resource constraints.

**Predictive Scaling** anticipates traffic patterns, while **Reactive Scaling** responds to current load conditions.

### Implementation

#### Step 1: Configure Frontend HPA

```bash
# Create horizontal pod autoscaler
kubectl autoscale deployment frontend --namespace dev \
    --cpu-percent=50 \
    --min=1 \
    --max=11

# Verify HPA creation
kubectl get hpa --namespace dev
```

**Concepts Explained:**
- **CPU Target**: 50% provides headroom for scaling decisions
- **Min/Max Replicas**: Prevents under/over-provisioning
- **Resource Metrics**: Default metrics-server provides CPU/memory data
- **Scaling Algorithm**: Target = Current * (Current Utilization / Target Utilization)

#### Step 2: Enable Cluster Autoscaler

```bash
# Configure node pool autoscaling
gcloud container clusters update onlineboutique-cluster-673 \
    --zone=us-east1-d \
    --enable-autoscaling \
    --node-pool=optimized-pool-7664 \
    --min-nodes=1 \
    --max-nodes=6
```

**Concepts Explained:**
- **Node Pool Scaling**: Adds/removes nodes based on pending pod requests
- **Scale-Up Triggers**: Unschedulable pods due to resource constraints
- **Scale-Down**: Removes underutilized nodes after grace period
- **Cost Control**: Maximum limits prevent runaway scaling costs

#### Step 3: Verify Autoscaling Configuration

```bash
# Check HPA status
kubectl get hpa --namespace dev

# Verify cluster autoscaler settings
gcloud container clusters describe onlineboutique-cluster-673 --zone=us-east1-d | grep -A 10 autoscaling

# Current node count
kubectl get nodes
```

#### Step 4: Conduct Load Testing

```bash
# Get frontend external IP
FRONTEND_IP=$(kubectl get service frontend-external --namespace dev -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# Execute high-volume load test
kubectl exec $(kubectl get pod --namespace=dev | grep 'loadgenerator' | cut -f1 -d ' ') -it --namespace=dev -- bash -c "export USERS=8000; locust --host=\"http://$FRONTEND_IP\" --headless -u \"8000\" 2>&1"
```

**Concepts Explained:**
- **Synthetic Load**: Simulates real user traffic patterns
- **Concurrent Users**: 8000 users create significant CPU/memory pressure
- **Load Generator**: Built-in service eliminates external dependencies
- **Performance Testing**: Validates scaling behavior under stress

#### Step 5: Monitor Scaling Behavior

```bash
# Real-time HPA monitoring
watch kubectl get hpa --namespace dev

# Pod scaling observation
watch kubectl get pods --namespace dev

# Node scaling monitoring
watch kubectl get nodes

# Resource utilization tracking
kubectl top pods --namespace dev
kubectl top nodes
```

#### Step 6: Scale Additional Services

```bash
# RecommendationService typically becomes bottleneck
kubectl autoscale deployment recommendationservice --namespace dev \
    --cpu-percent=50 \
    --min=1 \
    --max=5

# Verify complete autoscaling setup
kubectl get hpa --namespace dev
```

**Concepts Explained:**
- **Service Dependencies**: Frontend load impacts downstream services
- **Bottleneck Identification**: CPU/memory monitoring reveals constraints
- **Cascading Scaling**: Multiple HPAs handle distributed load patterns

#### Step 7: Analyze Scaling Events

```bash
# Review HPA details
kubectl describe hpa frontend --namespace dev
kubectl describe hpa recommendationservice --namespace dev

# Scaling event history
kubectl get events --namespace dev --sort-by=.metadata.creationTimestamp

# Final resource distribution
kubectl get pods --namespace dev -o wide
```

---

## Task 5: Advanced Optimization Strategies

### Architectural Concepts

**Resource Right-Sizing** involves analyzing actual usage patterns and setting appropriate requests/limits. **Node Auto Provisioning (NAP)** automatically selects optimal machine types for workloads.

**Multi-Metric Scaling** uses CPU, memory, and custom metrics for more sophisticated autoscaling decisions.

### Implementation

#### Step 1: Workload Analysis

```bash
# Comprehensive resource usage analysis
kubectl top pods --namespace dev --sort-by=cpu
kubectl top pods --namespace dev --sort-by=memory

# Resource allocation review
kubectl get deployments --namespace dev -o custom-columns=NAME:.metadata.name,CPU-REQUEST:.spec.template.spec.containers[0].resources.requests.cpu,MEMORY-REQUEST:.spec.template.spec.containers[0].resources.requests.memory

# Service health indicators
kubectl get pods --namespace dev -o custom-columns=NAME:.metadata.name,RESTARTS:.status.containerStatuses[0].restartCount,STATUS:.status.phase
```

#### Step 2: Additional Service Autoscaling

```bash
# ProductCatalogService - high read traffic
kubectl autoscale deployment productcatalogservice --namespace dev \
    --cpu-percent=70 \
    --min=1 \
    --max=4

# CartService - user session dependent
kubectl autoscale deployment cartservice --namespace dev \
    --cpu-percent=60 \
    --min=1 \
    --max=3

# CheckoutService - critical path optimization
kubectl autoscale deployment checkoutservice --namespace dev \
    --cpu-percent=60 \
    --min=1 \
    --max=3

# CurrencyService - shared dependency
kubectl autoscale deployment currencyservice --namespace dev \
    --cpu-percent=70 \
    --min=1 \
    --max=3
```

**Concepts Explained:**
- **Service-Specific Thresholds**: Different CPU targets based on service characteristics
- **Replica Limits**: Constrained by service architecture and dependencies
- **Priority Scaling**: Critical path services get higher replica counts

#### Step 3: Enable Node Auto Provisioning

```bash
# Configure automatic node provisioning
gcloud container clusters update onlineboutique-cluster-673 \
    --zone=us-east1-d \
    --enable-autoprovisioning \
    --max-cpu=16 \
    --max-memory=64 \
    --min-cpu=1 \
    --min-memory=2

# Verify NAP configuration
gcloud container clusters describe onlineboutique-cluster-673 \
    --zone=us-east1-d \
    --format="value(autoscaling.autoprovisioningNodePoolDefaults)"
```

**Concepts Explained:**
- **NAP Benefits**: Automatically selects optimal machine types
- **Resource Bounds**: Prevents excessive resource allocation
- **Cost Optimization**: Matches node configuration to actual workload needs

#### Step 4: Memory-Based Autoscaling

```bash
# Advanced HPA with memory metrics
cat <<EOF | kubectl apply -f -
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: adservice-memory-hpa
  namespace: dev
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: adservice
  minReplicas: 1
  maxReplicas: 3
  metrics:
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
EOF
```

**Concepts Explained:**
- **Multi-Metric Scaling**: CPU and memory provide comprehensive resource monitoring
- **Memory-Intensive Services**: Some workloads benefit from memory-based scaling
- **HPA v2 API**: Enables complex scaling policies and multiple metrics

#### Step 5: Resource Optimization

```bash
# Apply resource requests/limits based on analysis
kubectl patch deployment cartservice --namespace dev --type='merge' -p='
{
  "spec": {
    "template": {
      "spec": {
        "containers": [
          {
            "name": "server",
            "resources": {
              "requests": {
                "cpu": "100m",
                "memory": "128Mi"
              },
              "limits": {
                "cpu": "200m",
                "memory": "256Mi"
              }
            }
          }
        ]
      }
    }
  }
}'
```

**Concepts Explained:**
- **Resource Requests**: Influence scheduling decisions and node selection
- **Resource Limits**: Prevent resource contention and noisy neighbor effects
- **Quality of Service**: Guaranteed, Burstable, or BestEffort classes

#### Step 6: Advanced HPA Configuration

```bash
# Sophisticated scaling behavior
cat <<EOF | kubectl apply -f -
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: frontend-advanced-hpa
  namespace: dev
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: frontend
  minReplicas: 1
  maxReplicas: 15
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 50
  behavior:
    scaleUp:
      stabilizationWindowSeconds: 60
      policies:
      - type: Percent
        value: 100
        periodSeconds: 60
    scaleDown:
      stabilizationWindowSeconds: 300
      policies:
      - type: Percent
        value: 10
        periodSeconds: 60
EOF
```

**Concepts Explained:**
- **Stabilization Windows**: Prevent thrashing during metric fluctuations
- **Scaling Policies**: Control rate and magnitude of scaling operations
- **Directional Behavior**: Different policies for scale-up vs scale-down

#### Step 7: Comprehensive Monitoring

```bash
# Create monitoring script
cat << 'EOF' > monitor_scaling.sh
#!/bin/bash
echo "=== HPA Status ==="
kubectl get hpa --namespace dev

echo -e "\n=== Resource Utilization ==="
kubectl top pods --namespace dev --sort-by=cpu

echo -e "\n=== Node Status ==="
kubectl get nodes -o custom-columns=NAME:.metadata.name,STATUS:.status.conditions[-1].type,CPU:.status.allocatable.cpu,MEMORY:.status.allocatable.memory

echo -e "\n=== Scaling Events ==="
kubectl get events --namespace dev --sort-by=.metadata.creationTimestamp | tail -10
EOF

chmod +x monitor_scaling.sh
./monitor_scaling.sh
```

---

## Best Practices and Recommendations

### Cost Optimization
1. **Right-Size Resources**: Match machine types to actual workload requirements
2. **Implement Autoscaling**: Scale down during low traffic periods
3. **Use Spot Instances**: Consider preemptible nodes for non-critical workloads
4. **Monitor Resource Usage**: Regular analysis prevents over-provisioning

### Performance Optimization
1. **Pod Disruption Budgets**: Ensure availability during maintenance
2. **Resource Requests/Limits**: Prevent resource contention
3. **Multi-Zone Deployment**: Consider regional clusters for production
4. **Health Checks**: Implement comprehensive readiness/liveness probes

### Security Considerations
1. **Network Policies**: Implement micro-segmentation between services
2. **Pod Security Standards**: Apply appropriate security contexts
3. **Secret Management**: Use Google Secret Manager for sensitive data
4. **RBAC**: Implement role-based access control

### Operational Excellence
1. **Monitoring**: Deploy comprehensive observability stack
2. **Logging**: Centralized log aggregation and analysis
3. **Backup Strategy**: Regular cluster and data backups
4. **Disaster Recovery**: Document and test recovery procedures

---

## Troubleshooting Common Issues

### Scaling Issues
- **Pods Pending**: Check resource requests vs node capacity
- **Slow Scaling**: Review HPA metrics and thresholds
- **Node Provisioning Delays**: Consider pre-scaled node pools

### Performance Problems
- **High Latency**: Analyze service dependencies and resource constraints
- **Memory Leaks**: Monitor long-running pod resource usage
- **CPU Throttling**: Adjust resource limits based on actual usage

### Deployment Failures
- **Image Pull Errors**: Verify image registry access and image names
- **Configuration Issues**: Validate YAML syntax and API versions
- **Resource Conflicts**: Check for name collisions and quota limits

---

## Conclusion

This playbook demonstrates comprehensive GKE cluster management, from initial deployment through advanced optimization. Key achievements include:

1. **Cost-Effective Infrastructure**: Optimized node pools reduce costs by 40-60%
2. **Zero-Downtime Deployments**: PDBs and rolling updates ensure availability
3. **Automatic Scaling**: HPA and cluster autoscaler handle traffic variations
4. **Performance Optimization**: Resource right-sizing and advanced scaling policies

The OnlineBoutique application now runs on a production-ready, cost-optimized, and automatically scaling GKE infrastructure capable of handling significant traffic surges while maintaining high availability and performance standards.