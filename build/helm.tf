variable "helm_version" {
  default = "v2.9.1"
}

variable "app_name" {
  default = "drupal"
}

variable "acme_email" {}

resource "google_container_cluster" "default" {
  name               = "tf-gke-helm"
  zone               = "us-central1-b"
  initial_node_count = 3
  network            = "agones-network"
  subnetwork         = "agones-network"
  project = "agones-alexander"

  // Use legacy ABAC until these issues are resolved: 
  //   https://github.com/mcuadros/terraform-provider-helm/issues/56
  //   https://github.com/terraform-providers/terraform-provider-kubernetes/pull/73
  enable_legacy_abac = true

  // Wait for the GCE LB controller to cleanup the resources.
  provisioner "local-exec" {
    when    = "destroy"
    command = "sleep 90"
  }
}
provider "helm" {
  tiller_image = "gcr.io/kubernetes-helm/tiller:${var.helm_version}"

  kubernetes {
    host                   = "${google_container_cluster.default.endpoint}"
    token                  = "${data.google_client_config.current.access_token}"
    client_certificate     = "${base64decode(google_container_cluster.default.master_auth.0.client_certificate)}"
    client_key             = "${base64decode(google_container_cluster.default.master_auth.0.client_key)}"
    cluster_ca_certificate = "${base64decode(google_container_cluster.default.master_auth.0.cluster_ca_certificate)}"
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
  repository = "${data.helm_repository.agones.metadata.0.name}"
  chart = "agones"
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
