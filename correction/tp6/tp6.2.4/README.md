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

- [azurerm_network_watcher.default](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_watcher) (resource)
- [azurerm_resource_group.network_watcher](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/resource_group) (resource)

## Required Inputs

The following input variables are required:

### <a name="input_location"></a> [location](#input\_location)

Description: Main Azure location for this lab.

Type: `string`

## Optional Inputs

The following input variables are optional (have default values):

### <a name="input_base_tags"></a> [base\_tags](#input\_base\_tags)

Description: Base tags applied to managed resources.

Type: `map(string)`

Default:

```json
{
  "managedBy": "terraform",
  "owner": "formation",
  "tp": "resource-already-exists-lab"
}
```

## Outputs

The following outputs are exported:

### <a name="output_network_watcher_name"></a> [network\_watcher\_name](#output\_network\_watcher\_name)

Description: Expected default Network Watcher name for selected region.

### <a name="output_network_watcher_rg_name"></a> [network\_watcher\_rg\_name](#output\_network\_watcher\_rg\_name)

Description: Resource group expected for default Network Watcher.
