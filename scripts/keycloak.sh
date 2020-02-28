echo '----> Installing Keycloak'

kubectl create ns keycloak
kubectl config set-context --current --namespace keycloak

helm upgrade --install keycloak codecentric/keycloak \
  --set keycloak.ingress.enabled=true \
  --set keycloak.ingress.hosts=$KEYCLOAK_HOSTNAME, \
  --set keycloak.ingress.tls.hosts=$KEYCLOAK_HOSTNAME, \
  --namespace='keycloak' --wait
