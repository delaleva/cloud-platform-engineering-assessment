# Credentials resolve from the environment.
provider "aws" {
  region = local.region

  # Shared, not dev: this role outlives any single environment.
  default_tags {
    tags = {
      Project     = local.project
      Environment = "shared"
      Owner       = "delaleva"
      ManagedBy   = "terraform"
    }
  }
}
