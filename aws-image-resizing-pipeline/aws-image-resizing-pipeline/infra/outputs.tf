output "source_bucket_name" {
  value = aws_s3_bucket.source.id
}

output "destination_bucket_name" {
  value = aws_s3_bucket.destination.id
}

output "sns_topic_arn" {
  value = aws_sns_topic.notifications.arn
}
