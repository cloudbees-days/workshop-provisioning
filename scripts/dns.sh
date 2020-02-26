echo '----> Setting up DNS records'

rm transaction.yaml
INGRESS_IP=$(kubectl get -n ingress-nginx svc | grep nginx-ingress-controller | awk '{print $4}')

gcloud config set project $DNS_PROJECT
gcloud dns record-sets list --zone=$DNS_ZONE
gcloud dns record-sets transaction start --zone=$DNS_ZONE
gcloud dns record-sets transaction add $INGRESS_IP --name=*.$WILDCARD_HOSTNAME \
--ttl="30" --type="A" --zone=$DNS_ZONE
gcloud dns record-sets transaction add $INGRESS_IP --name=$CORE_HOSTNAME \
--ttl="30" --type="A" --zone=$DNS_ZONE
gcloud dns record-sets transaction add $INGRESS_IP --name=$FLOW_HOSTNAME \
--ttl="30" --type="A" --zone=$DNS_ZONE
# Add nexus hostnames
gcloud dns record-sets transaction add $INGRESS_IP --name=$NEXUS_HOSTNAME \
--ttl="30" --type="A" --zone=$DNS_ZONE
# Add docker hostnames
gcloud dns record-sets transaction add $INGRESS_IP --name=$DOCKER_HOSTNAME \
--ttl="30" --type="A" --zone=$DNS_ZONE
# Run the transaction
gcloud dns record-sets transaction execute --zone=$DNS_ZONE

gcloud config set project $CLUSTER_PROJECT