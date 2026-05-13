Here's the updated README ready to paste into GitHub:

---

# Part 3 — CodeBuild Configuration

## Overview

This milestone configures AWS CodeBuild to automatically build a Docker image from source code, push it to Amazon ECR, and deploy the updated image to EKS using kubectl. It also establishes the GitHub connection required for CodePipeline to trigger builds automatically on each push to main.

---

## Files

- `buildspec.yml` — original build specification covering build and deploy in a single file
- `buildspec_build.yml` — build-only specification added in Milestone 7, handles Docker build and ECR push
- `buildspec_deploy.yml` — deploy-only specification added in Milestone 7, handles EKS deployment
- `code_build_template.yaml` — CloudFormation template for the CodeBuild IAM role and project

---

## What Was Built

### buildspec.yml
The original build specification defines three phases:

**pre_build**
- Authenticates Docker to Amazon ECR using a temporary token generated via IAM
- Sets the IMAGE_URI variable using the Git commit SHA via `$CODEBUILD_RESOLVED_SOURCE_VERSION` for image traceability

**build**
- Builds the Docker image
- Tags the image with both the commit SHA and latest

**post_build**
- Pushes both image tags to ECR
- Configures kubectl to connect to the EKS cluster
- Updates the EKS deployment with the new image

### buildspec_build.yml and buildspec_deploy.yml
Added in Milestone 7 to support the manual approval gate. The original buildspec was split into two separate files so the pipeline could pause between build and deploy for human review.

- `buildspec_build.yml` — runs pre_build and build phases only, pushes image to ECR
- `buildspec_deploy.yml` — runs pre_build and post_build phases only, deploys to EKS

The pipeline template references each file via `BuildspecOverride` in the appropriate stage.

### Security Considerations
- AWS Account ID stored in SSM Parameter Store at `/cicd-pipeline/aws-account-id` instead of hardcoded in the template
- ECR authentication uses temporary tokens via IAM — no static credentials
- IAM role uses inline policies scoped to specific actions instead of broad managed policies

### code_build_template.yaml
CloudFormation template that provisions the following resources:

**AWS::IAM::Role**
- Custom IAM role for CodeBuild
- Inline policies scoped to specific actions for SSM Parameter Store, ECR, EKS, CloudWatch Logs, S3, and CloudFormation

**AWS::CodeBuild::Project**
- Linux container environment using `aws/codebuild/standard:7.0`
- Source and artifact type set to CODEPIPELINE
- References the IAM role via `!GetAtt`

**CodeBuildAccessEntry**
- Added to automate EKS access for CodeBuild on every stack deploy
- Eliminates the manual `aws-auth` ConfigMap step
- Uses the modern EKS Access Entry pattern instead of editing ConfigMap directly

### GitHub Connection
Established a connection between AWS CodePipeline and GitHub so CodePipeline can monitor the main branch and trigger the pipeline automatically on each push.

---

## Deploy Order

```
1.  Part 1 - Network Stack          ← deploy first
2.  Part 2 - EKS Cluster Stack      ← needs VpcId and PrivateSubnets
3.  Part 2 - Worker Node Stack      ← needs PrivateSubnets
4.  Part 2 - ECR Repository Stack
5.  Part 4 - S3 Artifacts Stack
6.  Part 3 - CodeBuild Stack        ← this stack
7.  Part 5 - CloudWatch Stack
8.  Part 5 - SNS Stack              ← must come before CodePipeline
9.  Part 4 - CodePipeline Stack     ← imports SNS export
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
6.  Delete CodePipeline stack
7.  Delete CodeBuild stack          ← this stack
8.  Delete S3 stack                 ← empty bucket first
9.  Delete ECR stack                ← delete images first
10. Delete Worker Node stack
11. Delete EKS Cluster stack
12. Delete VPC stack
```

---

## Obstacles Encountered

### GitHub Repo Not Appearing in CodePipeline Dropdown
After creating the initial GitHub connection, the aws-cicd-pipeline repo was not appearing in the repository dropdown in CodePipeline.

Root cause: The AWS Connector for GitHub was only showing under Authorized GitHub Apps, which grants basic read access, but was not installed under Installed GitHub Apps, which is required for repository-level access.

Fix: Reinstalled the AWS Connector app through the Install a new app option in AWS and explicitly granted access to the aws-cicd-pipeline repository.