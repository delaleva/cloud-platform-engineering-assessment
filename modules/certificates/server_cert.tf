# The server certificate the load balancer presents to prove it is the host
# clients asked for, and the ACM import that is the only way to give a
# listener a certificate.

resource "tls_private_key" "server" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_cert_request" "server" {
  private_key_pem = tls_private_key.server.private_key_pem

  # A client compares the name it asked for against this list, not against the
  # common name below. Both carry the hostname because older tools still show
  # the common name.
  dns_names = [local.fqdn]

  subject {
    common_name = local.fqdn
  }
}

resource "tls_locally_signed_cert" "server" {
  cert_request_pem      = tls_cert_request.server.cert_request_pem
  ca_private_key_pem    = tls_private_key.ca.private_key_pem
  ca_cert_pem           = tls_self_signed_cert.ca.cert_pem
  validity_period_hours = var.certificate_validity_hours

  allowed_uses = [
    "digital_signature",
    "key_encipherment",
    "server_auth",
  ]
}

# The load balancer can only be given a certificate through ACM. Ours was signed
# by our own CA rather than issued by ACM, so it is uploaded ready-made. ACM
# never hands a key back, which is why the client's certificate is not here.
resource "aws_acm_certificate" "server" {
  private_key      = tls_private_key.server.private_key_pem
  certificate_body = tls_locally_signed_cert.server.cert_pem

  # The CA certificate is served alongside the one above, so a client can follow
  # the signature back to the authority it already trusts.
  certificate_chain = tls_self_signed_cert.ca.cert_pem

  tags = {
    Name = "${var.name}-server"
  }

  # Make the new certificate before removing the old one, so the load balancer
  # is never left with nothing to serve.
  lifecycle {
    create_before_destroy = true
  }
}
