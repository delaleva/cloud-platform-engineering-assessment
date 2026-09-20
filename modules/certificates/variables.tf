variable "name" {
  description = "Prefix applied to all resource names."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,18}$", var.name))
    error_message = "name must be 2-19 characters, lowercase alphanumeric and hyphens, starting with a letter."
  }
}

variable "private_zone_name" {
  description = "Name of the hosted zone the API is served under, which the certificate's subject alternative name must match."
  type        = string
}

variable "api_hostname" {
  description = "Host label for the API inside that zone."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]([a-z0-9-]*[a-z0-9])?$", var.api_hostname))
    error_message = "api_hostname must be a single DNS label, lowercase alphanumeric and hyphens."
  }
}

# Thirty days: long enough to build, test and demonstrate, short enough that
# anything left behind stops working on its own.
variable "certificate_validity_hours" {
  description = "How long the generated CA and leaf certificates stay valid."
  type        = number
  default     = 720

  validation {
    condition     = var.certificate_validity_hours >= 24
    error_message = "certificate_validity_hours must be at least 24."
  }
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
