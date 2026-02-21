# Remove-CM7SoftwareUpdateDeploymentPackage

## SYNOPSIS
Removes a software update deployment package from MECM using CIM.

## DESCRIPTION
The `Remove-CM7SoftwareUpdateDeploymentPackage` function removes (deletes) a software update deployment package (`SMS_SoftwareUpdatesPackage`) from Microsoft Endpoint Configuration Manager (MECM) using CIM.

This function is the CIM-based equivalent of the `Remove-CMSoftwareUpdateDeploymentPackage` cmdlet from the ConfigurationManager PowerShell module, but uses direct CIM queries over WinRM instead of requiring the ConfigMgr console or PowerShell drive.

The function performs the following actions:

1. Validates an active connection exists (established via `Connect-CM7`)
2. Resolves the package by name or package ID
3. Removes the `SMS_SoftwareUpdatesPackage` instance via CIM (with confirmation by default)

Key features:
- **Multiple Identification**: Remove by Name, PackageID, or pipeline input object
- **Wildcard Support**: Use `*` and `?` in package names to match multiple packages
- **Force Parameter**: Bypass confirmation prompts for scripted scenarios
- **WhatIf/Confirm**: Full ShouldProcess support for safe operations

## PARAMETERS

### -Name
Specifies the name of the software update deployment package to remove. Supports wildcard characters (`*` and `?`).

- **Type**: String
- **Position**: Named
- **Required**: Yes (when using ByName parameter set)
- **Parameter Set**: ByName
- **Accept wildcard characters**: Yes

### -Id
Specifies the PackageID of the software update deployment package to remove.

- **Type**: String
- **Position**: Named
- **Required**: Yes (when using ById parameter set)
- **Parameter Set**: ById
- **Accept wildcard characters**: No

### -InputObject
A software update deployment package object (from `Get-CM7SoftwareUpdateDeploymentPackage`) to remove.

- **Type**: Object
- **Position**: Named
- **Required**: Yes (when using ByInputObject parameter set)
- **Parameter Set**: ByInputObject
- **Accept pipeline input**: Yes

### -Force
Suppresses confirmation prompts and removes the package without asking.

- **Type**: SwitchParameter
- **Position**: Named
- **Required**: No

### -WhatIf
Shows what would happen if the cmdlet runs. The cmdlet is not run.

- **Type**: SwitchParameter
- **Position**: Named
- **Required**: No

### -Confirm
Prompts you for confirmation before running the cmdlet.

- **Type**: SwitchParameter
- **Position**: Named
- **Required**: No

## EXAMPLES

### EXAMPLE 1: Remove by name
```powershell
Remove-CM7SoftwareUpdateDeploymentPackage -Name "Test-SUG" -Force
```
Removes the software update deployment package named "Test-SUG" without prompting for confirmation.

### EXAMPLE 2: Remove by PackageID
```powershell
Remove-CM7SoftwareUpdateDeploymentPackage -Id "XXX00001" -Force
```
Removes the package with the specified PackageID.

### EXAMPLE 3: Remove by InputObject
```powershell
$pkg = Get-CM7SoftwareUpdateDeploymentPackage -Name "Test-SUG"
Remove-CM7SoftwareUpdateDeploymentPackage -InputObject $pkg -Force
```
Removes a package using a previously retrieved package object.

### EXAMPLE 4: Preview removal with WhatIf
```powershell
Remove-CM7SoftwareUpdateDeploymentPackage -Name "Test-SUG" -WhatIf
```
Shows what would happen without actually removing the package.

## OUTPUTS

### MECM7.RemovedSoftwareUpdateDeploymentPackage
The function returns a custom object of type `MECM7.RemovedSoftwareUpdateDeploymentPackage` with the following properties:

| Property   | Type   | Description                                 |
|------------|--------|---------------------------------------------|
| PackageID  | String | The unique package ID of the removed package |
| Name       | String | The name of the removed package              |
| Status     | String | Always "Removed" on successful deletion      |

## REQUIREMENTS
- An active MECM/SCCM connection established via `Connect-CM7`
- PowerShell 5.1 or higher
- Access to the MECM SMS Provider via WinRM
- Sufficient MECM permissions to delete software update deployment packages

## NOTES
- The function removes software update deployment packages using the `SMS_SoftwareUpdatesPackage` WMI class directly via CIM sessions.
- When using `-Name` with wildcards, multiple packages may match and all will be removed.
- The `-Force` parameter bypasses the confirmation prompt for scripted automation scenarios.
- By default, the function has `ConfirmImpact = 'High'`, which means it will prompt for confirmation unless `-Force` is used or `$ConfirmPreference` is set to `None`.
- Pipeline input is supported via the `InputObject` parameter, allowing objects from `Get-CM7SoftwareUpdateDeploymentPackage` to be piped directly.
- Removing a deployment package does not remove the software update group or the updates themselves; it only removes the package object.
- Wildcard support uses WQL `LIKE` operator translation (`*` → `%`, `?` → `_`).

## RELATED LINKS
- [Connect-CM7](./Connect-CM7.md) - Establish connection to MECM
- [Get-CM7SoftwareUpdateDeploymentPackage](./Get-CM7SoftwareUpdateDeploymentPackage.md) - Retrieve software update deployment package information
- [New-CM7SoftwareUpdateDeploymentPackage](./New-CM7SoftwareUpdateDeploymentPackage.md) - Create a new software update deployment package

## SEE ALSO
- `Remove-CMSoftwareUpdateDeploymentPackage` - Native ConfigurationManager module equivalent
- `Remove-CimInstance` - PowerShell CIM cmdlet for removing WMI instances
- `SMS_SoftwareUpdatesPackage` - MECM WMI class for deployment packages
