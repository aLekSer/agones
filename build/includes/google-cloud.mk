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

#    ____                   _         ____ _                 _
#   / ___| ___   ___   __ _| | ___   / ___| | ___  _   _  __| |
#  | |  _ / _ \ / _ \ / _` | |/ _ \ | |   | |/ _ \| | | |/ _` |
#  | |_| | (_) | (_) | (_| | |  __/ | |___| | (_) | |_| | (_| |
#   \____|\___/ \___/ \__, |_|\___|  \____|_|\___/ \__,_|\__,_|
#                     |___/

# Initialise the gcloud login and project configuration, if you are working with GCP
gcloud-init: ensure-build-config
	docker run --rm -it $(common_mounts) $(build_tag) gcloud init

# Creates and authenticates a small, 6 node GKE cluster to work against (2 nodes are used for agones-metrics and agones-system)
gcloud-test-cluster: GCP_CLUSTER_LEGACYABAC ?= false
gcloud-test-cluster: GCP_CLUSTER_NODEPOOL_INITIALNODECOUNT ?= 4
gcloud-test-cluster: GCP_CLUSTER_NODEPOOL_MACHINETYPE ?= n1-standard-4
gcloud-test-cluster: $(ensure-build-image)
	docker run --rm -it $(common_mounts) $(DOCKER_RUN_ARGS) $(build_tag) gcloud \
		deployment-manager deployments create $(GCP_CLUSTER_NAME)  \
		--properties cluster.zone:$(GCP_CLUSTER_ZONE),cluster.name:$(GCP_CLUSTER_NAME),cluster.nodePool.initialNodeCount:$(GCP_CLUSTER_NODEPOOL_INITIALNODECOUNT),cluster.nodePool.machineType:$(GCP_CLUSTER_NODEPOOL_MACHINETYPE),cluster.legacyAbac:$(GCP_CLUSTER_LEGACYABAC)\
		--template=$(mount_path)/build/gke-test-cluster/cluster.yml.jinja
	$(MAKE) gcloud-auth-cluster
	$(MAKE) setup-test-cluster

clean-gcloud-test-cluster: $(ensure-build-image)
	docker run --rm -it $(common_mounts) $(DOCKER_RUN_ARGS) $(build_tag) gcloud \
		deployment-manager deployments delete $(GCP_CLUSTER_NAME)

### Deploy cluster with Terraform
terraform-init:
	docker run --rm -it $(common_mounts) $(DOCKER_RUN_ARGS) $(build_tag) bash -c '\
	cd $(mount_path)/build && terraform init && gcloud auth application-default login'

terraform-clean:
	rm -r ./.terraform
	rm ./terraform.tfstate*

# Creates a cluster and install release version of Agones controller
# Version could be specified by AGONES_VERSION
gcloud-terraform-cluster: GCP_CLUSTER_LEGACYABAC ?= false
gcloud-terraform-cluster: GCP_CLUSTER_NODEPOOL_INITIALNODECOUNT ?= 4
gcloud-terraform-cluster: GCP_CLUSTER_NODEPOOL_MACHINETYPE ?= n1-standard-4
gcloud-terraform-cluster: AGONES_VERSION ?= 0.9.0
gcloud-terraform-cluster: $(ensure-build-image)
gcloud-terraform-cluster:
ifndef GCP_PROJECT
	$(eval GCP_PROJECT=$(shell sh -c "gcloud config get-value project 2> /dev/null"))
endif
	$(DOCKER_RUN) bash -c 'export TF_VAR_agones_version=$(AGONES_VERSION) && \
	    export TF_VAR_password=$(GKE_PASSWORD) && \
		cd $(mount_path)/build && terraform apply -auto-approve -var values_file="" \
		-var chart="agones" \
	 	-var "cluster={name=\"$(GCP_CLUSTER_NAME)\", machineType=\"$(GCP_CLUSTER_NODEPOOL_MACHINETYPE)\", \
		 zone=\"$(GCP_CLUSTER_ZONE)\", project=\"$(GCP_PROJECT)\", \
		 initialNodeCount=\"$(GCP_CLUSTER_NODEPOOL_INITIALNODECOUNT)\", \
		 legacyABAC=\"$(GCP_CLUSTER_LEGACYABAC)\"}"'
	$(MAKE) gcloud-auth-cluster

# Creates a cluster and install current version of Agones controller
# Set all necessary variables as `make install` does
gcloud-terraform-install: GCP_CLUSTER_LEGACYABAC ?= false
gcloud-terraform-install: GCP_CLUSTER_NODEPOOL_INITIALNODECOUNT ?= 4
gcloud-terraform-install: GCP_CLUSTER_NODEPOOL_MACHINETYPE ?= n1-standard-4
gcloud-terraform-install: ALWAYS_PULL_SIDECAR := true
gcloud-terraform-install: IMAGE_PULL_POLICY := "Always"
gcloud-terraform-install: PING_SERVICE_TYPE := "LoadBalancer"
gcloud-terraform-install: CRD_CLEANUP := true
gcloud-terraform-install:
ifndef GCP_PROJECT
	$(eval GCP_PROJECT=$(shell sh -c "gcloud config get-value project 2> /dev/null"))
endif
	$(DOCKER_RUN) bash -c 'export TF_VAR_password=$(GKE_PASSWORD) && \
		cd $(mount_path)/build && terraform apply -auto-approve -var agones_version="$(VERSION)" -var image_registry="$(REGISTRY)" \
		-var pull_policy="$(IMAGE_PULL_POLICY)" \
		-var always_pull_sidecar="$(ALWAYS_PULL_SIDECAR)" \
		-var image_pull_secret="$(IMAGE_PULL_SECRET)" \
		-var ping_service_type="$(PING_SERVICE_TYPE)" \
		-var crd_cleanup="$(CRD_CLEANUP)" \
		-var "cluster={name=\"$(GCP_CLUSTER_NAME)\", machineType=\"$(GCP_CLUSTER_NODEPOOL_MACHINETYPE)\", \
		 zone=\"$(GCP_CLUSTER_ZONE)\", project=\"$(GCP_PROJECT)\", \
		 initialNodeCount=\"$(GCP_CLUSTER_NODEPOOL_INITIALNODECOUNT)\", \
		 legacyABAC=\"$(GCP_CLUSTER_LEGACYABAC)\"}"'
	$(MAKE) gcloud-auth-cluster

gcloud-terraform-destroy-cluster:
	$(DOCKER_RUN) bash -c 'cd $(mount_path)/build && \
	 terraform destroy -auto-approve'

# Creates a gcloud cluster for end-to-end
# it installs also a consul cluster to handle build system concurrency using a distributed lock
gcloud-e2e-test-cluster: $(ensure-build-image)
	docker run --rm -it $(common_mounts) $(DOCKER_RUN_ARGS) $(build_tag) gcloud \
		deployment-manager deployments create e2e-test-cluster \
		--config=$(mount_path)/build/gke-test-cluster/cluster-e2e.yml
	GCP_CLUSTER_NAME=e2e-test-cluster GCP_CLUSTER_ZONE=us-west1-c $(MAKE) gcloud-auth-cluster
	docker run --rm $(common_mounts) $(DOCKER_RUN_ARGS) $(build_tag) \
		kubectl apply -f $(mount_path)/build/helm.yaml
	docker run --rm $(common_mounts) $(DOCKER_RUN_ARGS) $(build_tag) \
		helm init --service-account helm --wait
	docker run --rm $(common_mounts) $(DOCKER_RUN_ARGS) $(build_tag) \
		helm install --wait --set Replicas=1,uiService.type=ClusterIP --name consul stable/consul

# Deletes the gcloud e2e cluster and cleanup any left pvc volumes
clean-gcloud-e2e-test-cluster: $(ensure-build-image)
	docker run --rm $(common_mounts) $(DOCKER_RUN_ARGS) $(build_tag) \
		helm delete --purge consul && kubectl delete pvc -l component=consul-consul
	GCP_CLUSTER_NAME=e2e-test-cluster $(MAKE) clean-gcloud-test-cluster

# Pulls down authentication information for kubectl against a cluster, name can be specified through GCP_CLUSTER_NAME
# (defaults to 'test-cluster')
gcloud-auth-cluster: $(ensure-build-image)
	docker run --rm $(common_mounts) $(build_tag) gcloud config set container/cluster $(GCP_CLUSTER_NAME)
	docker run --rm $(common_mounts) $(build_tag) gcloud config set compute/zone $(GCP_CLUSTER_ZONE)
	docker run --rm $(common_mounts) $(build_tag) gcloud container clusters get-credentials $(GCP_CLUSTER_NAME)
	-docker run --rm $(common_mounts) $(build_tag) bash -c 'echo - n $$(gcloud config get-value account) | md5sum | cut -b-32 > /tmp/hash && \
	kubectl create clusterrolebinding cluster-admin-binding-$$(cat /tmp/hash) --clusterrole cluster-admin --user $$(gcloud config get-value account)'

# authenticate our docker configuration so that you can do a docker push directly
# to the gcr.io repository
gcloud-auth-docker: $(ensure-build-image)
	docker run --rm $(common_mounts) $(build_tag) gcloud auth print-access-token | docker login -u oauth2accesstoken --password-stdin https://gcr.io

# Clean the gcloud configuration
clean-gcloud-config:
	-sudo rm -r $(build_path)/.config