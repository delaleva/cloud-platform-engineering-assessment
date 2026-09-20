output "plan_role_arn" {
  description = "Role ARN to store as the GitHub Actions secret AWS_ROLE_ARN."
  value       = aws_iam_role.plan.arn
}
