# The self-signed certificate authority: the key that signs every other
# certificate here, its certificate published to S3 for the load balancer's
# trust store, and a custody copy of the key in Secrets Manager.

# Larger than the certificates it signs, because a CA lives longer and is worth
# more to an attacker than any one certificate it issues.
resource "tls_private_key" "ca" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "tls_self_signed_cert" "ca" {
  private_key_pem       = tls_private_key.ca.private_key_pem
  validity_period_hours = var.certificate_validity_hours
  is_ca_certificate     = true

  subject {
    common_name  = "${var.name} internal CA"
    organization = var.name
  }

  allowed_uses = [
    "cert_signing",
    "crl_signing",
    "digital_signature",
  ]
}

# Public material, so it is the certificate only and never the CA private key.
resource "aws_s3_object" "ca_bundle" {
  bucket       = aws_s3_bucket.artefacts.id
  key          = "trust-store/ca.pem"
  content      = tls_self_signed_cert.ca.cert_pem
  content_type = "application/x-pem-file"
  kms_key_id   = aws_kms_key.this.arn

  tags = {
    Name = "${var.name}-ca-bundle"
  }
}

# The load balancer's list of certificate authorities it will accept client
# certificates from. The listener points at this, and a certificate signed by
# anything else is refused during the handshake, before a request exists.
resource "aws_lb_trust_store" "this" {
  name = "${var.name}-ca"

  # The API takes a bucket and an object key rather than certificate text, so
  # the CA certificate is published to S3 first and copied in from there.
  ca_certificates_bundle_s3_bucket = aws_s3_bucket.artefacts.id
  ca_certificates_bundle_s3_key    = aws_s3_object.ca_bundle.key

  # Without the version, replacing the bundle leaves this resource unchanged
  # and the load balancer keeps trusting the old authority.
  ca_certificates_bundle_s3_object_version = aws_s3_object.ca_bundle.version_id

  tags = {
    Name = "${var.name}-ca"
  }
}

# Nothing reads this. It is a custody copy, so losing the state file does not
# also mean losing the authority that signed every certificate here.
resource "aws_secretsmanager_secret" "ca_private_key" {
  name                    = "${var.name}/ca-private-key"
  description             = "Private key of the internal certificate authority"
  kms_key_id              = aws_kms_key.this.arn
  recovery_window_in_days = var.secret_recovery_window_days

  tags = {
    Name = "${var.name}-ca-private-key"
  }
}

resource "aws_secretsmanager_secret_version" "ca_private_key" {
  secret_id     = aws_secretsmanager_secret.ca_private_key.id
  secret_string = tls_private_key.ca.private_key_pem
}
