# Copyright 2019 Google LLC All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

provider "aws" {
  version = ">= 2.11"
  region  = var.region
}


resource "aws_vpc" "example" {
 cidr_block = "10.0.0.0/16"
 enable_dns_hostnames = true
 enable_dns_support = true
 tags = "${
   map(
    "Name", "terraform-eks",
    "kubernetes.io/cluster/example", "shared",
   )
 }"
}

resource "aws_vpc" "main" {
cidr_block = "10.0.0.0/16"
enable_dns_hostnames = true
enable_dns_support = true
tags = "${
   map(
    "Name", "terraform-eks",
    "kubernetes.io/cluster/example", "shared",
   )
}"
}

#
# main EKS terraform resource definition
#
resource "aws_eks_cluster" "main" {
  name = "${var.cluster_name}"
  worker_groups = [
    {
      name                          = "worker-group-1"
      instance_type                 = "t2.micro"
      asg_desired_capacity          = 5
      additional_security_group_ids = [aws_security_group.worker_group_mgmt_one.id]
    },
    {
      name                          = "worker-group-2"
      instance_type                 = "t2.micro"
      additional_security_group_ids = [aws_security_group.worker_group_mgmt_two.id]
      asg_desired_capacity          = 5
    },
  ]
}