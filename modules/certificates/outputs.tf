output "fqdn" {
  description = "Name the server certificate is issued for."
  value       = local.fqdn
}

output "kms_key_arn" {
  description = "Customer managed key covering the secrets, the artefacts bucket and the consuming module's log groups."
  value       = aws_kms_key.this.arn
}

output "server_certificate_arn" {
  description = "ACM ARN of the imported server certificate, for a listener to serve."
  value       = aws_acm_certificate.server.arn
}

output "trust_store_arn" {
  description = "Trust store a listener validates client certificates against."
  value       = aws_lb_trust_store.this.arn
}

output "client_common_names" {
  description = "Subjects of the client certificates issued here, for a consumer to authorise against."
  value       = [tls_cert_request.client.subject[0].common_name]
}

# These expose ARNs rather than values, so a consumer reads the secret itself.
output "client_identity_secret_arn" {
  description = "Secret holding the client certificate, its key and the CA certificate."
  value       = aws_secretsmanager_secret.client_identity.arn
}
