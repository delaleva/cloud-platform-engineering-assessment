locals {
  project     = "cpe"
  environment = "dev"
  name        = "${local.project}-${local.environment}"
  region      = "eu-west-2"
}
