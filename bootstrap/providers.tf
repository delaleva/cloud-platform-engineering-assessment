provider "aws" {
  region = local.region

  # Tagged as shared rather than dev because this role outlives any single
  # environment.
  default_tags {
    tags = {
      Project     = local.project
      Environment = "shared"
      Owner       = "delaleva"
      ManagedBy   = "terraform"
    }
  }
}
