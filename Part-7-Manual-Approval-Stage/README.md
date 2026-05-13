Here's Part 7 ready to paste into GitHub:

---

# Part 7 — Manual Approval Stage

## Overview

This milestone adds a manual approval gate between the build and deploy stages in CodePipeline. After the Docker image is built and pushed to ECR, the pipeline pauses and sends an email notification to the reviewer. The deployment to EKS only proceeds after a human approves it in the AWS console. This simulates a real production workflow where a senior engineer gates all deployments.

---

## Files

- `Part-4-Pipeline-Setup/code_pipeline_template.yaml` — updated to add Approve and Deploy stages and SNS approval policy
- `Part-3-CodeBuild-Configuration/buildspec_build.yml` — new file, build only
- `Part-3-CodeBuild-Configuration/buildspec_deploy.yml` — new file, deploy only

---

## What Was Built

### buildspec Split
The original `buildspec.yml` handled both build and deploy in a single file. To support the approval gate it was split into two separate files:

- **buildspec_build.yml** — pre_build and build phases only. Authenticates to ECR, builds the Docker image, tags it, and pushes both tags to ECR. Stops there.
- **buildspec_deploy.yml** — pre_build and post_build phases only. Reconstructs the IMAGE_URI using the same commit SHA, configures kubectl, runs deploy.sh, and updates the EKS deployment.

The original `buildspec.yml` remains in `Part-3-CodeBuild-Configuration/` for reference.

### CodePipeline Updates

**New pipeline stages:**
- **Approve** — pauses the pipeline after Build. Sends an SNS email notification with the message "Review the build and approve to deploy to EKS". Pipeline waits indefinitely until a reviewer approves or rejects in the console.
- **Deploy** — new CodeBuild action that runs `buildspec_deploy.yml` via `BuildspecOverride`. Only runs after approval is granted.

**Build stage updated:**
- `BuildspecOverride` added pointing to `buildspec_build.yml` so the build stage runs build-only logic

**New IAM policy:**
- **sns-approval-policy** — grants CodePipeline `sns:Publish` on the SNS topic so it can send the approval notification email

### Pipeline Flow

```
GitHub push to main
        ↓
Source stage — pulls code
        ↓
Build stage — builds image, pushes to ECR
        ↓
Approve stage — sends email, pipeline pauses
        ↓
Reviewer approves or rejects in AWS console
        ↓
Deploy stage — deploys to EKS (approve only)
```

---

## Approval Flow Test

Pushed a code change to main, pipeline triggered and paused at the Approve stage, received the SNS email notification, logged into CodePipeline console, clicked Review and Approved. Deploy stage ran and completed successfully.

**Result:** ✅ Approval flow works end to end

---

## Rejection Flow Test

Pushed a code change to main, pipeline triggered and paused at the Approve stage, clicked Review and Rejected. Pipeline stopped and the Deploy stage never ran. EKS was not updated.

**Result:** ✅ Rejection flow works — nothing reaches EKS without approval

---

## Deploy Order

```
1.  Part 1 - Network Stack
2.  Part 2 - EKS Cluster Stack
3.  Part 2 - Worker Node Stack
4.  Part 2 - ECR Repository Stack
5.  Part 4 - S3 Artifacts Stack
6.  Part 3 - CodeBuild Stack
7.  Part 5 - CloudWatch Stack
8.  Part 5 - SNS Stack              ← must come before CodePipeline
9.  Part 4 - CodePipeline Stack     ← imports SNS export
10. Part 5 - Lambda Stack
11. Part 5 - EventBridge Stack
```

---

## Teardown Order

```
1.  kubectl delete namespace dev
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

**buildspec filename mismatch** — pipeline failed with `no such file or directory` after adding `BuildspecOverride`. Root cause: buildspec files were saved with underscores (`buildspec_build.yml`) but the pipeline template referenced them with dashes (`buildspec-build.yml`). Fix: updated both `BuildspecOverride` paths in the pipeline template to match the actual filenames.

**SNS deployment order dependency** — CodePipeline stack failed with `No export named mtier:PipelineNotificationsArn found` because the SNS stack was not deployed first. Fix: SNS must always be deployed before CodePipeline on every rebuild.

---

## Result

The pipeline now requires human sign-off before any code reaches EKS. The build runs automatically, the reviewer gets an email, and nothing deploys until they approve it in the console. The rejection flow also works — a rejected pipeline stops completely and leaves EKS untouched.