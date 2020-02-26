echo '----> Installing Core'

kubectl create ns cloudbees-core
helm upgrade --install cloudbees-core cloudbees/cloudbees-core \
  --values ./helm/core.yml \
  --set OperationsCenter.HostName=$CORE_HOSTNAME \
  --set OperationsCenter.Ingress.tls.Host=$CORE_HOSTNAME \
  --namespace='cloudbees-core'


CORE_PASSWORD=$(kubectl -n cloudbees-core exec cjoc-0 -- sh -c "until cat /var/jenkins_home/secrets/initialAdminPassword 2>&-; do sleep 5; done")

echo '#### Core password: '$CORE_PASSWORD' ####'