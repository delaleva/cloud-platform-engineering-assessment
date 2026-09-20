output "vpc_id" {
  description = "VPC the API is deployed into."
  value       = module.network.vpc_id
}

output "private_subnet_ids" {
  description = "Private subnets, one per AZ."
  value       = module.network.private_subnet_ids
}

# Everything needed to exercise the deployment and read the result.
output "test_client_function_name" {
  description = "Invoke this to run one request end to end."
  value       = module.test_client.function_name
}

output "api_log_group_name" {
  description = "Where the API's structured request logs land."
  value       = module.api.log_group_name
}

output "access_logs_bucket" {
  description = "Load balancer access and connection logs. A refused handshake appears only in the connection log."
  value       = module.api.access_logs_bucket
}
