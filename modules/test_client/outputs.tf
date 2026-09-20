output "function_name" {
  description = "Name of the test client function, for invoking it by hand."
  value       = aws_lambda_function.this.function_name
}
