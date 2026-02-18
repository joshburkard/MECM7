# Get-CM7CollectionQueryMembershipRule

## SYNOPSIS

Retrieves query membership rules for a Microsoft Endpoint Configuration Manager (MECM) collection using CIM.

## DESCRIPTION

The `Get-CM7CollectionQueryMembershipRule` function queries the SMS_Collection WMI class to retrieve query-based membership rules for a MECM collection. Query rules use WQL (WMI Query Language) expressions to dynamically determine collection membership based on resource attributes such as device name, operating system, or hardware properties.

This function is the CIM-based equivalent of the `Get-CMCollectionQueryMembershipRule` cmdlet from the ConfigurationManager PowerShell module, but uses direct CIM queries over WinRM instead of requiring the ConfigMgr console or PowerShell drive.

The function performs the following actions:

1. Validates an active connection exists (established via `Connect-CM7`)
2. Resolves collection name to CollectionID if needed
3. Retrieves the full collection instance to access lazy-loaded CollectionRules
4. Filters collection rules for type `SMS_CollectionRuleQuery`
5. Returns formatted query rule objects with commonly used properties

Key features:
- **Name or ID Lookup**: Query by collection name or CollectionID
- **Rule Name Filtering**: Filter by query rule name with wildcard support
- **Flexible Querying**: Query all query rules or filter by specific rule names
- **Query Rules Only**: Shows only query-based rules, not direct, include, or exclude rules

## PARAMETERS

### -CollectionName

Specifies the name of the collection to retrieve query membership rules for.

- **Type**: String
- **Position**: Named
- **Default**: None
- **Required**: No (but either CollectionName or CollectionId must be provided)
- **Alias**: Name
- **Accept pipeline input**: Yes (ByPropertyName)
- **Accept wildcard characters**: No

Example: `All Systems`

### -CollectionId

Specifies the CollectionID of the collection to retrieve query membership rules for. This is the unique identifier assigned by MECM to each collection.

- **Type**: String
- **Position**: Named
- **Default**: None
- **Required**: No (but either CollectionName or CollectionId must be provided)
- **Alias**: Id
- **Accept pipeline input**: Yes (ByPropertyName)
- **Accept wildcard characters**: No

Example: `SMS00001` (All Systems collection identifier)

### -RuleName

Specifies the name of the query rule to filter by. This parameter is optional and can be used in combination with -CollectionName or -CollectionId to further filter the results. Supports PowerShell wildcard characters (`*` and `?`).

- **Type**: String
- **Position**: Named
- **Default**: None
- **Required**: No
- **Accept pipeline input**: No
- **Accept wildcard characters**: Yes

Examples:
- `Test-Servers` - Exact match for a specific query rule
- `Test-*` - All query rules starting with "Test-"
- `*Server*` - All query rules containing "Server"

## OUTPUTS

### MECM7.CollectionQueryMembershipRule

The function returns PSCustomObject instances with the following properties:

**Standard Properties:**
- **RuleName** (String): The name of the query rule
- **QueryExpression** (String): The WQL query expression that determines membership
- **QueryId** (Int32): The unique identifier of the query rule within the collection
- **CollectionId** (String): The ID of the parent collection that contains the rule

## EXAMPLES

### Example 1: Retrieve all query rules for a collection

```powershell
Get-CM7CollectionQueryMembershipRule -CollectionName "All Systems"
```

Retrieves all query membership rules defined on the "All Systems" collection.

### Example 2: Retrieve query rules matching a pattern

```powershell
Get-CM7CollectionQueryMembershipRule -CollectionName "All Systems" -RuleName "Test*"
```

Retrieves all query membership rules where the rule name matches the pattern "Test*".

### Example 3: Query by collection ID

```powershell
Get-CM7CollectionQueryMembershipRule -CollectionId "SMS00001"
```

Retrieves all query membership rules for the collection with ID "SMS00001".

### Example 4: Query by specific rule name

```powershell
Get-CM7CollectionQueryMembershipRule -CollectionId "SMS00001" -RuleName "Windows Servers"
```

Retrieves the query membership rule named "Windows Servers" within the specified collection.

### Example 5: Combine collection name and rule name filters

```powershell
Get-CM7CollectionQueryMembershipRule -CollectionName "Production Devices" -RuleName "*Server*"
```

Retrieves query rules where the rule name contains "Server" from the "Production Devices" collection.

### Example 6: View the WQL query expression

```powershell
$rules = Get-CM7CollectionQueryMembershipRule -CollectionName "All Workstations"
$rules | Select-Object RuleName, QueryExpression
```

Retrieves query rules and displays the rule names alongside their WQL expressions.

## NOTES

### Membership Types

MECM collections support different membership methods:

- **Direct Membership**: Members explicitly added to the collection (use Get-CM7CollectionDirectMembershipRule)
- **Query Rules**: Members added based on WQL queries (retrieved by this function)
- **Include Collections**: Members from other collections added via include rules (use Get-CM7CollectionIncludeMembershipRule)
- **Exclude Collections**: Members of the parent collection but excluded via exclude rules (use Get-CM7CollectionExcludeMembershipRule)
- **All Members**: All members regardless of how they were added (use Get-CM7CollectionMember)

### Related Functions

- **Get-CM7CollectionDirectMembershipRule** - Retrieves direct membership rules
- **Get-CM7CollectionIncludeMembershipRule** - Retrieves include membership rules
- **Get-CM7CollectionExcludeMembershipRule** - Retrieves exclude membership rules
- **Get-CM7Collection** - Retrieves collection properties
- **Connect-CM7** - Establishes connection to MECM

### Prerequisites

- PowerShell 5.1 or higher
- WinRM access to the MECM SMS Provider
- An active MECM connection (established via `Connect-CM7`)
- Appropriate MECM administrative permissions

### Performance Considerations

- The function retrieves the full collection instance to access lazy-loaded CollectionRules
- For collections with many rules, filtering by RuleName reduces output
- Wildcard patterns use regex matching on the RuleName property

### WQL Query Examples

Common WQL expressions used in collection query rules:

```sql
-- All Windows 10 devices
SELECT * FROM SMS_R_System WHERE SMS_R_System.OperatingSystemNameAndVersion LIKE '%Workstation 10.0%'

-- All servers
SELECT * FROM SMS_R_System WHERE SMS_R_System.OperatingSystemNameAndVersion LIKE '%Server%'

-- Devices by name pattern
SELECT * FROM SMS_R_System WHERE SMS_R_System.Name LIKE 'SRV-%'
```

### ConfigurationManager Equivalence

This function is equivalent to the ConfigurationManager module's `Get-CMCollectionQueryMembershipRule` cmdlet:

```powershell
# ConfigurationManager module (requires ConfigMgr console)
Get-CMCollectionQueryMembershipRule -CollectionId "SMS00001"

# MECM7 module (requires only WinRM access)
Get-CM7CollectionQueryMembershipRule -CollectionId "SMS00001"
```

## SEE ALSO

- [Get-CM7CollectionIncludeMembershipRule](./Get-CM7CollectionIncludeMembershipRule.md)
- [Get-CM7CollectionExcludeMembershipRule](./Get-CM7CollectionExcludeMembershipRule.md)
- [Get-CM7CollectionDirectMembership](./Get-CM7CollectionDirectMembership.md)
- [Get-CM7Collection](./Get-CM7Collection.md)
- [Get-CM7Device](./Get-CM7Device.md)
- [Connect-CM7](./Connect-CM7.md)
- [Microsoft Endpoint Configuration Manager Documentation](https://docs.microsoft.com/en-us/mem/configmgr/)
