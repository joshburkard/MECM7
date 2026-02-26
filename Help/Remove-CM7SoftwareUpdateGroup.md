# Remove-CM7SoftwareUpdateGroup

---
## SYNOPSIS

Removes a software update group from MECM using CIM connectivity.

## SYNTAX

```PowerShell
Remove-CM7SoftwareUpdateGroup [-Name] <string> [-Force] [-WhatIf] [<CommonParameters>]
Remove-CM7SoftwareUpdateGroup [-CI_ID] <int> [-Force] [-WhatIf] [<CommonParameters>]
```

## DESCRIPTION

Removes a software update group (SMS_AuthorizationList) from Microsoft Endpoint Configuration Manager (MECM) using CIM. This function is analogous to Remove-CMSoftwareUpdateGroup from the ConfigurationManager module, but works via CIM.

## PARAMETERS

- **Name** (string, required): Name of the software update group.
- **CI_ID** (int, required): CI_ID of the software update group.
- **Force** (switch, optional): Force removal without confirmation.
- **WhatIf** (switch, optional): Shows what would happen if the command runs.

## EXAMPLES

### Example 1

```PowerShell
Remove-CM7SoftwareUpdateGroup -Name "Test-SUG-Creation" -Force
```

### Example 2

```PowerShell
Remove-CM7SoftwareUpdateGroup -CI_ID 12345678 -Force
```

## NOTES
- Requires CIM connectivity to SCCM site server.
- Only removes the specified software update group.

## RELATED LINKS
- [Remove-CMSoftwareUpdateGroup](https://learn.microsoft.com/en-us/powershell/module/configurationmanager/remove-cmsoftwareupdategroup?view=sccm-ps)
- [New-CM7SoftwareUpdateGroup](./New-CM7SoftwareUpdateGroup.md)
- [Get-CM7SoftwareUpdateGroup](./Get-CM7SoftwareUpdateGroup.md)

---
