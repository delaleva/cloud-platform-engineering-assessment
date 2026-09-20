# A private hosted zone is shared infrastructure, like the endpoints. Workloads
# add records to it rather than each creating their own zone, which would
# collide the moment a second workload appeared.
resource "aws_route53_zone" "private" {
  name          = var.private_zone_name
  force_destroy = true

  vpc {
    vpc_id = aws_vpc.this.id
  }

  tags = {
    Name = var.private_zone_name
  }
}

# DNS lookups still leave a VPC that has no internet gateway, so recording what
# the workload resolves is worth doing even when nothing can route out.
resource "aws_cloudwatch_log_group" "resolver_query_log" {
  name              = "/aws/route53/resolver/${var.name}"
  retention_in_days = var.log_retention_days

  tags = {
    Name = "${var.name}-resolver-query-log"
  }
}

# Route 53 Resolver writes through a service-linked role, so none is defined here.
resource "aws_route53_resolver_query_log_config" "this" {
  name            = "${var.name}-resolver-query-log"
  destination_arn = aws_cloudwatch_log_group.resolver_query_log.arn

  tags = {
    Name = "${var.name}-resolver-query-log"
  }
}

resource "aws_route53_resolver_query_log_config_association" "this" {
  resolver_query_log_config_id = aws_route53_resolver_query_log_config.this.id
  resource_id                  = aws_vpc.this.id
}
