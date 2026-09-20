# The load balancer is the only group with an inbound rule. The API function is
# outbound only, because the load balancer reaches Lambda through the service
# API rather than over the network.

resource "aws_security_group" "alb" {
  name_prefix = "${var.name}-alb-"
  description = "Internal load balancer fronting the API"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${var.name}-alb"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Any service inside the VPC may connect. A production deployment would name
# consumer security groups instead, so a new workload has to be granted access
# rather than inheriting it.
resource "aws_vpc_security_group_ingress_rule" "alb_https" {
  security_group_id = aws_security_group.alb.id
  description       = "HTTPS from inside the VPC"
  cidr_ipv4         = var.vpc_cidr
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
}

resource "aws_security_group" "api" {
  name_prefix = "${var.name}-api-"
  description = "API function"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${var.name}-api"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_egress_rule" "api_to_endpoints" {
  security_group_id            = aws_security_group.api.id
  description                  = "Secrets Manager through the interface endpoint"
  referenced_security_group_id = var.endpoint_security_group_id
  from_port                    = 443
  to_port                      = 443
  ip_protocol                  = "tcp"
}

# The network module hands over an empty endpoint group, so each workload that
# needs it grants itself access. Referencing the group rather than the subnet
# range means only this function reaches the endpoint.
resource "aws_vpc_security_group_ingress_rule" "endpoints_from_api" {
  security_group_id            = var.endpoint_security_group_id
  description                  = "API function reaching Secrets Manager"
  referenced_security_group_id = aws_security_group.api.id
  from_port                    = 443
  to_port                      = 443
  ip_protocol                  = "tcp"
}
