# Save-CM7SoftwareUpdate.md

## SYNOPSIS
Saves one or more software updates to update groups and deployment packages using CIM connectivity.

## DESCRIPTION
The Save-CM7SoftwareUpdate function allows you to save software updates to update groups and deployment packages in MECM, using CIM connectivity. You can specify updates by name, ID, object, or group. Supports download location, retry logic, and language selection.

## PARAMETERS
-DeploymentPackageName <String> (Mandatory)
-SoftwareUpdateName <String[]> (By name)
-SoftwareUpdateId <String[]> (By ID)
-SoftwareUpdate <Object> (By object)
-SoftwareUpdateGroupName <String[]> (By group name)
-SoftwareUpdateGroupId <String[]> (By group ID)
-SoftwareUpdateGroup <Object> (By group object)
-Location <String> (Optional)
-RetryCount <UInt32> (Optional, default 3)
-RetryDelaySec <UInt32> (Optional, default 2)
-SoftwareUpdateLanguage <String[]> (Optional)
-DisableWildcardHandling <Switch> (Optional)
-ForceWildcardHandling <Switch> (Optional)

## EXAMPLES
### Example 1
Save-CM7SoftwareUpdate -SoftwareUpdateName "Cumulative Update for Windows 10 (KB3095020)" -DeploymentPackageName "Package01" -SoftwareUpdateLanguage "English"

### Example 2
Get-CM7SoftwareUpdateGroup -Name "Test-SUG" | Save-CM7SoftwareUpdate -DeploymentPackageName "Package01"

### Example 3
Save-CM7SoftwareUpdate -SoftwareUpdateGroupName "Test-SUG" -DeploymentPackageName "Package01" -Location "\\Server01\Updates"

## NOTES
Requires CIM connectivity to MECM site server.

## RELATED LINKS
- Get-CM7SoftwareUpdate
- Get-CM7SoftwareUpdateGroup
- New-CM7SoftwareUpdateDeploymentPackage
- Remove-CM7SoftwareUpdateDeploymentPackage
