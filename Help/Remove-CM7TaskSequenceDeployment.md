# Remove-CM7TaskSequenceDeployment

## SYNOPSIS

Removes a task sequence deployment from MECM using CIM.

## DESCRIPTION

The `Remove-CM7TaskSequenceDeployment` function removes (deletes) a task sequence deployment (`SMS_Advertisement` with `ProgramName = '*'`) from Microsoft Endpoint Configuration Manager (MECM) using CIM.

This function is the CIM-based equivalent of the `Remove-CMTaskSequenceDeployment` cmdlet from the ConfigurationManager PowerShell module, but uses direct CIM queries over WinRM instead of requiring the ConfigMgr console or PowerShell drive.

The function performs the following actions:

1. Validates an active connection exists (established via `Connect-CM7`)
2. Resolves the deployment by advertisement ID, collection name, task sequence name, task sequence PackageID, deployment name, or input object
3. Verifies the advertisement is a task sequence deployment (`ProgramName = '*'`)
4. Removes the `SMS_Advertisement` instance via CIM (with confirmation by default)

Key features:
- **Multiple Identification**: Remove by AdvertisementID, collection name, task sequence name/PackageID, deployment name, or pipeline input object
- **Wildcard Support**: Use `*` and `?` in collection names, task sequence names, and deployment names to match multiple deployments
- **Pipeline Support**: Accept deployment objects from `Get-CM7TaskSequenceDeployment` via pipeline
- **Force Parameter**: Bypass confirmation prompts for scripted scenarios
- **WhatIf/Confirm**: Full ShouldProcess support for safe operations

## PARAMETERS

### -AdvertisementID

Specifies the unique advertisement ID (deployment ID) of the task sequence deployment to remove.

- **Type**: String
- **Position**: Named
- **Default**: None
- **Required**: Yes (when using ByAdvertisementID parameter set)
- **Parameter Set**: ByAdvertisementID
- **Accept pipeline input**: False
- **Accept wildcard characters**: No

Example: `"CM120BD2"` - Removes the deployment with this advertisement ID

### -CollectionName

Specifies the name of the collection targeted by the task sequence deployment(s) to remove. Supports wildcard characters (`*` and `?`). If multiple deployments match, all are removed.

- **Type**: String
- **Position**: Named
- **Default**: None
- **Required**: Yes (when using ByCollectionName parameter set)
- **Parameter Set**: ByCollectionName
- **Accept pipeline input**: False
- **Accept wildcard characters**: Yes

Example: `"Test-Collection-Direct"` - Removes all TS deployments targeting this collection

### -TaskSequenceName

Specifies the name of the task sequence associated with the deployment(s) to remove. Supports wildcard characters (`*` and `?`). If multiple deployments match, all are removed.

- **Type**: String
- **Position**: Named
- **Default**: None
- **Required**: Yes (when using ByTaskSequenceName parameter set)
- **Parameter Set**: ByTaskSequenceName
- **Accept pipeline input**: False
- **Accept wildcard characters**: Yes

Example: `"Test Josh"` - Removes all deployments of this task sequence

### -TaskSequencePackageId

Specifies the PackageID of the task sequence associated with the deployment(s) to remove. If multiple deployments match, all are removed.

- **Type**: String
- **Position**: Named
- **Default**: None
- **Required**: Yes (when using ByTaskSequencePackageId parameter set)
- **Parameter Set**: ByTaskSequencePackageId
- **Accept pipeline input**: False
- **Accept wildcard characters**: No

Example: `"CM100FAD"` - Removes all deployments of this task sequence PackageID

### -DeploymentName

Specifies the name of the deployment (AdvertisementName) to remove. Supports wildcard characters (`*` and `?`). If multiple deployments match, all are removed.

- **Type**: String
- **Position**: Named
- **Default**: None
- **Required**: Yes (when using ByDeploymentName parameter set)
- **Parameter Set**: ByDeploymentName
- **Accept pipeline input**: False
- **Accept wildcard characters**: Yes

Example: `"Test Josh - Test-Collection-Direct"` - Removes the deployment with this name

### -InputObject

Specifies a task sequence deployment object to remove. Typically obtained from `Get-CM7TaskSequenceDeployment`. The object must have an `AdvertisementID` property.

- **Type**: PSObject
- **Position**: Named
- **Default**: None
- **Required**: Yes (when using ByInputObject parameter set)
- **Parameter Set**: ByInputObject
- **Accept pipeline input**: Yes (ByValue)
- **Accept wildcard characters**: No

### -Force

Suppresses confirmation prompts and removes the deployment without asking. By default, the function prompts for confirmation before deletion due to the destructive nature of the operation.

- **Type**: SwitchParameter
- **Position**: Named
- **Default**: False
- **Required**: No
- **Parameter Set**: All

### -WhatIf

Shows what would happen if the cmdlet runs. The cmdlet is not run.

- **Type**: SwitchParameter
- **Position**: Named
- **Default**: False
- **Required**: No

### -Confirm

Prompts you for confirmation before running the cmdlet.

- **Type**: SwitchParameter
- **Position**: Named
- **Default**: True (ConfirmImpact is High)
- **Required**: No

## EXAMPLES

### EXAMPLE 1: Remove a deployment by AdvertisementID

```powershell
Remove-CM7TaskSequenceDeployment -AdvertisementID "CM120BD2" -Force
```

Removes the task sequence deployment with the specified advertisement ID without prompting for confirmation.

### EXAMPLE 2: Remove all deployments targeting a collection

```powershell
Remove-CM7TaskSequenceDeployment -CollectionName "Test-Collection-Direct" -Force
```

Removes all task sequence deployments targeting the specified collection.

### EXAMPLE 3: Remove all deployments of a task sequence by name

```powershell
Remove-CM7TaskSequenceDeployment -TaskSequenceName "Test Josh" -Force
```

Removes all deployments of the task sequence named "Test Josh".

### EXAMPLE 4: Remove all deployments by PackageID

```powershell
Remove-CM7TaskSequenceDeployment -TaskSequencePackageId "CM100FAD" -Force
```

Removes all deployments of the task sequence with PackageID "CM100FAD".

### EXAMPLE 5: Remove a deployment by name

```powershell
Remove-CM7TaskSequenceDeployment -DeploymentName "Test Josh - Test-Collection-Direct" -Force
```

Removes the deployment with the specified name.

### EXAMPLE 6: Remove deployments via pipeline

```powershell
Get-CM7TaskSequenceDeployment -CollectionName "Test-*" | Remove-CM7TaskSequenceDeployment -Force
```

Retrieves all task sequence deployments targeting collections whose names start with "Test-" and removes them via pipeline input.

### EXAMPLE 7: Preview removal with WhatIf

```powershell
Remove-CM7TaskSequenceDeployment -DeploymentName "Test*" -WhatIf
```

Shows what would happen without actually removing the deployment(s).

### EXAMPLE 8: Remove a deployment using a stored object

```powershell
$deployment = Get-CM7TaskSequenceDeployment -AdvertisementID "CM120BD2"
Remove-CM7TaskSequenceDeployment -InputObject $deployment -Force
```

Retrieves a deployment object first and then passes it to `Remove-CM7TaskSequenceDeployment` for removal.

### EXAMPLE 9: Remove and capture result

```powershell
$result = Remove-CM7TaskSequenceDeployment -AdvertisementID "CM120BD2" -Force
Write-Host "Removed: $($result.AdvertisementName) ($($result.AdvertisementID)) - $($result.Status)"
```

Removes a deployment and captures the result object for logging or further processing.

### EXAMPLE 10: Bulk remove deployments by wildcard pattern

```powershell
Remove-CM7TaskSequenceDeployment -DeploymentName "Temp-TSD-*" -Force
```

Removes all task sequence deployments whose names match the wildcard pattern.

## OUTPUTS

### MECM7.RemovedTaskSequenceDeployment

The function returns a custom object of type `MECM7.RemovedTaskSequenceDeployment` with the following properties:

| Property | Type | Description |
|----------|------|-------------|
| AdvertisementID | String | The unique advertisement ID of the removed deployment |
| AdvertisementName | String | The display name of the removed deployment |
| CollectionID | String | The collection ID that the deployment was targeting |
| CollectionName | String | The resolved name of the target collection |
| PackageID | String | The PackageID of the task sequence that was deployed |
| TaskSequenceName | String | The resolved name of the task sequence |
| Status | String | Always "Removed" on successful deletion |

## REQUIREMENTS

- An active MECM/SCCM connection established via `Connect-CM7`
- PowerShell 5.1 or higher
- Access to the MECM SMS Provider via WinRM
- Sufficient MECM permissions to delete task sequence deployments (SMS_Advertisement)

## NOTES

- The function removes task sequence deployments using the `SMS_Advertisement` WMI class directly via CIM sessions.
- Task sequence deployments are identified by `ProgramName = '*'` in the `SMS_Advertisement` class. Only advertisements with this marker are affected.
- When using `-CollectionName`, `-TaskSequenceName`, `-TaskSequencePackageId`, or `-DeploymentName`, multiple deployments may match and all will be removed.
- The `-Force` parameter bypasses the confirmation prompt for scripted automation scenarios.
- By default, the function has `ConfirmImpact = 'High'`, which means it will prompt for confirmation unless `-Force` is used or `$ConfirmPreference` is set to `None`.
- Pipeline input is supported via the `InputObject` parameter, allowing objects from `Get-CM7TaskSequenceDeployment` to be piped directly.
- Removing a deployment does not remove the task sequence itself or the target collection; it only removes the deployment relationship.
- Wildcard support uses WQL `LIKE` operator translation (`*` → `%`, `?` → `_`).

## RELATED LINKS

- [Connect-CM7](./Connect-CM7.md) - Establish connection to MECM
- [Get-CM7TaskSequenceDeployment](./Get-CM7TaskSequenceDeployment.md) - Retrieve task sequence deployment information
- [New-CM7TaskSequenceDeployment](./New-CM7TaskSequenceDeployment.md) - Create a new task sequence deployment
- [Get-CM7TaskSequence](./Get-CM7TaskSequence.md) - Retrieve task sequence information
- [Get-CM7Collection](./Get-CM7Collection.md) - Retrieve collection information

## SEE ALSO

- `Remove-CMTaskSequenceDeployment` - Native ConfigurationManager module equivalent
- `Remove-CimInstance` - PowerShell CIM cmdlet for removing WMI instances
- `SMS_Advertisement` - MECM WMI class for deployments (advertisements)
