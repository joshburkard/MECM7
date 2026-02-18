# Remove-CM7DeviceCollectionVariable

## SYNOPSIS

Removes a collection variable from a MECM device collection using CIM.

## DESCRIPTION

The `Remove-CM7DeviceCollectionVariable` function removes one or more collection variables from a specified device collection in Microsoft Endpoint Configuration Manager (MECM) using CIM. Collection variables are stored in the `SMS_CollectionSettings` WMI class and can be used during task sequence execution and other MECM operations.

This function is the CIM-based equivalent of the `Remove-CMDeviceCollectionVariable` cmdlet from the ConfigurationManager PowerShell module, but uses direct CIM queries over WinRM instead of requiring the ConfigMgr console or PowerShell drive.

The function performs the following actions:

1. Validates an active connection exists (established via `Connect-CM7`)
2. Resolves the collection (by name or ID) and verifies it is a device collection
3. Retrieves existing `SMS_CollectionSettings` and loads the `CollectionVariables` lazy property
4. Finds the matching variable(s) by exact name or wildcard pattern
5. Removes the matching variable(s) from the array
6. Writes the updated settings back via CIM

Key features:
- **Name or ID Lookup**: Target collection by name or CollectionID
- **Wildcard Support**: Remove multiple variables matching a wildcard pattern
- **Non-Destructive Warnings**: Warns instead of throwing when the variable does not exist
- **ShouldProcess**: Full support for `-WhatIf` and `-Confirm`

## PARAMETERS

### -CollectionName

Specifies the name of the device collection to remove the variable from. The collection must exist and be a device collection (not a user collection).

- **Type**: String
- **Position**: 0 (first positional parameter)
- **Default**: None
- **Required**: Yes (for ByCollectionName parameter set)
- **Parameter Set**: ByCollectionName
- **Accept pipeline input**: False
- **Accept wildcard characters**: No

Example: `Test-Collection-Direct`

### -CollectionId

Specifies the CollectionID of the device collection to remove the variable from. The collection must exist and be a device collection (not a user collection).

- **Type**: String
- **Position**: Named
- **Default**: None
- **Required**: Yes (for ByCollectionId parameter set)
- **Parameter Set**: ByCollectionId
- **Accept pipeline input**: False
- **Accept wildcard characters**: No

Example: `CM101C00`

### -VariableName

Specifies the name of the variable to remove. Supports wildcard characters (`*` and `?`) to remove multiple variables matching a pattern.

- **Type**: String
- **Position**: Named
- **Default**: None
- **Required**: Yes
- **Parameter Set**: All
- **Accept pipeline input**: False
- **Accept wildcard characters**: Yes

Examples:
- `OSDComputerName` - Remove a specific variable
- `Test-*` - Remove all variables starting with "Test-"
- `*Temp*` - Remove all variables containing "Temp"

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

### MECM7.RemovedCollectionVariable

The function returns a PSCustomObject for each removed variable with the following properties:

- **Name** (String): The name of the removed collection variable
- **Value** (String): The value of the removed collection variable
- **IsMasked** (Boolean): Whether the variable value was masked (hidden)
- **CollectionId** (String): The CollectionID of the collection the variable was removed from
- **Status** (String): Always `Removed`

## EXAMPLES

### Example 1: Remove a specific collection variable

```powershell
Remove-CM7DeviceCollectionVariable -CollectionName "Test-Collection-Direct" -VariableName "OSDComputerName"
```

Removes the collection variable named "OSDComputerName" from the "Test-Collection-Direct" collection. Prompts for confirmation.

### Example 2: Remove a variable using CollectionId

```powershell
Remove-CM7DeviceCollectionVariable -CollectionId "CM101C00" -VariableName "InstallSoftware" -Force
```

Removes the collection variable from the collection identified by its CollectionID without prompting for confirmation.

### Example 3: Remove multiple variables by wildcard pattern

```powershell
Remove-CM7DeviceCollectionVariable -CollectionName "Test-Collection-Direct" -VariableName "Test-*"
```

Removes all collection variables whose names match the wildcard pattern "Test-*".

### Example 4: Preview removal with WhatIf

```powershell
Remove-CM7DeviceCollectionVariable -CollectionName "Test-Collection-Direct" -VariableName "OldVar" -WhatIf
```

Shows what would happen without actually removing the variable.

### Example 5: Remove a variable and verify

```powershell
Remove-CM7DeviceCollectionVariable -CollectionName "Test-Collection-Direct" -VariableName "BuildNumber" -Force
Get-CM7CollectionVariable -CollectionName "Test-Collection-Direct" -VariableName "BuildNumber"
```

Removes a variable and then verifies it was removed (the second command should return no results).

### Example 6: Remove all test variables

```powershell
Remove-CM7DeviceCollectionVariable -CollectionName "Test-Collection-Direct" -VariableName "TestVar_*" -Force
```

Removes all variables matching the "TestVar_*" pattern from the collection.

## NOTES

### Variable Removal Behavior

- If the specified variable **does not exist**, the function writes a **warning** but does not throw an error
- If the collection has **no settings or no variables**, the function writes a warning and returns
- When using **wildcards**, all matching variables are removed in a single operation
- When **all variables** are removed, the `CollectionVariables` array is set to empty (the `SMS_CollectionSettings` instance is preserved)

### SMS_CollectionSettings

The function works with the `SMS_CollectionSettings` WMI class:
- The `CollectionVariables` property is a lazy property requiring a secondary retrieval
- After removing variables, the function commits the updated array via `Set-CimInstance`
- The `SMS_CollectionSettings` instance itself is not deleted, even if all variables are removed

### ShouldProcess / ConfirmImpact

The function has a `ConfirmImpact` of `High`, meaning:
- Without `-Force`, the user will be prompted for confirmation
- `-WhatIf` shows what would happen without making changes
- `-Confirm` explicitly requests confirmation

### Related Functions

- **New-CM7DeviceCollectionVariable** - Creates collection variables
- **Get-CM7CollectionVariable** - Retrieves collection variables
- **Get-CM7Collection** - Retrieves collection properties
- **Connect-CM7** - Establishes connection to MECM

### Prerequisites

- PowerShell 5.1 or higher
- WinRM access to the MECM SMS Provider
- An active MECM connection (established via `Connect-CM7`)
- Appropriate MECM administrative permissions (Collection modify rights)

### ConfigurationManager Equivalence

This function is equivalent to the ConfigurationManager module's `Remove-CMDeviceCollectionVariable` cmdlet:

```powershell
# ConfigurationManager module (requires ConfigMgr console)
Remove-CMDeviceCollectionVariable -CollectionId "CM101C00" -VariableName "TestVar" -Force

# MECM7 module (requires only WinRM access)
Remove-CM7DeviceCollectionVariable -CollectionId "CM101C00" -VariableName "TestVar" -Force
```

## SEE ALSO

- [New-CM7DeviceCollectionVariable](./New-CM7DeviceCollectionVariable.md)
- [Get-CM7CollectionVariable](./Get-CM7CollectionVariable.md)
- [Get-CM7Collection](./Get-CM7Collection.md)
- [Get-CM7Device](./Get-CM7Device.md)
- [Connect-CM7](./Connect-CM7.md)
- [Microsoft Endpoint Configuration Manager Documentation](https://docs.microsoft.com/en-us/mem/configmgr/)
