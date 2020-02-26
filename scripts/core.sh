echo '----> Installing Core'

kubectl create ns cloudbees-core
helm upgrade --install cloudbees-core cloudbees/cloudbees-core \
  --values ./helm/core.yml \
  --set OperationsCenter.HostName=$CORE_HOSTNAME \
  --set OperationsCenter.Ingress.tls.Host=$CORE_HOSTNAME \
  --namespace='cloudbees-core'