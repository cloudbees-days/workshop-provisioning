#!/bin/bash

# Load environment variables from .env
source .env

echo '----> Provisioning cluster '$CLUSTER_NAME' in region '$REGION' in project '$CLUSTER_PROJECT'.'
gcloud config set project $CLUSTER_PROJECT

# Making runtime directory for storing artifacts - toggle with $SAVE_RUN environment variable
mkdir run

# Provision a GKE cluster
. ./scripts/gke.sh

# Initialize Helm
. ./scripts/helm.sh

# Install nginx ingress controller
. ./scripts/nginx.sh

# Install cert-manager
. ./scripts/cert-manager.sh

# Setting up DNS records
. ./scripts/dns.sh

# Install Core
. ./scripts/core.sh

# Install Flow
. ./scripts/flow.sh

# Install Nexus
. ./scripts/nexus.sh