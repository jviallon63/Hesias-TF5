variable "project_name" {
  type        = string
  description = "Project prefix used in resource names."
  default     = "tp6"
}

variable "environment" {
  type        = string
  description = "Environment name used in naming and tagging."
  default     = "lab"
}
