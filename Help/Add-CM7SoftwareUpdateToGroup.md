# Add-CM7SoftwareUpdateToGroup

## SYNOPSIS

Adds one or more software updates to a software update group in Microsoft Endpoint Configuration Manager (MECM) using CIM.

## DESCRIPTION

The `Add-CM7SoftwareUpdateToGroup` function adds software updates to an existing software update group (SMS_AuthorizationList) in MECM using CIM. Software updates can be specified by CI_ID, Article ID (KB number), name, or by passing software update objects retrieved from `Get-CM7SoftwareUpdate`.

This function is the CIM-based equivalent of the `Add-CMSoftwareUpdateToGroup` cmdlet from the ConfigurationManager PowerShell module, but uses direct CIM queries over WinRM instead of requiring the ConfigMgr console or PowerShell drive.

The function performs the following actions:

1. Validates an active connection exists (established via `Connect-CM7`)
2. Resolves the target software update group by name, CI_ID, or input object
3. Resolves the software updates to add by CI_ID, Article ID, name, or input object
4. Merges the new update CI_IDs with the existing group's Updates array (skipping duplicates)
5. Saves the updated group via CIM
6. Returns the updated software update group as a formatted `MECM7.SoftwareUpdateGroup` object

Key features:
- **Multiple Group Selection**: Specify the target group by name, CI_ID, or pipeline object
- **Multiple Update Selection**: Specify updates by CI_ID, Article ID, name wildcard, or software update objects
- **Duplicate Prevention**: Automatically skips updates that are already in the group
- **Pipeline Support**: Accepts software update group objects from the pipeline
- **WhatIf/Confirm**: Full ShouldProcess support for safe operations
- **Force**: Suppress confirmation prompts for automation scenarios

## PARAMETERS

### -SoftwareUpdateGroupName

Specifies the name (LocalizedDisplayName) of the software update group to add updates to. Mutually exclusive with `-SoftwareUpdateGroupId` and `-SoftwareUpdateGroup`.

- **Type**: String
- **Position**: Named
- **Default**: None
- **Required**: Yes (in ByGroupName* parameter sets)
- **Accept pipeline input**: False
- **Accept wildcard characters**: No

Examples:
- `"Test-SUG"` - Target a specific software update group
- `"SO Servers-SecurityPatches-2026-02"` - Target a descriptive named group

### -SoftwareUpdateGroupId

Specifies the CI_ID (integer) of the software update group to add updates to. Mutually exclusive with `-SoftwareUpdateGroupName` and `-SoftwareUpdateGroup`.

- **Type**: Int32
- **Position**: Named
- **Default**: None
- **Required**: Yes (in ByGroupId* parameter sets)
- **Accept pipeline input**: False
- **Accept wildcard characters**: No

### -SoftwareUpdateGroup

Specifies a software update group object (as returned by `Get-CM7SoftwareUpdateGroup`) to add updates to. Accepts pipeline input. Mutually exclusive with `-SoftwareUpdateGroupName` and `-SoftwareUpdateGroupId`.

- **Type**: PSObject
- **Position**: Named
- **Default**: None
- **Required**: Yes (in ByGroupObject* parameter sets)
- **Accept pipeline input**: Yes (ByValue)
- **Accept wildcard characters**: No

### -SoftwareUpdate

Specifies one or more software update objects (as returned by `Get-CM7SoftwareUpdate`) to add to the group. The CI_ID property is extracted from each object. Mutually exclusive with `-UpdateId`, `-ArticleId`, and `-SoftwareUpdateName`.

- **Type**: PSObject[]
- **Position**: Named
- **Default**: None
- **Required**: Yes (in *AndSoftwareUpdate parameter sets)
- **Accept pipeline input**: False
- **Accept wildcard characters**: No

### -UpdateId

Specifies an array of software update CI_IDs (integers) to add to the group. Mutually exclusive with `-SoftwareUpdate`, `-ArticleId`, and `-SoftwareUpdateName`.

- **Type**: Int32[]
- **Position**: Named
- **Default**: None
- **Required**: Yes (in *AndUpdateId parameter sets)
- **Accept pipeline input**: False
- **Accept wildcard characters**: No

Example: `@(16788010, 16788011, 16788012)`

### -ArticleId

Specifies an array of software update Article IDs (KB numbers) to add to the group. The function resolves these to CI_IDs by querying SMS_SoftwareUpdate. If an Article ID is not found, a warning is issued and it is skipped. Mutually exclusive with `-SoftwareUpdate`, `-UpdateId`, and `-SoftwareUpdateName`.

- **Type**: String[]
- **Position**: Named
- **Default**: None
- **Required**: Yes (in *AndArticleId parameter sets)
- **Accept pipeline input**: False
- **Accept wildcard characters**: No

Example: `@("4038779", "5041578")`

### -SoftwareUpdateName

Specifies the name (LocalizedDisplayName) of the software update(s) to add. Supports wildcard characters (* and ?). The function resolves the name to CI_IDs by querying SMS_SoftwareUpdate. Mutually exclusive with `-SoftwareUpdate`, `-UpdateId`, and `-ArticleId`.

- **Type**: String
- **Position**: Named
- **Default**: None
- **Required**: Yes (in *AndSoftwareUpdateName parameter sets)
- **Accept pipeline input**: False
- **Accept wildcard characters**: Yes

### -Force

Suppresses confirmation prompts. Use this for automation scenarios.

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
- **Default**: False
- **Required**: No

## EXAMPLES

### EXAMPLE 1: Add a software update by Article ID

```powershell
Add-CM7SoftwareUpdateToGroup -SoftwareUpdateGroupName "Test-SUG" -ArticleId @("4038779") -Force
```

Adds the software update(s) matching Article ID 4038779 to the "Test-SUG" software update group.

### EXAMPLE 2: Add a software update object (like Add-CMSoftwareUpdateToGroup)

```powershell
$SU = Get-CM7SoftwareUpdate -ArticleId "4038779"
Add-CM7SoftwareUpdateToGroup -SoftwareUpdateGroupName "Test-SUG" -SoftwareUpdate $SU -Force
```

Retrieves a software update object and adds it to the group. This mirrors the native `Add-CMSoftwareUpdateToGroup` workflow.

### EXAMPLE 3: Add a software update by CI_ID

```powershell
Add-CM7SoftwareUpdateToGroup -SoftwareUpdateGroupName "Test-SUG" -UpdateId @(16788010, 16788011) -Force
```

Adds software updates by their CI_ID values to the specified software update group.

### EXAMPLE 4: Add updates matching a name pattern

```powershell
Add-CM7SoftwareUpdateToGroup -SoftwareUpdateGroupName "SO Servers-SecurityPatches-2026-02" -SoftwareUpdateName "*Cumulative*" -Force
```

Adds all software updates whose names contain "Cumulative" to the specified group.

### EXAMPLE 5: Use pipeline to specify the group

```powershell
Get-CM7SoftwareUpdateGroup -Name "Test-SUG" | Add-CM7SoftwareUpdateToGroup -ArticleId @("4038779") -Force
```

Pipes a software update group object and adds updates to it by Article ID.

### EXAMPLE 6: Add updates to a group specified by CI_ID

```powershell
Add-CM7SoftwareUpdateToGroup -SoftwareUpdateGroupId 17164572 -ArticleId @("4038779", "5041578") -Force
```

Adds software updates by Article ID to a group specified by its CI_ID.

### EXAMPLE 7: Preview changes with WhatIf

```powershell
Add-CM7SoftwareUpdateToGroup -SoftwareUpdateGroupName "Test-SUG" -UpdateId @(16788010) -WhatIf
```

Shows what would happen without actually modifying the software update group.

### EXAMPLE 8: Add multiple updates from query results

```powershell
$updates = Get-CM7SoftwareUpdate -Severity Critical -IsSuperseded $false
Add-CM7SoftwareUpdateToGroup -SoftwareUpdateGroupName "Critical-Patches-Feb-2026" -SoftwareUpdate $updates -Force
```

Queries for all current critical software updates and adds them to a group.

### EXAMPLE 9: Add updates with verbose output

```powershell
Add-CM7SoftwareUpdateToGroup -SoftwareUpdateGroupName "Test-SUG" -ArticleId @("4038779") -Force -Verbose
```

Adds updates with verbose output showing WQL queries, resolved CI_IDs, and operation details.

### EXAMPLE 10: Clone updates from one group to another

```powershell
$sourceGroup = Get-CM7SoftwareUpdateGroup -Name "SO Servers-SecurityPatches-2025-12"
Add-CM7SoftwareUpdateToGroup -SoftwareUpdateGroupName "SO Servers-SecurityPatches-2026-01" -UpdateId $sourceGroup.Updates -Force
```

Copies all software updates from one group into another. Duplicates are automatically skipped.

## OUTPUTS

### MECM7.SoftwareUpdateGroup

The function returns a custom object of type `MECM7.SoftwareUpdateGroup` with the following properties:

| Property | Type | Description |
|----------|------|-------------|
| CI_ID | int | Unique configuration item identifier |
| CI_UniqueID | string | Globally unique identifier for the configuration item |
| LocalizedDisplayName | string | Display name of the software update group |
| LocalizedDescription | string | Description of the software update group |
| IsDeployed | bool | Whether the group is currently deployed |
| IsExpired | bool | Whether the group contains expired updates |
| IsSuperseded | bool | Whether the group contains superseded updates |
| NumberOfUpdates | int | Number of software updates in the group |
| DateCreated | datetime | Date/time the group was created |
| DateLastModified | datetime | Date/time the group was last modified |
| LocalizedCategoryInstanceNames | string[] | Category names associated with the group |

All additional WMI properties from the `SMS_AuthorizationList` class are also included.

**Note**: If all specified updates are already members of the group, no changes are made and `$null` is returned.

## REQUIREMENTS

- An active MECM/SCCM connection established via `Connect-CM7`
- PowerShell 5.1 or higher
- Access to the MECM SMS Provider via WinRM
- Sufficient MECM permissions to modify software update groups

## NOTES

- The function modifies software update groups using the `SMS_AuthorizationList` WMI class directly via CIM sessions.
- Updates that are already in the group are automatically skipped — no duplicates are added.
- When using `-ArticleId`, the function queries `SMS_SoftwareUpdate` to resolve Article IDs to CI_IDs. If an Article ID matches multiple updates (e.g., different architectures), all matching updates are included.
- When using `-SoftwareUpdateName`, wildcard characters (* and ?) are supported for matching multiple updates.
- The `-SoftwareUpdate` parameter accepts objects from `Get-CM7SoftwareUpdate`, extracting the CI_ID from each object.
- The `PSTypeName` is automatically set to `MECM7.SoftwareUpdateGroup` for improved formatting and type safety.
- The returned object is identical in structure to objects returned by `Get-CM7SoftwareUpdateGroup`.

### Comparison with Native Cmdlet

| Feature | Add-CMSoftwareUpdateToGroup | Add-CM7SoftwareUpdateToGroup |
|---------|---------------------------|------------------------------|
| Requires ConfigMgr Console | Yes | No |
| Connection Method | PSDrive | CIM/WinRM |
| PowerShell 7 Support | Limited | Full |
| Remote Management | Local only | Remote via WinRM |
| Update by CI_ID | Yes | Yes |
| Update by Article ID | No | Yes |
| Update by Name | No | Yes (with wildcards) |
| Update by Object | Yes | Yes |
| Group by Pipeline | Yes | Yes |
| Duplicate Prevention | Yes | Yes |
| WhatIf Support | Yes | Yes |
| Returns | SMS objects | PSCustomObject |

### Error Handling

| Error | Cause | Resolution |
|-------|-------|------------|
| "Not connected to MECM" | No active CIM connection | Run `Connect-CM7` first |
| "not found" | Software update group name or ID does not exist | Verify the group name/ID |
| "Multiple software update groups found" | Duplicate group names | Use `-SoftwareUpdateGroupId` instead |
| "No software update found for Article ID" | Invalid KB number | Verify the Article ID exists in MECM |
| "No software updates to add" | All updates could not be resolved | Verify the update identifiers |
| Access denied | Insufficient permissions | Ensure MECM permissions to modify SMS_AuthorizationList |

## RELATED LINKS

- [Connect-CM7](./Connect-CM7.md) - Establish connection to MECM
- [Get-CM7SoftwareUpdateGroup](./Get-CM7SoftwareUpdateGroup.md) - Retrieve software update group information
- [New-CM7SoftwareUpdateGroup](./New-CM7SoftwareUpdateGroup.md) - Create a new software update group
- [Get-CM7SoftwareUpdate](./Get-CM7SoftwareUpdate.md) - Retrieve software update information
- [Get-CM7SoftwareUpdateDeployment](./Get-CM7SoftwareUpdateDeployment.md) - Retrieve software update deployments
- [Get-CM7SoftwareUpdateDeploymentPackage](./Get-CM7SoftwareUpdateDeploymentPackage.md) - Retrieve software update deployment packages

## SEE ALSO

- `Add-CMSoftwareUpdateToGroup` - Native ConfigurationManager module equivalent
- `Set-CimInstance` - PowerShell CIM cmdlet for modifying WMI instances
- [SMS_AuthorizationList WMI Class](https://learn.microsoft.com/en-us/mem/configmgr/develop/reference/sum/sms_authorizationlist-server-wmi-class)
