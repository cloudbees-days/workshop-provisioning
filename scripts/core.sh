echo '----> Installing Core'

kubectl create ns cloudbees-core
kubectl config set-context --current --namespace cloudbees-core

helm upgrade --install cloudbees-core cloudbees/cloudbees-core \
  --wait \
  --set OperationsCenter.HostName=$CORE_HOSTNAME \
  --set nginx-ingress.Enabled=false \
  --set OperationsCenter.Ingress.tls.Host=$CORE_HOSTNAME \
  --namespace='cloudbees-core' \
  --values ./helm/core.yml


CORE_PASSWORD=$(kubectl -n cloudbees-core exec cjoc-0 -- sh -c "until cat /var/jenkins_home/secrets/initialAdminPassword 2>&-; do sleep 5; done")

echo '#### Core password: '$CORE_PASSWORD' ####'

# while [[ $(curl --write-out %{http_code} --silent --output /dev/null -k https://$CORE_HOSTNAME/cjoc/login) -ne 200 ]]; do
#   echo "Waiting for Core to become available"
#   sleep 5
# done

# cd robot
# node setup_core.js --secret $CORE_PASSWORD --username ldonley --password changeme --email ldonley@cloudbees.com --url https://$CORE_HOSTNAME/cjoc/
# cd ..