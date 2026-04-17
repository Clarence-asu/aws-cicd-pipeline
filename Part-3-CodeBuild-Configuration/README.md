# Part 3 - CodeBuild Configuration

## Overview
This milestone configures AWS CodeBuild to automatically build a Docker image 
from source code, push it to Amazon ECR, and deploy the updated image to EKS 
using kubectl. It also establishes the GitHub connection required for 
CodePipeline to trigger builds automatically on each push to main.

---

## Files
- `buildspec.yml` - CodeBuild build specification file
- `code_build_template.yaml` - CloudFormation template for the CodeBuild 
IAM role and project

---

## What Was Completed

### buildspec.yml
The build specification defines three phases:

**pre_build**
- Authenticates Docker to Amazon ECR using a temporary token generated via IAM
- Sets the IMAGE_URI variable using the Git commit SHA via 
$CODEBUILD_RESOLVED_SOURCE_VERSION for image traceability

**build**
- Builds the Docker image
- Tags the image with both the commit SHA and latest

**post_build**
- Pushes both image tags to ECR
- Configures kubectl to connect to the EKS cluster
- Updates the EKS deployment with the new image

### Security Considerations
- AWS Account ID stored in SSM Parameter Store at 
`/cicd-pipeline/aws-account-id` instead of hardcoded in the template
- ECR authentication uses temporary tokens via IAM - no static credentials
- IAM role uses inline policies scoped to specific actions instead of broad 
managed policies

### code_build_template.yaml
CloudFormation template that provisions the following resources:

**AWS::IAM::Role**
- Custom IAM role for CodeBuild
- Inline policies scoped to specific actions for SSM Parameter Store, 
ECR, EKS, and CloudWatch Logs

**AWS::CodeBuild::Project**
- Linux container environment using aws/codebuild/standard:7.0
- Source and artifact type set to CODEPIPELINE
- References the IAM role via !GetAtt

### GitHub Connection
Established a connection between AWS CodePipeline and GitHub so CodePipeline 
can monitor the main branch and trigger the pipeline automatically on each 
push.

---

## Obstacles Encountered

### GitHub Repo Not Appearing in CodePipeline Dropdown
After creating the initial GitHub connection, the aws-cicd-pipeline repo was 
not appearing in the repository dropdown in CodePipeline. 

Root cause: The AWS Connector for GitHub was only showing under Authorized 
GitHub Apps, which grants basic read access, but was not installed under 
Installed GitHub Apps, which is required for repository-level access.

Fix: Reinstalled the AWS Connector app through the Install a new app option 
in AWS and explicitly granted access to the aws-cicd-pipeline repository.