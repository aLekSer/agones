# Set region for regional GKE clusters or Zone for Zonal clusters
#CLOUDSDK_COMPUTE_REGION=""
CLOUDSDK_COMPUTE_ZONE=us-west1-c

# Name of GKE cluster
CLOUDSDK_CONTAINER_CLUSTER=test-cluster

# (Optional) Project of GKE Cluster, only if you want helm to authenticate
# to a GKE cluster in another project (requires IAM Service Accounts are properly setup)
GCLOUD_PROJECT=agones-alexander

gcloud container clusters get-credentials --zone "$CLOUDSDK_COMPUTE_ZONE" "$CLOUDSDK_CONTAINER_CLUSTER"

gcloud builds submit . --config=./test/load/cloudbuild.yaml --substitutions=_VERSION=1.5.0-1f60bac
#gcloud builds submit . --config=cloudbuild.yaml

