# Get-CM7CollectionVariable

## SYNOPSIS

Retrieves collection variables from a Microsoft Endpoint Configuration Manager (MECM) collection using CIM.

## DESCRIPTION

The `Get-CM7CollectionVariable` function queries the SMS_CollectionSettings WMI class to retrieve collection variables for a specified MECM collection. Collection variables are name-value pairs that can be used during task sequence execution and other MECM operations.

This function is the CIM-based equivalent of the `Get-CMCollectionVariable` cmdlet from the ConfigurationManager PowerShell module, but uses direct CIM queries over WinRM instead of requiring the ConfigMgr console or PowerShell drive.

The function performs the following actions:

1. Validates an active connection exists (established via `Connect-CM7`)
2. Resolves collection name to CollectionID if needed
3. Queries the SMS_CollectionSettings class via CIM
4. Retrieves the full instance to load the lazy property `CollectionVariables`
5. Returns formatted variable objects with Name, Value, and IsMasked properties

Key features:
- **Name or ID Lookup**: Query by collection name or CollectionID
- **Variable Filtering**: Filter by variable name with wildcard support
- **Lazy Property Handling**: Properly retrieves lazy properties from SMS_CollectionSettings
- **Masked Variables**: Indicates whether a variable value is masked (hidden)

## PARAMETERS

### -CollectionName

Specifies the name of the collection to retrieve variables for.

- **Type**: String
- **Position**: 0 (first positional parameter)
- **Default**: None
- **Required**: No (required for ByCollectionName parameter set)
- **Parameter Set**: ByCollectionName
- **Accept pipeline input**: False
- **Accept wildcard characters**: No

Example: `Test-Collection-Direct`

### -CollectionId

Specifies the CollectionID of the collection to retrieve variables for. This is the unique identifier assigned by MECM to each collection.

- **Type**: String
- **Position**: Named
- **Default**: None
- **Required**: Yes (for ByCollectionId parameter set)
- **Parameter Set**: ByCollectionId
- **Accept pipeline input**: False
- **Accept wildcard characters**: No

Example: `CM101C00`

### -VariableName

Specifies the name of the variable to retrieve. This parameter is optional and can be used in combination with -CollectionName or -CollectionId to filter the results. Supports PowerShell wildcard characters (`*` and `?`). If not specified, all variables for the collection are returned.

- **Type**: String
- **Position**: Named
- **Default**: None
- **Required**: No
- **Parameter Set**: All
- **Accept pipeline input**: False
- **Accept wildcard characters**: Yes

Examples:
- `Test-Normal` - Exact match for a single variable
- `Test-*` - All variables starting with "Test-"
- `*Config*` - All variables containing "Config"

## OUTPUTS

### MECM7.CollectionVariable

The function returns PSCustomObject instances with the following properties:

- **Name** (String): The name of the collection variable
- **Value** (String): The value of the collection variable. For masked variables, this may be empty or obscured.
- **IsMasked** (Boolean): Whether the variable value is masked (hidden in the MECM console)

## EXAMPLES

### Example 1: Retrieve all variables for a collection

```powershell
Get-CM7CollectionVariable -CollectionName "Test-Collection-Direct"
```

Retrieves all collection variables defined on the "Test-Collection-Direct" collection.

### Example 2: Retrieve variables by collection ID

```powershell
Get-CM7CollectionVariable -CollectionId "CM101C00"
```

Retrieves all collection variables for the collection with ID "CM101C00".

### Example 3: Retrieve a specific variable by name

```powershell
Get-CM7CollectionVariable -CollectionName "Test-Collection-Direct" -VariableName "Test-Normal"
```

Retrieves only the variable named "Test-Normal" from the specified collection.

### Example 4: Retrieve variables matching a wildcard pattern

```powershell
Get-CM7CollectionVariable -CollectionName "Test-Collection-Direct" -VariableName "Test-*"
```

Retrieves all variables whose names start with "Test-" from the specified collection.

### Example 5: Check for masked variables

```powershell
Get-CM7CollectionVariable -CollectionName "Test-Collection-Direct" | Where-Object { $_.IsMasked -eq $true }
```

Retrieves all masked (hidden) variables from the specified collection.

### Example 6: Use verbose output for troubleshooting

```powershell
Get-CM7CollectionVariable -CollectionName "Test-Collection-Direct" -Verbose
```

Retrieves all variables with detailed verbose output showing the WQL queries being executed.

## NOTES

### Collection Variables

Collection variables in MECM are name-value pairs associated with a collection. They are commonly used in:

- **Task Sequences**: Variables are available during OS deployment task sequences for devices in the collection
- **Configuration Baselines**: Can be referenced in compliance settings
- **Scripts**: Available for use in MECM scripts targeting the collection

### Masked Variables

When a variable is marked as masked (`IsMasked = $true`), its value is hidden in the MECM console and may not be retrievable via WMI/CIM. The `IsMasked` property indicates whether the variable is configured as hidden.

### Lazy Properties

The `CollectionVariables` property of `SMS_CollectionSettings` is a lazy property in MECM WMI. This means it is not returned by standard WQL queries. The function handles this by performing a secondary retrieval of the full instance using `Get-CimInstance -InputObject` to ensure lazy properties are populated.

### Related Functions

- **Get-CM7Collection** - Retrieves collection properties
- **Get-CM7CollectionMember** - Retrieves all members of a collection
- **Get-CM7CollectionDirectMembershipRule** - Retrieves direct membership rules
- **Connect-CM7** - Establishes connection to MECM

### Prerequisites

- PowerShell 5.1 or higher
- WinRM access to the MECM SMS Provider
- An active MECM connection (established via `Connect-CM7`)
- Appropriate MECM administrative permissions

### Performance Considerations

- **Lazy Property Retrieval**: The function performs two CIM queries per call (one to find the settings, one to load lazy properties). This is required by the MECM WMI provider design.
- **Wildcard Patterns**: Wildcard filtering is performed client-side after retrieving all variables for the collection.

### ConfigurationManager Equivalence

This function is equivalent to the ConfigurationManager module's `Get-CMCollectionVariable` cmdlet:

```powershell
# ConfigurationManager module (requires ConfigMgr console)
Get-CMCollectionVariable -CollectionId "CM101C00"

# MECM7 module (requires only WinRM access)
Get-CM7CollectionVariable -CollectionId "CM101C00"
```

## SEE ALSO

- [Get-CM7Collection](./Get-CM7Collection.md)
- [Get-CM7CollectionMember](./Get-CM7CollectionMember.md)
- [Get-CM7Device](./Get-CM7Device.md)
- [Connect-CM7](./Connect-CM7.md)
- [Microsoft Endpoint Configuration Manager Documentation](https://docs.microsoft.com/en-us/mem/configmgr/)
