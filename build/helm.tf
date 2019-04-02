variable "helm_version" {
  default = "v2.9.1"
}

variable "app_name" {
  default = "drupal"
}

resource "kubernetes_service_account" "tiller" {
  metadata {
    name      = "tiller"
    namespace = "kube-system"
  }

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
  namespace       = "${kubernetes_service_account.tiller.metadata.0.namespace}"
  tiller_image    = "gcr.io/kubernetes-helm/tiller:v2.11.0"

/*
  kubernetes {
    config_path = "~/.kube/${var.env}"
  }
  */
}
/*
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

resource "kubernetes_namespace" "agones-system" {
  metadata {
    annotations {
      name = "example-annotation"
    }

    labels {
      mylabel = "label-value"
    }

    name = "agones-system"
  }

}
resource "kubernetes_service_account" "tiller_service_account" {
  metadata {
    name = "tiller"
  }
}

resource "kubernetes_cluster_role_binding" "tiller" {
  metadata {
    name = "tiller"
  }

  subject {
    kind = "User"
    name = "system:serviceaccount:kube-system:tiller"
  }

  role_ref {
    kind  = "ClusterRole"
    name = "cluster-admin"
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
*/
data "google_client_config" "current" {}


resource "random_id" "endpoint-name" {
  byte_length = 2
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