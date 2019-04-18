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
//  terraform apply -var project="<YOUR_GCP_ProjectID>" -var agones_version="0.9.0"
variable "password" {
   default= ""
}
variable "agones_version" {
  default="0.9.0"
}
variable "project" {default = "agones"}
module "agones" {
  #source = "git::https://github.com/GoogleCloudPlatform/agones.git//build/?ref=master"
  source = "git::https://github.com/alekser/agones.git//build/?ref=feature/helm-terraform"

  password     = "${var.password}"
  cluster = {
      "zone"             = "us-west1-c"
      "name"             = "test-cluster"
      "machineType"      = "n1-standard-4"
      "initialNodeCount" = "4"
      "legacyAbac"       = false
      "project"          = "${var.project}"
  }
  agones_version = "${var.agones_version}"
  values_file=""
  chart="agones"
}