# Uses name_prefix so a replacement can be created before the old group is
# destroyed, which a fixed name would prevent.
resource "aws_security_group" "vpc_endpoint" {
  name_prefix = "${var.name}-vpc-endpoint-"
  description = "Interface endpoint network interfaces"
  vpc_id      = aws_vpc.this.id

  tags = {
    Name = "${var.name}-vpc-endpoint"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# The VPC's default security group is adopted and left empty so that no
# workload can quietly depend on it.
resource "aws_default_security_group" "this" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.name}-default-do-not-use"
  }
}
