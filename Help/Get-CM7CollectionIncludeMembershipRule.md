# Get-CM7CollectionIncludeMembershipRule

## SYNOPSIS

Retrieves include membership rules for a Microsoft Endpoint Configuration Manager (MECM) collection using CIM.

## DESCRIPTION

The `Get-CM7CollectionIncludeMembershipRule` function queries the SMS_Collection WMI class to retrieve include collection membership rules for a MECM collection. Include rules reference another collection whose members are included in the parent collection's effective membership.

This function is the CIM-based equivalent of the `Get-CMCollectionIncludeMembershipRule` cmdlet from the ConfigurationManager PowerShell module, but uses direct CIM queries over WinRM instead of requiring the ConfigMgr console or PowerShell drive.

The function performs the following actions:

1. Validates an active connection exists (established via `Connect-CM7`)
2. Resolves collection name to CollectionID if needed
3. Retrieves the full collection instance to access lazy-loaded CollectionRules
4. Filters collection rules for type `SMS_CollectionRuleIncludeCollection`
5. Returns formatted include rule objects with commonly used properties

Key features:
- **Name or ID Lookup**: Query by collection name or CollectionID
- **Include Collection Filtering**: Filter by included collection name with wildcard support, or by included CollectionID
- **Flexible Querying**: Query all include rules or filter by specific included collections
- **Include Rules Only**: Shows only include collection rules, not direct, exclude, or query rules

## PARAMETERS

### -CollectionName

Specifies the name of the collection to retrieve include membership rules for.

- **Type**: String
- **Position**: Named
- **Default**: None
- **Required**: No (but either CollectionName or CollectionId must be provided)
- **Alias**: Name
- **Accept pipeline input**: Yes (ByPropertyName)
- **Accept wildcard characters**: No

Example: `All Systems`

### -CollectionId

Specifies the CollectionID of the collection to retrieve include membership rules for. This is the unique identifier assigned by MECM to each collection.

- **Type**: String
- **Position**: Named
- **Default**: None
- **Required**: No (but either CollectionName or CollectionId must be provided)
- **Alias**: Id
- **Accept pipeline input**: Yes (ByPropertyName)
- **Accept wildcard characters**: No

Example: `SMS00001` (All Systems collection identifier)

### -IncludeCollectionName

Specifies the name of the included collection to filter rules by. This parameter is optional and can be used in combination with -CollectionName or -CollectionId to further filter the results. Supports PowerShell wildcard characters (`*` and `?`).

- **Type**: String
- **Position**: Named
- **Default**: None
- **Required**: No
- **Accept pipeline input**: No
- **Accept wildcard characters**: Yes

Examples:
- `Test-Collection-Direct` - Exact match for a specific included collection
- `Test-*` - All included collections starting with "Test-"
- `*Server*` - All included collections containing "Server"

### -IncludeCollectionId

Specifies the CollectionID of the included collection to filter rules by. This parameter is optional and can be used in combination with -CollectionName or -CollectionId to further filter the results.

- **Type**: String
- **Position**: Named
- **Default**: None
- **Required**: No
- **Accept pipeline input**: No
- **Accept wildcard characters**: No

Example: `SMS00002`

## OUTPUTS

### MECM7.CollectionIncludeMembershipRule

The function returns PSCustomObject instances with the following properties:

**Standard Properties:**
- **RuleName** (String): The name of the include rule (typically the name of the included collection)
- **IncludeCollectionId** (String): The CollectionID of the included collection
- **CollectionId** (String): The ID of the parent collection that contains the rule

## EXAMPLES

### Example 1: Retrieve all include rules for a collection

```powershell
Get-CM7CollectionIncludeMembershipRule -CollectionName "All Systems"
```

Retrieves all include membership rules defined on the "All Systems" collection.

### Example 2: Retrieve include rules matching a pattern

```powershell
Get-CM7CollectionIncludeMembershipRule -CollectionName "All Systems" -IncludeCollectionName "Test*"
```

Retrieves all include membership rules where the included collection name matches the pattern "Test*".

### Example 3: Query by collection ID

```powershell
Get-CM7CollectionIncludeMembershipRule -CollectionId "SMS00001"
```

Retrieves all include membership rules for the collection with ID "SMS00001".

### Example 4: Query by specific included collection ID

```powershell
Get-CM7CollectionIncludeMembershipRule -CollectionId "SMS00001" -IncludeCollectionId "SMS00002"
```

Retrieves the include membership rule for the specified included collection ID within the specified parent collection.

### Example 5: Combine collection name and include filters

```powershell
Get-CM7CollectionIncludeMembershipRule -CollectionName "Production Devices" -IncludeCollectionName "*Servers*"
```

Retrieves include rules where the included collection name contains "Servers" from the "Production Devices" collection.

## NOTES

### Membership Types

MECM collections support different membership methods:

- **Direct Membership**: Members explicitly added to the collection (use Get-CM7CollectionDirectMembershipRule)
- **Query Rules**: Members added based on WQL queries (use Get-CM7CollectionQueryMembershipRule)
- **Include Collections**: Members from other collections added via include rules (retrieved by this function)
- **Exclude Collections**: Members of the parent collection but excluded via exclude rules (use Get-CM7CollectionExcludeMembershipRule)
- **All Members**: All members regardless of how they were added (use Get-CM7CollectionMember)

### Related Functions

- **Get-CM7CollectionDirectMembershipRule** - Retrieves direct membership rules
- **Get-CM7CollectionExcludeMembershipRule** - Retrieves exclude membership rules
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
- For collections with many rules, filtering by IncludeCollectionName or IncludeCollectionId reduces output
- Wildcard patterns use regex matching on the RuleName property

### ConfigurationManager Equivalence

This function is equivalent to the ConfigurationManager module's `Get-CMCollectionIncludeMembershipRule` cmdlet:

```powershell
# ConfigurationManager module (requires ConfigMgr console)
Get-CMCollectionIncludeMembershipRule -CollectionId "SMS00001"

# MECM7 module (requires only WinRM access)
Get-CM7CollectionIncludeMembershipRule -CollectionId "SMS00001"
```

## SEE ALSO

- [Get-CM7CollectionExcludeMembershipRule](./Get-CM7CollectionExcludeMembershipRule.md)
- [Get-CM7CollectionDirectMembership](./Get-CM7CollectionDirectMembership.md)
- [Get-CM7Collection](./Get-CM7Collection.md)
- [Get-CM7Device](./Get-CM7Device.md)
- [Connect-CM7](./Connect-CM7.md)
- [Microsoft Endpoint Configuration Manager Documentation](https://docs.microsoft.com/en-us/mem/configmgr/)
