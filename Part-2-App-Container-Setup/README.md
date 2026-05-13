Here's the updated README ready to paste into GitHub:

---

# Part 2 — Application & Container Setup

This milestone covers everything needed to containerize the nginx web application and prepare it for deployment to the EKS cluster. It includes the Kubernetes manifests, a custom nginx configuration, a Dockerfile, an ECR repository for storing the Docker image, security group setup for the load balancer and worker nodes, and an automation script that ties everything together at deploy time.

---

## What Was Built

### Web Application
A simple nginx web application consisting of two files:

- `index.html` — a custom HTML page that displays "CI/CD Pipeline — Deployed Successfully" when the app is live. This serves as proof that the full pipeline worked end to end.
- `nginx.conf` — a custom nginx configuration that tells nginx to listen on port 80, serve files from `/usr/share/nginx/html`, and return `index.html` as the default page for any incoming request.

### Dockerfile
A minimal Dockerfile that uses the official nginx image as the base and exposes port 80. The nginx configuration and HTML content are not baked into the image — they get injected at runtime via the ConfigMap. This means configuration changes don't require rebuilding the image.

### Kubernetes Manifests
Four manifests were created and must be applied in this order:

**namespace_manifest.yaml** — creates the `dev` namespace that all other resources are deployed into.

**configmap_manifest.yaml** — stores the contents of `nginx.conf` and `index.html` as key-value pairs. When the pod starts, Kubernetes mounts the ConfigMap into the container, placing `nginx.conf` at `/etc/nginx/nginx.conf` and `index.html` at `/usr/share/nginx/html/index.html`. nginx reads both files on startup and knows how to behave.

**deployment_manifest.yaml** — defines the deployment with 2 replicas running the nginx image pulled from ECR. The image line uses a placeholder `ECR_URI_PLACEHOLDER` that gets replaced at deploy time by the automation script. The deployment targets pods with the label `app: my-app`.

**service_lb_manifest.yaml** — creates a LoadBalancer service in the `dev` namespace that routes port 80 traffic to pods with the label `app: my-app`. An annotation references the `LoadBalancerSG` created in CloudFormation using a placeholder `LB_SG_PLACEHOLDER` that also gets replaced at deploy time.

### Security Groups
Two security groups were added to the worker node CloudFormation template:

**LoadBalancerSG** — allows inbound TCP port 80 from the internet (`0.0.0.0/0`) and outbound TCP port 80 to the VPC CIDR (`10.0.0.0/16`). This SG gets attached to the AWS Load Balancer provisioned by Kubernetes when the service manifest is applied.

**NodeGroupSG** — allows inbound TCP port 80 from the `LoadBalancerSG` only, and all outbound traffic. This locks down worker node access so only the load balancer can send traffic to the pods.

Both SG IDs are exported as CloudFormation outputs so the automation script can pull them at deploy time.

### ECR Repository
A separate CloudFormation template `ecr_repository_template.yaml` was created to provision a private ECR repository named `my-nginx-app`. The repository URI is exported as a CloudFormation output (`mtier:ErcRepository`) so the automation script can inject it into the deployment manifest automatically on every deploy. This eliminates the need to hardcode the URI — which would break every time the stack is torn down and redeployed since ECR generates a new URI each time.

### Automation Script
`deploy.sh` runs on the bastion host after all CloudFormation stacks are deployed. It does three things:

1. Pulls the `LoadBalancerSG` ID from CloudFormation exports and injects it into the service manifest, replacing `LB_SG_PLACEHOLDER`
2. Pulls the ECR repository URI from CloudFormation exports and injects it into the deployment manifest, replacing `ECR_URI_PLACEHOLDER`
3. Applies all four manifests to the cluster in the correct order

This script ensures that no values are hardcoded anywhere in the manifests. Every deploy pulls fresh values directly from the infrastructure.

### .gitattributes
A `.gitattributes` file was added to the root of the repo to enforce LF line endings across all files. Without this, Windows machines push CRLF line endings which break bash scripts and YAML files when they run inside Linux-based CodeBuild containers. Adding `* text=auto eol=lf` ensures consistent line endings regardless of the developer's OS.

---

## CloudFormation Changes to Existing Templates

### worker_nodes_template.yaml
- Added `NodeGroupSG` resource with inbound port 80 from `LoadBalancerSG`
- Added `LoadBalancerSG` resource with inbound port 80 from internet and outbound port 80 to VPC
- Added `LoadBalancerSGId` output exporting the LB SG ID for use in the automation script

### eks_cluster_template.yaml
- Added `AccessConfig: AuthenticationMode: API_AND_CONFIG_MAP` to the EKS cluster resource
- Added `BastionAccessEntry` resource that registers the SSM IAM role as a recognized identity inside EKS with cluster admin access — this replaced the manual process of adding the role through the EKS console on every deploy

---

## Deploy Order

```
1.  Part 1 - Network Stack          ← deploy first
2.  Part 2 - EKS Cluster Stack      ← needs VpcId and PrivateSubnets
3.  Part 2 - Worker Node Stack      ← needs PrivateSubnets
4.  Part 2 - ECR Repository Stack
5.  Part 4 - S3 Artifacts Stack
6.  Part 3 - CodeBuild Stack
7.  Part 5 - CloudWatch Stack
8.  Part 5 - SNS Stack              ← must come before CodePipeline
9.  Part 4 - CodePipeline Stack     ← imports SNS export
10. Part 5 - Lambda Stack
11. Part 5 - EventBridge Stack
12. Connect to bastion via SSM
13. Run deploy.sh to inject values and apply manifests
```

---

## Teardown Order

```
1.  kubectl delete namespace dev    ← removes all resources in the namespace
2.  Delete EventBridge stack
3.  Delete Lambda stack
4.  Delete SNS stack
5.  Delete CloudWatch stack
6.  Delete CodePipeline stack
7.  Delete CodeBuild stack
8.  Delete S3 stack                 ← empty bucket first
9.  Delete ECR stack                ← delete images first
10. Delete Worker Node stack
11. Delete EKS Cluster stack
12. Delete VPC stack
```

---

## Obstacles Encountered

### LoadBalancerSG CloudFormation Errors
The `LoadBalancerSG` failed to create three times during stack deployment before getting it right.

The first failure was a CIDR typo — `10.0.0.0./16` had an extra period before the `/16`. CloudFormation rejected it with a malformed CIDR block error.

The second failure came from using `IpProtocol: -1` alongside `FromPort` and `ToPort`. AWS doesn't allow port ranges when the protocol is set to `-1` (all traffic) because `-1` already covers everything. Removing the port lines fixed it.

The fix: when using `-1` don't include ports, when using `tcp` always include both `FromPort` and `ToPort`.

### BastionAccessEntry — Manual to Automated
Initially the SSM IAM role had to be manually added to the EKS cluster through the console after every stack deploy. Without this step `kubectl get nodes` would return a credentials error because EKS didn't recognize the bastion's IAM role as an authorized identity.

The fix was adding two things to the EKS cluster template. First, `AccessConfig: AuthenticationMode: API_AND_CONFIG_MAP` was added to the cluster resource — this tells EKS to accept the newer access entry method instead of relying solely on the `aws-auth` ConfigMap. Second, a `BastionAccessEntry` resource was added that registers the SSM IAM role with cluster admin permissions automatically when the stack deploys. The `DependsOn: EksCluster` ensures the access entry only gets created after the cluster exists.

This eliminated the manual console step entirely. Every stack deploy now configures access automatically.