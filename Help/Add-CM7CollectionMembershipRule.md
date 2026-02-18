# Add-CM7CollectionMembershipRule

## SYNOPSIS

Adds a membership rule to a MECM collection using CIM.

## DESCRIPTION

The `Add-CM7CollectionMembershipRule` function adds one or more membership rules to an existing device or user collection in Microsoft Endpoint Configuration Manager (MECM) using CIM. It invokes the `AddMembershipRule` method on the `SMS_Collection` class via CIM.

This function is the CIM-based equivalent of the `Add-CMCollectionMembershipRule` and related cmdlets (`Add-CMDeviceCollectionDirectMembershipRule`, `Add-CMDeviceCollectionQueryMembershipRule`, `Add-CMDeviceCollectionIncludeMembershipRule`, `Add-CMDeviceCollectionExcludeMembershipRule`) from the ConfigurationManager PowerShell module, but uses direct CIM queries over WinRM instead of requiring the ConfigMgr console or PowerShell drive.

Supported rule types:

- **Direct** (`SMS_CollectionRuleDirect`) - Adds a specific resource (device/user) by ResourceId
- **Query** (`SMS_CollectionRuleQuery`) - Adds a WQL query rule that dynamically determines membership
- **Include** (`SMS_CollectionRuleIncludeCollection`) - Includes members from another collection
- **Exclude** (`SMS_CollectionRuleExcludeCollection`) - Excludes members from another collection

The function performs the following actions:

1. Validates an active connection exists (established via `Connect-CM7`)
2. Resolves the target collection (by name or ID)
3. Validates rule-type-specific parameters
4. Creates the appropriate membership rule CIM embedded instance
5. Invokes the `AddMembershipRule` WMI method on the `SMS_Collection` instance
6. Returns a result object indicating success

Key features:
- **All Rule Types**: Direct, Query, Include, and Exclude rules in a single function
- **Flexible Collection Identification**: Target collection by name or CollectionID
- **Multi-Resource Support**: Add multiple direct members in a single call via ResourceId array
- **Include/Exclude by Name or ID**: Reference include/exclude collections by name or CollectionID
- **Resource Validation**: Validates resources exist before adding direct rules
- **WhatIf/Confirm**: Full ShouldProcess support for safe operations

## PARAMETERS

### -CollectionName

Specifies the name of the collection to add the membership rule to. Mutually exclusive with `-CollectionId`.

- **Type**: String
- **Position**: 0 (first positional parameter)
- **Default**: None
- **Required**: Yes (when using ByCollectionName parameter set)
- **Parameter Set**: ByCollectionName
- **Accept pipeline input**: False
- **Accept wildcard characters**: No

Example: `"My Device Collection"` - Adds a rule to the collection with this name

### -CollectionId

Specifies the CollectionID of the collection to add the membership rule to. Mutually exclusive with `-CollectionName`.

- **Type**: String
- **Position**: Named
- **Default**: None
- **Required**: Yes (when using ByCollectionId parameter set)
- **Parameter Set**: ByCollectionId
- **Accept pipeline input**: False
- **Accept wildcard characters**: No

Example: `"CM101C04"` - Adds a rule to the collection with this ID

### -RuleType

Specifies the type of membership rule to add. Valid values are:

- `Direct` - Add a specific resource directly by ResourceId
- `Query` - Add a WQL query-based rule
- `Include` - Include members from another collection
- `Exclude` - Exclude members from another collection

- **Type**: String
- **Position**: Named
- **Default**: None
- **Required**: Yes
- **Parameter Set**: All
- **Accept pipeline input**: False
- **Valid Values**: Direct, Query, Include, Exclude

### -ResourceId

Specifies the ResourceID(s) of the resource(s) to add as direct members. Required when `-RuleType` is `Direct`. Accepts an array to add multiple resources in a single call.

- **Type**: Int32[]
- **Position**: Named
- **Default**: None
- **Required**: Yes (when RuleType is Direct)
- **Parameter Set**: All
- **Accept pipeline input**: False
- **Accept wildcard characters**: No

Examples:
- `16777220` - Add a single resource
- `16777220, 16777221` - Add multiple resources

### -RuleName

Specifies the name for the membership rule. Required for Query, Include, and Exclude rules. For Direct rules, this is optional and defaults to the resource name.

- **Type**: String
- **Position**: Named
- **Default**: Resource name (for Direct), collection name (for Include/Exclude)
- **Required**: Yes (for Query rules)
- **Parameter Set**: All
- **Accept pipeline input**: False
- **Accept wildcard characters**: No

Example: `"Test-Servers"` - Names the query rule

### -QueryExpression

Specifies the WQL query expression for the rule. Required when `-RuleType` is `Query`.

- **Type**: String
- **Position**: Named
- **Default**: None
- **Required**: Yes (when RuleType is Query)
- **Parameter Set**: All
- **Accept pipeline input**: False
- **Accept wildcard characters**: No

Example: `"select SMS_R_SYSTEM.ResourceID from SMS_R_System where SMS_R_System.Name like 'TEST-%'"`

### -IncludeCollectionId

Specifies the CollectionID of the collection to include. Required when `-RuleType` is `Include` and `-IncludeCollectionName` is not specified.

- **Type**: String
- **Position**: Named
- **Default**: None
- **Required**: Conditional (when RuleType is Include)
- **Parameter Set**: All
- **Accept pipeline input**: False
- **Accept wildcard characters**: No

Example: `"SMS00001"` - Includes members from "All Systems"

### -IncludeCollectionName

Specifies the name of the collection to include. Required when `-RuleType` is `Include` and `-IncludeCollectionId` is not specified.

- **Type**: String
- **Position**: Named
- **Default**: None
- **Required**: Conditional (when RuleType is Include)
- **Parameter Set**: All
- **Accept pipeline input**: False
- **Accept wildcard characters**: No

Example: `"All Systems"` - Includes members from "All Systems"

### -ExcludeCollectionId

Specifies the CollectionID of the collection to exclude. Required when `-RuleType` is `Exclude` and `-ExcludeCollectionName` is not specified.

- **Type**: String
- **Position**: Named
- **Default**: None
- **Required**: Conditional (when RuleType is Exclude)
- **Parameter Set**: All
- **Accept pipeline input**: False
- **Accept wildcard characters**: No

Example: `"CM101C00"` - Excludes members from the specified collection

### -ExcludeCollectionName

Specifies the name of the collection to exclude. Required when `-RuleType` is `Exclude` and `-ExcludeCollectionId` is not specified.

- **Type**: String
- **Position**: Named
- **Default**: None
- **Required**: Conditional (when RuleType is Exclude)
- **Parameter Set**: All
- **Accept pipeline input**: False
- **Accept wildcard characters**: No

Example: `"Test-Collection-Direct"` - Excludes members from the named collection

### -WhatIf

Shows what would happen if the cmdlet runs. The cmdlet is not run.

- **Type**: SwitchParameter
- **Position**: Named
- **Default**: False
- **Required**: No

### -Confirm

Prompts you for confirmation before running the cmdlet.

- **Type**: SwitchParameter
- **Position**: Named
- **Default**: False (ConfirmImpact is Medium)
- **Required**: No

## EXAMPLES

### Example 1: Add a direct membership rule

```powershell
Add-CM7CollectionMembershipRule -CollectionName "My Collection" -RuleType Direct -ResourceId 16777220
```

Adds device with ResourceID 16777220 as a direct member of "My Collection".

### Example 2: Add multiple direct membership rules

```powershell
Add-CM7CollectionMembershipRule -CollectionId "CM101C04" -RuleType Direct -ResourceId 16777220, 16777221
```

Adds two devices as direct members of the collection using CollectionID.

### Example 3: Add a query membership rule

```powershell
Add-CM7CollectionMembershipRule -CollectionName "My Collection" -RuleType Query -RuleName "Test Servers" -QueryExpression "select SMS_R_SYSTEM.ResourceID from SMS_R_System where SMS_R_System.Name like 'TEST-%'"
```

Adds a query rule that dynamically includes all devices matching the name pattern `TEST-%`.

### Example 4: Add an include collection rule by ID

```powershell
Add-CM7CollectionMembershipRule -CollectionName "My Collection" -RuleType Include -IncludeCollectionId "SMS00001"
```

Adds an include rule that includes all members of "All Systems" in "My Collection".

### Example 5: Add an include collection rule by name

```powershell
Add-CM7CollectionMembershipRule -CollectionName "My Collection" -RuleType Include -IncludeCollectionName "All Systems"
```

Adds an include rule by referencing the include collection by name.

### Example 6: Add an exclude collection rule

```powershell
Add-CM7CollectionMembershipRule -CollectionName "My Collection" -RuleType Exclude -ExcludeCollectionId "CM101C00"
```

Adds an exclude rule that excludes all members of the specified collection.

### Example 7: Add an exclude collection rule by name

```powershell
Add-CM7CollectionMembershipRule -CollectionName "My Collection" -RuleType Exclude -ExcludeCollectionName "Test-Collection-Direct"
```

Adds an exclude rule by referencing the exclude collection by name.

### Example 8: WhatIf support

```powershell
Add-CM7CollectionMembershipRule -CollectionName "My Collection" -RuleType Query -RuleName "Test" -QueryExpression "select * from SMS_R_System" -WhatIf
```

Shows what would happen without actually adding the rule.

## OUTPUT

Returns a `MECM7.CollectionMembershipRuleResult` object with the following properties:

| Property | Type | Description |
|----------|------|-------------|
| CollectionId | String | The CollectionID of the target collection |
| CollectionName | String | The name of the target collection |
| RuleType | String | The type of rule added (Direct, Query, Include, Exclude) |
| RuleName | String | The name of the rule |
| ResourceId | Int32 | The ResourceID (Direct rules only) |
| ResourceName | String | The resource name (Direct rules only) |
| QueryExpression | String | The WQL query expression (Query rules only) |
| IncludeCollectionId | String | The included CollectionID (Include rules only) |
| IncludeCollectionName | String | The included collection name (Include rules only) |
| ExcludeCollectionId | String | The excluded CollectionID (Exclude rules only) |
| ExcludeCollectionName | String | The excluded collection name (Exclude rules only) |
| Status | String | The result status ('Added') |

## NOTES

- Requires an active CIM session established via `Connect-CM7`
- Uses the `SMS_Collection.AddMembershipRule` WMI method via CIM
- Direct rules use `SMS_CollectionRuleDirect` embedded instances
- Query rules use `SMS_CollectionRuleQuery` embedded instances
- Include rules use `SMS_CollectionRuleIncludeCollection` embedded instances
- Exclude rules use `SMS_CollectionRuleExcludeCollection` embedded instances
- Resources are validated before adding direct membership rules
- Non-existent resources produce a warning and are skipped (not thrown as errors)

## RELATED LINKS

- [Get-CM7CollectionDirectMembershipRule](./Get-CM7CollectionDirectMembership.md)
- [Get-CM7CollectionQueryMembershipRule](./Get-CM7CollectionQueryMembershipRule.md)
- [Get-CM7CollectionIncludeMembershipRule](./Get-CM7CollectionIncludeMembershipRule.md)
- [Get-CM7CollectionExcludeMembershipRule](./Get-CM7CollectionExcludeMembershipRule.md)
- [New-CM7Collection](./New-CM7Collection.md)
- [Remove-CM7Collection](./Remove-CM7Collection.md)
- [Get-CM7Collection](./Get-CM7Collection.md)
- [Connect-CM7](./Connect-CM7.md)
