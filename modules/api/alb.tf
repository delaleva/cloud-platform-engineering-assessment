# The internal load balancer, the wiring that lets it invoke the function, and
# the listener where mutual TLS is enforced.
resource "aws_lb" "this" {
  name               = "${var.name}-api"
  internal           = true
  load_balancer_type = "application"
  subnets            = var.private_subnet_ids
  security_groups    = [aws_security_group.alb.id]

  # The function trusts a header this listener sets, so malformed headers are
  # dropped rather than forwarded.
  drop_invalid_header_fields = true

  # Off so a rebuild is never blocked. Any real environment turns it on.
  enable_deletion_protection = false

  access_logs {
    bucket  = aws_s3_bucket.access_logs.id
    prefix  = "alb"
    enabled = true
  }

  # A failed handshake never reaches the access log, so rejected clients would
  # otherwise be invisible. Connection logs are where that audit trail lives.
  connection_logs {
    bucket  = aws_s3_bucket.access_logs.id
    prefix  = "connection"
    enabled = true
  }

  tags = {
    Name = "${var.name}-api"
  }

  depends_on = [aws_s3_bucket_policy.access_logs]
}

# No health_check block. A Lambda target has health checks disabled by default,
# and declaring the block makes the provider send HTTP defaults that a Lambda
# target group rejects. Leaving them on would also invoke the function on every
# probe, with no client certificate attached.
resource "aws_lb_target_group" "api" {
  name        = "${var.name}-api"
  target_type = "lambda"

  tags = {
    Name = "${var.name}-api"
  }
}

resource "aws_lambda_permission" "alb" {
  statement_id  = "AllowInvocationFromLoadBalancer"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api.function_name
  principal     = "elasticloadbalancing.amazonaws.com"
  source_arn    = aws_lb_target_group.api.arn
}

resource "aws_lb_target_group_attachment" "api" {
  target_group_arn = aws_lb_target_group.api.arn
  target_id        = aws_lambda_function.api.arn

  # Nothing here references the permission, so the ordering has to be explicit
  # or the attachment can happen before invocation is allowed.
  depends_on = [aws_lambda_permission.alb]
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.this.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"

  # The trust store below runs the opposite direction: this proves who the
  # listener is, that decides whose certificates it accepts.
  certificate_arn = var.server_certificate_arn

  # verify mode is what makes this mutual TLS. In passthrough mode the load
  # balancer forwards the certificate without checking it against the trust
  # store, which would move certificate validation into application code.
  mutual_authentication {
    mode            = "verify"
    trust_store_arn = var.trust_store_arn
  }

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api.arn
  }
}

# The zone is shared and comes from the network module. This workload owns only
# its own record, which resolves inside the VPC and never in public DNS.
resource "aws_route53_record" "api" {
  zone_id = var.private_zone_id
  name    = var.fqdn
  type    = "A"

  alias {
    name                   = aws_lb.this.dns_name
    zone_id                = aws_lb.this.zone_id
    evaluate_target_health = false
  }
}
