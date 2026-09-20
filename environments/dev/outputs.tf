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
