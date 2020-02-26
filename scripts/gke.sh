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

echo '----> Setup cluster admin permissions'
kubectl create clusterrolebinding cluster-admin-binding  --clusterrole cluster-admin  --user $(gcloud config get-value account)

echo '----> Setup custom storage class'
kubectl create -f ./k8s/storageclass.yml
kubectl annotate storageclass standard storageclass.kubernetes.io/is-default-class-
kubectl annotate storageclass ssd storageclass.kubernetes.io/is-default-class=true