variable "name" {
  description = "Prefix applied to all resource names."
  type        = string
}

variable "vpc_id" {
  description = "VPC the function is placed in."
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnets the function runs in."
  type        = list(string)
}

variable "endpoint_security_group_id" {
  description = "Security group on the interface endpoint network interfaces."
  type        = string
}

variable "api_security_group_id" {
  description = "Security group fronting the API, which this function connects to."
  type        = string
}

variable "api_url" {
  description = "URL of the API to call."
  type        = string
}

variable "client_identity_secret_arn" {
  description = "Secret holding the client certificate, its key, and the CA bundle."
  type        = string
}

variable "kms_key_arn" {
  description = "Key protecting the secret and the log group."
  type        = string
}

variable "log_retention_days" {
  description = "Retention for the function log group, in days."
  type        = number
  default     = 365
}
