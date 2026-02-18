# New-CM7DeviceVariable

## SYNOPSIS

Creates a new device variable on a MECM device using CIM.

## DESCRIPTION

The `New-CM7DeviceVariable` function creates a new device variable (name-value pair) on a specified device in Microsoft Endpoint Configuration Manager (MECM) using CIM. Device variables are stored in the `SMS_MachineSettings` WMI class and can be used during task sequence execution and other MECM operations.

This function is the CIM-based equivalent of the `New-CMDeviceVariable` cmdlet from the ConfigurationManager PowerShell module, but uses direct CIM queries over WinRM instead of requiring the ConfigMgr console or PowerShell drive.

The function performs the following actions:

1. Validates an active connection exists (established via `Connect-CM7`)
2. Resolves the device (by name or ResourceId) and verifies it exists
3. Retrieves existing `SMS_MachineSettings` (or creates new settings if none exist)
4. If a variable with the same name already exists, it is overwritten
5. Creates and appends (or replaces) the `SMS_MachineVariable` embedded instance
6. Writes the updated settings back via CIM

Key features:
- **Name or ResourceId Lookup**: Target device by name or ResourceID
- **Masked Variables**: Support for creating hidden/masked variable values
- **Duplicate Detection**: Overwrites existing variables with the same name
- **Auto-Create Settings**: Creates `SMS_MachineSettings` if the device has no existing settings
- **ShouldProcess**: Full support for `-WhatIf` and `-Confirm`

## PARAMETERS

### -DeviceName

Specifies the name of the device to add the variable to. The device must exist in MECM.

- **Type**: String
- **Position**: 0 (first positional parameter)
- **Default**: None
- **Required**: Yes (for ByDeviceName parameter set)
- **Parameter Set**: ByDeviceName
- **Accept pipeline input**: False
- **Accept wildcard characters**: No

Example: `Test-2016-1`

### -ResourceId

Specifies the ResourceID of the device to add the variable to. The device must exist in MECM.

- **Type**: Int32
- **Position**: Named
- **Default**: None
- **Required**: Yes (for ByResourceId parameter set)
- **Parameter Set**: ByResourceId
- **Accept pipeline input**: False
- **Accept wildcard characters**: No

Example: `16893210`

### -VariableName

Specifies the name of the variable to create or overwrite. Variable names must not contain spaces. If a variable with the same name already exists, its value and IsMasked setting will be overwritten.

- **Type**: String
- **Position**: Named
- **Default**: None
- **Required**: Yes
- **Parameter Set**: All
- **Accept pipeline input**: False
- **Accept wildcard characters**: No
- **Validation**: Must not contain spaces (regex: `^\S+$`)

Examples:
- `OSDComputerName` - Standard OSD variable
- `InstallSoftware` - Custom flag variable
- `Config_Path` - Path variable with underscore

### -Value

Specifies the value of the variable. Can be an empty string.

- **Type**: String
- **Position**: Named
- **Default**: None
- **Required**: Yes
- **Parameter Set**: All
- **Accept pipeline input**: False
- **Accept wildcard characters**: No
- **Allow empty string**: Yes

Examples:
- `WKS-001` - Computer name value
- `True` - Boolean flag
- `C:\Windows\System32;D:\Apps` - Path with special characters
- `` (empty string)

### -IsMasked

Specifies whether the variable value should be masked (hidden) in the MECM console. When set, the value is obscured in the UI and may not be retrievable via standard queries.

- **Type**: Switch
- **Position**: Named
- **Default**: `$false`
- **Required**: No
- **Parameter Set**: All
- **Accept pipeline input**: False

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

### MECM7.DeviceVariable

The function returns a PSCustomObject with the following properties:

- **Name** (String): The name of the created device variable
- **Value** (String): The value of the device variable
- **IsMasked** (Boolean): Whether the variable value is masked (hidden)
- **ResourceId** (Int32): The ResourceID of the device the variable was added to

## EXAMPLES

### Example 1: Create a simple device variable

```powershell
New-CM7DeviceVariable -DeviceName "Test-2016-1" -VariableName "OSDComputerName" -Value "WKS-001"
```

Creates a new device variable named "OSDComputerName" with value "WKS-001" on the device "Test-2016-1".

### Example 2: Create a variable using ResourceId

```powershell
New-CM7DeviceVariable -ResourceId 16893210 -VariableName "InstallSoftware" -Value "True"
```

Creates a new device variable on the device identified by its ResourceID.

### Example 3: Create a masked (hidden) variable

```powershell
New-CM7DeviceVariable -DeviceName "Test-2016-1" -VariableName "SecretKey" -Value "P@ssw0rd!" -IsMasked
```

Creates a masked device variable. The value will be obscured in the MECM console.

### Example 4: Create a variable with an empty value

```powershell
New-CM7DeviceVariable -DeviceName "Test-2016-1" -VariableName "EmptyVar" -Value ""
```

Creates a device variable with an empty string value.

### Example 5: Create a variable with special characters in the value

```powershell
New-CM7DeviceVariable -DeviceName "Test-2016-1" -VariableName "AppPath" -Value "C:\Program Files\MyApp;D:\Data"
```

Creates a device variable containing semicolons and backslashes in the value.

### Example 6: Create a variable without confirmation prompt

```powershell
New-CM7DeviceVariable -DeviceName "Test-2016-1" -VariableName "AutoVar" -Value "AutoValue" -Force
```

Creates a variable and suppresses the confirmation prompt.

### Example 7: Preview creation with WhatIf

```powershell
New-CM7DeviceVariable -DeviceName "Test-2016-1" -VariableName "TestVar" -Value "TestValue" -WhatIf
```

Shows what would happen without actually creating the variable.

### Example 8: Create and verify a variable

```powershell
$newVar = New-CM7DeviceVariable -DeviceName "Test-2016-1" -VariableName "BuildNumber" -Value "22H2" -Force
Get-CM7DeviceVariable -DeviceName "Test-2016-1" -VariableName "BuildNumber"
```

Creates a variable and then verifies it was created successfully.

## NOTES

### Device Variables

Device variables in MECM are name-value pairs associated with a specific device. They are commonly used in:

- **Task Sequences**: Variables are available during OS deployment for the specific device
- **Configuration Baselines**: Can be referenced in compliance settings
- **Scripts**: Available for use in MECM scripts targeting the device

### Variable Name Restrictions

- Variable names **must not contain spaces**
- If a variable with the same name already exists, it will be **overwritten** with the new value
- Variable names are case-sensitive in WMI storage

### Masked Variables

When a variable is marked as masked (`-IsMasked`), its value is hidden in the MECM console. This is useful for sensitive information like passwords or API keys. Note that masked values may not be retrievable via WMI/CIM queries after creation.

### SMS_MachineSettings

The function works with the `SMS_MachineSettings` WMI class:
- If the device already has settings, the function appends the new variable to the existing `MachineVariables` array
- If the device has no settings yet, the function creates a new `SMS_MachineSettings` instance
- The `MachineVariables` property is a lazy property requiring a secondary retrieval

### Related Functions

- **Get-CM7DeviceVariable** - Retrieves device variables
- **Get-CM7Device** - Retrieves device properties
- **New-CM7DeviceCollectionVariable** - Creates collection-level variables
- **Connect-CM7** - Establishes connection to MECM

### Prerequisites

- PowerShell 5.1 or higher
- WinRM access to the MECM SMS Provider
- An active MECM connection (established via `Connect-CM7`)
- Appropriate MECM administrative permissions (Device modify rights)

### ConfigurationManager Equivalence

This function is equivalent to the ConfigurationManager module's `New-CMDeviceVariable` cmdlet:

```powershell
# ConfigurationManager module (requires ConfigMgr console)
New-CMDeviceVariable -DeviceName "Test-2016-1" -VariableName "TestVar" -Value "TestValue"

# MECM7 module (requires only WinRM access)
New-CM7DeviceVariable -DeviceName "Test-2016-1" -VariableName "TestVar" -Value "TestValue"
```

## SEE ALSO

- [Get-CM7DeviceVariable](./Get-CM7DeviceVariable.md)
- [Get-CM7Device](./Get-CM7Device.md)
- [New-CM7DeviceCollectionVariable](./New-CM7DeviceCollectionVariable.md)
- [Connect-CM7](./Connect-CM7.md)
- [Microsoft Endpoint Configuration Manager Documentation](https://docs.microsoft.com/en-us/mem/configmgr/)
