LB_SG_ID=$(aws cloudformation list-exports \
  --query "Exports[?Name=='mtier:LoadBalancerSGId'].Value" \
  --output text)

sed -i "s/LB_SG_PLACEHOLDER/$LB_SG_ID/" service_lb_manifest.yaml

ECR_URI=$(aws cloudformation list-exports \
  --query "Exports[?Name=='mtier:ErcRepository'].Value" \
  --output text)

sed -i "s/ECR_URI_PLACEHOLDER/$ECR_URI/" deployment_manifest.yaml


kubectl apply -f namespace_manifest.yaml
kubectl apply -f configmap_manifest.yaml
kubectl apply -f deployment_manifest.yaml
kubectl apply -f service_lb_manifest.yaml
