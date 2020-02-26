#!/bin/bash

# Load environment variables from .env
source .env

echo '----> Initiating destruction...'

# Cleaning DNS records
. ./scripts/cleanup-dns.sh

# Delete cluster
. ./scripts/delete-cluster.sh