terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# 1. S3 Source Bucket (with EventBridge Notification enabled)
resource "aws_s3_bucket" "source" {
  bucket_prefix = "img-pipeline-source-"
  force_destroy = true
}

resource "aws_s3_bucket_notification" "source_notification" {
  bucket      = aws_s3_bucket.source.id
  eventbridge = true
}

# 2. S3 Destination Bucket
resource "aws_s3_bucket" "destination" {
  bucket_prefix = "img-pipeline-dest-"
  force_destroy = true
}

# 3. Dead-Letter SQS Queue
resource "aws_sqs_queue" "dlq" {
  name = "img-resizer-dlq"
}

# 4. SNS Topic for Notifications
resource "aws_sns_topic" "notifications" {
  name = "img-resizer-topic"
}

# 5. IAM Role for Lambda
resource "aws_iam_role" "lambda_role" {
  name = "img_resizer_lambda_execution_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_policy" "lambda_policy" {
  name = "img_resizer_lambda_policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = ["s3:GetObject"]
        Resource = "${aws_s3_bucket.source.arn}/*"
      },
      {
        Effect = "Allow"
        Action = ["s3:PutObject"]
        Resource = "${aws_s3_bucket.destination.arn}/*"
      },
      {
        Effect = "Allow"
        Action = ["sns:Publish"]
        Resource = aws_sns_topic.notifications.arn
      },
      {
        Effect = "Allow"
        Action = ["sqs:SendMessage"]
        Resource = aws_sqs_queue.dlq.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_attach" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}

# 6. Lambda Function Definition
resource "aws_lambda_function" "resizer" {
  filename         = "../src/lambda/function.zip"
  function_name    = "image-resizing-function"
  role             = aws_iam_role.lambda_role.arn
  handler          = "index.handler"
  runtime          = "nodejs20.x"
  memory_size      = 1024
  timeout          = 15

  environment {
    variables = {
      DESTINATION_BUCKET = aws_s3_bucket.destination.id
      SNS_TOPIC_ARN      = aws_sns_topic.notifications.arn
      RESIZE_WIDTH       = "300"
    }
  }

  dead_letter_config {
    target_arn = aws_sqs_queue.dlq.arn
  }
}

# 7. EventBridge Rule and Target
resource "aws_cloudwatch_event_rule" "s3_upload" {
  name        = "capture-s3-image-upload"
  description = "Triggers Lambda when a new image is uploaded to source S3"

  event_pattern = jsonencode({
    source      = ["aws.s3"]
    detail-type = ["Object Created"]
    detail = {
      bucket = {
        name = [aws_s3_bucket.source.id]
      }
    }
  })
}

resource "aws_cloudwatch_event_target" "lambda_target" {
  rule      = aws_cloudwatch_event_rule.s3_upload.name
  target_id = "SendToLambda"
  arn       = aws_lambda_function.resizer.arn
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.resizer.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.s3_upload.arn
}
