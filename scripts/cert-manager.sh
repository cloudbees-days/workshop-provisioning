echo '----> Deploying cert-manager'

kubectl create namespace cert-manager

kubectl apply --validate=false -f https://github.com/jetstack/cert-manager/releases/download/v0.13.1/cert-manager.yaml

sleep 20

sed 's/REPLACE_EMAIL/'$EMAIL'/' ./k8s/cluster-issuers.yml | kubectl apply -f -