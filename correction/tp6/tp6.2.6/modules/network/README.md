## Requirements

No requirements.

## Providers

The following providers are used by this module:

- <a name="provider_azurerm"></a> [azurerm](#provider\_azurerm)

## Modules

No modules.

## Resources

The following resources are used by this module:

- [azurerm_virtual_network.main](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network) (resource)

## Required Inputs

The following input variables are required:

### <a name="input_address_space"></a> [address\_space](#input\_address\_space)

Description: Address space for the virtual network.

Type: `list(string)`

### <a name="input_location"></a> [location](#input\_location)

Description: Azure location for module resources.

Type: `string`

### <a name="input_rg_name"></a> [rg\_name](#input\_rg\_name)

Description: Resource group name where VNet is deployed.

Type: `string`

### <a name="input_tags"></a> [tags](#input\_tags)

Description: Tags applied to module resources.

Type: `map(string)`

### <a name="input_vnet_name"></a> [vnet\_name](#input\_vnet\_name)

Description: Virtual network name.

Type: `string`

## Optional Inputs

No optional inputs.

## Outputs

The following outputs are exported:

### <a name="output_vnet_name"></a> [vnet\_name](#output\_vnet\_name)

Description: Virtual network name.
