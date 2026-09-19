locals {
  project = "cpe"
  region  = "eu-west-2"
  name    = "${local.project}-github-actions"

  github_org  = "delaleva"
  github_repo = "cloud-platform-engineering-assessment"
  github_ref  = "refs/heads/main"

  # The trigger is appended to this to form the full subject claim.
  github_subject = "repo:${local.github_org}/${local.github_repo}"
}
