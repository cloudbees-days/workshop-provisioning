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


FLOW_SERVER_POD=$(kubectl get pods | grep flow-server | awk '{print $CLUSTER_NAME}')

FLOW_SERVER_STATUS=$(kubectl exec $FLOW_SERVER_POD -- /opt/cbflow/health-check)
TARGET_STATUS="OK Server status: 'running'"

echo '----> Waiting for the Flow server to come online'
until [ "$FLOW_SERVER_STATUS" == "$TARGET_STATUS" ]; do 
  sleep 15;
  FLOW_SERVER_STATUS=$(kubectl exec $FLOW_SERVER_POD -- /opt/cbflow/health-check);
done

kubectl patch deployment flow-bound-agent -p "$(cat ./k8s/flowAgentPatch.yaml)"

# Create Users and resourcePools
echo '----> Adding users to Flow'
kubectl exec $FLOW_SERVER_POD -- groupadd flow
kubectl exec $FLOW_SERVER_POD -- useradd -g flow flow
