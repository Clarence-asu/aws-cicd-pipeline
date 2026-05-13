Here's the Part 5 README ready to paste into GitHub:

---

# Part 5 — Monitoring & Notifications

## Overview

This milestone adds monitoring and alerting to the pipeline. CloudWatch captures build and deployment logs, EventBridge watches for pipeline state changes, Lambda processes the events and publishes to SNS, and SNS delivers email notifications. The result is an automated alerting system that fires an email every time the pipeline starts, fails, or succeeds.

---

## Files

- `cloudwatch_template.yaml` — CloudFormation template for the CloudWatch log group
- `sns_template.yaml` — CloudFormation template for the SNS topic and email subscription
- `lambda_template.yaml` — CloudFormation template for the Lambda IAM role and function
- `eventbridge_template.yaml` — CloudFormation template for the EventBridge rule and Lambda invoke permission

---

## What Was Built

### CloudWatch Log Group (cloudwatch_template.yaml)

Captures build and deployment logs from CodeBuild.

**Key decisions:**
- **LogGroupName: mtier-Logroup** — consistent with mtier naming convention
- **RetentionInDays: 30** — logs kept for 30 days then automatically purged
- **LogGroupClass: STANDARD** — standard storage class for active log access
- **DeletionProtectionEnabled: true** — prevents accidental deletion of logs

The log group ARN is exported as `mtier:BuildDeployLogsArn` for use by the Lambda IAM role.

---

### SNS Topic (sns_template.yaml)

Delivers email notifications when pipeline state changes occur.

**Resources:**
- **MtierPipelineTopic** — Standard SNS topic named `MtierTopic`
- **MtierPipelineSubscription** — email subscription to `clarenceasu@gmail.com`

**Key decisions:**
- Standard topic used instead of FIFO — ordering not required for notifications
- Email subscription requires manual confirmation after stack deploy — confirmation link sent to the subscribed address

The topic ARN is exported as `mtier:PipelineNotificationsArn` and imported by the CodePipeline, Lambda, and EventBridge stacks.

**Note:** SNS must be deployed before CodePipeline. The pipeline template imports `mtier:PipelineNotificationsArn` for the manual approval stage — deploying CodePipeline before SNS causes a stack failure.

---

### Lambda Function (lambda_template.yaml)

Triggered by EventBridge on pipeline state changes. Publishes a notification message to SNS.

**IAM Role — MtierSnsCloudwatchLambdaIamRole:**
- **mtier-sns-policy** — `sns:Publish` scoped to the SNS topic ARN
- **mtier-cloudwatch-policy** — `logs:CreateLogGroup`, `logs:CreateLogStream`, `logs:PutLogEvents` scoped to the CloudWatch log group ARN

**Lambda Function — MtierLambdaFunction:**
- Runtime: `python3.12`
- Handler: `index.lambda_handler`
- Architecture: `x86_64`
- Environment variable: `SNS_TOPIC_ARN` injected at runtime via `!ImportValue`
- Inline Python code deployed via `ZipFile`

**What the function does:**
Extracts the pipeline name and state from the EventBridge event, then publishes a message in the format `app-pipeline is FAILED` to the SNS topic. The SNS topic delivers it as an email.

**Exports:**
- `mtier:LambdaFunctionArn` — used by EventBridge to set the target
- `mtier:LambdaFunction` — Lambda function name for reference

---

### EventBridge Rule (eventbridge_template.yaml)

Watches for CodePipeline state changes and invokes the Lambda function.

**MtierEventRule:**
- Matches events from source `aws.codepipeline`
- Filters on detail-type `CodePipeline Pipeline Execution State Change`
- Target: Lambda function via `!ImportValue mtier:LambdaFunctionArn`
- State: ENABLED

**LambdaInvokePermission:**
- Grants EventBridge `lambda:InvokeFunction` permission on the Lambda function
- Scoped to the specific EventBridge rule ARN via `SourceArn`

---

## Notification Flow

```
CodePipeline state changes
        ↓
EventBridge rule fires
        ↓
Lambda function invoked
        ↓
Lambda publishes to SNS topic
        ↓
SNS delivers email notification
```

---

## Deploy Order

```
1.  Part 1 - Network Stack
2.  Part 2 - EKS Cluster Stack
3.  Part 2 - Worker Node Stack
4.  Part 2 - ECR Repository Stack
5.  Part 4 - S3 Artifacts Stack
6.  Part 3 - CodeBuild Stack
7.  Part 5 - CloudWatch Stack       ← this stack, must come before Lambda
8.  Part 5 - SNS Stack              ← this stack, must come before CodePipeline and Lambda
9.  Part 4 - CodePipeline Stack
10. Part 5 - Lambda Stack           ← this stack, needs CloudWatch and SNS exports
11. Part 5 - EventBridge Stack      ← this stack, needs Lambda export
```

---

## Teardown Order

```
1.  kubectl delete namespace dev
2.  Delete EventBridge stack        ← this stack
3.  Delete Lambda stack             ← this stack
4.  Delete SNS stack                ← this stack
5.  Delete CloudWatch stack         ← this stack
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

**SNS subscription confirmation in spam** — after deploying the SNS stack, the confirmation email from AWS landed in the spam folder. SNS will not deliver any messages until the subscription is confirmed. Always check spam if the confirmation email doesn't appear in the inbox.

**Lambda Architectures property type error** — `Architectures` expects a list not a string. Setting `Architectures: x86_64` caused a CloudFormation validation error. Fix: changed to a list format with a dash.

**Lambda Role property format error** — `Role` requires a full IAM role ARN. Using `!Ref` returns only the role name which fails validation. Fix: changed to `!GetAtt MtierSnsCloudwatchLambdaIamRole.Arn`.

**Duplicate Outputs block** — template had two separate `Outputs:` sections which is invalid YAML. Fix: merged both into a single `Outputs:` block.

**CRLF line endings** — Lambda `ZipFile` inline code failed to parse due to Windows CRLF line endings. Fix: changed file encoding to LF in VS Code via the status bar.

**Deployment order dependency** — Lambda stack failed with `No export named mtier:BuildDeployLogsArn found` because CloudWatch was not deployed first. Fix: always deploy CloudWatch and SNS before Lambda and CodePipeline.

---

## Result

Every pipeline execution triggers an email notification. The full alerting chain — EventBridge → Lambda → SNS → email — fires automatically on every state change including STARTED, SUCCEEDED, and FAILED. No manual monitoring required.