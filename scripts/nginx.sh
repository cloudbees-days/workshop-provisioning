echo '----> Installing the nginx-ingress controller'

kubectl create ns ingress-nginx
helm upgrade --install \
  nginx-ingress stable/nginx-ingress \
  --values ./helm/nginx.yml \
  --version 1.4.0 \
  --namespace ingress-nginx

sleep 30