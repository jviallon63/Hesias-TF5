variable "location" {
  type        = string
  description = "Main Azure location for this lab."
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
