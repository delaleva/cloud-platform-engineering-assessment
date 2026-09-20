# Mutual TLS proves a certificate was signed by the trusted CA. It does not
# say which holders are allowed, so the API reads this list and rejects
# anyone else. It is authorisation policy, which is why it lives here and
# not with the certificates.
resource "aws_secretsmanager_secret" "allowed_clients" {
  name                    = "${var.name}/allowed-clients"
  description             = "Client certificate subjects the API will serve"
  kms_key_id              = var.kms_key_arn
  recovery_window_in_days = var.secret_recovery_window_days

  tags = {
    Name = "${var.name}-allowed-clients"
  }
}

resource "aws_secretsmanager_secret_version" "allowed_clients" {
  secret_id = aws_secretsmanager_secret.allowed_clients.id

  secret_string = jsonencode({
    allowed_common_names = var.allowed_common_names
  })
}
