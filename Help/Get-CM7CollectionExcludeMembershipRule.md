# Get-CM7CollectionExcludeMembershipRule

## SYNOPSIS

Retrieves exclude membership rules for a Microsoft Endpoint Configuration Manager (MECM) collection using CIM.

## DESCRIPTION

The `Get-CM7CollectionExcludeMembershipRule` function queries the SMS_Collection WMI class to retrieve exclude collection membership rules for a MECM collection. Exclude rules reference another collection whose members are excluded from the parent collection's effective membership.

This function is the CIM-based equivalent of the `Get-CMCollectionExcludeMembershipRule` cmdlet from the ConfigurationManager PowerShell module, but uses direct CIM queries over WinRM instead of requiring the ConfigMgr console or PowerShell drive.

The function performs the following actions:

1. Validates an active connection exists (established via `Connect-CM7`)
2. Resolves collection name to CollectionID if needed
3. Retrieves the full collection instance to access lazy-loaded CollectionRules
4. Filters collection rules for type `SMS_CollectionRuleExcludeCollection`
5. Returns formatted exclude rule objects with commonly used properties

Key features:
- **Name or ID Lookup**: Query by collection name or CollectionID
- **Exclude Collection Filtering**: Filter by excluded collection name with wildcard support, or by excluded CollectionID
- **Flexible Querying**: Query all exclude rules or filter by specific excluded collections
- **Exclude Rules Only**: Shows only exclude collection rules, not direct, include, or query rules

## PARAMETERS

### -CollectionName

Specifies the name of the collection to retrieve exclude membership rules for.

- **Type**: String
- **Position**: Named
- **Default**: None
- **Required**: No (but either CollectionName or CollectionId must be provided)
- **Alias**: Name
- **Accept pipeline input**: Yes (ByPropertyName)
- **Accept wildcard characters**: No

Example: `All Systems`

### -CollectionId

Specifies the CollectionID of the collection to retrieve exclude membership rules for. This is the unique identifier assigned by MECM to each collection.

- **Type**: String
- **Position**: Named
- **Default**: None
- **Required**: No (but either CollectionName or CollectionId must be provided)
- **Alias**: Id
- **Accept pipeline input**: Yes (ByPropertyName)
- **Accept wildcard characters**: No

Example: `SMS00001` (All Systems collection identifier)

### -ExcludeCollectionName

Specifies the name of the excluded collection to filter rules by. This parameter is optional and can be used in combination with -CollectionName or -CollectionId to further filter the results. Supports PowerShell wildcard characters (`*` and `?`).

- **Type**: String
- **Position**: Named
- **Default**: None
- **Required**: No
- **Accept pipeline input**: No
- **Accept wildcard characters**: Yes

Examples:
- `Test-Collection-Direct` - Exact match for a specific excluded collection
- `Test-*` - All excluded collections starting with "Test-"
- `*Server*` - All excluded collections containing "Server"

### -ExcludeCollectionId

Specifies the CollectionID of the excluded collection to filter rules by. This parameter is optional and can be used in combination with -CollectionName or -CollectionId to further filter the results.

- **Type**: String
- **Position**: Named
- **Default**: None
- **Required**: No
- **Accept pipeline input**: No
- **Accept wildcard characters**: No

Example: `SMS00002`

## OUTPUTS

### MECM7.CollectionExcludeMembershipRule

The function returns PSCustomObject instances with the following properties:

**Standard Properties:**
- **RuleName** (String): The name of the exclude rule (typically the name of the excluded collection)
- **ExcludeCollectionId** (String): The CollectionID of the excluded collection
- **CollectionId** (String): The ID of the parent collection that contains the rule

## EXAMPLES

### Example 1: Retrieve all exclude rules for a collection

```powershell
Get-CM7CollectionExcludeMembershipRule -CollectionName "All Systems"
```

Retrieves all exclude membership rules defined on the "All Systems" collection.

### Example 2: Retrieve exclude rules matching a pattern

```powershell
Get-CM7CollectionExcludeMembershipRule -CollectionName "All Systems" -ExcludeCollectionName "Test*"
```

Retrieves all exclude membership rules where the excluded collection name matches the pattern "Test*".

### Example 3: Query by collection ID

```powershell
Get-CM7CollectionExcludeMembershipRule -CollectionId "SMS00001"
```

Retrieves all exclude membership rules for the collection with ID "SMS00001".

### Example 4: Query by specific excluded collection ID

```powershell
Get-CM7CollectionExcludeMembershipRule -CollectionId "SMS00001" -ExcludeCollectionId "SMS00002"
```

Retrieves the exclude membership rule for the specified excluded collection ID within the specified parent collection.

### Example 5: Combine collection name and exclude filters

```powershell
Get-CM7CollectionExcludeMembershipRule -CollectionName "Production Devices" -ExcludeCollectionName "*Decommissioned*"
```

Retrieves exclude rules where the excluded collection name contains "Decommissioned" from the "Production Devices" collection.

## NOTES

### Membership Types

MECM collections support different membership methods:

- **Direct Membership**: Members explicitly added to the collection (use Get-CM7CollectionDirectMembershipRule)
- **Query Rules**: Members added based on WQL queries (use Get-CM7CollectionQueryMembershipRule)
- **Include Collections**: Members from other collections added via include rules (use Get-CM7CollectionIncludeMembershipRule)
- **Exclude Collections**: Members of the parent collection but excluded via exclude rules (retrieved by this function)
- **All Members**: All members regardless of how they were added (use Get-CM7CollectionMember)

### Related Functions

- **Get-CM7CollectionDirectMembershipRule** - Retrieves direct membership rules
- **Get-CM7CollectionIncludeMembershipRule** - Retrieves include membership rules
- **Get-CM7CollectionQueryMembershipRule** - Retrieves query membership rules
- **Get-CM7Collection** - Retrieves collection properties
- **Connect-CM7** - Establishes connection to MECM

### Prerequisites

- PowerShell 5.1 or higher
- WinRM access to the MECM SMS Provider
- An active MECM connection (established via `Connect-CM7`)
- Appropriate MECM administrative permissions

### Performance Considerations

- The function retrieves the full collection instance to access lazy-loaded CollectionRules
- For collections with many rules, filtering by ExcludeCollectionName or ExcludeCollectionId reduces output
- Wildcard patterns use regex matching on the RuleName property

### ConfigurationManager Equivalence

This function is equivalent to the ConfigurationManager module's `Get-CMCollectionExcludeMembershipRule` cmdlet:

```powershell
# ConfigurationManager module (requires ConfigMgr console)
Get-CMCollectionExcludeMembershipRule -CollectionId "SMS00001"

# MECM7 module (requires only WinRM access)
Get-CM7CollectionExcludeMembershipRule -CollectionId "SMS00001"
```

## SEE ALSO

- [Get-CM7CollectionDirectMembershipRule](./Get-CM7CollectionDirectMembership.md)
- [Get-CM7Collection](./Get-CM7Collection.md)
- [Get-CM7Device](./Get-CM7Device.md)
- [Connect-CM7](./Connect-CM7.md)
- [Microsoft Endpoint Configuration Manager Documentation](https://docs.microsoft.com/en-us/mem/configmgr/)
