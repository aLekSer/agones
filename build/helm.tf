variable "helm_version" {
  default = "v2.9.1"
}

variable "app_name" {
  default = "drupal"
}

variable "acme_email" {}

provider "helm" {
  service_account = "${kubernetes_service_account.tiller_service_account.metadata.0.name}"
  tiller_image = "gcr.io/kubernetes-helm/tiller:${var.helm_version}"

  kubernetes {
    host                   = "${google_container_cluster.primary.endpoint}"
    token                  = "${data.google_client_config.current.access_token}"
    client_certificate     = "${base64decode(google_container_cluster.primary.master_auth.0.client_certificate)}"
    client_key             = "${base64decode(google_container_cluster.primary.master_auth.0.client_key)}"
    cluster_ca_certificate = "${base64decode(google_container_cluster.primary.master_auth.0.cluster_ca_certificate)}"
  }
}
resource "kubernetes_service_account" "tiller_service_account" {
  metadata {
    name = "tiller"
    namespace = "agones-system"
  }
}

resource "kubernetes_cluster_role_binding" "tiller_cluster_role_binding2" {
  metadata {
    name = "tiller2"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cluster-admin2"
  }
  subject {
    kind      = "ServiceAccount"
    name      = "default"
    namespace = "agones-system"
  }
  subject {
    kind      = "ServiceAccount"
    name      = "${kubernetes_service_account.tiller_service_account.metadata.0.name}"
    namespace = "agones-system"
  }
}
resource "kubernetes_cluster_role_binding" "tiller_crb" {
  metadata {
    name = "tiller"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "helm-hook"
  }
  subject {
    kind      = "ServiceAccount"
    name      = "default"
    namespace = "kube-system"
  }
  subject {
    kind      = "ServiceAccount"
    name      = "${kubernetes_service_account.tiller_service_account.metadata.0.name}"
    namespace = "agones-system"
  }
}
data "google_client_config" "current" {}

resource "google_compute_address" "default" {
  name   = "tf-gke-helm-agones"
  region = "us-central1-b"
}

resource "random_id" "endpoint-name" {
  byte_length = 2
}

resource "google_endpoints_service" "openapi_service" {
  service_name   = "agones-${random_id.endpoint-name.hex}.endpoints.agones-alexander.cloud.goog"
  project        = "agones-alexander"
}
data "helm_repository" "agones" {
    name = "agones"
    url  = "https://agones.dev/chart/stable"
}
resource "helm_release" "agones" {
  name  = "kube-lego"
  chart = "stable/kube-lego"
}
resource "helm_release" "agones2" {
  name  = "agones"
  force_update = "true"
  repository = "${data.helm_repository.agones.metadata.0.name}"
  chart = "agones"
  values = [
    "${file("./values.yaml")}"
  ]
  set {
    name  = "registerServiceAccounts"
    value = "true"
  }
  set {
    name  = "crds.CleanupOnDelete"
    value = "true"
  }
  version = "0.9.0-rccc"
  namespace  = "agones-system"
}

resource "null_resource" "helm_update" {
  triggers = {
    always_run = "${timestamp()}"
  }

  provisioner "local-exec" {
    command = "helm update"
  }
}

provider "kubernetes" {
}
resource "kubernetes_cluster_role_binding" "example" {
    metadata {
        name = "terraform-example"
    }
    role_ref {
        api_group = "rbac.authorization.k8s.io"
        kind = "ClusterRole"
        name = "cluster-admin"
    }
    subject {
        kind = "User"
        name = "admin"
        api_group = "rbac.authorization.k8s.io"
    }
    subject {
        kind = "ServiceAccount"
        name = "helm"
        namespace = "kube-system"
    }
    subject {
        kind = "Group"
        name = "system:masters"
        api_group = "rbac.authorization.k8s.io"
    }
}

resource "kubernetes_cluster_role_binding" "helm-hook-cleanup" {
  metadata {
    name = "helm-hook-cleanup"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "helm-hook"
  }
  subject {
    kind      = "ServiceAccount"
    name      = "helm-hook-cleanup"
    namespace = "agones-system"
  }
}

resource "kubernetes_cluster_role" "helm-hook" {
    metadata {
        name = "helm-hook"
    }

    rule {
        api_groups = ["stable.agones.dev", ""]
        resources  =  ["pods", "fleets", "fleetallocations", "fleetautoscalers", "gameservers", "gameserversets", "gameserverallocations"]
        verbs      = ["delete", "list", "get" ]
    }
}
resource "kubernetes_cluster_role" "cluster_admin2" {
    metadata {
        name = "cluster-admin2"
    }

    rule {
        api_groups = ["*"]
        resources  =  ["*"]
        verbs      = ["*" ]
    }
}