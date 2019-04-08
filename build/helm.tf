variable "helm_version" {
  default = "v2.9.1"
}


resource "kubernetes_service_account" "tiller" {
  metadata {
    name      = "tiller"
    namespace = "kube-system"
  }
  depends_on = ["google_container_cluster.primary"]

  automount_service_account_token = true
}

resource "kubernetes_cluster_role_binding" "tiller" {
  metadata {
    name = "tiller"
  }

  role_ref {
    kind      = "ClusterRole"
    name      = "cluster-admin"
    api_group = "rbac.authorization.k8s.io"
  }

  subject {
    kind = "ServiceAccount"
    name = "tiller"

    api_group = ""
    namespace = "kube-system"
  }
}

provider "helm" {
  version = "~> 0.7"

  debug           = true
  install_tiller  = true
  service_account = "${kubernetes_service_account.tiller.metadata.0.name}"
  #namespace       = "${kubernetes_service_account.tiller.metadata.0.namespace}"
  tiller_image    = "gcr.io/kubernetes-helm/tiller:v2.12.3"

  kubernetes {
  load_config_file = false
    host                   = "https://${google_container_cluster.primary.endpoint}"
  token = "${data.google_client_config.default.access_token}"
  cluster_ca_certificate = "${base64decode(google_container_cluster.primary.master_auth.0.cluster_ca_certificate)}"
  /*
    host                   = "https://${google_container_cluster.primary.endpoint}"
    cluster_ca_certificate = "${base64decode(google_container_cluster.primary.master_auth.0.cluster_ca_certificate)}"
    client_certificate     = "${base64decode(google_container_cluster.primary.master_auth.0.client_certificate)}"
    client_key             = "${base64decode(google_container_cluster.primary.master_auth.0.client_key)}"
 */
  }
  
}
/*
  kubernetes {
    config_path = "~/.kube/${var.env}"
}
*/

data "google_client_config" "current" {}


data "helm_repository" "agones" {
    name = "agones"
    url  = "https://agones.dev/chart/stable"
}
resource "helm_release" "agones" {
  name  = "kube-lego"
  chart = "stable/kube-lego"
}
resource "helm_release" "agones2" {
  #depends_on = ["kubernetes_cluster_role_binding.tiller"]
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
  version = "0.9.0-rc"
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


data "google_client_config" "default" {}

provider "kubernetes" {
  load_config_file = false
    host                   = "https://${google_container_cluster.primary.endpoint}"
  token = "${data.google_client_config.default.access_token}"
  cluster_ca_certificate = "${base64decode(google_container_cluster.primary.master_auth.0.cluster_ca_certificate)}"

   # cluster_ca_certificate = "${base64decode(google_container_cluster.primary.master_auth.0.cluster_ca_certificate)}"
   # client_certificate     = "${base64decode(google_container_cluster.primary.master_auth.0.client_certificate)}"
   # client_key             = "${base64decode(google_container_cluster.primary.master_auth.0.client_key)}"
}

/*
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
*/

resource "kubernetes_cluster_role" "tiller-manager" {
    metadata {
        name = "tiller-manager"
    }

    rule {
      
        api_groups = ["", "extensions", "apps"]
        resources  =  ["configmaps", "secrets"]
        verbs      = ["*" ]
    }
} 

resource "kubernetes_cluster_role_binding" "tiller2" {
  metadata {
    name = "tiller2"
  }

  role_ref {
    kind      = "ClusterRole"
    name      = "tiller-manager"
    api_group = "rbac.authorization.k8s.io"
  }

  subject {
    kind = "ServiceAccount"
    name = "tiller"

    api_group = ""
    namespace = "kube-system"
  }
}