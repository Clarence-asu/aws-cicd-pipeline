LB_SG_ID=$(aws cloudformation list-exports \
  --query "Exports[?Name=='mtier:LoadBalancerSGId'].Value" \
  --output text)

sed -i "s|LB_SG_PLACEHOLDER|$LB_SG_ID|" manifests/service_lb_manifest.yaml

ECR_URI=$(aws cloudformation list-exports \
  --query "Exports[?Name=='mtier:ErcRepository'].Value" \
  --output text)

sed -i "s|ECR_URI_PLACEHOLDER|$ECR_URI|" manifests/deployment_manifest.yaml

kubectl apply -f manifests/namespace_manifest.yaml
kubectl apply -f manifests/configmap_manifest.yaml
kubectl apply -f manifests/deployment_manifest.yaml
kubectl apply -f manifests/service_lb_manifest.yaml