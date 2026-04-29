LB_SG_ID=$(aws cloudformation list-exports \
  --query "Exports[?Name=='mtier:LoadBalancerSGId'].Value" \
  --output text)

sed -i "s|LB_SG_PLACEHOLDER|$LB_SG_ID|" Part-2-App-Container-Setup/manifests/service_lb_manifest.yaml

ECR_URI=$(aws cloudformation list-exports \
  --query "Exports[?Name=='mtier:ErcRepository'].Value" \
  --output text)

sed -i "s|ECR_URI_PLACEHOLDER|$ECR_URI|" Part-2-App-Container-Setup/manifests/deployment_manifest.yaml

kubectl apply -f Part-2-App-Container-Setup/manifests/namespace_manifest.yaml
kubectl apply -f Part-2-App-Container-Setup/manifests/configmap_manifest.yaml
kubectl apply -f Part-2-App-Container-Setup/manifests/deployment_manifest.yaml
kubectl apply -f Part-2-App-Container-Setup/manifests/service_lb_manifest.yaml