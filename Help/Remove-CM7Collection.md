# Remove-CM7Collection

## SYNOPSIS

Removes a collection from MECM using CIM.

## DESCRIPTION

The `Remove-CM7Collection` function removes (deletes) a device or user collection from Microsoft Endpoint Configuration Manager (MECM) using CIM. It deletes an `SMS_Collection` instance via CIM.

This function is the CIM-based equivalent of the `Remove-CMCollection` / `Remove-CMDeviceCollection` / `Remove-CMUserCollection` cmdlets from the ConfigurationManager PowerShell module, but uses direct CIM queries over WinRM instead of requiring the ConfigMgr console or PowerShell drive.

The function performs the following actions:

1. Validates an active connection exists (established via `Connect-CM7`)
2. Resolves the collection (by name, ID, or input object)
3. Validates the collection is not a built-in protected collection
4. Warns about member count before removal (if applicable)
5. Removes the `SMS_Collection` instance via CIM (with confirmation by default)

Key features:
- **Multiple Identification**: Remove by name, CollectionID, or pipeline input object
- **Protected Collection Guard**: Built-in collections (All Systems, All Users, etc.) cannot be removed
- **Member Count Warning**: Warns when removing a collection that has members
- **Pipeline Support**: Accept collection objects from `Get-CM7Collection` via pipeline
- **Force Parameter**: Bypass confirmation prompts for scripted scenarios
- **WhatIf/Confirm**: Full ShouldProcess support for safe operations

## PARAMETERS

### -Name

Specifies the name of the collection to remove. If multiple collections match the name, an error is thrown to prevent accidental deletion. Use `-CollectionId` for unambiguous removal.

- **Type**: String
- **Position**: 0 (first positional parameter)
- **Default**: None
- **Required**: Yes (when using ByName parameter set)
- **Parameter Set**: ByName
- **Accept pipeline input**: False
- **Accept wildcard characters**: No

Example: `"Old Test Collection"` - Removes the collection with this exact name

### -CollectionId

Specifies the CollectionID of the collection to remove. Provides unambiguous identification of the target collection.

- **Type**: String
- **Position**: Named
- **Default**: None
- **Required**: Yes (when using ById parameter set)
- **Parameter Set**: ById
- **Accept pipeline input**: False
- **Accept wildcard characters**: No

Example: `"CM101C99"` - Removes the collection with this ID

### -InputObject

Specifies a collection object to remove. Typically obtained from `Get-CM7Collection` or other functions that return collection objects. The object must have a `CollectionId` or `CollectionID` property.

- **Type**: PSObject
- **Position**: Named
- **Default**: None
- **Required**: Yes (when using ByInputObject parameter set)
- **Parameter Set**: ByInputObject
- **Accept pipeline input**: Yes (ByValue)
- **Accept wildcard characters**: No

### -Force

Suppresses confirmation prompts and removes the collection without asking. By default, the function prompts for confirmation before deletion due to the destructive nature of the operation.

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

### EXAMPLE 1: Remove a collection by name

```powershell
Remove-CM7Collection -Name "Old Test Collection"
```

Removes the collection named "Old Test Collection" after prompting for confirmation.

### EXAMPLE 2: Remove a collection by ID without confirmation

```powershell
Remove-CM7Collection -CollectionId "CM101C99" -Force
```

Removes the collection with the specified CollectionID without prompting for confirmation.

### EXAMPLE 3: Remove collections matching a pattern via pipeline

```powershell
Get-CM7Collection -Name "Test-*" | Remove-CM7Collection -Force
```

Retrieves all collections whose names start with "Test-" and removes them via pipeline input.

### EXAMPLE 4: Preview removal with WhatIf

```powershell
Remove-CM7Collection -Name "Temp Collection" -WhatIf
```

Shows what would happen without actually removing the collection.

### EXAMPLE 5: Remove a collection using a stored object

```powershell
$coll = Get-CM7Collection -CollectionId "CM101C50"
Remove-CM7Collection -InputObject $coll -Force
```

Retrieves a collection object first and then passes it to `Remove-CM7Collection` for removal.

### EXAMPLE 6: Remove and capture result

```powershell
$result = Remove-CM7Collection -Name "Decommissioned Servers" -Force
Write-Host "Removed: $($result.Name) ($($result.CollectionId)) - $($result.Status)"
```

Removes a collection and captures the result object for logging or further processing.

### EXAMPLE 7: Bulk remove collections from a list

```powershell
$collectionsToRemove = @("Temp-Collection-1", "Temp-Collection-2", "Temp-Collection-3")
foreach ($collName in $collectionsToRemove) {
    $result = Remove-CM7Collection -Name $collName -Force
    Write-Host "Removed: $($result.Name) - $($result.Status)"
}
```

Removes multiple collections by name in a loop.

## OUTPUTS

### MECM7.RemovedCollection

The function returns a custom object of type `MECM7.RemovedCollection` with the following properties:

| Property | Type | Description |
|----------|------|-------------|
| CollectionId | String | The unique collection identifier of the removed collection |
| Name | String | The display name of the removed collection |
| CollectionType | String | The type of collection: "Device" or "User" |
| MemberCount | Int | Number of members the collection had at time of removal |
| Status | String | Always "Removed" on successful deletion |

## REQUIREMENTS

- An active MECM/SCCM connection established via `Connect-CM7`
- PowerShell 5.1 or higher
- Access to the MECM SMS Provider via WinRM
- Sufficient MECM permissions to delete collections

## NOTES

- The function removes collections using the `SMS_Collection` WMI class directly via CIM sessions.
- Built-in protected collections (All Systems `SMS00001`, All Users `SMS00002`, etc.) cannot be removed. The function throws an error if you attempt to remove them.
- When a collection has members, a warning is displayed showing the member count before removal.
- The `-Force` parameter bypasses the confirmation prompt but does NOT bypass the protected collection check.
- By default, the function has `ConfirmImpact = 'High'`, which means it will prompt for confirmation unless `-Force` is used or `$ConfirmPreference` is set to `None`.
- When using `-Name`, the function throws an error if multiple collections match the name. Use `-CollectionId` for unambiguous removal.
- Pipeline input is supported via the `InputObject` parameter, allowing objects from `Get-CM7Collection` to be piped directly.
- Removing a collection does not remove the devices or users that were members of it; it only removes the collection grouping.

## RELATED LINKS

- [Connect-CM7](./Connect-CM7.md) - Establish connection to MECM
- [Get-CM7Collection](./Get-CM7Collection.md) - Retrieve collection information
- [New-CM7Collection](./New-CM7Collection.md) - Create a new collection
- [Move-CM7Object](./Move-CM7Object.md) - Move MECM objects between folders
- [Get-CM7CollectionMember](./Get-CM7CollectionMember.md) - Retrieve collection members

## SEE ALSO

- `Remove-CMCollection` - Native ConfigurationManager module equivalent
- `Remove-CMDeviceCollection` - Native cmdlet for removing device collections
- `Remove-CMUserCollection` - Native cmdlet for removing user collections
- `Remove-CimInstance` - PowerShell CIM cmdlet for removing WMI instances
