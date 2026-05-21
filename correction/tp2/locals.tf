locals {
  common_tags = {
    environment = var.environment
    project     = "tp2"
    managed_by  = "terraform"
    owner       = "me"
  }
}