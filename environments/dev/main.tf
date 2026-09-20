# The private network that everything else sits in.
module "network" {
  source = "../../modules/network"

  name              = local.name
  vpc_cidr          = "10.42.0.0/20"
  azs               = ["eu-west-2a", "eu-west-2b"]
  private_zone_name = "internal.cpe"

  # Only the services the functions call at runtime need an endpoint.
  interface_endpoint_services = ["secretsmanager"]
}

# The certificate authority and everything it signs.
module "certificates" {
  source = "../../modules/certificates"

  name              = local.name
  api_hostname      = "api"
  private_zone_name = module.network.private_zone_name

  # Zero in both modules so the environment can be rebuilt under the same names
  # on the same day. Any real environment keeps the default recovery window.
  secret_recovery_window_days = 0
}

# The API itself: the load balancer that enforces mutual TLS, and the
# function behind it.
module "api" {
  source = "../../modules/api"

  name            = local.name
  fqdn            = module.certificates.fqdn
  private_zone_id = module.network.private_zone_id

  server_certificate_arn = module.certificates.server_certificate_arn
  trust_store_arn        = module.certificates.trust_store_arn
  allowed_common_names   = module.certificates.client_common_names
  kms_key_arn            = module.certificates.kms_key_arn

  vpc_id                     = module.network.vpc_id
  vpc_cidr                   = module.network.vpc_cidr
  private_subnet_ids         = module.network.private_subnet_ids
  endpoint_security_group_id = module.network.endpoint_security_group_id

  secret_recovery_window_days = 0
}

# Calls the API from inside the VPC with a certificate this CA signed, going
# through the same handshake as any other caller. Verification only, not part
# of the service.
module "test_client" {
  source = "../../modules/test_client"

  name                       = local.name
  vpc_id                     = module.network.vpc_id
  private_subnet_ids         = module.network.private_subnet_ids
  endpoint_security_group_id = module.network.endpoint_security_group_id
  api_security_group_id      = module.api.api_security_group_id
  api_url                    = module.api.api_url
  client_identity_secret_arn = module.certificates.client_identity_secret_arn
  kms_key_arn                = module.certificates.kms_key_arn
}
