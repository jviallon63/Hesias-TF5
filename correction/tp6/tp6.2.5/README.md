## Requirements

The following requirements are needed by this module:

- <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) (>= 1.5.0)

- <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) (~> 4.0)

## Providers

The following providers are used by this module:

- <a name="provider_azurerm"></a> [azurerm](#provider\_azurerm) (~> 4.0)

## Modules

No modules.

## Resources

The following resources are used by this module:

- [azurerm_network_interface.app](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_interface) (resource)
- [azurerm_network_interface_security_group_association.app](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_interface_security_group_association) (resource)
- [azurerm_network_security_group.app](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_security_group) (resource)
- [azurerm_resource_group.main](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/resource_group) (resource)
- [azurerm_subnet.app](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet) (resource)
- [azurerm_virtual_network.main](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network) (resource)

## Required Inputs

No required inputs.

## Optional Inputs

The following input variables are optional (have default values):

### <a name="input_base_tags"></a> [base\_tags](#input\_base\_tags)

Description: Base tags applied to all resources.

Type: `map(string)`

Default:

```json
{
  "managedBy": "terraform",
  "owner": "formation",
  "tp": "invalid-foreach-lab"
}
```

### <a name="input_environment"></a> [environment](#input\_environment)

Description: Environment name used in naming and tagging.

Type: `string`

Default: `"lab"`

### <a name="input_location"></a> [location](#input\_location)

Description: Azure region used by this lab.

Type: `string`

Default: `"westeurope"`

### <a name="input_nic_count"></a> [nic\_count](#input\_nic\_count)

Description: Number of NICs to create for the lab scenario.

Type: `number`

Default: `2`

### <a name="input_project_name"></a> [project\_name](#input\_project\_name)

Description: Project prefix used in resource names.

Type: `string`

Default: `"tp6"`

## Outputs

The following outputs are exported:

### <a name="output_nic_names"></a> [nic\_names](#output\_nic\_names)

Description: NIC names created by the lab.

### <a name="output_resource_group_name"></a> [resource\_group\_name](#output\_resource\_group\_name)

Description: Main resource group name.

### <a name="output_vnet_name"></a> [vnet\_name](#output\_vnet\_name)

Description: Virtual network name.
