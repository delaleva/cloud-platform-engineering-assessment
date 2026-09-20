# S3 bucket names are globally unique, so the account and region are appended.
data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

# Access logs cannot go to CloudWatch and cannot use a customer managed key, so
# they live in their own bucket under S3-managed encryption. That gap is the
# reason this bucket exists separately from the artefacts bucket.
resource "aws_s3_bucket" "access_logs" {
  bucket        = "${var.name}-alb-logs-${data.aws_caller_identity.current.account_id}-${data.aws_region.current.region}"
  force_destroy = true

  tags = {
    Name = "${var.name}-alb-logs"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "access_logs" {
  bucket = aws_s3_bucket.access_logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "access_logs" {
  bucket = aws_s3_bucket.access_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Regions enabled before August 2022 deliver logs from a regional account
# rather than a service principal, which is what this data source resolves.
data "aws_elb_service_account" "current" {}

data "aws_iam_policy_document" "access_logs" {
  statement {
    sid       = "AllowLogDelivery"
    effect    = "Allow"
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.access_logs.arn}/*"]

    principals {
      type        = "AWS"
      identifiers = [data.aws_elb_service_account.current.arn]
    }
  }

  statement {
    sid       = "DenyInsecureTransport"
    effect    = "Deny"
    actions   = ["s3:*"]
    resources = [aws_s3_bucket.access_logs.arn, "${aws_s3_bucket.access_logs.arn}/*"]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "access_logs" {
  bucket = aws_s3_bucket.access_logs.id
  policy = data.aws_iam_policy_document.access_logs.json

  depends_on = [aws_s3_bucket_public_access_block.access_logs]
}
