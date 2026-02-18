# Remove-CM7CollectionMembershipRule

## SYNOPSIS

Removes a membership rule from a MECM collection using CIM.

## DESCRIPTION

The `Remove-CM7CollectionMembershipRule` function removes one or more membership rules from an existing device or user collection in Microsoft Endpoint Configuration Manager (MECM) using CIM. It invokes the `DeleteMembershipRule` method on the `SMS_Collection` class via CIM.

This function is the CIM-based equivalent of the `Remove-CMCollectionMembershipRule` and related cmdlets (`Remove-CMDeviceCollectionDirectMembershipRule`, `Remove-CMDeviceCollectionQueryMembershipRule`, `Remove-CMDeviceCollectionIncludeMembershipRule`, `Remove-CMDeviceCollectionExcludeMembershipRule`) from the ConfigurationManager PowerShell module, but uses direct CIM queries over WinRM instead of requiring the ConfigMgr console or PowerShell drive.

Supported rule types:

- **Direct** (`SMS_CollectionRuleDirect`) - Removes a specific resource (device/user) by ResourceId or ResourceName
- **Query** (`SMS_CollectionRuleQuery`) - Removes a WQL query rule by RuleName
- **Include** (`SMS_CollectionRuleIncludeCollection`) - Removes an include collection rule
- **Exclude** (`SMS_CollectionRuleExcludeCollection`) - Removes an exclude collection rule

The function performs the following actions:

1. Validates an active connection exists (established via `Connect-CM7`)
2. Resolves the target collection (by name or ID)
3. Retrieves existing membership rules of the specified type
4. Matches the rule(s) to remove based on the provided parameters
5. Invokes the `DeleteMembershipRule` WMI method on the `SMS_Collection` instance
6. Returns a result object indicating success

Key features:
- **All Rule Types**: Direct, Query, Include, and Exclude rules in a single function
- **Flexible Collection Identification**: Target collection by name or CollectionID
- **Multi-Resource Support**: Remove multiple direct members in a single call via ResourceId array
- **Wildcard Support**: Remove rules by wildcard pattern (ResourceName, RuleName)
- **Include/Exclude by Name or ID**: Reference include/exclude collections by name or CollectionID
- **Force Parameter**: Suppress confirmation prompts for scripted/automated scenarios
- **WhatIf/Confirm**: Full ShouldProcess support for safe operations

## PARAMETERS

### -CollectionName

Specifies the name of the collection to remove the membership rule from. Mutually exclusive with `-CollectionId`.

- **Type**: String
- **Position**: 0 (first positional parameter)
- **Default**: None
- **Required**: Yes (when using ByCollectionName parameter set)
- **Parameter Set**: ByCollectionName
- **Accept pipeline input**: False
- **Accept wildcard characters**: No

Example: `"My Device Collection"` - Removes a rule from the collection with this name

### -CollectionId

Specifies the CollectionID of the collection to remove the membership rule from. Mutually exclusive with `-CollectionName`.

- **Type**: String
- **Position**: Named
- **Default**: None
- **Required**: Yes (when using ByCollectionId parameter set)
- **Parameter Set**: ByCollectionId
- **Accept pipeline input**: False
- **Accept wildcard characters**: No

Example: `"CM101C04"` - Removes a rule from the collection with this ID

### -RuleType

Specifies the type of membership rule to remove. Valid values are:

- `Direct` - Remove a specific resource directly by ResourceId or ResourceName
- `Query` - Remove a WQL query-based rule by RuleName
- `Include` - Remove an include collection rule
- `Exclude` - Remove an exclude collection rule

- **Type**: String
- **Position**: Named
- **Default**: None
- **Required**: Yes
- **Parameter Set**: All
- **Accept pipeline input**: False
- **Valid Values**: Direct, Query, Include, Exclude

### -ResourceId

Specifies the ResourceID(s) of the resource(s) to remove as direct members. Required when `-RuleType` is `Direct` and `-ResourceName` is not specified. Accepts an array to remove multiple resources in a single call.

- **Type**: Int32[]
- **Position**: Named
- **Default**: None
- **Required**: Conditional (when RuleType is Direct and ResourceName is not specified)
- **Parameter Set**: All
- **Accept pipeline input**: False
- **Accept wildcard characters**: No

Examples:
- `16777220` - Remove a single resource
- `16777220, 16777221` - Remove multiple resources

### -ResourceName

Specifies the name of the resource to remove as a direct member. Required when `-RuleType` is `Direct` and `-ResourceId` is not specified. Supports wildcard characters (`*`, `?`) for batch removal.

- **Type**: String
- **Position**: Named
- **Default**: None
- **Required**: Conditional (when RuleType is Direct and ResourceId is not specified)
- **Parameter Set**: All
- **Accept pipeline input**: False
- **Accept wildcard characters**: Yes

Examples:
- `"TEST-2016-1"` - Remove a specific resource by name
- `"TEST-*"` - Remove all resources matching the pattern

### -RuleName

Specifies the name of the query rule to remove. Required when `-RuleType` is `Query`. Supports wildcard characters (`*`, `?`) for batch removal.

- **Type**: String
- **Position**: Named
- **Default**: None
- **Required**: Yes (when RuleType is Query)
- **Parameter Set**: All
- **Accept pipeline input**: False
- **Accept wildcard characters**: Yes

Examples:
- `"Test-Servers"` - Remove a specific query rule
- `"*Server*"` - Remove all query rules matching the pattern

### -IncludeCollectionId

Specifies the CollectionID of the include collection rule to remove. Required when `-RuleType` is `Include` and `-IncludeCollectionName` is not specified.

- **Type**: String
- **Position**: Named
- **Default**: None
- **Required**: Conditional (when RuleType is Include)
- **Parameter Set**: All
- **Accept pipeline input**: False
- **Accept wildcard characters**: No

Example: `"SMS00001"` - Removes the include rule referencing "All Systems"

### -IncludeCollectionName

Specifies the name of the include collection rule to remove. Required when `-RuleType` is `Include` and `-IncludeCollectionId` is not specified.

- **Type**: String
- **Position**: Named
- **Default**: None
- **Required**: Conditional (when RuleType is Include)
- **Parameter Set**: All
- **Accept pipeline input**: False
- **Accept wildcard characters**: No

Example: `"All Systems"` - Removes the include rule referencing "All Systems"

### -ExcludeCollectionId

Specifies the CollectionID of the exclude collection rule to remove. Required when `-RuleType` is `Exclude` and `-ExcludeCollectionName` is not specified.

- **Type**: String
- **Position**: Named
- **Default**: None
- **Required**: Conditional (when RuleType is Exclude)
- **Parameter Set**: All
- **Accept pipeline input**: False
- **Accept wildcard characters**: No

Example: `"CM101C00"` - Removes the exclude rule referencing the specified collection

### -ExcludeCollectionName

Specifies the name of the exclude collection rule to remove. Required when `-RuleType` is `Exclude` and `-ExcludeCollectionId` is not specified.

- **Type**: String
- **Position**: Named
- **Default**: None
- **Required**: Conditional (when RuleType is Exclude)
- **Parameter Set**: All
- **Accept pipeline input**: False
- **Accept wildcard characters**: No

Example: `"Test-Collection-Direct"` - Removes the exclude rule referencing the named collection

### -Force

Suppresses confirmation prompts and removes the rule without asking. By default, the function prompts for confirmation before deletion (ConfirmImpact is High).

- **Type**: SwitchParameter
- **Position**: Named
- **Default**: False
- **Required**: No

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
- **Default**: False (ConfirmImpact is High)
- **Required**: No

## EXAMPLES

### Example 1: Remove a direct membership rule by ResourceId

```powershell
Remove-CM7CollectionMembershipRule -CollectionName "My Collection" -RuleType Direct -ResourceId 16777220 -Force
```

Removes device with ResourceID 16777220 from the direct membership rules of "My Collection".

### Example 2: Remove multiple direct membership rules

```powershell
Remove-CM7CollectionMembershipRule -CollectionId "CM101C04" -RuleType Direct -ResourceId 16777220, 16777221 -Force
```

Removes two devices from the direct membership rules of the collection using CollectionID.

### Example 3: Remove a direct membership rule by ResourceName

```powershell
Remove-CM7CollectionMembershipRule -CollectionName "My Collection" -RuleType Direct -ResourceName "TEST-2016-1" -Force
```

Removes the named resource from the direct membership rules.

### Example 4: Remove direct membership rules by wildcard

```powershell
Remove-CM7CollectionMembershipRule -CollectionName "My Collection" -RuleType Direct -ResourceName "TEST-*" -Force
```

Removes all direct membership rules matching the wildcard pattern `TEST-*`.

### Example 5: Remove a query membership rule

```powershell
Remove-CM7CollectionMembershipRule -CollectionName "My Collection" -RuleType Query -RuleName "Test Servers" -Force
```

Removes the query rule named "Test Servers" from "My Collection".

### Example 6: Remove query rules by wildcard

```powershell
Remove-CM7CollectionMembershipRule -CollectionName "My Collection" -RuleType Query -RuleName "*Server*" -Force
```

Removes all query rules matching the wildcard pattern.

### Example 7: Remove an include collection rule by ID

```powershell
Remove-CM7CollectionMembershipRule -CollectionName "My Collection" -RuleType Include -IncludeCollectionId "SMS00001" -Force
```

Removes the include rule that references "All Systems".

### Example 8: Remove an include collection rule by name

```powershell
Remove-CM7CollectionMembershipRule -CollectionName "My Collection" -RuleType Include -IncludeCollectionName "All Systems" -Force
```

Removes the include rule by referencing the include collection by name.

### Example 9: Remove an exclude collection rule

```powershell
Remove-CM7CollectionMembershipRule -CollectionName "My Collection" -RuleType Exclude -ExcludeCollectionId "CM101C00" -Force
```

Removes the exclude rule that references the specified collection.

### Example 10: Remove an exclude collection rule by name

```powershell
Remove-CM7CollectionMembershipRule -CollectionName "My Collection" -RuleType Exclude -ExcludeCollectionName "Test-Collection-Direct" -Force
```

Removes the exclude rule by referencing the exclude collection by name.

### Example 11: WhatIf support

```powershell
Remove-CM7CollectionMembershipRule -CollectionName "My Collection" -RuleType Direct -ResourceId 16777220 -WhatIf
```

Shows what would happen without actually removing the rule.

## OUTPUT

Returns a `MECM7.CollectionMembershipRuleResult` object with the following properties:

| Property | Type | Description |
|----------|------|-------------|
| CollectionId | String | The CollectionID of the target collection |
| CollectionName | String | The name of the target collection |
| RuleType | String | The type of rule removed (Direct, Query, Include, Exclude) |
| RuleName | String | The name of the rule |
| ResourceId | Int32 | The ResourceID (Direct rules only) |
| ResourceName | String | The resource name (Direct rules only) |
| QueryExpression | String | The WQL query expression (Query rules only) |
| IncludeCollectionId | String | The included CollectionID (Include rules only) |
| IncludeCollectionName | String | The included collection name (Include rules only) |
| ExcludeCollectionId | String | The excluded CollectionID (Exclude rules only) |
| ExcludeCollectionName | String | The excluded collection name (Exclude rules only) |
| Status | String | The result status ('Removed') |

## NOTES

- Requires an active CIM session established via `Connect-CM7`
- Uses the `SMS_Collection.DeleteMembershipRule` WMI method via CIM
- Direct rules use `SMS_CollectionRuleDirect` embedded instances
- Query rules use `SMS_CollectionRuleQuery` embedded instances
- Include rules use `SMS_CollectionRuleIncludeCollection` embedded instances
- Exclude rules use `SMS_CollectionRuleExcludeCollection` embedded instances
- Existing rules are first retrieved and matched before deletion
- Non-matching rules produce a warning and are skipped (not thrown as errors)
- Supports wildcard patterns for ResourceName and RuleName to enable batch removal
- ConfirmImpact is set to High; use `-Force` to suppress confirmation in scripts

## RELATED LINKS

- [Add-CM7CollectionMembershipRule](./Add-CM7CollectionMembershipRule.md)
- [Get-CM7CollectionDirectMembershipRule](./Get-CM7CollectionDirectMembership.md)
- [Get-CM7CollectionQueryMembershipRule](./Get-CM7CollectionQueryMembershipRule.md)
- [Get-CM7CollectionIncludeMembershipRule](./Get-CM7CollectionIncludeMembershipRule.md)
- [Get-CM7CollectionExcludeMembershipRule](./Get-CM7CollectionExcludeMembershipRule.md)
- [New-CM7Collection](./New-CM7Collection.md)
- [Remove-CM7Collection](./Remove-CM7Collection.md)
- [Get-CM7Collection](./Get-CM7Collection.md)
- [Connect-CM7](./Connect-CM7.md)
