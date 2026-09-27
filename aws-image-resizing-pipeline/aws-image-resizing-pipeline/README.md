# Serverless Event-Driven Image Resizing Pipeline

An automated, cloud-native image processing pipeline built on AWS using Node.js, Amazon S3, EventBridge, AWS Lambda, and Terraform.

## 🚀 Architecture

1. **Image Upload:** User uploads an original image to the **Source S3 Bucket**.
2. **Event Dispatch:** S3 sends an `Object Created` event notification to **Amazon EventBridge**.
3. **Compute Execution:** EventBridge invokes the **AWS Lambda** function.
4. **Transformation:** Lambda processes and resizes the image using the high-performance `Sharp` engine.
5. **Storage & Notification:** Resized image is stored in the **Destination S3 Bucket**, and a completion notification is published to **Amazon SNS**.
6. **Fault Tolerance:** Unhandled execution failures are routed to an **Amazon SQS Dead-Letter Queue (DLQ)**.

---

## 🛠️ Tech Stack

* **Cloud Provider:** Amazon Web Services (AWS)
* **Infrastructure as Code (IaC):** Terraform
* **Compute:** AWS Lambda (Node.js 20 runtime)
* **Storage:** Amazon S3
* **Event Routing:** Amazon EventBridge
* **Messaging & Alerts:** Amazon SNS, Amazon SQS
* **Image Processing Engine:** Sharp (Linux x64 binary wrapper)

---

## ⚙️ Deployment Instructions

### Prerequisites
* AWS CLI configured with valid credentials.
* Terraform v1.5+ installed.
* Node.js v20+ and npm installed.

### Step 1: Package the Lambda Deployment Zip
Navigate to the source directory, install production dependencies (including Linux binary dependencies for Sharp), and zip the artifact:

```bash
cd src/lambda
npm install --platform=linux --arch=x64 sharp
npm install @aws-sdk/client-s3 @aws-sdk/client-sns
zip -r function.zip index.mjs package.json node_modules/
```

### Step 2: Deploy Infrastructure via Terraform
Navigate to the Infrastructure directory and execute the Terraform workflow:

```bash
cd ../../infra
terraform init
terraform plan
terraform apply --auto-approve
```

---

## 🧪 Testing the Pipeline

1. **Subscribe your email to the SNS Topic:**
   ```bash
   aws sns subscribe \
     --topic-arn <SNS_TOPIC_ARN_FROM_OUTPUTS> \
     --protocol email \
     --notification-endpoint your-email@example.com
   ```
2. **Upload a Sample Image to the Source S3 Bucket:**
   ```bash
   aws s3 cp sample.jpg s3://<SOURCE_BUCKET_NAME>/sample.jpg
   ```
3. **Verify Output:**
   * Check the Destination Bucket for `thumbnails/sample_thumb.jpg`.
   * Confirm the completion email from Amazon SNS.
   * View invocation logs in **AWS CloudWatch Log Groups**.

---

## 🔒 Security & Best Practices

* **Principle of Least Privilege:** IAM policies explicitly grant actions strictly required for S3 object reads/writes, SNS publishing, and SQS messaging.
* **Separation of Buckets:** Source and Destination buckets are strictly separated to prevent infinite Lambda execution cycles.
* **Resilience:** Implemented DLQ pattern via SQS to isolate failed tasks for debugging without losing data.
