echo '----> Installing Nexus'

kubectl create ns nexus
kubectl config set-context --current --namespace nexus

helm upgrade --install nexus stable/sonatype-nexus \
  --values ./helm/nexus.yml \
  --set nexusProxy.env.nexusDockerHost=$DOCKER_HOSTNAME \
  --set nexusProxy.env.nexusHttpHost=$NEXUS_HOSTNAME \
  --namespace='nexus' --wait


# CORE_PASSWORD=$(kubectl -n cloudbees-core exec cjoc-0 -- sh -c "until cat /var/jenkins_home/secrets/initialAdminPassword 2>&-; do sleep 5; done")

# echo '#### Core password: '$CORE_PASSWORD' ####'