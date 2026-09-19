# Credentials come from the environment: AWS_PROFILE locally, OIDC in CI.
provider "aws" {
  region = local.region

  # Common tags for every resource. Modules add only Name.
  default_tags {
    tags = {
      Project     = local.project
      Environment = local.environment
      Owner       = "delaleva"
      ManagedBy   = "terraform"
    }
  }
}
