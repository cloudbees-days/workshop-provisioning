echo '----> Provisioning GCP environment'

# Create the network rule
network_check=$(gcloud compute firewall-rules list --format=json | grep freeipa)
if [[ -n $network_check ]] ; then
  echo "Firewall rule already exists"
else
gcloud compute firewall-rules create freeipa \
  --project=$CLUSTER_PROJECT \
  --direction=INGRESS \
  --priority=1000 \
  --network=default \
  --action=ALLOW \
  --rules=tcp:22,tcp:80,tcp:443,tcp:389,tcp:636,tcp:88,tcp:464,tcp:53,udp:88,udp:464,udp:53,udp:123 \
  --source-ranges=0.0.0.0/0 \
  --target-tags=freeipa
fi

# Create vm
vm_check=$(gcloud compute instances list | grep $FREEIPA_VM_NAME)
if [[ -n $vm_check ]] ; then
  echo "VM "$FREEIPA_VM_NAME" already exists."
else
  gcloud beta compute instances create $FREEIPA_VM_NAME \
    --project=$CLUSTER_PROJECT  \
    --zone=$REGION \
    --hostname=$FREEIPA_HOSTNAME \
    --machine-type=n1-standard-1 \
    --subnet=default \
    --network-tier=PREMIUM \
    --maintenance-policy=MIGRATE \
    --scopes=https://www.googleapis.com/auth/devstorage.read_only,https://www.googleapis.com/auth/logging.write,https://www.googleapis.com/auth/monitoring.write,https://www.googleapis.com/auth/servicecontrol,https://www.googleapis.com/auth/service.management.readonly,https://www.googleapis.com/auth/trace.append \
    --tags=http-server,https-server,freeipa \
    --image=centos-7-v20200309 \
    --image-project=centos-cloud \
    --boot-disk-size=10GB \
    --boot-disk-type=pd-standard \
    --boot-disk-device-name=$FREEIPA_VM_NAME \
    --reservation-affinity=any 
fi

VM_IP=$(gcloud compute instances describe $FREEIPA_VM_NAME --zone=$REGION --format='get(networkInterfaces[0].accessConfigs[0].natIP)')

sshe() {
  ssh -o 'StrictHostKeyChecking no' $VM_USER@$VM_IP "$@"
}

if sshe command -v docker 2>/dev/null ; then
  echo "Docker already installed."
  sshe docker version
else
  sshe curl https://get.docker.com/ | sshe bash -
  sshe sudo usermod -aG docker $VM_USER
  sshe sudo systemctl start docker
  sshe sudo systemctl enable docker
fi

sshe sudo firewall-cmd --add-service=freeipa-ldap --add-service=freeipa-ldaps
sshe sudo firewall-cmd --add-service=freeipa-ldap --add-service=freeipa-ldaps --permanent

echo '----> Setting up DNS record'

rm -f transaction.yaml

gcloud config set project $DNS_PROJECT

# Grab the current IP address of the DNS record
OLD_IP=$(gcloud dns record-sets list --zone=$DNS_ZONE | grep $FREEIPA_HOSTNAME | awk '{print $4}')
CURRENT_TTL=$(gcloud dns record-sets list --zone=$DNS_ZONE | grep $FREEIPA_HOSTNAME | awk '{print $3}')

if [[ $OLD_IP != $VM_IP ]]; then
  # Start the transaction
  gcloud dns record-sets transaction start --zone=$DNS_ZONE
  if [[ $OLD_IP ]]; then
    gcloud dns record-sets transaction remove $OLD_IP --name=$FREEIPA_HOSTNAME \
    --ttl=$CURRENT_TTL --type="A" --zone=$DNS_ZONE
  fi
  gcloud dns record-sets transaction add $VM_IP --name=$FREEIPA_HOSTNAME \
  --ttl="30" --type="A" --zone=$DNS_ZONE
  # Run the transaction
  gcloud dns record-sets transaction execute --zone=$DNS_ZONE
else
  echo "No need to update DNS for FreeIPA"
fi

# Switch back to the main GCP project
gcloud config set project $CLUSTER_PROJECT

echo "----> Setting up FreeIPA"
sshe sudo mkdir /var/lib/ipa-data
sshe sudo setsebool -P container_manage_cgroup 1
sshe docker run --name freeipa-server-container -ti \
    -h $FREEIPA_HOSTNAME \
    -e PASSWORD=changeme \
    -e IPA_SERVER_IP=$VM_IP \
    -p 53:53/udp -p 53:53 \
    -p 80:80 -p 443:443 -p 389:389 -p 636:636 -p 88:88 -p 464:464 \
    -p 88:88/udp -p 464:464/udp -p 123:123/udp \
    -v /var/lib/ipa-data:/data:Z -d freeipa/freeipa-server ipa-server-install