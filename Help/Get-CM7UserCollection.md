# Get-CM7UserCollection

## SYNOPSIS

Retrieves user collection information from Microsoft Endpoint Configuration Manager (MECM) using CIM.

## DESCRIPTION

The `Get-CM7UserCollection` function is a convenience wrapper around `Get-CM7Collection` that automatically filters for user collections (CollectionType = User). It queries the SMS_Collection WMI class to retrieve detailed user collection information from MECM.

This function is the CIM-based equivalent of the `Get-CMUserCollection` cmdlet from the ConfigurationManager PowerShell module, but uses direct CIM queries over WinRM instead of requiring the ConfigMgr console or PowerShell drive.

The function performs the following actions:

1. Validates an active connection exists (established via `Connect-CM7`)
2. Delegates to `Get-CM7Collection` with `-CollectionType User`
3. Returns formatted user collection objects with commonly used properties

Key features:
- **User-Only**: Automatically filters to return only user collections
- **Wildcard Support**: Use `*` and `?` in collection names for pattern matching
- **Fast Mode**: Return limited properties for faster queries on large environments
- **Flexible Querying**: Query by name, CollectionID, or retrieve all user collections

## PARAMETERS

### -Name

Specifies the name of the user collection to retrieve. Supports PowerShell wildcard characters (`*` and `?`).

- **Type**: String
- **Position**: 0 (first positional parameter)
- **Default**: None
- **Required**: No
- **Parameter Set**: ByName
- **Accept pipeline input**: False
- **Accept wildcard characters**: Yes

Examples:
- `All Users` - Exact match
- `TEST-*` - All user collections starting with "TEST-"
- `*Group*` - All user collections containing "Group"

### -CollectionId

Specifies the CollectionID of the user collection to retrieve. This is the unique identifier assigned by MECM to each collection.

- **Type**: String
- **Position**: Named
- **Default**: None
- **Required**: Yes (for ByCollectionId parameter set)
- **Parameter Set**: ByCollectionId
- **Accept pipeline input**: False
- **Accept wildcard characters**: No

Example: `SMS00002` (All Users collection identifier)

### -Fast

Returns limited properties for faster performance. Only essential properties are returned:
- CollectionID
- Name
- CollectionType
- MemberCount
- LastRefreshTime

This is useful when querying large numbers of user collections or when you only need basic information.

- **Type**: SwitchParameter
- **Position**: Named
- **Default**: False
- **Required**: No
- **Parameter Set**: All
- **Accept pipeline input**: False

## EXAMPLES

### EXAMPLE 1: Get a user collection by exact name

```powershell
Get-CM7UserCollection -Name "All Users"
```

Retrieves the user collection with the exact name "All Users".

### EXAMPLE 2: Get user collections using wildcard pattern

```powershell
Get-CM7UserCollection -Name "TEST-*"
```

Retrieves all user collections whose names start with "TEST-". The wildcard `*` matches zero or more characters.

### EXAMPLE 3: Get user collections containing a string

```powershell
Get-CM7UserCollection -Name "*Group*"
```

Retrieves all user collections with "Group" anywhere in their name.

### EXAMPLE 4: Get a user collection by CollectionID

```powershell
Get-CM7UserCollection -CollectionId "SMS00002"
```

Retrieves the user collection with CollectionID "SMS00002" (typically the "All Users" collection).

### EXAMPLE 5: Get all user collections with limited properties

```powershell
Get-CM7UserCollection -Fast
```

Retrieves all user collections with limited properties for faster query performance.

### EXAMPLE 6: Use Fast mode for quick queries

```powershell
Get-CM7UserCollection -Name "TEST-*" -Fast
```

Retrieves all user collections starting with "TEST-" but returns only essential properties for faster performance.

### EXAMPLE 7: Get all user collections (use with caution)

```powershell
Get-CM7UserCollection
```

Retrieves all user collections from MECM. Warning: This can return a large result set in production environments.

### EXAMPLE 8: Get user collection properties

```powershell
$collection = Get-CM7UserCollection -Name "All Users"
Write-Host "Collection: $($collection.Name)"
Write-Host "CollectionID: $($collection.CollectionId)"
Write-Host "Type: $($collection.CollectionType)"
Write-Host "Member Count: $($collection.MemberCount)"
```

Retrieves a user collection and displays specific properties.

### EXAMPLE 9: Filter and export user collections

```powershell
Get-CM7UserCollection -Fast |
    Where-Object { $_.MemberCount -gt 100 } |
    Export-Csv -Path "LargeUserCollections.csv" -NoTypeInformation
```

Gets all user collections, filters for those with more than 100 members, and exports to CSV.

### EXAMPLE 10: Find user collections by creation date

```powershell
Get-CM7UserCollection |
    Where-Object { $_.CreatedDate -gt (Get-Date).AddMonths(-1) } |
    Select-Object Name, MemberCount, CreatedDate
```

Finds all user collections created in the last month and displays their properties.

### EXAMPLE 11: Count user collections

```powershell
$userCollections = Get-CM7UserCollection
Write-Host "Total User Collections: $($userCollections.Count)"
Write-Host "Average Member Count: $(($userCollections | Measure-Object -Property MemberCount -Average).Average)"
```

Gets all user collections and displays count and average member count statistics.

### EXAMPLE 12: Equivalent to Get-CM7Collection with -CollectionType User

```powershell
# These two commands produce identical results:
Get-CM7UserCollection -Name "TEST-*"
Get-CM7Collection -Name "TEST-*" -CollectionType User
```

Demonstrates that `Get-CM7UserCollection` is functionally equivalent to `Get-CM7Collection -CollectionType User`.

## OUTPUTS

### MECM7.Collection

The function returns custom objects of type `MECM7.Collection` with the following properties:

| Property | Type | Description |
|----------|------|-------------|
| CollectionId | String | The unique collection identifier (e.g., "SMS00002") |
| Name | String | The display name of the collection |
| CollectionType | String | Always "User" for this function |
| TypeValue | Int | Always 1 (User) for this function |
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

- This function is a convenience wrapper around `Get-CM7Collection -CollectionType User`.
- It is the CIM-based equivalent of the `Get-CMUserCollection` cmdlet from the ConfigurationManager module.
- The function queries the SMS_Collection WMI class directly via CIM sessions, providing direct access to MECM data without requiring the ConfigurationManager PowerShell module.
- Wildcard characters in collection names are converted from PowerShell syntax (`*`, `?`) to WQL syntax for server-side filtering.
- The function automatically converts numeric CollectionType values to friendly names in the returned objects. For this function, the CollectionType will always be "User".
- For environments with large numbers of collections, consider using the `-Fast` parameter or filtering by specific criteria to improve query performance.
- The `PSTypeName` is automatically set to `MECM7.Collection` for improved formatting and type safety.

## RELATED LINKS

- [Connect-CM7](./Connect-CM7.md) - Establish connection to MECM
- [Get-CM7Collection](./Get-CM7Collection.md) - Retrieve all collection types from MECM
- [Get-CM7DeviceCollection](./Get-CM7DeviceCollection.md) - Retrieve device collection information from MECM

## SEE ALSO

- `Get-CMUserCollection` - Native ConfigurationManager module equivalent
- `Get-CM7Collection` - The underlying function used by this wrapper
- `Get-CimInstance` - PowerShell CIM cmdlet for WMI queries
