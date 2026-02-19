# New-CM7SoftwareUpdateGroup

## SYNOPSIS

Creates a new software update group in Microsoft Endpoint Configuration Manager (MECM) using CIM.

## DESCRIPTION

The `New-CM7SoftwareUpdateGroup` function creates a new software update group (SMS_AuthorizationList) in MECM using CIM. A software update group is a container for software updates that can be deployed to collections.

This function is the CIM-based equivalent of the `New-CMSoftwareUpdateGroup` cmdlet from the ConfigurationManager PowerShell module, but uses direct CIM queries over WinRM instead of requiring the ConfigMgr console or PowerShell drive.

The function performs the following actions:

1. Validates an active connection exists (established via `Connect-CM7`)
2. Checks for duplicate software update group names
3. Optionally resolves software update CI_IDs from Article IDs
4. Creates a new `SMS_AuthorizationList` instance via CIM with the specified properties
5. Returns the created software update group as a formatted `MECM7.SoftwareUpdateGroup` object

Key features:
- **Empty or Pre-populated Groups**: Create empty groups or include updates at creation time
- **Multiple Update Selection**: Specify updates by CI_ID, SoftwareUpdateId, or Article ID (KB number)
- **Duplicate Detection**: Prevents creation of groups with existing names
- **WhatIf/Confirm**: Full ShouldProcess support for safe operations
- **Force**: Suppress confirmation prompts for automation scenarios

## PARAMETERS

### -Name

Specifies the name of the new software update group (LocalizedDisplayName). Must be unique within the MECM environment.

- **Type**: String
- **Position**: 0 (first positional parameter)
- **Default**: None
- **Required**: Yes
- **Parameter Set**: All
- **Accept pipeline input**: False
- **Accept wildcard characters**: No

Examples:
- `"SO Servers-SecurityPatches-2026-02"` - Descriptive name for patching
- `"Monthly Cumulative Updates"` - Group for monthly updates

### -Description

Specifies an optional description for the software update group (LocalizedDescription). This text appears in the MECM console.

- **Type**: String
- **Position**: Named
- **Default**: Empty string
- **Required**: No
- **Parameter Set**: All
- **Accept pipeline input**: False
- **Accept wildcard characters**: No

### -UpdateId

Specifies an array of software update CI_IDs (integers) to include in the group. These correspond to the CI_ID property of SMS_SoftwareUpdate instances.
Mutually exclusive with `-SoftwareUpdateId` and `-ArticleId`.

- **Type**: Int32[]
- **Position**: Named
- **Default**: None (empty group)
- **Required**: No
- **Parameter Set**: ByUpdateId
- **Accept pipeline input**: False
- **Accept wildcard characters**: No

Example: `@(16788010, 16788011, 16788012)`

### -SoftwareUpdateId

Alias for `-UpdateId`. Specifies an array of software update CI_IDs (integers) to include in the group. Provided for compatibility with `New-CMSoftwareUpdateGroup` syntax.
Mutually exclusive with `-UpdateId` and `-ArticleId`.

- **Type**: Int32[]
- **Position**: Named
- **Default**: None (empty group)
- **Required**: No
- **Parameter Set**: BySoftwareUpdateId
- **Accept pipeline input**: False
- **Accept wildcard characters**: No
- **Alias**: SoftwareUpdateId

### -ArticleId

Specifies an array of software update Article IDs (KB numbers) to include in the group. The function resolves these to CI_IDs by querying SMS_SoftwareUpdate. If an Article ID is not found, a warning is issued and it is skipped.
Mutually exclusive with `-UpdateId` and `-SoftwareUpdateId`.

- **Type**: String[]
- **Position**: Named
- **Default**: None (empty group)
- **Required**: No
- **Parameter Set**: ByArticleId
- **Accept pipeline input**: False
- **Accept wildcard characters**: No

Example: `@("5041578", "5041580")`

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

### EXAMPLE 1: Create an empty software update group

```powershell
New-CM7SoftwareUpdateGroup -Name "SO Servers-SecurityPatches-2026-02" -Force
```

Creates a new empty software update group. Updates can be added later.

### EXAMPLE 2: Create a software update group with a description

```powershell
New-CM7SoftwareUpdateGroup -Name "SO Servers-SecurityPatches-2026-02" -Description "Security patches for servers - February 2026" -Force
```

Creates a new software update group with a descriptive text.

### EXAMPLE 3: Create a software update group with updates by CI_ID

```powershell
New-CM7SoftwareUpdateGroup -Name "Patching-2026-02" -UpdateId @(16788010, 16788011) -Force
```

Creates a software update group pre-populated with the specified software updates.

### EXAMPLE 4: Create a software update group with updates by Article ID

```powershell
New-CM7SoftwareUpdateGroup -Name "KB Patches" -ArticleId @("5041578", "5041580") -Force
```

Creates a software update group with updates resolved from KB Article IDs.

### EXAMPLE 5: Create a software update group from Get-CM7SoftwareUpdate results

```powershell
$updates = Get-CM7SoftwareUpdate -Name "*Cumulative*" | Select-Object -ExpandProperty CI_ID
New-CM7SoftwareUpdateGroup -Name "Cumulative Updates - Feb 2026" -UpdateId $updates -Force
```

Queries for software updates matching a pattern and creates a group containing them.

### EXAMPLE 6: Preview group creation with WhatIf

```powershell
New-CM7SoftwareUpdateGroup -Name "Test Group" -WhatIf
```

Shows what would happen without actually creating the software update group.

### EXAMPLE 7: Create a group and inspect the result

```powershell
$newGroup = New-CM7SoftwareUpdateGroup -Name "Monthly Patches" -Description "Monthly security patches" -Force
Write-Host "Created: $($newGroup.LocalizedDisplayName) (CI_ID: $($newGroup.CI_ID))"
```

Creates a software update group and captures the result for further processing.

### EXAMPLE 8: Create a group using SoftwareUpdateId alias

```powershell
New-CM7SoftwareUpdateGroup -Name "Compatibility Group" -SoftwareUpdateId @(16788010) -Force
```

Uses the `-SoftwareUpdateId` alias (compatible with `New-CMSoftwareUpdateGroup` parameter naming).

### EXAMPLE 9: Create a group with verbose output

```powershell
New-CM7SoftwareUpdateGroup -Name "Verbose Test" -Force -Verbose
```

Creates a software update group with verbose output showing the WQL queries and operations being performed.

### EXAMPLE 10: Create a group from an existing group's updates

```powershell
$sourceGroup = Get-CM7SoftwareUpdateGroup -Name "SO Servers-SecurityPatches-2025-12"
$newGroup = New-CM7SoftwareUpdateGroup -Name "SO Servers-SecurityPatches-2026-01" -UpdateId $sourceGroup.Updates -Description "Cloned from 2025-12" -Force
```

Clones the update list from an existing software update group into a new one.

## OUTPUTS

### MECM7.SoftwareUpdateGroup

The function returns a custom object of type `MECM7.SoftwareUpdateGroup` with the following properties:

| Property | Type | Description |
|----------|------|-------------|
| CI_ID | int | Unique configuration item identifier |
| CI_UniqueID | string | Globally unique identifier for the configuration item |
| LocalizedDisplayName | string | Display name of the software update group |
| LocalizedDescription | string | Description of the software update group |
| IsDeployed | bool | Whether the group is currently deployed (False for new groups) |
| IsExpired | bool | Whether the group contains expired updates |
| IsSuperseded | bool | Whether the group contains superseded updates |
| NumberOfUpdates | int | Number of software updates in the group |
| DateCreated | datetime | Date/time the group was created |
| DateLastModified | datetime | Date/time the group was last modified |
| LocalizedCategoryInstanceNames | string[] | Category names associated with the group |

All additional WMI properties from the `SMS_AuthorizationList` class are also included.

## REQUIREMENTS

- An active MECM/SCCM connection established via `Connect-CM7`
- PowerShell 5.1 or higher
- Access to the MECM SMS Provider via WinRM
- Sufficient MECM permissions to create software update groups

## NOTES

- The function creates software update groups using the `SMS_AuthorizationList` WMI class directly via CIM sessions.
- The function checks for duplicate group names before creation and throws an error if one exists.
- When using `-ArticleId`, the function queries `SMS_SoftwareUpdate` to resolve Article IDs to CI_IDs. If an Article ID matches multiple updates (e.g., different architectures), all matching updates are included.
- An empty software update group (no updates) is valid and can have updates added later through the MECM console or by modifying the `Updates` property.
- The `PSTypeName` is automatically set to `MECM7.SoftwareUpdateGroup` for improved formatting and type safety.
- The returned object is identical in structure to objects returned by `Get-CM7SoftwareUpdateGroup`.

### Comparison with Native Cmdlet

| Feature | New-CMSoftwareUpdateGroup | New-CM7SoftwareUpdateGroup |
|---------|--------------------------|---------------------------|
| Requires ConfigMgr Console | Yes | No |
| Connection Method | PSDrive | CIM/WinRM |
| PowerShell 7 Support | Limited | Full |
| Remote Management | Local only | Remote via WinRM |
| Update by CI_ID | Yes | Yes |
| Update by Article ID | No | Yes |
| Duplicate Detection | Yes | Yes |
| WhatIf Support | Yes | Yes |
| Returns | SMS objects | PSCustomObject |

### Error Handling

| Error | Cause | Resolution |
|-------|-------|------------|
| "Not connected to MECM" | No active CIM connection | Run `Connect-CM7` first |
| "already exists" | Duplicate group name | Choose a unique name |
| "No software update found for Article ID" | Invalid KB number | Verify the Article ID exists in MECM |
| Access denied | Insufficient permissions | Ensure MECM permissions to create SMS_AuthorizationList |

## RELATED LINKS

- [Connect-CM7](./Connect-CM7.md) - Establish connection to MECM
- [Get-CM7SoftwareUpdateGroup](./Get-CM7SoftwareUpdateGroup.md) - Retrieve software update group information
- [Get-CM7SoftwareUpdate](./Get-CM7SoftwareUpdate.md) - Retrieve software update information
- [Get-CM7SoftwareUpdateDeployment](./Get-CM7SoftwareUpdateDeployment.md) - Retrieve software update deployments
- [Get-CM7SoftwareUpdateDeploymentPackage](./Get-CM7SoftwareUpdateDeploymentPackage.md) - Retrieve software update deployment packages

## SEE ALSO

- `New-CMSoftwareUpdateGroup` - Native ConfigurationManager module equivalent
- `New-CimInstance` - PowerShell CIM cmdlet for creating WMI instances
- [SMS_AuthorizationList WMI Class](https://learn.microsoft.com/en-us/mem/configmgr/develop/reference/sum/sms_authorizationlist-server-wmi-class)
