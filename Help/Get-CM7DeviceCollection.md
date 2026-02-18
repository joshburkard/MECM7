# Get-CM7DeviceCollection

## SYNOPSIS

Retrieves device collection information from Microsoft Endpoint Configuration Manager (MECM) using CIM.

## DESCRIPTION

The `Get-CM7DeviceCollection` function is a convenience wrapper around `Get-CM7Collection` that automatically filters for device collections (CollectionType = Device). It queries the SMS_Collection WMI class to retrieve detailed device collection information from MECM.

This function is the CIM-based equivalent of the `Get-CMDeviceCollection` cmdlet from the ConfigurationManager PowerShell module, but uses direct CIM queries over WinRM instead of requiring the ConfigMgr console or PowerShell drive.

The function performs the following actions:

1. Validates an active connection exists (established via `Connect-CM7`)
2. Delegates to `Get-CM7Collection` with `-CollectionType Device`
3. Returns formatted device collection objects with commonly used properties

Key features:
- **Device-Only**: Automatically filters to return only device collections
- **Wildcard Support**: Use `*` and `?` in collection names for pattern matching
- **Fast Mode**: Return limited properties for faster queries on large environments
- **Flexible Querying**: Query by name, CollectionID, or retrieve all device collections

## PARAMETERS

### -Name

Specifies the name of the device collection to retrieve. Supports PowerShell wildcard characters (`*` and `?`).

- **Type**: String
- **Position**: 0 (first positional parameter)
- **Default**: None
- **Required**: No
- **Parameter Set**: ByName
- **Accept pipeline input**: False
- **Accept wildcard characters**: Yes

Examples:
- `All Systems` - Exact match
- `TEST-*` - All device collections starting with "TEST-"
- `*Server*` - All device collections containing "Server"

### -CollectionId

Specifies the CollectionID of the device collection to retrieve. This is the unique identifier assigned by MECM to each collection.

- **Type**: String
- **Position**: Named
- **Default**: None
- **Required**: Yes (for ByCollectionId parameter set)
- **Parameter Set**: ByCollectionId
- **Accept pipeline input**: False
- **Accept wildcard characters**: No

Example: `SMS00001` (All Systems collection identifier)

### -Fast

Returns limited properties for faster performance. Only essential properties are returned:
- CollectionID
- Name
- CollectionType
- MemberCount
- LastRefreshTime

This is useful when querying large numbers of device collections or when you only need basic information.

- **Type**: SwitchParameter
- **Position**: Named
- **Default**: False
- **Required**: No
- **Parameter Set**: All
- **Accept pipeline input**: False

## EXAMPLES

### EXAMPLE 1: Get a device collection by exact name

```powershell
Get-CM7DeviceCollection -Name "All Systems"
```

Retrieves the device collection with the exact name "All Systems".

### EXAMPLE 2: Get device collections using wildcard pattern

```powershell
Get-CM7DeviceCollection -Name "TEST-*"
```

Retrieves all device collections whose names start with "TEST-". The wildcard `*` matches zero or more characters.

### EXAMPLE 3: Get device collections containing a string

```powershell
Get-CM7DeviceCollection -Name "*Server*"
```

Retrieves all device collections with "Server" anywhere in their name.

### EXAMPLE 4: Get a device collection by CollectionID

```powershell
Get-CM7DeviceCollection -CollectionId "SMS00001"
```

Retrieves the device collection with CollectionID "SMS00001" (typically the "All Systems" collection).

### EXAMPLE 5: Get all device collections with limited properties

```powershell
Get-CM7DeviceCollection -Fast
```

Retrieves all device collections with limited properties for faster query performance.

### EXAMPLE 6: Use Fast mode for quick queries

```powershell
Get-CM7DeviceCollection -Name "TEST-*" -Fast
```

Retrieves all device collections starting with "TEST-" but returns only essential properties for faster performance.

### EXAMPLE 7: Get all device collections (use with caution)

```powershell
Get-CM7DeviceCollection
```

Retrieves all device collections from MECM. Warning: This can return a large result set in production environments.

### EXAMPLE 8: Get device collection properties

```powershell
$collection = Get-CM7DeviceCollection -Name "All Systems"
Write-Host "Collection: $($collection.Name)"
Write-Host "CollectionID: $($collection.CollectionId)"
Write-Host "Type: $($collection.CollectionType)"
Write-Host "Member Count: $($collection.MemberCount)"
```

Retrieves a device collection and displays specific properties.

### EXAMPLE 9: Filter and export device collections

```powershell
Get-CM7DeviceCollection -Fast |
    Where-Object { $_.MemberCount -gt 100 } |
    Export-Csv -Path "LargeDeviceCollections.csv" -NoTypeInformation
```

Gets all device collections, filters for those with more than 100 members, and exports to CSV.

### EXAMPLE 10: Find device collections by creation date

```powershell
Get-CM7DeviceCollection |
    Where-Object { $_.CreatedDate -gt (Get-Date).AddMonths(-1) } |
    Select-Object Name, MemberCount, CreatedDate
```

Finds all device collections created in the last month and displays their properties.

### EXAMPLE 11: Count device collections

```powershell
$deviceCollections = Get-CM7DeviceCollection
Write-Host "Total Device Collections: $($deviceCollections.Count)"
Write-Host "Average Member Count: $(($deviceCollections | Measure-Object -Property MemberCount -Average).Average)"
```

Gets all device collections and displays count and average member count statistics.

### EXAMPLE 12: Equivalent to Get-CM7Collection with -CollectionType Device

```powershell
# These two commands produce identical results:
Get-CM7DeviceCollection -Name "TEST-*"
Get-CM7Collection -Name "TEST-*" -CollectionType Device
```

Demonstrates that `Get-CM7DeviceCollection` is functionally equivalent to `Get-CM7Collection -CollectionType Device`.

## OUTPUTS

### MECM7.Collection

The function returns custom objects of type `MECM7.Collection` with the following properties:

| Property | Type | Description |
|----------|------|-------------|
| CollectionId | String | The unique collection identifier (e.g., "SMS00001") |
| Name | String | The display name of the collection |
| CollectionType | String | Always "Device" for this function |
| TypeValue | Int | Always 2 (Device) for this function |
| MemberCount | Int | Number of members in the collection |
| LastRefreshTime | DateTime | Date and time the collection membership was last refreshed |
| LastChangeTime | DateTime | Date and time the collection was last modified |
| Comments | String | Comment/description for the collection |
| OwnedByThisSite | Boolean | Whether this collection is owned by the current site |
| RefreshType | Int | Collection refresh schedule type |

### Full Mode Properties (without -Fast)

When using the full query (without -Fast), all WMI properties from SMS_Collection are included, including:
- CollectionRules
- IncludeCollectionID
- ExcludeCollectionID
- CurrentStatus
- And many other SMS_Collection WMI class properties

## REQUIREMENTS

- An active MECM/SCCM connection established via `Connect-CM7`
- PowerShell 5.1 or higher
- Access to the MECM SMS Provider via WinRM

## NOTES

- This function is a convenience wrapper around `Get-CM7Collection -CollectionType Device`.
- It is the CIM-based equivalent of the `Get-CMDeviceCollection` cmdlet from the ConfigurationManager module.
- The function queries the SMS_Collection WMI class directly via CIM sessions, providing direct access to MECM data without requiring the ConfigurationManager PowerShell module.
- Wildcard characters in collection names are converted from PowerShell syntax (`*`, `?`) to WQL syntax for server-side filtering.
- The function automatically converts numeric CollectionType values to friendly names in the returned objects. For this function, the CollectionType will always be "Device".
- For environments with large numbers of collections, consider using the `-Fast` parameter or filtering by specific criteria to improve query performance.
- The `PSTypeName` is automatically set to `MECM7.Collection` for improved formatting and type safety.

## RELATED LINKS

- [Connect-CM7](./Connect-CM7.md) - Establish connection to MECM
- [Get-CM7Collection](./Get-CM7Collection.md) - Retrieve all collection types from MECM
- [Get-CM7Device](./Get-CM7Device.md) - Retrieve device information

## SEE ALSO

- `Get-CMDeviceCollection` - Native ConfigurationManager module equivalent
- `Get-CM7Collection` - The underlying function used by this wrapper
- `Get-CimInstance` - PowerShell CIM cmdlet for WMI queries
