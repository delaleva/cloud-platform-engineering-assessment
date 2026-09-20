# Encrypted with an AWS-managed key. The customer managed key belongs to the
# workload module, which depends on this one and so cannot be referenced here.
resource "aws_cloudwatch_log_group" "flow_log" {
  name              = "/aws/vpc/${var.name}"
  retention_in_days = var.log_retention_days

  tags = {
    Name = "${var.name}-flow-log"
  }
}

data "aws_iam_policy_document" "flow_log_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["vpc-flow-logs.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "flow_log" {
  name               = "${var.name}-flow-log"
  description        = "Lets the VPC flow log service write to its log group"
  assume_role_policy = data.aws_iam_policy_document.flow_log_assume.json

  tags = {
    Name = "${var.name}-flow-log"
  }
}

# Scoped to this log group's streams rather than to all of CloudWatch Logs.
data "aws_iam_policy_document" "flow_log" {
  statement {
    effect = "Allow"

    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogStreams",
    ]

    resources = ["${aws_cloudwatch_log_group.flow_log.arn}:*"]
  }
}

resource "aws_iam_role_policy" "flow_log" {
  name   = "${var.name}-flow-log"
  role   = aws_iam_role.flow_log.id
  policy = data.aws_iam_policy_document.flow_log.json
}

# Captures all traffic rather than rejects alone, because accepted traffic is
# what proves the private path to the endpoints is working.
resource "aws_flow_log" "this" {
  vpc_id               = aws_vpc.this.id
  traffic_type         = "ALL"
  iam_role_arn         = aws_iam_role.flow_log.arn
  log_destination_type = "cloud-watch-logs"
  log_destination      = aws_cloudwatch_log_group.flow_log.arn

  tags = {
    Name = "${var.name}-flow-log"
  }
}
