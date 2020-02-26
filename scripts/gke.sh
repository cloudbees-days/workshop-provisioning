echo '----> Provisioning GKE cluster'
gcloud beta container clusters create $CLUSTER_NAME \
--cluster-version=1.14.10-gke.17 \
--machine-type=n2-standard-4 \
--num-nodes=2 \
--region=$REGION \
--verbosity=none \
--scopes=cloud-platform \
--enable-autoscaling \
--min-nodes="0" \
--max-nodes="5" \
--identity-namespace=$CLUSTER_PROJECT.svc.id.goog

echo '----> Setting up kubectl'
gcloud container clusters get-credentials $CLUSTER_NAME --zone $REGION --project $CLUSTER_PROJECT