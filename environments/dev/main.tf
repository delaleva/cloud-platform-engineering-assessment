module "network" {
  source = "../../modules/network"

  name              = local.name
  vpc_cidr          = "10.42.0.0/20"
  azs               = ["eu-west-2a", "eu-west-2b"]
  private_zone_name = "internal.cpe"

  # Only what the workload calls at runtime.
  interface_endpoint_services = ["secretsmanager"]
}

# Owns the certificate authority and everything it signs. Consumers receive
# ARNs, so no private key crosses a module boundary.
module "certificates" {
  source = "../../modules/certificates"

  name              = local.name
  api_hostname      = "api"
  private_zone_name = module.network.private_zone_name

  # Zero so the environment can be rebuilt under the same names on the same day.
  # Any real environment keeps the default recovery window.
  secret_recovery_window_days = 0
}

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

# For verification only.
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
