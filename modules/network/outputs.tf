output "vpc_id" {
  description = "ID of the VPC."
  value       = aws_vpc.this.id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC."
  value       = aws_vpc.this.cidr_block
}

output "private_subnet_ids" {
  description = "Private subnet IDs, in var.azs order."
  value       = [for az in var.azs : aws_subnet.private[az].id]
}

output "endpoint_security_group_id" {
  description = "Security group attached to the interface endpoint network interfaces."
  value       = aws_security_group.vpc_endpoint.id
}

output "private_zone_id" {
  description = "Hosted zone workloads add their records to."
  value       = aws_route53_zone.private.zone_id
}

output "private_zone_name" {
  description = "Name of the private hosted zone."
  value       = aws_route53_zone.private.name
}
