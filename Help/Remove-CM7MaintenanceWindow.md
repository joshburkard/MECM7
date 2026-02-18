# Remove-CM7MaintenanceWindow

## SYNOPSIS

Removes a maintenance window from a MECM collection using CIM.

## DESCRIPTION

The `Remove-CM7MaintenanceWindow` function removes one or more maintenance windows (service windows) from a specified collection in Microsoft Endpoint Configuration Manager (MECM) using CIM. Maintenance windows define scheduled time periods during which deployments and other operations can be applied to collection members.

This function is the CIM-based equivalent of the `Remove-CMMaintenanceWindow` cmdlet from the ConfigurationManager PowerShell module, but uses direct CIM queries over WinRM instead of requiring the ConfigMgr console or PowerShell drive.

The function performs the following actions:

1. Validates an active connection exists (established via `Connect-CM7`)
2. Resolves the collection (by name or ID)
3. Retrieves existing `SMS_CollectionSettings` and loads the `ServiceWindows` lazy property
4. Finds the matching maintenance window(s) by exact name, wildcard pattern, or ServiceWindowID
5. Removes the matching window(s) from the array
6. Writes the updated settings back via CIM

Key features:
- **Name or ID Lookup**: Target collection by name or CollectionID
- **Multiple Identification Methods**: Identify windows by name (with wildcard support) or ServiceWindowID
- **Combined Filtering**: Use both name and ServiceWindowID together for precise targeting
- **Non-Destructive Warnings**: Warns instead of throwing when the maintenance window does not exist
- **ShouldProcess**: Full support for `-WhatIf` and `-Confirm`

## PARAMETERS

### -CollectionName

Specifies the name of the collection to remove the maintenance window from.

- **Type**: String
- **Position**: 0 (first positional parameter)
- **Default**: None
- **Required**: Yes (for ByCollectionName parameter set)
- **Parameter Set**: ByCollectionName
- **Accept pipeline input**: False
- **Accept wildcard characters**: No

Example: `Test-Collection-Direct`

### -CollectionId

Specifies the CollectionID of the collection to remove the maintenance window from.

- **Type**: String
- **Position**: Named
- **Default**: None
- **Required**: Yes (for ByCollectionId parameter set)
- **Parameter Set**: ByCollectionId
- **Accept pipeline input**: False
- **Accept wildcard characters**: No

Example: `CM101C00`

### -MaintenanceWindowName

Specifies the name of the maintenance window to remove. Supports wildcard characters (`*` and `?`) to remove multiple maintenance windows matching a pattern. When used together with `-ServiceWindowID`, both criteria must match.

- **Type**: String
- **Position**: Named
- **Default**: None
- **Required**: No (but at least one of `-MaintenanceWindowName` or `-ServiceWindowID` must be specified)
- **Parameter Set**: All
- **Accept pipeline input**: False
- **Accept wildcard characters**: Yes

Examples:
- `Daily MW` - Remove a specific maintenance window
- `Test-*` - Remove all maintenance windows starting with "Test-"
- `*Update*` - Remove all maintenance windows containing "Update"

### -ServiceWindowID

Specifies the unique ServiceWindowID (GUID) of the maintenance window to remove. When used together with `-MaintenanceWindowName`, both criteria must match.

- **Type**: String
- **Position**: Named
- **Default**: None
- **Required**: No (but at least one of `-MaintenanceWindowName` or `-ServiceWindowID` must be specified)
- **Parameter Set**: All
- **Accept pipeline input**: False
- **Accept wildcard characters**: No

Example: `a1b2c3d4-e5f6-7890-abcd-ef1234567890`

### -Force

Suppresses confirmation prompts. Use this parameter in automated scripts to avoid interactive prompts.

- **Type**: Switch
- **Position**: Named
- **Default**: `$false`
- **Required**: No

### -WhatIf

Shows what would happen if the cmdlet runs. The cmdlet is not run and no changes are made.

### -Confirm

Prompts you for confirmation before running the cmdlet.

## OUTPUTS

### MECM7.RemovedMaintenanceWindow

The function returns a PSCustomObject for each removed maintenance window with the following properties:

- **Name** (String): The name of the removed maintenance window
- **Description** (String): The description of the removed maintenance window
- **ServiceWindowID** (String): The unique identifier of the removed maintenance window
- **IsEnabled** (Boolean): Whether the maintenance window was enabled before removal
- **ServiceWindowType** (String): The type of maintenance window. Possible values:
  - `General` - All deployments (type 1 and 6)
  - `SoftwareUpdatesOnly` - Software updates only (type 4)
  - `TaskSequencesOnly` - Task sequences only (type 5)
- **StartTime** (DateTime): The start time of the removed maintenance window
- **Duration** (Int): The duration of the maintenance window in minutes
- **RecurrenceType** (String): The recurrence schedule type. Possible values:
  - `None` - One-time window (type 1)
  - `Daily` - Repeats daily (type 2)
  - `Weekly` - Repeats weekly (type 3)
  - `MonthlyByWeekday` - Repeats monthly on a specific weekday (type 4)
  - `MonthlyByDate` - Repeats monthly on a specific date (type 5)
- **IsGMT** (Boolean): Whether the maintenance window used UTC/GMT time
- **ServiceWindowSchedules** (String): The raw schedule token string from MECM
- **CollectionID** (String): The CollectionID the maintenance window was removed from
- **Status** (String): Always `Removed`

## EXAMPLES

### Example 1: Remove a specific maintenance window by name

```powershell
Remove-CM7MaintenanceWindow -CollectionName "Test-Collection-Direct" -MaintenanceWindowName "Daily MW"
```

Removes the maintenance window named "Daily MW" from the "Test-Collection-Direct" collection. Prompts for confirmation.

### Example 2: Remove a maintenance window using CollectionId

```powershell
Remove-CM7MaintenanceWindow -CollectionId "CM101C00" -MaintenanceWindowName "Weekly Updates" -Force
```

Removes the maintenance window from the collection identified by its CollectionID without prompting for confirmation.

### Example 3: Remove multiple maintenance windows by wildcard pattern

```powershell
Remove-CM7MaintenanceWindow -CollectionName "Test-Collection-Direct" -MaintenanceWindowName "Test-*"
```

Removes all maintenance windows whose names match the wildcard pattern "Test-*".

### Example 4: Remove a maintenance window by ServiceWindowID

```powershell
Remove-CM7MaintenanceWindow -CollectionName "Test-Collection-Direct" -ServiceWindowID "a1b2c3d4-e5f6-7890-abcd-ef1234567890" -Force
```

Removes the maintenance window with the specified ServiceWindowID without prompting for confirmation.

### Example 5: Preview removal with WhatIf

```powershell
Remove-CM7MaintenanceWindow -CollectionName "Test-Collection-Direct" -MaintenanceWindowName "Old MW" -WhatIf
```

Shows what would happen without actually removing the maintenance window.

### Example 6: Remove a maintenance window and verify

```powershell
Remove-CM7MaintenanceWindow -CollectionName "Test-Collection-Direct" -MaintenanceWindowName "Patch Window" -Force
Get-CM7MaintenanceWindow -CollectionName "Test-Collection-Direct" -MaintenanceWindowName "Patch Window"
```

Removes a maintenance window and then verifies it was removed (the second command should return no results).

### Example 7: Remove using both name and ServiceWindowID for precision

```powershell
Remove-CM7MaintenanceWindow -CollectionName "Test-Collection-Direct" -MaintenanceWindowName "Daily MW" -ServiceWindowID "a1b2c3d4-e5f6-7890-abcd-ef1234567890" -Force
```

Removes the maintenance window only if both the name and ServiceWindowID match, ensuring precise targeting when duplicate names exist.

## NOTES

### Maintenance Window Removal Behavior

- If the specified maintenance window **does not exist**, the function writes a **warning** but does not throw an error
- If the collection has **no settings or no maintenance windows**, the function writes a warning and returns
- When using **wildcards** with `-MaintenanceWindowName`, all matching windows are removed in a single operation
- When **all maintenance windows** are removed, the `ServiceWindows` array is set to empty (the `SMS_CollectionSettings` instance is preserved)
- When both `-MaintenanceWindowName` and `-ServiceWindowID` are specified, a window must match **both** criteria to be removed

### SMS_CollectionSettings

The function works with the `SMS_CollectionSettings` WMI class:
- The `ServiceWindows` property is a lazy property requiring a secondary retrieval
- After removing maintenance windows, the function commits the updated array via `Set-CimInstance`
- The `SMS_CollectionSettings` instance itself is not deleted, even if all maintenance windows are removed

### Maintenance Window Types

MECM supports three types of maintenance windows:

| Type | Description |
|------|-------------|
| **General** | Applies to all deployments (software updates, task sequences, and applications) |
| **SoftwareUpdatesOnly** | Applies only to software update deployments |
| **TaskSequencesOnly** | Applies only to task sequence deployments |

### ShouldProcess / ConfirmImpact

The function has a `ConfirmImpact` of `High`, meaning:
- Without `-Force`, the user will be prompted for confirmation
- `-WhatIf` shows what would happen without making changes
- `-Confirm` explicitly requests confirmation

### Related Functions

- **New-CM7MaintenanceWindow** - Creates maintenance windows
- **Get-CM7MaintenanceWindow** - Retrieves maintenance windows
- **Get-CM7Collection** - Retrieves collection properties
- **Connect-CM7** - Establishes connection to MECM

### Prerequisites

- PowerShell 5.1 or higher
- WinRM access to the MECM SMS Provider
- An active MECM connection (established via `Connect-CM7`)
- Appropriate MECM administrative permissions (Collection modify rights)

### Performance Considerations

- **Lazy Property Retrieval**: The function performs two CIM queries per call (one to find the settings, one to load lazy properties). This is required by the MECM WMI provider design.
- **Wildcard Patterns**: Wildcard filtering on maintenance window names is performed client-side after retrieving all windows for the collection.

### ConfigurationManager Equivalence

This function is equivalent to the ConfigurationManager module's `Remove-CMMaintenanceWindow` cmdlet:

```powershell
# ConfigurationManager module (requires ConfigMgr console)
Remove-CMMaintenanceWindow -CollectionId "CM101C00" -MaintenanceWindowName "Daily MW" -Force

# MECM7 module (requires only WinRM access)
Remove-CM7MaintenanceWindow -CollectionId "CM101C00" -MaintenanceWindowName "Daily MW" -Force
```

## SEE ALSO

- [New-CM7MaintenanceWindow](./New-CM7MaintenanceWindow.md)
- [Get-CM7MaintenanceWindow](./Get-CM7MaintenanceWindow.md)
- [Get-CM7Collection](./Get-CM7Collection.md)
- [Get-CM7Device](./Get-CM7Device.md)
- [Connect-CM7](./Connect-CM7.md)
- [Microsoft Endpoint Configuration Manager Documentation](https://docs.microsoft.com/en-us/mem/configmgr/)
