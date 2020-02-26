echo '----> Installing the nginx-ingress controller'

helm install --namespace ingress-nginx \
  --name nginx-ingress stable/nginx-ingress \
  --values ./helm/nginx.yml \
  --version 1.4.0