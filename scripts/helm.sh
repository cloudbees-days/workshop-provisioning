echo '----> Setting up Tiller'
kubectl -n kube-system create serviceaccount tiller

kubectl create clusterrolebinding tiller \
  --clusterrole=cluster-admin \
  --serviceaccount=kube-system:tiller

echo '----> Initializing Helm'
helm init --wait --service-account tiller
helm repo add cloudbees https://charts.cloudbees.com/public/cloudbees
helm repo update

sleep 5