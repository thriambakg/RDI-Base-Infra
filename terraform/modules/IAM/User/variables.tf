variable "user_name" {
  description = "Name of the IAM user"
  type        = string
}

variable "path" {
  description = "Path for the IAM user"
  type        = string
  default     = "/"
}

variable "managed_policy_arns" {
  description = "List of managed policy ARNs to attach to the user"
  type        = list(string)
  default     = []
}

variable "inline_policies" {
  description = "Map of inline policy names to policy document (JSON string)"
  type        = map(string)
  default     = {}
}

variable "tags" {
  description = "Tags to apply to the IAM user"
  type        = map(string)
  default     = {}
}
