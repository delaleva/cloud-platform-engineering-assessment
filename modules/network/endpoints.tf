data "aws_region" "current" {}

# One network interface per subnet. Private DNS lets the SDK resolve the normal
# service hostname to these interfaces without an endpoint override.
resource "aws_vpc_endpoint" "interface" {
  for_each = var.interface_endpoint_services

  vpc_id            = aws_vpc.this.id
  service_name      = "com.amazonaws.${data.aws_region.current.region}.${each.key}"
  vpc_endpoint_type = "Interface"
  subnet_ids        = [for s in aws_subnet.private : s.id]

  # Every endpoint shares this group, so a caller let in to one can reach them
  # all on the network. IAM still decides what each caller may do with each.
  security_group_ids  = [aws_security_group.vpc_endpoint.id]
  private_dns_enabled = true

  tags = {
    Name = "${var.name}-${each.key}-endpoint"
  }
}
