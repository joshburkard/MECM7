# Remove-CM7SoftwareUpdateDeployment.md

---
## SYNOPSIS

Removes a software update deployment from a specified collection using CIM connectivity.

## SYNTAX

```PowerShell
Remove-CM7SoftwareUpdateDeployment [-SoftwareUpdateGroupName] <string> [-CollectionName] <string> [-Force] [-WhatIf] [<CommonParameters>]
```

## DESCRIPTION

Removes a deployment of a software update group from a device collection in SCCM, using CIM connectivity. This function is analogous to Remove-CMSoftwareUpdateDeployment from the ConfigurationManager module, but works via CIM.

## PARAMETERS

- **SoftwareUpdateGroupName** (string, required): Name of the software update group.
- **CollectionName** (string, required): Name of the collection from which to remove the deployment.
- **Force** (switch, optional): Force removal without confirmation.
- **WhatIf** (switch, optional): Shows what would happen if the command runs.

## EXAMPLES

### Example 1

```PowerShell
Remove-CM7SoftwareUpdateDeployment -SoftwareUpdateGroupName "Test-SUG" -CollectionName "Test-Collection-Direct"
```

### Example 2

```PowerShell
Remove-CM7SoftwareUpdateDeployment -SoftwareUpdateGroupName "Test-SUG" -CollectionName "Test-Collection-Include" -Force
```

## NOTES

- Requires CIM connectivity to SCCM site server.
- Only removes deployments for the specified SUG and collection.

## RELATED LINKS

- [Remove-CMSoftwareUpdateDeployment](https://learn.microsoft.com/en-us/powershell/module/configurationmanager/remove-cmsoftwareupdatedeployment?view=sccm-ps)
- [New-CM7SoftwareUpdateDeployment](./New-CM7SoftwareUpdateDeployment.md)
- [Get-CM7SoftwareUpdateDeployment](./Get-CM7SoftwareUpdateDeployment.md)

---
