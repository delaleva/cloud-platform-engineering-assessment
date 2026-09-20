# Proves the mutual TLS path end to end from inside the VPC, which is the only
# place the API is reachable from. Deployed in dev and never in production,
# which is why it is a separate module rather than part of the API.

resource "aws_security_group" "this" {
  name_prefix = "${var.name}-client-"
  description = "In-VPC test client"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${var.name}-client"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_egress_rule" "to_endpoints" {
  security_group_id            = aws_security_group.this.id
  description                  = "Secrets Manager through the interface endpoint"
  referenced_security_group_id = var.endpoint_security_group_id
  from_port                    = 443
  to_port                      = 443
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "to_api" {
  security_group_id            = aws_security_group.this.id
  description                  = "Mutual TLS to the API"
  referenced_security_group_id = var.api_security_group_id
  from_port                    = 443
  to_port                      = 443
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "endpoints_from_client" {
  security_group_id            = var.endpoint_security_group_id
  description                  = "Test client reaching Secrets Manager"
  referenced_security_group_id = aws_security_group.this.id
  from_port                    = 443
  to_port                      = 443
  ip_protocol                  = "tcp"
}

data "aws_iam_policy_document" "assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "this" {
  name               = "${var.name}-client"
  description        = "Execution role for the in-VPC test client"
  assume_role_policy = data.aws_iam_policy_document.assume.json

  tags = {
    Name = "${var.name}-client"
  }
}

# Network interface management cannot be scoped to particular subnets, so the
# AWS-managed policy is used rather than a hand-written copy of the same grants.
resource "aws_iam_role_policy_attachment" "vpc_access" {
  role       = aws_iam_role.this.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

data "aws_iam_policy_document" "this" {
  statement {
    sid       = "ReadClientIdentity"
    effect    = "Allow"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [var.client_identity_secret_arn]
  }

  statement {
    sid       = "DecryptWithWorkloadKey"
    effect    = "Allow"
    actions   = ["kms:Decrypt"]
    resources = [var.kms_key_arn]
  }
}

resource "aws_iam_role_policy" "this" {
  name   = "${var.name}-client"
  role   = aws_iam_role.this.id
  policy = data.aws_iam_policy_document.this.json
}

resource "aws_cloudwatch_log_group" "this" {
  name              = "/aws/lambda/${var.name}-client"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn

  tags = {
    Name = "${var.name}-client"
  }
}

# Packaged at plan time. The handler uses only the standard library and the
# boto3 the runtime already ships, so there is no build step.
data "archive_file" "this" {
  type        = "zip"
  source_dir  = "${path.module}/src"
  output_path = "${path.module}/.build/client.zip"

  excludes = ["__pycache__"]
}

resource "aws_lambda_function" "this" {
  function_name    = "${var.name}-client"
  description      = "In-VPC test client for the mutual TLS API"
  role             = aws_iam_role.this.arn
  handler          = "handler.handler"
  runtime          = "python3.13"
  architectures    = ["arm64"]
  filename         = data.archive_file.this.output_path
  source_code_hash = data.archive_file.this.output_base64sha256
  timeout          = 30
  memory_size      = 256

  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [aws_security_group.this.id]
  }

  environment {
    variables = {
      CLIENT_IDENTITY_SECRET = var.client_identity_secret_arn
      API_URL                = var.api_url
    }
  }

  tags = {
    Name = "${var.name}-client"
  }

  depends_on = [
    aws_cloudwatch_log_group.this,
    aws_iam_role_policy_attachment.vpc_access,
  ]
}
