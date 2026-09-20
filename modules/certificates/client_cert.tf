# The client certificate and the Secrets Manager secret holding it. The test
# client reads that secret at startup and presents the certificate when it
# connects, which is how the load balancer knows who is calling. In production
# the caller would generate its own key and send us only a request to sign.

resource "tls_private_key" "client" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_cert_request" "client" {
  private_key_pem = tls_private_key.client.private_key_pem

  subject {
    common_name  = "${var.name}-client"
    organization = var.name
  }
}

resource "tls_locally_signed_cert" "client" {
  cert_request_pem      = tls_cert_request.client.cert_request_pem
  ca_private_key_pem    = tls_private_key.ca.private_key_pem
  ca_cert_pem           = tls_self_signed_cert.ca.cert_pem
  validity_period_hours = var.certificate_validity_hours

  allowed_uses = [
    "digital_signature",
    "key_encipherment",
    "client_auth",
  ]
}

# The in-VPC test client fetches this to present a certificate to the listener.
resource "aws_secretsmanager_secret" "client_identity" {
  name                    = "${var.name}/client-identity"
  description             = "Client certificate and private key for the test harness"
  kms_key_id              = aws_kms_key.this.arn
  recovery_window_in_days = var.secret_recovery_window_days

  tags = {
    Name = "${var.name}-client-identity"
  }
}

resource "aws_secretsmanager_secret_version" "client_identity" {
  secret_id = aws_secretsmanager_secret.client_identity.id

  # The CA certificate is bundled in so the client can check the load balancer's
  # certificate as well. In mutual TLS each side verifies the other.
  secret_string = jsonencode({
    certificate = tls_locally_signed_cert.client.cert_pem
    private_key = tls_private_key.client.private_key_pem
    ca          = tls_self_signed_cert.ca.cert_pem
  })
}
