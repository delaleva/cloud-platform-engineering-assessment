# Holds the CA bundle the trust store is built from. force_destroy is set
# because versioning retains object versions that would otherwise block
# teardown.
resource "aws_s3_bucket" "artefacts" {
  bucket        = local.artefacts_bucket
  force_destroy = true

  tags = {
    Name = "${var.name}-artefacts"
  }
}

# A trust store change is a security event, so keeping old versions means a bad
# bundle can be rolled back rather than reconstructed.
resource "aws_s3_bucket_versioning" "artefacts" {
  bucket = aws_s3_bucket.artefacts.id

  versioning_configuration {
    status = "Enabled"
  }
}

# A bucket key caches one data key per bucket rather than requesting one for
# every object.
resource "aws_s3_bucket_server_side_encryption_configuration" "artefacts" {
  bucket = aws_s3_bucket.artefacts.id

  rule {
    bucket_key_enabled = true

    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.this.arn
    }
  }
}

resource "aws_s3_bucket_public_access_block" "artefacts" {
  bucket = aws_s3_bucket.artefacts.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# S3 accepts plaintext HTTP by default, so refusing it has to be written down.
data "aws_iam_policy_document" "artefacts" {
  statement {
    sid    = "DenyInsecureTransport"
    effect = "Deny"

    actions = ["s3:*"]

    resources = [
      aws_s3_bucket.artefacts.arn,
      "${aws_s3_bucket.artefacts.arn}/*",
    ]

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

resource "aws_s3_bucket_policy" "artefacts" {
  bucket = aws_s3_bucket.artefacts.id
  policy = data.aws_iam_policy_document.artefacts.json

  depends_on = [aws_s3_bucket_public_access_block.artefacts]
}
