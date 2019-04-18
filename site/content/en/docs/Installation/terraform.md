---
title: "Install Agones using Terraform"
linkTitle: "Install with Terraform"
weight: 4
description: >
  This chart install the Agones application and defines deployment on a [Kubernetes](http://kubernetes.io) cluster using the Terraform.

---

## Prerequisites

- Terraform v0.11.13
- [Helm](https://docs.helm.sh/helm/) package manager 2.10.0+
- Access to Google Cloud Kubernetes Engine
- `gcloud` utility installed
- Git

## Installing the Agones as Terraform submodule

You can use Terraform to provision your GKE cluster and install agones on it using Helm Terraform provider.

The example of submodule configuration could be found here:
 {{< ghlink href="examples/terraform-submodule/module.tf" >}}Terraform configuration with Agones submodule{{< /ghlink >}}

First you should run:
```
terraform init
```

It would use git to clone the current master of Agones, and use `./build` folder as starting point of Agones submodule, which contains all necessary Terraform configuration files.

Next step you should make sure that you authenticate using gcloud:
```
gcloud auth application-default login
```

Now you are able to deploy properly configured GKE cluster and specify release version of Agones you want to use:
```
terraform apply -var project="<YOUR_GCP_ProjectID>" -var agones_version="0.9.0"
```

Run next command to setup your kubectl:
```
gcloud container clusters get-credentials --zone us-west1-c  test-cluster
```

You would see:
```
Fetching cluster endpoint and auth data.
kubeconfig entry generated for test-cluster.
```

Check that your has access to kubernetes cluster:
```
kubectl get nodes
```

Make sure you have 6 nodes in `Ready` state.

## Uninstall the Agones and delete GKE cluster

Run next command to delete all Terraform provisioned resources:
```
terraform destroy
```
