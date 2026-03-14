variable "role_name" {
  description = "Name of the IAM role"
  type        = string
}

variable "description" {
  description = "Description of the IAM role"
  type        = string
  default     = ""
}

variable "path" {
  description = "Path for the IAM role"
  type        = string
  default     = "/"
}

variable "assume_role_policy" {
  description = "Assume role policy document (JSON string). Define in caller main.tf for flexibility."
  type        = string
}

variable "inline_policies" {
  description = "Map of inline policy name to policy document (JSON string). Define policies in caller main.tf."
  type        = map(string)
  default     = {}
}

variable "managed_policy_arns" {
  description = "List of managed policy ARNs to attach"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags to apply to the role"
  type        = map(string)
  default     = {}
}
