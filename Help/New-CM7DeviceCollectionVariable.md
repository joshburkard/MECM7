# New-CM7DeviceCollectionVariable

## SYNOPSIS

Creates a new collection variable on a MECM device collection using CIM.

## DESCRIPTION

The `New-CM7DeviceCollectionVariable` function creates a new collection variable (name-value pair) on a specified device collection in Microsoft Endpoint Configuration Manager (MECM) using CIM. Collection variables are stored in the `SMS_CollectionSettings` WMI class and can be used during task sequence execution and other MECM operations.

This function is the CIM-based equivalent of the `New-CMDeviceCollectionVariable` cmdlet from the ConfigurationManager PowerShell module, but uses direct CIM queries over WinRM instead of requiring the ConfigMgr console or PowerShell drive.

The function performs the following actions:

1. Validates an active connection exists (established via `Connect-CM7`)
2. Resolves the collection (by name or ID) and verifies it is a device collection
3. Retrieves existing `SMS_CollectionSettings` (or creates new settings if none exist)
4. If a variable with the same name already exists, it is overwritten
5. Creates and appends (or replaces) the `SMS_CollectionVariable` embedded instance
6. Writes the updated settings back via CIM

Key features:
- **Name or ID Lookup**: Target collection by name or CollectionID
- **Masked Variables**: Support for creating hidden/masked variable values
- **Duplicate Detection**: Overwrites existing variables with the same name
- **Auto-Create Settings**: Creates `SMS_CollectionSettings` if the collection has no existing settings
- **ShouldProcess**: Full support for `-WhatIf` and `-Confirm`

## PARAMETERS

### -CollectionName

Specifies the name of the device collection to add the variable to. The collection must exist and be a device collection (not a user collection).

- **Type**: String
- **Position**: 0 (first positional parameter)
- **Default**: None
- **Required**: Yes (for ByCollectionName parameter set)
- **Parameter Set**: ByCollectionName
- **Accept pipeline input**: False
- **Accept wildcard characters**: No

Example: `Test-Collection-Direct`

### -CollectionId

Specifies the CollectionID of the device collection to add the variable to. The collection must exist and be a device collection (not a user collection).

- **Type**: String
- **Position**: Named
- **Default**: None
- **Required**: Yes (for ByCollectionId parameter set)
- **Parameter Set**: ByCollectionId
- **Accept pipeline input**: False
- **Accept wildcard characters**: No

Example: `CM101C00`

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

### MECM7.CollectionVariable

The function returns a PSCustomObject with the following properties:

- **Name** (String): The name of the created collection variable
- **Value** (String): The value of the collection variable
- **IsMasked** (Boolean): Whether the variable value is masked (hidden)
- **CollectionId** (String): The CollectionID of the collection the variable was added to

## EXAMPLES

### Example 1: Create a simple collection variable

```powershell
New-CM7DeviceCollectionVariable -CollectionName "Test-Collection-Direct" -VariableName "OSDComputerName" -Value "WKS-001"
```

Creates a new collection variable named "OSDComputerName" with value "WKS-001" on the "Test-Collection-Direct" collection.

### Example 2: Create a variable using CollectionId

```powershell
New-CM7DeviceCollectionVariable -CollectionId "CM101C00" -VariableName "InstallSoftware" -Value "True"
```

Creates a new collection variable on the collection identified by its CollectionID.

### Example 3: Create a masked (hidden) variable

```powershell
New-CM7DeviceCollectionVariable -CollectionName "Test-Collection-Direct" -VariableName "SecretKey" -Value "P@ssw0rd!" -IsMasked
```

Creates a masked collection variable. The value will be obscured in the MECM console.

### Example 4: Create a variable with an empty value

```powershell
New-CM7DeviceCollectionVariable -CollectionName "Test-Collection-Direct" -VariableName "EmptyVar" -Value ""
```

Creates a collection variable with an empty string value.

### Example 5: Create a variable with special characters in the value

```powershell
New-CM7DeviceCollectionVariable -CollectionName "Test-Collection-Direct" -VariableName "AppPath" -Value "C:\Program Files\MyApp;D:\Data"
```

Creates a collection variable containing semicolons and backslashes in the value.

### Example 6: Create a variable without confirmation prompt

```powershell
New-CM7DeviceCollectionVariable -CollectionName "Test-Collection-Direct" -VariableName "AutoVar" -Value "AutoValue" -Force
```

Creates a variable and suppresses the confirmation prompt.

### Example 7: Preview creation with WhatIf

```powershell
New-CM7DeviceCollectionVariable -CollectionName "Test-Collection-Direct" -VariableName "TestVar" -Value "TestValue" -WhatIf
```

Shows what would happen without actually creating the variable.

### Example 8: Create and verify a variable

```powershell
$newVar = New-CM7DeviceCollectionVariable -CollectionName "Test-Collection-Direct" -VariableName "BuildNumber" -Value "22H2" -Force
Get-CM7CollectionVariable -CollectionName "Test-Collection-Direct" -VariableName "BuildNumber"
```

Creates a variable and then verifies it was created successfully.

## NOTES

### Collection Variables

Collection variables in MECM are name-value pairs associated with a device collection. They are commonly used in:

- **Task Sequences**: Variables are available during OS deployment for devices in the collection
- **Configuration Baselines**: Can be referenced in compliance settings
- **Scripts**: Available for use in MECM scripts targeting the collection

### Variable Name Restrictions

- Variable names **must not contain spaces**
- If a variable with the same name already exists, it will be **overwritten** with the new value
- Variable names are case-sensitive in WMI storage

### Masked Variables

When a variable is marked as masked (`-IsMasked`), its value is hidden in the MECM console. This is useful for sensitive information like passwords or API keys. Note that masked values may not be retrievable via WMI/CIM queries after creation.

### SMS_CollectionSettings

The function works with the `SMS_CollectionSettings` WMI class:
- If the collection already has settings, the function appends the new variable to the existing `CollectionVariables` array
- If the collection has no settings yet, the function creates a new `SMS_CollectionSettings` instance
- The `CollectionVariables` property is a lazy property requiring a secondary retrieval

### Related Functions

- **Get-CM7CollectionVariable** - Retrieves collection variables
- **Get-CM7Collection** - Retrieves collection properties
- **New-CM7Collection** - Creates a new collection
- **Connect-CM7** - Establishes connection to MECM

### Prerequisites

- PowerShell 5.1 or higher
- WinRM access to the MECM SMS Provider
- An active MECM connection (established via `Connect-CM7`)
- Appropriate MECM administrative permissions (Collection modify rights)

### ConfigurationManager Equivalence

This function is equivalent to the ConfigurationManager module's `New-CMDeviceCollectionVariable` cmdlet:

```powershell
# ConfigurationManager module (requires ConfigMgr console)
New-CMDeviceCollectionVariable -CollectionId "CM101C00" -VariableName "TestVar" -Value "TestValue"

# MECM7 module (requires only WinRM access)
New-CM7DeviceCollectionVariable -CollectionId "CM101C00" -VariableName "TestVar" -Value "TestValue"
```

## SEE ALSO

- [Get-CM7CollectionVariable](./Get-CM7CollectionVariable.md)
- [Get-CM7Collection](./Get-CM7Collection.md)
- [New-CM7Collection](./New-CM7Collection.md)
- [Get-CM7Device](./Get-CM7Device.md)
- [Connect-CM7](./Connect-CM7.md)
- [Microsoft Endpoint Configuration Manager Documentation](https://docs.microsoft.com/en-us/mem/configmgr/)
