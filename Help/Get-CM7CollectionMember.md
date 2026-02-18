# Get-CM7CollectionMember

## SYNOPSIS

Retrieves members of a Microsoft Endpoint Configuration Manager (MECM) collection using CIM.

## DESCRIPTION

The `Get-CM7CollectionMember` function queries the SMS_FullCollectionMembership WMI class to retrieve all members of a MECM collection, regardless of how they were added (direct rules, query rules, include rules, or exclude rules).

This function is the CIM-based equivalent of the `Get-CMCollectionMember` cmdlet from the ConfigurationManager PowerShell module, but uses direct CIM queries over WinRM instead of requiring the ConfigMgr console or PowerShell drive.

The function performs the following actions:

1. Validates an active connection exists (established via `Connect-CM7`)
2. Resolves collection name to CollectionID if needed
3. Queries the SMS_FullCollectionMembership WMI class for all members of the collection
4. Applies optional resource name, resource ID, or SMSID filters
5. Returns formatted collection member objects with commonly used properties

Key features:
- **Name or ID Lookup**: Query by collection name or CollectionID
- **Resource Filtering**: Filter by resource name with wildcard support, resource ID, or SMSID
- **Fast Mode**: Return limited properties for better performance on large collections
- **All Members**: Returns all collection members regardless of membership rule type (direct, query, include, exclude)

## PARAMETERS

### -CollectionName

Specifies the name of the collection to retrieve members for.

- **Type**: String
- **Position**: Named
- **Default**: None
- **Required**: No (but either CollectionName or CollectionId must be provided)
- **Alias**: Name
- **Accept pipeline input**: Yes (ByPropertyName)
- **Accept wildcard characters**: No

Example: `All Systems`

### -CollectionId

Specifies the CollectionID of the collection to retrieve members for. This is the unique identifier assigned by MECM to each collection.

- **Type**: String
- **Position**: Named
- **Default**: None
- **Required**: No (but either CollectionName or CollectionId must be provided)
- **Alias**: Id
- **Accept pipeline input**: Yes (ByPropertyName)
- **Accept wildcard characters**: No

Example: `SMS00001` (All Systems collection identifier)

### -ResourceName

Specifies the name of the resource to filter by. This parameter is optional and can be used in combination with -CollectionName or -CollectionId to further filter the results. Supports PowerShell wildcard characters (`*` and `?`).

- **Type**: String
- **Position**: Named
- **Default**: None
- **Required**: No
- **Accept pipeline input**: No
- **Accept wildcard characters**: Yes

Examples:
- `COMPUTER01` - Exact match for a specific resource
- `TEST-*` - All resources starting with "TEST-"
- `*SERVER*` - All resources containing "SERVER"

### -ResourceId

Specifies the ResourceID of the resource to filter by. This parameter is optional and can be used in combination with -CollectionName or -CollectionId to further filter the results.

- **Type**: Int
- **Position**: Named
- **Default**: -1 (not specified)
- **Required**: No
- **Accept pipeline input**: No
- **Accept wildcard characters**: No

Example: `16777220`

### -SmsId

Specifies the SMSID (GUID) of the resource to filter by. This parameter is optional and can be used in combination with -CollectionName or -CollectionId to further filter the results.

- **Type**: String
- **Position**: Named
- **Default**: None
- **Required**: No
- **Accept pipeline input**: No
- **Accept wildcard characters**: No

Example: `GUID:12345678-1234-1234-1234-123456789012`

### -Fast

Returns limited properties for faster queries. When specified, only essential properties are returned (ResourceID, Name, ResourceType, CollectionID, SiteCode, Domain).

- **Type**: Switch
- **Position**: Named
- **Default**: False
- **Required**: No
- **Accept pipeline input**: No

## OUTPUTS

### MECM7.CollectionMember

The function returns PSCustomObject instances with the following properties:

**Standard Properties (always returned):**
| Property | Type | Description |
|----------|------|-------------|
| ResourceId | Int | The unique ResourceID of the member |
| Name | String | The name of the member resource |
| ResourceType | String | The type of resource ('Device', 'User', or 'Unknown') |
| CollectionId | String | The ID of the collection |
| SiteCode | String | The site code the member is assigned to |
| Domain | String | The domain of the member resource |

**Extended Properties (returned when -Fast is NOT specified):**
| Property | Type | Description |
|----------|------|-------------|
| SmsId | String | The SMSID (GUID) of the resource |
| IsClient | Boolean | Whether the resource has the ConfigMgr client installed |
| IsActive | Boolean | Whether the resource is active |
| IsObsolete | Boolean | Whether the resource is marked as obsolete |
| IsAssigned | Boolean | Whether the resource is assigned to the site |
| IsDecommissioned | Boolean | Whether the resource is decommissioned |
| IsDirect | Boolean | Whether the resource is a direct member |
| IsBlockedClient | Boolean | Whether the client is blocked |
| ClientType | Int | The type of client |
| DeviceOwner | Int | The device owner type |
| ClientCertType | Int | The client certificate type |

## EXAMPLES

### Example 1: Retrieve all members of a collection by name

```powershell
Get-CM7CollectionMember -CollectionName "All Systems"
```

Retrieves all members of the "All Systems" collection, returning full details for each member.

### Example 2: Retrieve members matching a wildcard pattern

```powershell
Get-CM7CollectionMember -CollectionName "All Systems" -ResourceName "TEST-*"
```

Retrieves all members whose name starts with "TEST-" from the "All Systems" collection.

### Example 3: Query by collection ID

```powershell
Get-CM7CollectionMember -CollectionId "SMS00001"
```

Retrieves all members of the collection with ID "SMS00001".

### Example 4: Query a specific resource by ID

```powershell
Get-CM7CollectionMember -CollectionId "SMS00001" -ResourceId 16777220
```

Retrieves the member with ResourceID 16777220 from the specified collection.

### Example 5: Fast mode for large collections

```powershell
Get-CM7CollectionMember -CollectionName "All Systems" -Fast
```

Retrieves all members with limited properties for better performance. Useful for large collections where only basic information is needed.

### Example 6: Combine collection name and resource name filter

```powershell
Get-CM7CollectionMember -CollectionName "Production Devices" -ResourceName "*SERVER*"
```

Retrieves members whose name contains "SERVER" from the "Production Devices" collection.

### Example 7: Pipeline input from Get-CM7Collection

```powershell
Get-CM7Collection -Name "Test-Collection-Query" | Get-CM7CollectionMember
```

Pipes collection output into Get-CM7CollectionMember to retrieve all members of that collection.

### Example 8: Filter by SMSID

```powershell
Get-CM7CollectionMember -CollectionId "SMS00001" -SmsId "GUID:12345678-1234-1234-1234-123456789012"
```

Retrieves the member with the specified SMSID from the collection.

## NOTES

### Membership Types

MECM collections support different membership methods. The `Get-CM7CollectionMember` function retrieves **all** members regardless of how they were added:

- **Direct Membership**: Members explicitly added to the collection (see `Get-CM7CollectionDirectMembershipRule`)
- **Query Rules**: Members added based on WQL queries (see `Get-CM7CollectionQueryMembershipRule`)
- **Include Collections**: Members from other collections added via include rules (see `Get-CM7CollectionIncludeMembershipRule`)
- **Exclude Collections**: Members excluded via exclude rules (see `Get-CM7CollectionExcludeMembershipRule`)

### Related Functions

- **Get-CM7CollectionDirectMembershipRule** - Retrieves direct membership rules
- **Get-CM7CollectionExcludeMembershipRule** - Retrieves exclude membership rules
- **Get-CM7CollectionIncludeMembershipRule** - Retrieves include membership rules
- **Get-CM7CollectionQueryMembershipRule** - Retrieves query membership rules
- **Get-CM7Collection** - Retrieves collection properties
- **Get-CM7Device** - Retrieves device information
- **Connect-CM7** - Establishes connection to MECM

### Prerequisites

- PowerShell 5.1 or higher
- WinRM access to the MECM SMS Provider
- An active MECM connection (established via `Connect-CM7`)
- Appropriate MECM administrative permissions

### Performance Considerations

- The function queries SMS_FullCollectionMembership which is efficient for member enumeration
- For large collections, use the `-Fast` parameter to limit returned properties
- Use `-ResourceName` or `-ResourceId` filters to reduce output when looking for specific members
- Wildcard patterns are converted to WQL LIKE operators for server-side filtering

### ConfigurationManager Equivalence

This function is equivalent to the ConfigurationManager module's `Get-CMCollectionMember` cmdlet:

```powershell
# ConfigurationManager module (requires ConfigMgr console)
Get-CMCollectionMember -CollectionId "SMS00001"

# MECM7 module (requires only WinRM access)
Get-CM7CollectionMember -CollectionId "SMS00001"
```

### Comparison with Get-CMCollectionMember

| Feature | Get-CMCollectionMember | Get-CM7CollectionMember |
|---------|----------------------|------------------------|
| Requires ConfigMgr console | Yes | No |
| Connection method | PSDrive | CIM/WinRM |
| PowerShell 7 support | Limited | Full |
| Remote management | Via PSDrive only | Direct WinRM |
| Collection name lookup | CollectionName parameter | CollectionName parameter |
| Wildcard support | Yes (-Name) | Yes (-ResourceName) |
| Fast mode | No | Yes (-Fast) |
| SMSID filter | Yes (-SmsId) | Yes (-SmsId) |

## SEE ALSO

- [Get-CM7CollectionDirectMembershipRule](./Get-CM7CollectionDirectMembership.md)
- [Get-CM7CollectionExcludeMembershipRule](./Get-CM7CollectionExcludeMembershipRule.md)
- [Get-CM7CollectionIncludeMembershipRule](./Get-CM7CollectionIncludeMembershipRule.md)
- [Get-CM7CollectionQueryMembershipRule](./Get-CM7CollectionQueryMembershipRule.md)
- [Get-CM7Collection](./Get-CM7Collection.md)
- [Get-CM7Device](./Get-CM7Device.md)
- [Connect-CM7](./Connect-CM7.md)
- [Microsoft Endpoint Configuration Manager Documentation](https://docs.microsoft.com/en-us/mem/configmgr/)
