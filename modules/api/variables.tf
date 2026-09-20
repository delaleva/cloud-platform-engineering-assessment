variable "name" {
  description = "Prefix applied to all resource names."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,18}$", var.name))
    error_message = "name must be 2-19 characters, lowercase alphanumeric and hyphens, starting with a letter."
  }
}

variable "fqdn" {
  description = "Name the API is served under. Must match the server certificate's subject alternative name."
  type        = string
}

variable "private_zone_id" {
  description = "Hosted zone the API's record is created in."
  type        = string
}

variable "server_certificate_arn" {
  description = "ACM certificate the listener presents."
  type        = string
}

variable "trust_store_arn" {
  description = "Trust store the listener validates client certificates against."
  type        = string
}

variable "allowed_common_names" {
  description = "Client certificate common names the API will serve. A verified certificate outside this list is refused."
  type        = list(string)

  validation {
    condition     = length(var.allowed_common_names) > 0
    error_message = "allowed_common_names must contain at least one name, or no caller can reach the API."
  }
}

variable "kms_key_arn" {
  description = "Customer managed key encrypting the allow list, the log group and the alarm topic."
  type        = string
}

# Deleting a secret normally reserves its name for the recovery window, which
# blocks rebuilding under the same names on the same day.
variable "secret_recovery_window_days" {
  description = "Days Secrets Manager holds a deleted secret before removing it. Zero deletes immediately."
  type        = number
  default     = 30

  validation {
    condition     = var.secret_recovery_window_days == 0 || (var.secret_recovery_window_days >= 7 && var.secret_recovery_window_days <= 30)
    error_message = "secret_recovery_window_days must be 0, or between 7 and 30."
  }
}

variable "vpc_id" {
  description = "VPC the load balancer and function are placed in."
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block of the VPC, used as the load balancer's allowed source range."
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnets for the load balancer and the function."
  type        = list(string)

  validation {
    condition     = length(var.private_subnet_ids) >= 2
    error_message = "private_subnet_ids must contain at least two subnets. A load balancer refuses a single one."
  }
}

variable "endpoint_security_group_id" {
  description = "Security group on the interface endpoint network interfaces, which this module adds rules to."
  type        = string
}

variable "log_retention_days" {
  description = "Retention for the function log group, in days."
  type        = number
  default     = 365

  validation {
    condition = contains(
      [1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653],
      var.log_retention_days
    )
    error_message = "log_retention_days must be one of the retention periods CloudWatch Logs accepts."
  }
}
