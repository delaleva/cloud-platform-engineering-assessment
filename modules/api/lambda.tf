# Packaged at plan time by the archive provider. The handler uses only the
# standard library and the boto3 the runtime already ships, so there is no
# dependency install and no separate build step.
data "archive_file" "api" {
  type        = "zip"
  source_dir  = "${path.module}/src/api"
  output_path = "${path.module}/.build/api.zip"

  # Bytecode would otherwise be packaged, changing the hash whenever Python
  # regenerates it and redeploying a function whose source has not changed.
  excludes = ["__pycache__"]
}

# Created here rather than left to Lambda, which would make one on first
# invocation with no retention limit and no customer managed key.
resource "aws_cloudwatch_log_group" "api" {
  name              = "/aws/lambda/${var.name}-api"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn

  tags = {
    Name = "${var.name}-api"
  }
}

# The environment holds the secret's name, never its value. The value is
# fetched at runtime, so nothing sensitive reaches the deployment package.
resource "aws_lambda_function" "api" {
  function_name    = "${var.name}-api"
  description      = "Internal API behind mutual TLS"
  role             = aws_iam_role.api.arn
  handler          = "handler.handler"
  runtime          = "python3.13"
  architectures    = ["arm64"]
  filename         = data.archive_file.api.output_path
  source_code_hash = data.archive_file.api.output_base64sha256
  timeout          = 10
  memory_size      = 256

  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [aws_security_group.api.id]
  }

  environment {
    variables = {
      ALLOWED_CLIENTS_SECRET = aws_secretsmanager_secret.allowed_clients.arn
    }
  }

  tags = {
    Name = "${var.name}-api"
  }

  depends_on = [
    aws_cloudwatch_log_group.api,
    aws_iam_role_policy_attachment.api_vpc_access,
  ]
}
