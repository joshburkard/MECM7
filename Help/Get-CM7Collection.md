# Get-CM7Collection

## SYNOPSIS

Retrieves collection information from Microsoft Endpoint Configuration Manager (MECM) using CIM.

## DESCRIPTION

The `Get-CM7Collection` function queries the SMS_Collection WMI class to retrieve detailed collection information from MECM. It provides flexible filtering options including collection name (with wildcard support), CollectionID, and collection type.

This function is the CIM-based equivalent of the `Get-CMCollection` cmdlet from the ConfigurationManager PowerShell module, but uses direct CIM queries over WinRM instead of requiring the ConfigMgr console or PowerShell drive.

The function performs the following actions:

1. Validates an active connection exists (established via `Connect-CM7`)
2. Builds a WQL query based on the provided parameters
3. Queries the SMS_Collection class via CIM
4. Returns formatted collection objects with commonly used properties

Key features:
- **Wildcard Support**: Use `*` and `?` in collection names for pattern matching
- **Collection Type Filtering**: Filter collections by type (Device, User, or Both)
- **Fast Mode**: Return limited properties for faster queries on large environments
- **Flexible Querying**: Query by name, CollectionID, or retrieve all collections

## PARAMETERS

### -Name

Specifies the name of the collection to retrieve. Supports PowerShell wildcard characters (`*` and `?`).

- **Type**: String
- **Position**: 0 (first positional parameter)
- **Default**: None
- **Required**: No
- **Parameter Set**: ByName
- **Accept pipeline input**: False
- **Accept wildcard characters**: Yes

Examples:
- `All Systems` - Exact match
- `TEST-*` - All collections starting with "TEST-"
- `*Server*` - All collections containing "Server"

### -CollectionId

Specifies the CollectionID of the collection to retrieve. This is the unique identifier assigned by MECM to each collection.

- **Type**: String
- **Position**: Named
- **Default**: None
- **Required**: Yes (for ByCollectionId parameter set)
- **Parameter Set**: ByCollectionId
- **Accept pipeline input**: False
- **Accept wildcard characters**: No

Example: `SMS00001` (All Systems collection identifier)

### -CollectionType

Filter collections by type. Valid values are 'Device', 'User', or 'Both'.

- Device collections contain device/computer objects
- User collections contain user objects
- 'Both' includes collections of all types

- **Type**: String
- **Position**: Named
- **Default**: None (all types)
- **Required**: No
- **Parameter Set**: All
- **Accept pipeline input**: False
- **Valid Values**: Device, User, Both

Example: `-CollectionType Device` returns only device collections

### -Fast

Returns limited properties for faster performance. Only essential properties are returned:
- CollectionID
- Name
- CollectionType
- MemberCount
- LastRefreshTime

This is useful when querying large numbers of collections or when you only need basic information.

- **Type**: SwitchParameter
- **Position**: Named
- **Default**: False
- **Required**: No
- **Parameter Set**: All
- **Accept pipeline input**: False

## EXAMPLES

### EXAMPLE 1: Get a collection by exact name

```powershell
Get-CM7Collection -Name "All Systems"
```

Retrieves the collection with the exact name "All Systems".

### EXAMPLE 2: Get collections using wildcard pattern

```powershell
Get-CM7Collection -Name "TEST-*"
```

Retrieves all collections whose names start with "TEST-". The wildcard `*` matches zero or more characters.

### EXAMPLE 3: Get collections containing a string

```powershell
Get-CM7Collection -Name "*Server*"
```

Retrieves all collections with "Server" anywhere in their name.

### EXAMPLE 4: Get a collection by CollectionID

```powershell
Get-CM7Collection -CollectionId "SMS00001"
```

Retrieves the collection with CollectionID "SMS00001" (typically the "All Systems" collection).

### EXAMPLE 5: Get all device collections

```powershell
Get-CM7Collection -CollectionType Device
```

Retrieves all device collections in the MECM environment.

### EXAMPLE 6: Get all user collections with limited properties

```powershell
Get-CM7Collection -CollectionType User -Fast
```

Retrieves all user collections with limited properties for faster query performance.

### EXAMPLE 7: Use Fast mode for quick queries

```powershell
Get-CM7Collection -Name "TEST-*" -Fast
```

Retrieves all collections starting with "TEST-" but returns only essential properties for faster performance.

### EXAMPLE 8: Get all collections (use with caution)

```powershell
Get-CM7Collection
```

Retrieves all collections from MECM. Warning: This can return a large result set in production environments.

### EXAMPLE 9: Get collection properties

```powershell
$collection = Get-CM7Collection -Name "All Systems"
Write-Host "Collection: $($collection.Name)"
Write-Host "CollectionID: $($collection.CollectionId)"
Write-Host "Type: $($collection.CollectionType)"
Write-Host "Member Count: $($collection.MemberCount)"
Write-Host "Created: $($collection.CreatedDate)"
```

Retrieves a collection and displays specific properties.

### EXAMPLE 10: Filter and export collections

```powershell
Get-CM7Collection -CollectionType Device -Fast |
    Where-Object { $_.MemberCount -gt 100 } |
    Export-Csv -Path "LargeCollections.csv" -NoTypeInformation
```

Gets all device collections, filters for those with more than 100 members, and exports to CSV.

### EXAMPLE 11: Find collections by creation date

```powershell
Get-CM7Collection -CollectionType Device |
    Where-Object { $_.CreatedDate -gt (Get-Date).AddMonths(-1) } |
    Select-Object Name, MemberCount, CreatedDate
```

Finds all device collections created in the last month and displays their properties.

### EXAMPLE 12: Count device collections

```powershell
$deviceCollections = Get-CM7Collection -CollectionType Device
Write-Host "Total Device Collections: $($deviceCollections.Count)"
Write-Host "Average Member Count: $(($deviceCollections | Measure-Object -Property MemberCount -Average).Average)"
```

Gets all device collections and displays count and average member count statistics.

## OUTPUTS

### MECM7.Collection

The function returns custom objects of type `MECM7.Collection` with the following properties:

| Property | Type | Description |
|----------|------|-------------|
| CollectionId | String | The unique collection identifier (e.g., "SMS00001") |
| Name | String | The display name of the collection |
| CollectionType | String | The type of collection: "Device", "User", or "Unknown" |
| TypeValue | Int | Numeric representation: 1=User, 2=Device |
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

- The function queries the SMS_Collection WMI class directly via CIM sessions, providing direct access to MECM data without requiring the ConfigurationManager PowerShell module.
- Wildcard characters in collection names are converted from PowerShell syntax (`*`, `?`) to WQL syntax for server-side filtering.
- The function automatically converts numeric CollectionType values (1=User, 2=Device) to friendly names in the returned objects.
- For environments with large numbers of collections, consider using the `-Fast` parameter or filtering by specific criteria to improve query performance.
- The `PSTypeName` is automatically set to `MECM7.Collection` for improved formatting and type safety.

## RELATED LINKS

- [Connect-CM7](./Connect-CM7.md) - Establish connection to MECM
- [Get-CM7Device](./Get-CM7Device.md) - Retrieve device information

## SEE ALSO

- `Get-CMCollection` - Native ConfigurationManager module equivalent
- `Get-CimInstance` - PowerShell CIM cmdlet for WMI queries
