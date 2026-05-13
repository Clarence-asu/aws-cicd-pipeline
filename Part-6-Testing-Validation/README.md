Here's Part 6 ready to paste into GitHub:

---

# Part 6 — Testing & Validation

## Overview

This milestone validates that every component of the pipeline works end to end. Each checkpoint was tested individually — pipeline triggering, ECR image updates, zero downtime rolling updates, and rollback. This milestone confirms the infrastructure built across Milestones 1 through 5 functions as designed.

---

## Files

No new templates were created in this milestone. All validation was performed against existing infrastructure.

---

## Checkpoints

### Checkpoint 1 — Pipeline Triggers Automatically
Pushed a code change to the main branch and confirmed the pipeline triggered automatically via the CodeStar GitHub connection. No manual pipeline execution required.

**Result:** ✅ Pipeline triggered on push to main

---

### Checkpoint 2 — Docker Image Appears in ECR
After a successful pipeline run confirmed the new Docker image was pushed to the `my-nginx-app` ECR repository with both the commit SHA tag and the `latest` tag.

**Result:** ✅ New image visible in ECR after every successful build

---

### Checkpoint 3 — Zero Downtime Rolling Update
Connected to the bastion via SSM Session Manager and ran `kubectl rollout status deployment/my-app -n dev` to verify the rolling update completed without downtime.

**Result:** ✅ `deployment "my-app" successfully rolled out`

---

### Checkpoint 4 — Rollback Test
Ran `kubectl rollout undo deployment/my-app -n dev` to roll back to the previous ReplicaSet, then confirmed the rollback completed successfully with `kubectl rollout status`.

**Result:** ✅ `deployment "my-app" successfully rolled out`

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
8.  Part 5 - SNS Stack
9.  Part 4 - CodePipeline Stack
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

**Rolling update stuck in Pending** — `kubectl rollout status` returned `error: deployment "my-app" exceeded its progress deadline`. Running `kubectl describe pod` revealed the error `0/2 nodes are available: 2 Too many pods`.

Root cause: the worker nodes were provisioned with a small instance type that could only fit a limited number of pods. With 2 replicas already running, there was no capacity for the third pod the rolling update needed to spin up before terminating the old ones.

Fix: scaled the deployment down to 1 replica with `kubectl scale deployment my-app --replicas=1 -n dev` to free up capacity, then the rolling update completed successfully.

In production this would be addressed by using larger instance types or configuring cluster autoscaling to add nodes when capacity is needed.

**Rollback history showed no CHANGE-CAUSE** — `kubectl rollout history` showed all revisions with `<none>` in the CHANGE-CAUSE column. This is expected behavior when deployments are managed via `kubectl apply` with injected manifests rather than imperative commands. The rollback still works correctly — the history just doesn't have annotations.

---

## Result

All four checkpoints passed. The pipeline triggers automatically, images are pushed to ECR on every build, rolling updates complete without downtime, and rollback works when needed. The full pipeline is validated end to end.