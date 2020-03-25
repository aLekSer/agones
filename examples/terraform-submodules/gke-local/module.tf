// Copyright 2019 Google LLC All Rights Reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.


// Run:
//  terraform apply -var project="<YOUR_GCP_ProjectID>" [-var agones_version="1.4.0"]

provider "google" {
  version = "~> 2.10"
}

provider "google-beta" {
  version = "~> 2.10"
}

variable "project" {
  default = ""
}

variable "name" {
  default = "agones-terraform-example"
}

// Install latest version of agones
variable "agones_version" {
  default = ""
}

variable "machine_type" {
  default = "n1-standard-4"
}

// Note: This is the number of gameserver nodes. The Agones module will automatically create an additional
// two node pools with 1 node each for "agones-system" and "agones-metrics".
variable "node_count" {
  default = "4"
}

variable "zone" {
  default     = "us-west1-c"
  description = "The GCP zone to create the cluster in"
}

variable "network" {
  default     = "default"
  description = "The name of the VPC network to attach the cluster and firewall rule to"
}

module "gke_cluster" {
  source = "../../../install/terraform/modules/gke"

  cluster = {
    "name"             = var.name
    "zone"             = var.zone
    "machineType"      = var.machine_type
    "initialNodeCount" = var.node_count
    "project"          = var.project
    "network"          = var.network
  }
}

module "helm_agones" {
  source = "../../../install/terraform/modules/helm"

  agones_version         = var.agones_version
  values_file            = ""
  chart                  = "agones"
  host                   = module.gke_cluster.host
  token                  = module.gke_cluster.token
  cluster_ca_certificate = module.gke_cluster.cluster_ca_certificate
  service_account = module.gke_cluster.service_account
}

output "host" {
  value = module.gke_cluster.host
}
output "token" {
  value = module.gke_cluster.token
}
output "cluster_ca_certificate" {
  value = module.gke_cluster.cluster_ca_certificate
}
