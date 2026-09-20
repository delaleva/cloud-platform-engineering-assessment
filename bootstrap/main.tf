# GitHub Actions identity for this AWS account: the provider that makes GitHub
# tokens verifiable, the role CI assumes, and the permissions that role gets.

# Registers GitHub as an identity provider for this account. client_id_list is
# the accepted audience list, despite its name, and no thumbprint is set because
# AWS validates GitHub's certificate against its own trust store.
resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]

  tags = {
    Name = "${local.name}-oidc"
  }
}

# The role's trust policy, rendered locally. Its conditions check who the token
# was issued for, and what produced it.
data "aws_iam_policy_document" "trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    # Exact matches rather than a pattern, so no other repository qualifies.
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values = [
        "${local.github_subject}:ref:${local.github_ref}",
        "${local.github_subject}:pull_request",
      ]
    }
  }
}

# assume_role_policy sets who may assume the role, not what it can do;
# permissions are attached separately. The name is explicit rather than
# name_prefix because a GitHub secret stores the resulting ARN.
resource "aws_iam_role" "plan" {
  name                 = "${local.name}-plan"
  description          = "Assumed by GitHub Actions to run terraform plan"
  assume_role_policy   = data.aws_iam_policy_document.trust.json
  max_session_duration = 3600

  tags = {
    Name = "${local.name}-plan"
  }
}

# The role's permissions. ReadOnlyAccess is broad, but it grants no secret
# reads, no decryption and no write actions, which is all a plan needs.
resource "aws_iam_role_policy_attachment" "read_only" {
  role       = aws_iam_role.plan.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}
