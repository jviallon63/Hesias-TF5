variable "location" {
  type        = string
  description = "Main Azure location for this lab."
  default     = "westeurope"
}

variable "network_watcher_region" {
  type        = string
  description = "Region suffix used in default Network Watcher name."
  default     = "westeurope"
}

variable "base_tags" {
  type        = map(string)
  description = "Base tags applied to managed resources."
  default = {
    owner     = "formation"
    managedBy = "terraform"
    tp        = "resource-already-exists-lab"
  }
}
