# Get-CM7CollectionDirectMembership

## SYNOPSIS

Retrieves direct membership information for a Microsoft Endpoint Configuration Manager (MECM) collection using CIM.

## DESCRIPTION

The `Get-CM7CollectionDirectMembership` function queries the SMS_CollectionMember_a WMI class to retrieve direct membership information for a MECM collection. Direct members are resources that have been explicitly added to a collection (as opposed to being added via query rules, include collections, or exclude collections).

This function is the CIM-based equivalent of the `Get-CMCollectionDirectMembership` cmdlet from the ConfigurationManager PowerShell module, but uses direct CIM queries over WinRM instead of requiring the ConfigMgr console or PowerShell drive.

The function performs the following actions:

1. Validates an active connection exists (established via `Connect-CM7`)
2. Resolves collection name to CollectionID if needed
3. Builds a WQL query based on the provided parameters
4. Queries the SMS_CollectionMember_a class via CIM
5. Returns formatted direct member objects with commonly used properties

Key features:
- **Name or ID Lookup**: Query by collection name or CollectionID
- **Resource Filtering**: Filter by resource name with wildcard support, or by ResourceID
- **Fast Mode**: Return limited properties for faster queries on large collections
- **Flexible Querying**: Query all direct members or filter by specific resources
- **Direct Members Only**: Shows only explicitly added members, not rule-based or included members

## PARAMETERS

### -Name

Specifies the name of the collection to retrieve direct members for. This is a required parameter when not using the ByCollectionId parameter set.

- **Type**: String
- **Position**: 0 (first positional parameter)
- **Default**: None
- **Required**: No (required for ByCollectionName parameter set)
- **Parameter Set**: ByCollectionName
- **Accept pipeline input**: False
- **Accept wildcard characters**: No

Example: `All Systems`

### -CollectionId

Specifies the CollectionID of the collection to retrieve direct members for. This is the unique identifier assigned by MECM to each collection.

- **Type**: String
- **Position**: Named
- **Default**: None
- **Required**: Yes (for ByCollectionId parameter set)
- **Parameter Set**: ByCollectionId
- **Accept pipeline input**: False
- **Accept wildcard characters**: No

Example: `SMS00001` (All Systems collection identifier)

### -ResourceName

Specifies the name of the resource (device or user) to retrieve direct membership information for. This parameter is optional and can be used in combination with -Name or -CollectionId to further filter the results. Supports PowerShell wildcard characters (`*` and `?`).

- **Type**: String
- **Position**: Named
- **Default**: None
- **Required**: No
- **Parameter Set**: All
- **Accept pipeline input**: False
- **Accept wildcard characters**: Yes

Examples:
- `TEST-DEVICE-001` - Exact match for a single device
- `TEST-*` - All devices starting with "TEST-"
- `*SERVER*` - All devices/resources containing "SERVER"

### -ResourceId

Specifies the ResourceID of the resource to retrieve direct membership information for. This parameter is optional and can be used in combination with -Name or -CollectionId to further filter the results.

- **Type**: Integer
- **Position**: Named
- **Default**: -1 (not specified)
- **Required**: No
- **Parameter Set**: All
- **Accept pipeline input**: False
- **Accept wildcard characters**: No

Example: `16777220`

### -Fast

Returns limited properties for faster performance. Only essential properties are returned:
- ResourceID
- Name
- ResourceType
- DateAdded
- MachineID
- CollectionId

Without this switch, all available WMI properties from SMS_CollectionMember_a are returned.

- **Type**: Switch
- **Position**: Named
- **Default**: False
- **Required**: No
- **Parameter Set**: All
- **Accept pipeline input**: False

## OUTPUTS

### MECM7.CollectionDirectMember

The function returns PSCustomObject instances with the following properties:

**Standard Properties:**
- **ResourceId** (Int32): The unique identifier of the resource
- **Name** (String): The name of the resource (device or user)
- **ResourceType** (String): The type of resource (Device, User, or Unknown)
- **DateAdded** (DateTime): When the resource was added to the collection
- **MachineId** (String): The machine/system identifier
- **CollectionId** (String): The ID of the collection

**Additional Properties (without -Fast):**
- **IsSpecific** (Boolean): Whether this is a specific / explicit membership
- **Ordinal** (Int32): The ordinal value for the membership

## EXAMPLES

### Example 1: Retrieve all direct members of a collection

```powershell
Get-CM7CollectionDirectMembership -Name "All Systems"
```

Retrieves all resources that are direct members of the "All Systems" collection.

### Example 2: Retrieve direct members matching a pattern

```powershell
Get-CM7CollectionDirectMembership -Name "All Systems" -ResourceName "TEST-*"
```

Retrieves all resources matching the pattern "TEST-*" that are direct members of the "All Systems" collection. Only returns resources explicitly added to the collection.

### Example 3: Query by collection ID

```powershell
Get-CM7CollectionDirectMembership -CollectionId "SMS00001"
```

Retrieves all direct members of the collection with ID "SMS00001" using the collection identifier instead of name.

### Example 4: Query specific resource membership

```powershell
Get-CM7CollectionDirectMembership -Name "All Systems" -ResourceName "COMPUTER01"
```

Retrieves direct membership information for "COMPUTER01" in the "All Systems" collection.

### Example 5: Query by resource ID

```powershell
Get-CM7CollectionDirectMembership -CollectionId "SMS00001" -ResourceId 16777220
```

Retrieves direct membership information for resource ID 16777220 in the specified collection.

### Example 6: Fast mode for better performance

```powershell
Get-CM7CollectionDirectMembership -Name "All Systems" -Fast
```

Retrieves direct members with limited properties for faster query execution on collections with many members.

### Example 7: Combine collection and resource filters

```powershell
Get-CM7CollectionDirectMembership -CollectionId "SMS00001" -ResourceName "SERVER-*" -Fast
```

Retrieves server devices matching the pattern "SERVER-*" that are direct members of the specified collection, returning limited properties.

## NOTES

### Membership Types

MECM collections support different membership methods:

- **Direct Membership**: Members explicitly added to the collection (retrieved by this function)
- **Query Rules**: Members added based on WQL queries (use Get-CM7CollectionQueryMembershipRule)
- **Include Collections**: Members from other collections added via include rules (use Get-CM7CollectionIncludeMembershipRule)
- **Exclude Collections**: Members of the parent collection but excluded via exclude rules (use Get-CM7CollectionExcludeMembershipRule)
- **All Members**: All members regardless of how they were added (use Get-CM7CollectionMember)

### Related Functions

- **Get-CM7CollectionMember** - Retrieves all members of a collection (any membership type)
- **Get-CM7CollectionDirectMembershipRule** - Retrieves direct membership rules
- **Get-CM7Collection** - Retrieves collection properties
- **Connect-CM7** - Establishes connection to MECM

### Prerequisites

- PowerShell 5.1 or higher
- WinRM access to the MECM SMS Provider
- An active MECM connection (established via `Connect-CM7`)
- Appropriate MECM administrative permissions

### Performance Considerations

- **Large Collections**: Use the -Fast parameter for collections with thousands of members
- **Wildcard Patterns**: Wildcard searches may take longer on large environments; be as specific as possible
- **Resource Filtering**: Filtering by ResourceId is faster than filtering by ResourceName

### ConfigurationManager Equivalence

This function is equivalent to the ConfigurationManager module's `Get-CMCollectionDirectMembership` cmdlet:

```powershell
# ConfigurationManager module (requires ConfigMgr console)
Get-CMCollectionDirectMembership -CollectionId "SMS00001"

# MECM7 module (requires only WinRM access)
Get-CM7CollectionDirectMembership -CollectionId "SMS00001"
```

## SEE ALSO

- [Get-CM7CollectionMember](./Get-CM7CollectionMember.md)
- [Get-CM7Collection](./Get-CM7Collection.md)
- [Get-CM7Device](./Get-CM7Device.md)
- [Connect-CM7](./Connect-CM7.md)
- [Microsoft Endpoint Configuration Manager Documentation](https://docs.microsoft.com/en-us/mem/configmgr/)
