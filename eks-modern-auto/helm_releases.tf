# ==================== HELM RELEASES ====================

# 1. Cilium: CNI Chaining Mode (Co-exists with AWS VPC CNI under EKS Auto Mode)
resource "helm_release" "cilium" {
  name             = "cilium"
  repository       = "https://helm.cilium.io/"
  chart            = "cilium"
  namespace        = "kube-system"
  version          = "1.16.2" # Use a modern stable release of Cilium

  # AWS VPC CNI Chaining configuration to prevent conflicts
  set {
    name  = "cni.chainingMode"
    value = "aws-vpc-cni"
  }

  set {
    name  = "cni.exclusive"
    value = "false"
  }

  # Disable IPv4 masquerading as VPC CNI handles routing and IPAM
  set {
    name  = "enableIPv4Masquerade"
    value = "false"
  }

  # Disable tunnel encapsulation (Use native VPC routing)
  set {
    name  = "tunnel"
    value = "disabled"
  }

  # Endpoint routes must be enabled for VPC CNI chaining
  set {
    name  = "endpointRoutes.enabled"
    value = "true"
  }

  # Use host port for health checks under chaining mode
  set {
    name  = "healthChecking.enabled"
    value = "true"
  }

  # Required configurations for AWS VPC CNI IPAM compatibility
  set {
    name  = "ipam.mode"
    value = "aws-vpc-cni"
  }

  set {
    name  = "ipam.operator.enabled"
    value = "false"
  }

  # Enable Cilium eBPF Network Policies
  set {
    name  = "enablePolicy"
    value = "default" # "default" allows policy enforcement while policies are defined
  }

  depends_on = [
    aws_eks_cluster.this
  ]
}

# 2. Istio Ambient Mesh: Base CRDs
resource "helm_release" "istio_base" {
  name             = "istio-base"
  repository       = "https://istio-release.storage.googleapis.com/charts"
  chart            = "base"
  namespace        = "istio-system"
  create_namespace = true
  version          = "1.24.1" # Modern version of Istio supporting stable Ambient Mesh

  depends_on = [
    aws_eks_cluster.this,
    helm_release.cilium
  ]
}

# 3. Istio Ambient Mesh: CNI DaemonSet (Required to redirect traffic to ztunnel)
resource "helm_release" "istio_cni" {
  name             = "istio-cni"
  repository       = "https://istio-release.storage.googleapis.com/charts"
  chart            = "cni"
  namespace        = "istio-system"
  version          = "1.24.1"

  # Ambient Mesh specific parameters
  set {
    name  = "profile"
    value = "ambient"
  }

  set {
    name  = "ambient.enabled"
    value = "true"
  }

  # Ensure cni configuration paths align with EKS Node OS defaults
  set {
    name  = "cni.cniBinDir"
    value = "/opt/cni/bin"
  }

  set {
    name  = "cni.cniConfDir"
    value = "/etc/cni/net.d"
  }

  depends_on = [
    helm_release.istio_base
  ]
}

# 4. Istio Ambient Mesh: Istiod (Control Plane)
resource "helm_release" "istiod" {
  name             = "istiod"
  repository       = "https://istio-release.storage.googleapis.com/charts"
  chart            = "istiod"
  namespace        = "istio-system"
  version          = "1.24.1"

  set {
    name  = "profile"
    value = "ambient"
  }

  # Enable CA certificates integration and Ambient telemetry L4/L7
  set {
    name  = "meshConfig.accessLogFile"
    value = "/dev/stdout"
  }

  depends_on = [
    helm_release.istio_cni
  ]
}

# 5. Istio Ambient Mesh: Ztunnel (DaemonSet for secure L4 mutual TLS)
resource "helm_release" "ztunnel" {
  name             = "ztunnel"
  repository       = "https://istio-release.storage.googleapis.com/charts"
  chart            = "ztunnel"
  namespace        = "istio-system"
  version          = "1.24.1"

  # ztunnel runs as a system DaemonSet capturing node traffic
  set {
    name  = "terminationGracePeriodSeconds"
    value = "30"
  }

  depends_on = [
    helm_release.istiod
  ]
}

# 6. Datadog Agent (DaemonSet for Observability on EKS Nodes)
resource "helm_release" "datadog" {
  name             = "datadog"
  repository       = "https://helm.datadoghq.com"
  chart            = "datadog"
  namespace        = "datadog"
  create_namespace = true
  version          = "3.84.0"

  # Core API Keys (Placeholders, typically fetched via Vault/SecretsManager)
  set {
    name  = "datadog.apiKey"
    value = "YOUR_DATADOG_API_KEY" # Should be injected securely in practice
  }

  set {
    name  = "datadog.appKey"
    value = "YOUR_DATADOG_APP_KEY"
  }

  set {
    name  = "datadog.site"
    value = "datadoghq.com"
  }

  # Datadog Agent configurations optimized for Cilium and Istio Ambient Mesh
  set {
    name  = "datadog.apm.portEnabled"
    value = "true"
  }

  # Run agents on Host Network to guarantee metrics collections under CNI chaining
  set {
    name  = "agents.useHostNetwork"
    value = "true"
  }

  # Enable system probe for eBPF Network performance monitoring (NPM)
  set {
    name  = "datadog.systemProbe.enabled"
    value = "true"
  }

  set {
    name  = "datadog.systemProbe.enableTCPQueueLength"
    value = "true"
  }

  set {
    name  = "datadog.systemProbe.enableOOMKill"
    value = "true"
  }

  # Enable Process monitoring
  set {
    name  = "datadog.processAgent.processCollection"
    value = "true"
  }

  # Autodiscovery for EKS containers and logs
  set {
    name  = "datadog.logs.enabled"
    value = "true"
  }

  set {
    name  = "datadog.logs.containerCollectAll"
    value = "true"
  }

  depends_on = [
    aws_eks_cluster.this,
    helm_release.cilium,
    helm_release.ztunnel
  ]
}
