terraform {
  required_version = "~> 1.16"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # Remote state is not enabled for this sandbox run.
  # Terraform 1.10+ locks natively, so no DynamoDB table.
  #
  # backend "s3" {
  #   bucket       = "cpe-tfstate-<account-id>-eu-west-2"
  #   key          = "environments/dev/terraform.tfstate"
  #   region       = "eu-west-2"
  #   encrypt      = true
  #   use_lockfile = true
  # }
}
