# GitHub Actions identity for this account.

# Registers GitHub as a trusted token issuer, once per account.
# client_id_list is the accepted audience.
# No thumbprint: AWS verifies GitHub's certificate against its own CA store.
resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]

  tags = {
    Name = "${local.name}-oidc"
  }
}

# Who may assume the role. Both conditions read fields GitHub signs into the
# token: aud is who the token was issued for, sub is what produced it.
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

    # Exact match, never a wildcard. Both triggers, so pull requests can plan.
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

# assume_role_policy is the trust document, not the permissions.
# Fixed name because it is copied into a GitHub secret.
resource "aws_iam_role" "plan" {
  name                 = "${local.name}-plan"
  description          = "Assumed by GitHub Actions to run terraform plan"
  assume_role_policy   = data.aws_iam_policy_document.trust.json
  max_session_duration = 3600

  tags = {
    Name = "${local.name}-plan"
  }
}

# What it may do. Broad, but no GetSecretValue, no kms:Decrypt, no writes.
resource "aws_iam_role_policy_attachment" "read_only" {
  role       = aws_iam_role.plan.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}
