# Get-CM7DeviceVariable

## SYNOPSIS

Retrieves device variables from a MECM device using CIM.

## DESCRIPTION

The `Get-CM7DeviceVariable` function queries the `SMS_MachineSettings` WMI class to retrieve device-specific variables for a specified MECM device. Device variables are name-value pairs that can be used during task sequence execution and other MECM operations.

This function is the CIM-based equivalent of the `Get-CMDeviceVariable` cmdlet from the ConfigurationManager PowerShell module, but uses direct CIM queries over WinRM instead of requiring the ConfigMgr console or PowerShell drive.

The function supports:
- **Name or ResourceId Lookup**: Target device by name or ResourceID
- **Variable Name Filter**: Filter variables by exact name or wildcard pattern
- **Lazy Property Handling**: Automatically retrieves lazy properties from `SMS_MachineSettings`

## PARAMETERS

### -DeviceName

Specifies the name of the device to retrieve variables for. The device must exist in MECM.

- **Type**: String
- **Position**: 0 (first positional parameter)
- **Default**: None
- **Required**: No (for ByDeviceName parameter set, but must be provided)
- **Parameter Set**: ByDeviceName
- **Accept pipeline input**: False
- **Accept wildcard characters**: No

Example: `Test-2016-1`

### -ResourceId

Specifies the ResourceID of the device to retrieve variables for.

- **Type**: Int32
- **Position**: Named
- **Default**: None
- **Required**: Yes (for ByResourceId parameter set)
- **Parameter Set**: ByResourceId
- **Accept pipeline input**: False
- **Accept wildcard characters**: No

Example: `16893210`

### -VariableName

Specifies the name of the variable to retrieve. Supports wildcard characters (`*` and `?`). If not specified, all variables for the device are returned.

- **Type**: String
- **Position**: Named
- **Default**: None
- **Required**: No
- **Parameter Set**: All
- **Accept pipeline input**: False
- **Accept wildcard characters**: Yes

Examples:
- `TestVar` - Retrieve a specific variable
- `Test*` - Retrieve all variables starting with "Test"
- `*Config*` - Retrieve all variables containing "Config"

## OUTPUTS

### MECM7.DeviceVariable

The function returns a PSCustomObject for each variable with the following properties:

- **Name** (String): The name of the device variable
- **Value** (String): The value of the device variable (may be empty for masked variables)
- **IsMasked** (Boolean): Whether the variable value is masked (hidden) in the MECM console

## EXAMPLES

### Example 1: Get all device variables by device name

```powershell
Get-CM7DeviceVariable -DeviceName "Test-2016-1"
```

Retrieves all device variables for the device "Test-2016-1".

### Example 2: Get all device variables by ResourceId

```powershell
Get-CM7DeviceVariable -ResourceId 16893210
```

Retrieves all device variables for the device with ResourceID 16893210.

### Example 3: Get a specific device variable

```powershell
Get-CM7DeviceVariable -DeviceName "Test-2016-1" -VariableName "OSDComputerName"
```

Retrieves the variable named "OSDComputerName" from the device "Test-2016-1".

### Example 4: Get variables using wildcard pattern

```powershell
Get-CM7DeviceVariable -DeviceName "Test-2016-1" -VariableName "Test*"
```

Retrieves all variables whose names start with "Test" from the specified device.

### Example 5: Get variables and display in table format

```powershell
Get-CM7DeviceVariable -DeviceName "Test-2016-1" | Format-Table Name, Value, IsMasked
```

Retrieves all variables for the device and displays them in a formatted table.

### Example 6: Check if a specific variable exists

```powershell
$var = Get-CM7DeviceVariable -DeviceName "Test-2016-1" -VariableName "OSDComputerName"
if ($var) {
    Write-Host "Variable found: $($var.Name) = $($var.Value)"
} else {
    Write-Host "Variable not found"
}
```

Checks if a specific variable exists on the device.

## NOTES

### SMS_MachineSettings

The function works with the `SMS_MachineSettings` WMI class:
- The `MachineVariables` property is a lazy property requiring a secondary retrieval
- The function first queries for the settings instance, then retrieves the full instance to load lazy properties
- Device variables are stored as `SMS_MachineVariable` embedded instances

### Variable Properties

Each variable has the following properties:
- **Name**: The variable identifier (case-insensitive in MECM)
- **Value**: The variable value (empty string for masked variables when retrieved via CIM)
- **IsMasked**: When `$true`, the value is obscured in the MECM console and API

### Related Functions

- **New-CM7DeviceCollectionVariable** - Creates collection-level variables
- **Remove-CM7DeviceCollectionVariable** - Removes collection-level variables
- **Get-CM7CollectionVariable** - Retrieves collection-level variables
- **Get-CM7Device** - Retrieves device information
- **Connect-CM7** - Establishes connection to MECM

### Prerequisites

- PowerShell 5.1 or higher
- WinRM access to the MECM SMS Provider
- An active MECM connection (established via `Connect-CM7`)
- Appropriate MECM administrative permissions (Read access to devices)

### ConfigurationManager Equivalence

This function is equivalent to the ConfigurationManager module's `Get-CMDeviceVariable` cmdlet:

```powershell
# ConfigurationManager module (requires ConfigMgr console)
Get-CMDeviceVariable -DeviceName "Test-2016-1"

# MECM7 module (requires only WinRM access)
Get-CM7DeviceVariable -DeviceName "Test-2016-1"
```

## SEE ALSO

- [Get-CM7CollectionVariable](./Get-CM7CollectionVariable.md)
- [New-CM7DeviceCollectionVariable](./New-CM7DeviceCollectionVariable.md)
- [Remove-CM7DeviceCollectionVariable](./Remove-CM7DeviceCollectionVariable.md)
- [Get-CM7Device](./Get-CM7Device.md)
- [Connect-CM7](./Connect-CM7.md)
- [Microsoft Endpoint Configuration Manager Documentation](https://docs.microsoft.com/en-us/mem/configmgr/)
