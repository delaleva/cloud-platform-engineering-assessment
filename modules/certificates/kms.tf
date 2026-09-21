data "aws_iam_policy_document" "kms" {
  # Hands access decisions to IAM in this account. It also covers the root user,
  # which cannot be deleted, so the key can never become unmanageable.
  statement {
    sid       = "AccountRootFullAccess"
    effect    = "Allow"
    actions   = ["kms:*"]
    resources = ["*"]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${local.account_id}:root"]
    }
  }

  # CloudWatch Logs encrypts with the key on the service's own behalf, so it
  # needs a grant here rather than an IAM policy. The encryption context
  # confines that grant to log groups in this account and region.
  statement {
    sid    = "CloudWatchLogs"
    effect = "Allow"

    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey",
    ]

    resources = ["*"]

    principals {
      type        = "Service"
      identifiers = ["logs.${local.region}.amazonaws.com"]
    }

    condition {
      test     = "ArnLike"
      variable = "kms:EncryptionContext:aws:logs:arn"
      values   = ["arn:aws:logs:${local.region}:${local.account_id}:log-group:*"]
    }
  }

  # The alarm topic is encrypted with this key, so the alarm service needs to
  # use it to publish. It is a different principal from CloudWatch Logs above.
  statement {
    sid       = "CloudWatchAlarmsToSns"
    effect    = "Allow"
    actions   = ["kms:GenerateDataKey*", "kms:Decrypt"]
    resources = ["*"]

    principals {
      type        = "Service"
      identifiers = ["cloudwatch.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [local.account_id]
    }
  }
}

# One key for everything this module stores, rather than one per artefact. The
# separation that matters is on the secrets themselves, where each role is
# granted only the ones it needs.
resource "aws_kms_key" "this" {
  description             = "Secrets, Lambda log groups and artefacts for ${var.name}"
  enable_key_rotation     = true
  deletion_window_in_days = 7
  policy                  = data.aws_iam_policy_document.kms.json

  tags = {
    Name = var.name
  }
}

resource "aws_kms_alias" "this" {
  name          = "alias/${var.name}"
  target_key_id = aws_kms_key.this.key_id
}
