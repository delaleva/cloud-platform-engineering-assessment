provider "aws" {
  region = local.region

  # Modules set only Name, so everything common belongs here.
  default_tags {
    tags = {
      Project     = local.project
      Environment = local.environment
      Owner       = "delaleva"
      ManagedBy   = "terraform"
    }
  }
}
