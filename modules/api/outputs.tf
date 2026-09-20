output "api_url" {
  description = "URL the in-VPC client calls. Resolvable only inside the VPC."
  value       = "https://${var.fqdn}/"
}

output "api_security_group_id" {
  description = "Security group fronting the API, for consumers to reference."
  value       = aws_security_group.alb.id
}

output "log_group_name" {
  description = "Log group holding the API's structured request logs."
  value       = aws_cloudwatch_log_group.api.name
}

output "access_logs_bucket" {
  description = "Bucket holding load balancer access and connection logs."
  value       = aws_s3_bucket.access_logs.id
}
