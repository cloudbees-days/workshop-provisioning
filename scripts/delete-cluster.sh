echo '----> Deleting cluster'
gcloud beta container clusters delete $CLUSTER_NAME \
--region=$REGION -q