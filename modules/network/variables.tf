variable "name" {
  description = "Prefix applied to all resource names."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,18}$", var.name))
    error_message = "name must be 2-19 characters, lowercase alphanumeric and hyphens, starting with a letter."
  }
}

variable "vpc_cidr" {
  description = "IPv4 CIDR block for the VPC. Private subnets are derived from it with four additional prefix bits."
  type        = string

  validation {
    condition = (
      can(cidrhost(var.vpc_cidr, 0)) &&
      tonumber(split("/", var.vpc_cidr)[1]) >= 16 &&
      tonumber(split("/", var.vpc_cidr)[1]) <= 24
    )
    error_message = "vpc_cidr must be a valid IPv4 CIDR block between /16 and /24."
  }
}

variable "azs" {
  description = "Availability zones to create one private subnet in each."
  type        = list(string)

  validation {
    condition     = length(var.azs) >= 2 && length(distinct(var.azs)) == length(var.azs)
    error_message = "azs must contain at least two distinct availability zones."
  }
}

variable "interface_endpoint_services" {
  description = "AWS service short names to create interface endpoints for, such as secretsmanager or kms."
  type        = set(string)
  default     = []
}

variable "log_retention_days" {
  description = "Retention for the VPC flow log and resolver query log groups, in days."
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

variable "private_zone_name" {
  description = "Private DNS zone associated with the VPC, such as internal.example."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]([a-z0-9-]*[a-z0-9])?(\\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)+$", var.private_zone_name))
    error_message = "private_zone_name must be a valid DNS name of at least two labels, such as internal.example."
  }
}
