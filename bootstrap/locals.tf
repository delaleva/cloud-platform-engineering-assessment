locals {
  project = "cpe"
  region  = "eu-west-2"
  name    = "${local.project}-github-actions"

  github_org     = "delaleva"
  github_org_id  = "25754364"
  github_repo    = "cloud-platform-engineering-assessment"
  github_repo_id = "1375048119"
  github_ref     = "refs/heads/main"

  # GitHub appends numeric IDs to the owner and repository names in the subject
  # claim, so a repository recreated under the same name cannot inherit access.
  github_subject = "repo:${local.github_org}@${local.github_org_id}/${local.github_repo}@${local.github_repo_id}"
}
