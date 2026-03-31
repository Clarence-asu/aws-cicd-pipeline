LB_SG_ID=$(aws cloudformation list-exports \
  --query "Exports[?Name=='mtier:LoadBalancerSGId'].Value" \
  --output text)

sed -i "s/LB_SG_PLACEHOLDER/$LB_SG_ID/" service_lb_manifest.yaml
