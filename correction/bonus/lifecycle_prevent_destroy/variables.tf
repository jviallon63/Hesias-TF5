variable "resource_group_name" {
  description = "Resource Group name"
  type        = string
  default     = "rg-tp7-lifecycle-41"
}

variable "location_rg" {
  description = "Azure region"
  type        = string
  default     = "westeurope"
}

variable "location_db" {
  description = "Azure region for the database"
  type        = string
  default     = "westeurope"
}

variable "postgres_name_prefix" {
  description = "Prefix for PostgreSQL Flexible Server name"
  type        = string
  default     = "psqltp741"
}

variable "admin_login" {
  description = "PostgreSQL admin login"
  type        = string
  default     = "psqladmin"
}
