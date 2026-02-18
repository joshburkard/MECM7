# Remove-CM7DeviceVariable

## SYNOPSIS

Removes a device variable from a MECM device using CIM.

## DESCRIPTION

The `Remove-CM7DeviceVariable` function removes one or more device variables from a specified device in Microsoft Endpoint Configuration Manager (MECM) using CIM. Device variables are stored in the `SMS_MachineSettings` WMI class and can be used during task sequence execution and other MECM operations.

This function is the CIM-based equivalent of the `Remove-CMDeviceVariable` cmdlet from the ConfigurationManager PowerShell module, but uses direct CIM queries over WinRM instead of requiring the ConfigMgr console or PowerShell drive.

The function performs the following actions:

1. Validates an active connection exists (established via `Connect-CM7`)
2. Resolves the device (by name or ResourceId) and verifies it exists
3. Retrieves existing `SMS_MachineSettings` and loads the `MachineVariables` lazy property
4. Finds the matching variable(s) by exact name or wildcard pattern
5. Removes the matching variable(s) from the array
6. Writes the updated settings back via CIM

Key features:
- **Name or ResourceId Lookup**: Target device by name or ResourceID
- **Wildcard Support**: Remove multiple variables matching a wildcard pattern
- **Non-Destructive Warnings**: Warns instead of throwing when the variable does not exist
- **ShouldProcess**: Full support for `-WhatIf` and `-Confirm`

## PARAMETERS

### -DeviceName

Specifies the name of the device to remove the variable from. The device must exist in MECM.

- **Type**: String
- **Position**: 0 (first positional parameter)
- **Default**: None
- **Required**: Yes (for ByDeviceName parameter set)
- **Parameter Set**: ByDeviceName
- **Accept pipeline input**: False
- **Accept wildcard characters**: No

Example: `Test-2016-1`

### -ResourceId

Specifies the ResourceID of the device to remove the variable from. The device must exist in MECM.

- **Type**: Int32
- **Position**: Named
- **Default**: None
- **Required**: Yes (for ByResourceId parameter set)
- **Parameter Set**: ByResourceId
- **Accept pipeline input**: False
- **Accept wildcard characters**: No

Example: `16893210`

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
- `Test*` - Remove all variables starting with "Test"
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

### MECM7.RemovedDeviceVariable

The function returns a PSCustomObject for each removed variable with the following properties:

- **Name** (String): The name of the removed device variable
- **Value** (String): The value of the removed device variable
- **IsMasked** (Boolean): Whether the variable value was masked (hidden)
- **ResourceId** (Int32): The ResourceID of the device the variable was removed from
- **Status** (String): Always `Removed`

## EXAMPLES

### Example 1: Remove a specific device variable

```powershell
Remove-CM7DeviceVariable -DeviceName "Test-2016-1" -VariableName "OSDComputerName"
```

Removes the device variable named "OSDComputerName" from the device "Test-2016-1". Prompts for confirmation.

### Example 2: Remove a variable using ResourceId

```powershell
Remove-CM7DeviceVariable -ResourceId 16893210 -VariableName "InstallSoftware" -Force
```

Removes the device variable from the device identified by its ResourceID without prompting for confirmation.

### Example 3: Remove multiple variables by wildcard pattern

```powershell
Remove-CM7DeviceVariable -DeviceName "Test-2016-1" -VariableName "Test*"
```

Removes all device variables whose names match the wildcard pattern "Test*".

### Example 4: Preview removal with WhatIf

```powershell
Remove-CM7DeviceVariable -DeviceName "Test-2016-1" -VariableName "OldVar" -WhatIf
```

Shows what would happen without actually removing the variable.

### Example 5: Remove a variable and verify

```powershell
Remove-CM7DeviceVariable -DeviceName "Test-2016-1" -VariableName "BuildNumber" -Force
Get-CM7DeviceVariable -DeviceName "Test-2016-1" -VariableName "BuildNumber"
```

Removes a variable and then verifies it was removed (the second command should return no results).

### Example 6: Remove all test variables

```powershell
Remove-CM7DeviceVariable -DeviceName "Test-2016-1" -VariableName "TestVar_*" -Force
```

Removes all variables matching the "TestVar_*" pattern from the device.

## NOTES

### Variable Removal Behavior

- If the specified variable **does not exist**, the function writes a **warning** but does not throw an error
- If the device has **no settings or no variables**, the function writes a warning and returns
- When using **wildcards**, all matching variables are removed in a single operation
- When **all variables** are removed, the `MachineVariables` array is set to empty (the `SMS_MachineSettings` instance is preserved)

### SMS_MachineSettings

The function works with the `SMS_MachineSettings` WMI class:
- The `MachineVariables` property is a lazy property requiring a secondary retrieval
- After removing variables, the function commits the updated array via `Set-CimInstance`
- The `SMS_MachineSettings` instance itself is not deleted, even if all variables are removed

### ShouldProcess / ConfirmImpact

The function has a `ConfirmImpact` of `High`, meaning:
- Without `-Force`, the user will be prompted for confirmation
- `-WhatIf` shows what would happen without making changes
- `-Confirm` explicitly requests confirmation

### Related Functions

- **New-CM7DeviceVariable** - Creates device variables
- **Get-CM7DeviceVariable** - Retrieves device variables
- **Get-CM7Device** - Retrieves device properties
- **Remove-CM7DeviceCollectionVariable** - Removes collection-level variables
- **Connect-CM7** - Establishes connection to MECM

### Prerequisites

- PowerShell 5.1 or higher
- WinRM access to the MECM SMS Provider
- An active MECM connection (established via `Connect-CM7`)
- Appropriate MECM administrative permissions (Device modify rights)

### ConfigurationManager Equivalence

This function is equivalent to the ConfigurationManager module's `Remove-CMDeviceVariable` cmdlet:

```powershell
# ConfigurationManager module (requires ConfigMgr console)
Remove-CMDeviceVariable -DeviceName "Test-2016-1" -VariableName "TestVar" -Force

# MECM7 module (requires only WinRM access)
Remove-CM7DeviceVariable -DeviceName "Test-2016-1" -VariableName "TestVar" -Force
```

## SEE ALSO

- [New-CM7DeviceVariable](./New-CM7DeviceVariable.md)
- [Get-CM7DeviceVariable](./Get-CM7DeviceVariable.md)
- [Get-CM7Device](./Get-CM7Device.md)
- [Remove-CM7DeviceCollectionVariable](./Remove-CM7DeviceCollectionVariable.md)
- [Connect-CM7](./Connect-CM7.md)
- [Microsoft Endpoint Configuration Manager Documentation](https://docs.microsoft.com/en-us/mem/configmgr/)
