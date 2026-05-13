Here's the updated README with those two obstacles removed:

---

# Part 4 — Pipeline Setup

## Overview

This milestone connects all previously built infrastructure into a fully automated CI/CD pipeline. A code push to the main branch on GitHub automatically triggers the pipeline, builds a Docker image, pushes it to ECR, and deploys it to the EKS cluster. In Milestone 7 the pipeline was extended to include a manual approval gate between the build and deploy stages.

---

## Files

- `s3_cf_template.yaml` — CloudFormation template for the S3 artifacts bucket
- `code_pipeline_template.yaml` — CloudFormation template for the CodePipeline IAM role and pipeline

---

## What Was Built

### S3 Artifacts Bucket (s3_cf_template.yaml)

Stores artifacts passed between pipeline stages.

**Key decisions:**
- **BucketNamespace: global** — avoids exposing account ID in the bucket name
- Versioning enabled — required by CodePipeline
- AES256 encryption and full public access block — security best practice
- Manual bucket emptying required before stack deletion — Lambda automation noted as future improvement

### CodePipeline IAM Role (code_pipeline_template.yaml)

Grants CodePipeline the permissions it needs to orchestrate the pipeline.

**Policies:**
- **codepipeline-policy** — pipeline management actions
- **s3-pipeline-policy** — read/write to artifacts bucket including `/*` for object-level access
- **codebuild-pipeline-policy** — start and monitor builds
- **codestar-policy** — use GitHub connection via CodeStar
- **sns-approval-policy** — publish to SNS topic for manual approval notifications (added in Milestone 7)

### CodePipeline (code_pipeline_template.yaml)

Connects GitHub to CodeBuild and orchestrates the full pipeline flow.

**Stages:**
- **Source** — monitors main branch via CodeStar connection to GitHub. Outputs SourceOutput artifact
- **Build** — passes SourceOutput to CodeBuild, runs `buildspec_build.yml` via BuildspecOverride
- **Approve** — pauses pipeline and sends SNS email notification to reviewer. Pipeline waits for manual approval before proceeding (added in Milestone 7)
- **Deploy** — passes SourceOutput to CodeBuild, runs `buildspec_deploy.yml` via BuildspecOverride (added in Milestone 7)

**Key configuration:**
- **PipelineType: V2** — enables triggers and pipeline variables
- **Triggers block with GitConfiguration** — automatically fires on push to main
- **BuildspecOverride** — each CodeBuild stage references its own buildspec file by path

---

## CodeBuild Updates

### S3 Policy Added
CodeBuild role required S3 read permissions to download source artifacts from the pipeline bucket. Both bucket ARN and `/*` object-level ARN included.

### CloudFormation Policy Added
`cloudformation:ListExports` required by deploy.sh to query stack exports at runtime.

### CodeBuildAccessEntry Added
Instead of manually editing the EKS aws-auth ConfigMap after every deploy, an `AWS::EKS::AccessEntry` resource was added to the CodeBuild template. This fully automates EKS access on every stack deploy — no manual steps required.

---

## buildspec.yml Updates

- Docker build command updated to point to `Part-2-App-Container-Setup/apps/`
- `deploy.sh` added to post_build phase before kubectl set image
- Deployment name corrected to `my-app`
- Namespace corrected to `dev`
- Base image changed from `nginx:latest` to `public.ecr.aws/nginx/nginx:latest` to avoid Docker Hub rate limits

---

## deploy.sh Updates

All manifest paths updated to include full `Part-2-App-Container-Setup/manifests/` prefix for CodeBuild execution context.

---

## Deploy Order

```
1.  Part 1 - Network Stack          ← deploy first
2.  Part 2 - EKS Cluster Stack      ← needs VpcId and PrivateSubnets
3.  Part 2 - Worker Node Stack      ← needs PrivateSubnets
4.  Part 2 - ECR Repository Stack
5.  Part 4 - S3 Artifacts Stack     ← this stack
6.  Part 3 - CodeBuild Stack
7.  Part 5 - CloudWatch Stack
8.  Part 5 - SNS Stack              ← must come before CodePipeline
9.  Part 4 - CodePipeline Stack     ← this stack, imports SNS export
10. Part 5 - Lambda Stack
11. Part 5 - EventBridge Stack
```

---

## Teardown Order

```
1.  kubectl delete namespace dev    ← removes all resources in the namespace
2.  Delete EventBridge stack
3.  Delete Lambda stack
4.  Delete SNS stack
5.  Delete CloudWatch stack
6.  Delete CodePipeline stack       ← this stack
7.  Delete CodeBuild stack
8.  Delete S3 stack                 ← empty bucket first, this stack
9.  Delete ECR stack                ← delete images first
10. Delete Worker Node stack
11. Delete EKS Cluster stack
12. Delete VPC stack
```

---

## Obstacles Encountered

**S3 bucket namespace error** — account-regional namespace requires a specific bucket name suffix. Switched to global namespace to keep account ID out of the bucket name.

**CodePipeline IAM permissions** — pipeline failed with `s3:PutObject` denied. Root cause: IAM policy only covered bucket ARN, not object ARN. Fix: added `/*` suffix resource.

**buildspec.yml path errors** — CodeBuild runs from repo root, not the subdirectory. All paths updated to include full directory prefix.

**Docker Hub rate limit** — `nginx:latest` pull failed with 429 Too Many Requests. Fix: switched base image to ECR Public Gallery which has no rate limits.

**EKS authentication** — kubectl commands failed with credentials error. Fix: `CodeBuildAccessEntry` added to CloudFormation — eliminates manual aws-auth ConfigMap editing on every deploy.

---

## Result

A fully automated pipeline triggered by a GitHub push with a manual approval gate between build and deploy. Code flows from GitHub → CodePipeline → CodeBuild (build) → Manual Approval → CodeBuild (deploy) → ECR → EKS with a human review step before anything reaches the cluster.