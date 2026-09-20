data "aws_iam_policy_document" "kms" {
  # Without this, a mistake anywhere else in the policy would lock everyone out
  # of the key permanently, and AWS support cannot recover it.
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
