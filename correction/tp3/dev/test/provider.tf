provider "azurerm" {
  features {
  }
  subscription_id                 = "37fe744e-5727-4031-a37a-f19348de8bf3"
  environment                     = "public"
  use_msi                         = false
  use_cli                         = true
  use_oidc                        = false
  resource_provider_registrations = "none"
}
