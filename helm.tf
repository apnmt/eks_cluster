provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.cluster.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
    exec {
      api_version = "client.authentication.k8s.io/v1alpha1"
      args        = ["eks", "get-token", "--cluster-name", data.aws_eks_cluster.cluster.name]
      command     = "aws"
    }
  }
}

resource "helm_release" "karpenter" {
  depends_on       = [module.eks.kubeconfig]
  namespace        = "karpenter"
  create_namespace = true
  name       = "karpenter"
  repository = "https://charts.karpenter.sh"
  chart      = "karpenter"
  version    = "v0.7.3"
  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.iam_assumable_role_karpenter.iam_role_arn
  }
  set {
    name  = "clusterName"
    value = local.cluster_name
  }
  set {
    name  = "clusterEndpoint"
    value = module.eks.cluster_endpoint
  }
  set {
    name  = "aws.defaultInstanceProfile"
    value = aws_iam_instance_profile.karpenter.name
  }
  set {
    name = "controller.resources.requests.cpu"
    value = "500m"
  }
  set {
    name = "controller.resources.requests.memory"
    value = "512Mi"
  }
}

resource "helm_release" "karpenter_provisioner" {
  depends_on = [helm_release.karpenter]
  chart = "apnmt-karpenter-provisioner"
  name  = "apnmt-karpenter-provisioner"
  namespace  = "karpenter"
  repository = "https://apnmt.github.io/apnmt-charts/"

  set {
    name  = "cluster.name"
    value = local.cluster_name
  }

  set {
    name  = "requirements.capacityType.values"
    value = "{${"spot"}}"
  }
  set {
    name  = "requirements.zones.values"
    value = "{${"eu-central-1a"}}"
  }
}

resource "helm_release" "metrics-server" {
  name       = "metrics-server"
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
}

resource "helm_release" "apnmt-emissary-apiext" {
  name       = "apnmt-emissary-apiext"
  repository = "https://apnmt.github.io/apnmt-charts/"
  chart      = "apnmt-emissary-apiext"
}

resource "helm_release" "apnmt-emissary-tracing" {
  name       = "apnmt-emissary-tracing"
  repository = "https://apnmt.github.io/apnmt-charts/"
  chart      = "apnmt-emissary-tracing"
  namespace = "apnmt"
  create_namespace = true

# helm chart can only be installed, if apnmt-emissary-apiext chart is already installed
  # otherwise Mapping will fail
  depends_on = [helm_release.apnmt-emissary-apiext]
}

resource "helm_release" "apnmt-emissary-ingress" {
  name       = "apnmt-emissary-ingress"
  repository = "https://apnmt.github.io/apnmt-charts/"
  chart      = "apnmt-emissary-ingress"
  namespace = "apnmt"
  create_namespace = true

  # helm chart can only be installed, if apnmt-emissary-tracing chart is already installed
  # otherwise emissary ingress needs to be restarted
  depends_on = [helm_release.apnmt-emissary-tracing]
}

resource "helm_release" "apnmt-tracing" {
  name       = "apnmt-tracing"
  repository = "https://apnmt.github.io/apnmt-charts/"
  chart      = "apnmt-tracing"
  namespace = "apnmt"
  create_namespace = true

  # helm chart can only be installed, if apnmt-emissary-apiext chart is already installed
  # otherwise Mapping will fail
  depends_on = [helm_release.apnmt-emissary-apiext]
}

resource "helm_release" "apnmt-elk" {
  name       = "apnmt-elk"
  repository = "https://apnmt.github.io/apnmt-charts/"
  chart      = "apnmt-elk"
  namespace = "apnmt"
  create_namespace = true

  # helm chart can only be installed, if apnmt-emissary-apiext chart is already installed
  # otherwise Mapping will fail
  depends_on = [helm_release.apnmt-emissary-apiext]
}

data "kubernetes_service" "emissary-ingress-load-balancer" {
  metadata {
    namespace = "apnmt"
    name = "apnmt-emissary-ingress"
  }
  depends_on = [helm_release.apnmt-emissary-ingress]
}

resource "helm_release" "apnmt-monitoring" {
  name       = "apnmt-monitoring"
  repository = "https://apnmt.github.io/apnmt-charts/"
  chart      = "apnmt-monitoring"
  namespace = "apnmt"
  create_namespace = true

  # helm chart can only be installed, if apnmt-emissary-apiext chart is already installed
  # otherwise Mapping will fail
  depends_on = [helm_release.apnmt-emissary-apiext]

  set {
    name  = "kube-prometheus-stack.grafana.grafana\\.ini.server.root_url"
    value = "https://${data.kubernetes_service.emissary-ingress-load-balancer.status.0.load_balancer.0.ingress.0.hostname}/grafana"
  }
}

resource "helm_release" "apnmt-kafka" {
  name       = "apnmt-kafka"
  repository = "https://apnmt.github.io/apnmt-charts/"
  chart      = "apnmt-kafka"
  namespace = "apnmt"
  create_namespace = true
}

resource "helm_release" "appointmentservice-k8s" {
  name       = "appointmentservice-k8s"
  repository = "https://apnmt.github.io/apnmt-charts/"
  chart      = "appointmentservice-k8s"
  namespace = "apnmt"
  create_namespace = true

  # helm chart can only be installed, if apnmt-emissary-apiext chart is already installed
  # otherwise Mapping will fail
  depends_on = [helm_release.apnmt-emissary-apiext]
}

resource "helm_release" "organizationservice-k8s" {
  name       = "organizationservice-k8s"
  repository = "https://apnmt.github.io/apnmt-charts/"
  chart      = "organizationservice-k8s"
  namespace = "apnmt"
  create_namespace = true

  # helm chart can only be installed, if apnmt-emissary-apiext chart is already installed
  # otherwise Mapping will fail
  depends_on = [helm_release.apnmt-emissary-apiext]
}

resource "helm_release" "organizationappointmentservice-k8s" {
  name       = "organizationappointmentservice-k8s"
  repository = "https://apnmt.github.io/apnmt-charts/"
  chart      = "organizationappointmentservice-k8s"
  namespace = "apnmt"
  create_namespace = true

  # helm chart can only be installed, if apnmt-emissary-apiext chart is already installed
  # otherwise Mapping will fail
  depends_on = [helm_release.apnmt-emissary-apiext]
}

resource "helm_release" "paymentservice-k8s" {
  name       = "paymentservice-k8s"
  repository = "https://apnmt.github.io/apnmt-charts/"
  chart      = "paymentservice-k8s"
  namespace = "apnmt"
  create_namespace = true

  # helm chart can only be installed, if apnmt-emissary-apiext chart is already installed
  # otherwise Mapping will fail
  depends_on = [helm_release.apnmt-emissary-apiext]
}

resource "helm_release" "authservice-k8s" {
  name       = "authservice-k8s"
  repository = "https://apnmt.github.io/apnmt-charts/"
  chart      = "authservice-k8s"
  namespace = "apnmt"
  create_namespace = true

  # helm chart can only be installed, if apnmt-emissary-apiext chart is already installed
  # otherwise Mapping will fail
  depends_on = [helm_release.apnmt-emissary-apiext]
}
