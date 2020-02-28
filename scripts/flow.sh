echo '----> Install Flow'

kubectl create namespace flow 
kubectl config set-context --current --namespace=flow

# Create service account so gcloud commands can run
kubectl create serviceaccount gcloud-sa -n flow
gcloud iam service-accounts add-iam-policy-binding \
  --role roles/iam.workloadIdentityUser \
  --member "serviceAccount:"$CLUSTER_PROJECT".svc.id.goog[flow/gcloud-sa]" \
  gcloud-sa@$CLUSTER_PROJECT.iam.gserviceaccount.com
kubectl annotate serviceaccount -n flow gcloud-sa \
  iam.gke.io/gcp-service-account=gcloud-sa@$CLUSTER_PROJECT.iam.gserviceaccount.com

echo '----> Installing Flow with the Helm chart'

helm upgrade --install flow cloudbees/cloudbees-flow \
  --wait \
  --set ingress.host=$FLOW_HOSTNAME \
  --values ./helm/flow.yml


kubectl patch deployment flow-bound-agent -p "$(cat ./k8s/flowAgentPatch.yaml)"
