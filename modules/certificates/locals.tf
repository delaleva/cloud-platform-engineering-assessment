data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.region

  # The server certificate's subject alternative name must match this exactly,
  # or the client rejects the handshake before any request is made.
  fqdn = "${var.api_hostname}.${var.private_zone_name}"

  artefacts_bucket = "${var.name}-artefacts-${local.account_id}-${local.region}"
}
