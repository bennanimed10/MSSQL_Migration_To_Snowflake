# Required variables
variable "bucket_name" {
  description = "Name of the S3 bucket"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

# Optional variables
variable "additional_tags" {
  description = "Additional tags to apply to the bucket"
  type        = map(string)
  default     = {}
}

variable "lifecycle_rules" {
  description = "List of lifecycle rules for the bucket"
  type = list(object({
    id     = string
    status = string
    filter = optional(object({
      prefix = optional(string)
      tags   = optional(map(string))
    }))
    expiration = optional(object({
      days = number
    }))
    noncurrent_version_expiration = optional(object({
      days = number
    }))
    transitions = optional(list(object({
      days          = number
      storage_class = string
    })))
  }))
  default = []
}

variable "enable_cors" {
  description = "Enable CORS configuration for the bucket"
  type        = bool
  default     = false
}

variable "cors_allowed_origins" {
  description = "List of allowed origins for CORS"
  type        = list(string)
  default     = ["*"]
}

variable "access_logging_bucket" {
  description = "S3 bucket for access logging"
  type        = string
  default     = null
}

variable "enable_intelligent_tiering" {
  description = "Enable intelligent tiering for the bucket"
  type        = bool
  default     = false
}

variable "intelligent_tiering_filter" {
  description = "Filter for intelligent tiering configuration"
  type = object({
    prefix = optional(string)
    tags   = optional(map(string))
  })
  default = null
}

variable "kms_key_id" {
  description = "KMS key ID for bucket encryption"
  type        = string
  default     = null
}

variable "enable_transfer_acceleration" {
  description = "Enable transfer acceleration for the bucket"
  type        = bool
  default     = false
}

variable "enable_request_payer" {
  description = "Enable requester pays for the bucket"
  type        = bool
  default     = false
}

