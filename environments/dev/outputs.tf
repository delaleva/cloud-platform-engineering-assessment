output "vpc_id" {
  description = "VPC the API is deployed into."
  value       = module.network.vpc_id
}

output "private_subnet_ids" {
  description = "Private subnets, one per AZ."
  value       = module.network.private_subnet_ids
}
