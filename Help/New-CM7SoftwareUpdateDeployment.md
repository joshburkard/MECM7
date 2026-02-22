# New-CM7SoftwareUpdateDeployment

## SYNOPSIS

Creates a new software update deployment in Microsoft Endpoint Configuration Manager (MECM) using CIM.

## DESCRIPTION

The `New-CM7SoftwareUpdateDeployment` function creates a new software update deployment (SMS_UpdatesAssignment) in MECM using CIM. A software update deployment assigns a software update group to a target collection, defining how and when the updates are installed on targeted clients.

This function is the CIM-based equivalent of the `New-CMSoftwareUpdateDeployment` cmdlet from the ConfigurationManager PowerShell module, but uses direct CIM queries over WinRM instead of requiring the ConfigMgr console or PowerShell drive.

The function performs the following actions:

1. Validates an active connection exists (established via `Connect-CM7`)
2. Resolves the software update group by name or CI_ID
3. Resolves the target collection by name or ID
4. Creates a new `SMS_UpdatesAssignment` instance via CIM with the specified deployment settings
5. Returns the created deployment as a formatted `MECM7.SoftwareUpdateDeployment` object

Key features:
- **Flexible Group Selection**: Specify the software update group by name or CI_ID
- **Flexible Collection Selection**: Specify the target collection by name or ID
- **Deployment Types**: Create Required (forced) or Available (optional) deployments
- **Scheduling**: Control available date/time and enforcement deadline
- **User Notification**: Configure client notification behavior
- **Restart Control**: Suppress restarts on servers, workstations, or both
- **Service Window Override**: Allow installation and restarts outside of maintenance windows
- **WhatIf/Confirm**: Full ShouldProcess support for safe operations
- **Force**: Suppress confirmation prompts for automation scenarios

## PARAMETERS

### -SoftwareUpdateGroupName

Specifies the name of the software update group to deploy (LocalizedDisplayName of SMS_AuthorizationList).
Mutually exclusive with `-SoftwareUpdateGroupId`.

- **Type**: String
- **Position**: Named
- **Default**: None
- **Required**: Yes (for ByGroupNameCollectionName and ByGroupNameCollectionId parameter sets)
- **Parameter Set**: ByGroupNameCollectionName, ByGroupNameCollectionId
- **Accept pipeline input**: False
- **Accept wildcard characters**: No

Example: `"Test-SUG"`

### -SoftwareUpdateGroupId

Specifies the CI_ID of the software update group to deploy.
Mutually exclusive with `-SoftwareUpdateGroupName`.

- **Type**: Int32
- **Position**: Named
- **Default**: None
- **Required**: Yes (for ByGroupIdCollectionName and ByGroupIdCollectionId parameter sets)
- **Parameter Set**: ByGroupIdCollectionName, ByGroupIdCollectionId
- **Accept pipeline input**: False
- **Accept wildcard characters**: No

Example: `17129359`

### -CollectionName

Specifies the name of the target collection for the deployment.
Mutually exclusive with `-CollectionId`.

- **Type**: String
- **Position**: Named
- **Default**: None
- **Required**: Yes (for ByGroupNameCollectionName and ByGroupIdCollectionName parameter sets)
- **Parameter Set**: ByGroupNameCollectionName, ByGroupIdCollectionName
- **Accept pipeline input**: False
- **Accept wildcard characters**: No

Example: `"Test-Collection-Direct"`

### -CollectionId

Specifies the ID of the target collection for the deployment (e.g., "CM101C00").
Mutually exclusive with `-CollectionName`.

- **Type**: String
- **Position**: Named
- **Default**: None
- **Required**: Yes (for ByGroupNameCollectionId and ByGroupIdCollectionId parameter sets)
- **Parameter Set**: ByGroupNameCollectionId, ByGroupIdCollectionId
- **Accept pipeline input**: False
- **Accept wildcard characters**: No

Example: `"CM101C00"`

### -DeploymentName

Specifies an optional name for the deployment (AssignmentName). If not specified, defaults to the software update group name.

- **Type**: String
- **Position**: Named
- **Default**: Software update group name
- **Required**: No
- **Parameter Set**: All
- **Accept pipeline input**: False
- **Accept wildcard characters**: No

### -Description

Specifies an optional description for the deployment (AssignmentDescription).

- **Type**: String
- **Position**: Named
- **Default**: Empty string
- **Required**: No
- **Parameter Set**: All
- **Accept pipeline input**: False
- **Accept wildcard characters**: No

### -DeploymentType

Specifies the deployment type. Valid values are:
- `Required`: Forces installation by the enforcement deadline (default)
- `Available`: Makes updates available in Software Center for optional installation

- **Type**: String
- **Position**: Named
- **Default**: Required
- **Required**: No
- **Parameter Set**: All
- **Accept pipeline input**: False
- **Accepted values**: Required, Available

### -AvailableDateTime

Specifies the date and time when the deployment becomes available to clients. Defaults to the current date and time.

- **Type**: DateTime
- **Position**: Named
- **Default**: Current date/time
- **Required**: No
- **Parameter Set**: All
- **Accept pipeline input**: False

### -DeadlineDateTime

Specifies the enforcement deadline date and time. After this time, the client will force installation of required deployments. Only meaningful with `DeploymentType` set to `Required`.

- **Type**: DateTime
- **Position**: Named
- **Default**: Same as AvailableDateTime (immediate enforcement)
- **Required**: No
- **Parameter Set**: All
- **Accept pipeline input**: False

### -UserNotification

Controls user notification behavior. Valid values are:
- `DisplayAll`: Show all notifications (default)
- `DisplaySoftwareCenterOnly`: Show only in Software Center
- `HideAll`: Hide all notifications

- **Type**: String
- **Position**: Named
- **Default**: DisplayAll
- **Required**: No
- **Parameter Set**: All
- **Accept pipeline input**: False
- **Accepted values**: DisplayAll, DisplaySoftwareCenterOnly, HideAll

### -SoftwareInstallation

Allows software update installation outside of maintenance windows. Default is `$false`.

- **Type**: Boolean
- **Position**: Named
- **Default**: False
- **Required**: No
- **Parameter Set**: All
- **Accept pipeline input**: False

### -AllowRestart

Allows system restart outside of maintenance windows. Default is `$false`.

- **Type**: Boolean
- **Position**: Named
- **Default**: False
- **Required**: No
- **Parameter Set**: All
- **Accept pipeline input**: False

### -RestartServer

Controls whether server restarts are allowed. When `$false`, suppresses restart on servers. Default is `$true`.

- **Type**: Boolean
- **Position**: Named
- **Default**: True
- **Required**: No
- **Parameter Set**: All
- **Accept pipeline input**: False

### -RestartWorkstation

Controls whether workstation restarts are allowed. When `$false`, suppresses restart on workstations. Default is `$true`.

- **Type**: Boolean
- **Position**: Named
- **Default**: True
- **Required**: No
- **Parameter Set**: All
- **Accept pipeline input**: False

### -RequirePostRebootFullScan

Requires a full scan of software updates after a system restart. Default is `$false`.

- **Type**: Boolean
- **Position**: Named
- **Default**: False
- **Required**: No
- **Parameter Set**: All
- **Accept pipeline input**: False

### -ProtectedType

Defines behavior for clients on protected (slow or unreliable) distribution points. Valid values are:
- `NoInstall`: Do not install software updates (default)
- `RemoteDistributionPoint`: Install from a remote distribution point

- **Type**: String
- **Position**: Named
- **Default**: NoInstall
- **Required**: No
- **Parameter Set**: All
- **Accept pipeline input**: False
- **Accepted values**: NoInstall, RemoteDistributionPoint

### -UnprotectedType

Defines behavior for clients not on any distribution point boundary. Valid values are:
- `NoInstall`: Do not install software updates
- `UnprotectedDistributionPoint`: Install from an unprotected distribution point (default)

- **Type**: String
- **Position**: Named
- **Default**: UnprotectedDistributionPoint
- **Required**: No
- **Parameter Set**: All
- **Accept pipeline input**: False
- **Accepted values**: NoInstall, UnprotectedDistributionPoint

### -UseBranchCache

Enables BranchCache for the deployment. Default is `$false`.

- **Type**: Boolean
- **Position**: Named
- **Default**: False
- **Required**: No
- **Parameter Set**: All
- **Accept pipeline input**: False

### -DownloadFromMicrosoftUpdate

Allows clients to download content from Microsoft Update if content is unavailable on distribution points. Default is `$false`.

- **Type**: Boolean
- **Position**: Named
- **Default**: False
- **Required**: No
- **Parameter Set**: All
- **Accept pipeline input**: False

### -UseGMTTimes

Specifies whether to use UTC/GMT times for the deployment schedule. Default is `$false` (use local client time).

- **Type**: Boolean
- **Position**: Named
- **Default**: False
- **Required**: No
- **Parameter Set**: All
- **Accept pipeline input**: False

### -Enabled

Whether the deployment is enabled. Default is `$true`.

- **Type**: Boolean
- **Position**: Named
- **Default**: True
- **Required**: No
- **Parameter Set**: All
- **Accept pipeline input**: False

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

### EXAMPLE 1: Create a basic required deployment

```powershell
New-CM7SoftwareUpdateDeployment -SoftwareUpdateGroupName "Test-SUG" -CollectionName "Test-Collection-Direct" -Force
```

Creates a required software update deployment targeting the specified collection using the software update group name.

### EXAMPLE 2: Create an available (optional) deployment

```powershell
New-CM7SoftwareUpdateDeployment -SoftwareUpdateGroupName "Test-SUG" -CollectionName "Test-Collection-Direct" -DeploymentType Available -Force
```

Creates an available deployment that users can optionally install from Software Center.

### EXAMPLE 3: Create a deployment with a 7-day enforcement deadline

```powershell
New-CM7SoftwareUpdateDeployment -SoftwareUpdateGroupName "Test-SUG" -CollectionName "Test-Collection-Direct" -DeadlineDateTime (Get-Date).AddDays(7) -Force
```

Creates a required deployment with an enforcement deadline 7 days from now.

### EXAMPLE 4: Create a deployment using CI_ID and collection ID

```powershell
New-CM7SoftwareUpdateDeployment -SoftwareUpdateGroupId 17129359 -CollectionId "CM101C00" -DeploymentName "Custom Deployment Name" -Description "Monthly patching" -Force
```

Creates a deployment using the software update group CI_ID and collection ID with a custom name.

### EXAMPLE 5: Create a deployment with restart suppression

```powershell
New-CM7SoftwareUpdateDeployment -SoftwareUpdateGroupName "Test-SUG" -CollectionName "Test-Collection-Direct" -RestartServer $false -RestartWorkstation $false -Force
```

Creates a deployment that suppresses restarts on both servers and workstations.

### EXAMPLE 6: Create a deployment with service window overrides

```powershell
New-CM7SoftwareUpdateDeployment -SoftwareUpdateGroupName "Test-SUG" -CollectionName "Test-Collection-Direct" -SoftwareInstallation $true -AllowRestart $true -Force
```

Creates a deployment that allows installation and restart outside of maintenance windows.

### EXAMPLE 7: Create a deployment with hidden notifications

```powershell
New-CM7SoftwareUpdateDeployment -SoftwareUpdateGroupName "Test-SUG" -CollectionName "Test-Collection-Direct" -UserNotification HideAll -Force
```

Creates a deployment that hides all user notifications.

### EXAMPLE 8: Preview deployment creation with WhatIf

```powershell
New-CM7SoftwareUpdateDeployment -SoftwareUpdateGroupName "Test-SUG" -CollectionName "Test-Collection-Direct" -WhatIf
```

Shows what would happen without actually creating the deployment.

### EXAMPLE 9: Create a deployment and inspect the result

```powershell
$deployment = New-CM7SoftwareUpdateDeployment -SoftwareUpdateGroupName "Test-SUG" -CollectionName "Test-Collection-Direct" -Force
Write-Host "Created: $($deployment.AssignmentName) (ID: $($deployment.AssignmentID), Collection: $($deployment.CollectionName))"
```

Creates a deployment and captures the result for further processing.

### EXAMPLE 10: Create a deployment with verbose output

```powershell
New-CM7SoftwareUpdateDeployment -SoftwareUpdateGroupName "Test-SUG" -CollectionName "Test-Collection-Direct" -Force -Verbose
```

Creates a deployment with verbose output showing the WQL queries and operations being performed.

### EXAMPLE 11: Create a deployment with all options configured

```powershell
New-CM7SoftwareUpdateDeployment `
    -SoftwareUpdateGroupName "Test-SUG" `
    -CollectionName "Test-Collection-Direct" `
    -DeploymentName "Patching - February 2026" `
    -Description "Monthly security patching for servers" `
    -DeploymentType Required `
    -AvailableDateTime (Get-Date) `
    -DeadlineDateTime (Get-Date).AddDays(7) `
    -UserNotification DisplaySoftwareCenterOnly `
    -SoftwareInstallation $false `
    -AllowRestart $false `
    -RestartServer $false `
    -RestartWorkstation $true `
    -UseGMTTimes $true `
    -UseBranchCache $true `
    -DownloadFromMicrosoftUpdate $false `
    -Force
```

Creates a fully configured deployment with explicit settings for all options.

## OUTPUTS

### PSCustomObject (MECM7.SoftwareUpdateDeployment)

The function returns a custom object of type `MECM7.SoftwareUpdateDeployment` with the following commonly used properties:

| Property | Type | Description |
|----------|------|-------------|
| AssignmentID | int | Unique assignment identifier |
| AssignmentName | string | Name of the software update deployment |
| TargetCollectionID | string | Target collection ID |
| CollectionName | string | Target collection name (resolved from ID) |
| AssignmentDescription | string | Description of the deployment |
| AssignmentAction | string | Action type (Detect, Install) |
| DesiredConfigType | string | Configuration type (Required, Available) |
| StartTime | datetime | Deployment start/available time |
| EnforcementDeadline | datetime | Enforcement deadline for required deployments |
| SuppressReboot | bool | Whether reboot is suppressed |
| UseGMTTimes | bool | Whether times are in GMT |
| NotifyUser | bool | Whether user is notified |
| OverrideServiceWindows | bool | Whether service windows are overridden |
| RebootOutsideOfServiceWindows | bool | Whether reboot is allowed outside service windows |
| Enabled | bool | Whether the deployment is enabled |

All additional WMI properties from the `SMS_UpdatesAssignment` class are also included.

Example object:

```powershell
PSTypeName                    : MECM7.SoftwareUpdateDeployment
AssignmentID                  : 16777350
AssignmentName                : Test-SUG
TargetCollectionID            : CM101C00
CollectionName                : Test-Collection-Direct
AssignmentDescription         : Monthly security patching
AssignmentAction              : Install
DesiredConfigType             : Required
StartTime                     : 2026-02-19 10:00:00
EnforcementDeadline           : 2026-02-26 10:00:00
SuppressReboot                : False
UseGMTTimes                   : False
NotifyUser                    : True
OverrideServiceWindows        : False
RebootOutsideOfServiceWindows : False
Enabled                       : True
```

## REQUIREMENTS

- An active MECM/SCCM connection established via `Connect-CM7`
- PowerShell 5.1 or higher
- Access to the MECM SMS Provider via WinRM
- Sufficient MECM permissions to create software update deployments (SMS_UpdatesAssignment)
- A valid software update group must exist
- A valid target collection must exist

## NOTES

- The function creates software update deployments using the `SMS_UpdatesAssignment` WMI class directly via CIM sessions.
- The function validates that the specified software update group and collection exist before creating the deployment.
- If no `-DeploymentName` is specified, the software update group name is used as the deployment name.
- For Required deployments, if no `-DeadlineDateTime` is specified, the deadline defaults to the available time (immediate enforcement).
- The `PSTypeName` is automatically set to `MECM7.SoftwareUpdateDeployment` for improved formatting and type safety.
- The returned object is identical in structure to objects returned by `Get-CM7SoftwareUpdateDeployment`.

### Parameter Sets

| Parameter Set | Required Parameters |
|---------------|---------------------|
| ByGroupNameCollectionName | `-SoftwareUpdateGroupName`, `-CollectionName` |
| ByGroupNameCollectionId | `-SoftwareUpdateGroupName`, `-CollectionId` |
| ByGroupIdCollectionName | `-SoftwareUpdateGroupId`, `-CollectionName` |
| ByGroupIdCollectionId | `-SoftwareUpdateGroupId`, `-CollectionId` |

### Comparison with Native Cmdlet

| Feature | New-CMSoftwareUpdateDeployment | New-CM7SoftwareUpdateDeployment |
|---------|-------------------------------|--------------------------------|
| Requires ConfigMgr Console | Yes | No |
| Connection Method | PSDrive | CIM/WinRM |
| PowerShell 7 Support | Limited | Full |
| Remote Management | Local only | Remote via WinRM |
| Group by Name | Yes | Yes |
| Group by ID | Yes | Yes |
| Collection by Name | Yes | Yes |
| Collection by ID | Yes | Yes |
| Deployment Type | Required/Available | Required/Available |
| Deadline Scheduling | Yes | Yes |
| User Notification Control | Yes | Yes |
| Restart Suppression | Yes | Yes |
| Service Window Override | Yes | Yes |
| WhatIf Support | Yes | Yes |
| Returns | SMS objects | PSCustomObject |

### Deployment Type Values

| Friendly Name | WMI Value (DesiredConfigType) |
|---------------|-------------------------------|
| Required | 1 |
| Available | 2 |

### Assignment Action Values

| Friendly Name | WMI Value |
|---------------|-----------|
| Detect | 0 |
| Install | 1 |

### SuppressReboot Values

| Value | Description |
|-------|-------------|
| 0 | No suppression (allow all restarts) |
| 1 | Suppress server restarts |
| 2 | Suppress workstation restarts |
| 3 | Suppress all restarts |

### Error Handling

| Error | Cause | Resolution |
|-------|-------|------------|
| "Not connected to MECM" | No active CIM connection | Run `Connect-CM7` first |
| "Software update group 'X' not found" | Invalid group name or CI_ID | Verify the software update group exists in MECM |
| "Collection 'X' not found" | Invalid collection name or ID | Verify the collection exists in MECM |
| "Multiple software update groups found" | Ambiguous group name | Use `-SoftwareUpdateGroupId` instead |
| "Multiple collections found" | Ambiguous collection name | Use `-CollectionId` instead |
| Access denied | Insufficient permissions | Ensure MECM permissions to create SMS_UpdatesAssignment |

## RELATED LINKS

- [Connect-CM7](./Connect-CM7.md) - Establish connection to MECM
- [Get-CM7SoftwareUpdateDeployment](./Get-CM7SoftwareUpdateDeployment.md) - Retrieve software update deployment information
- [Get-CM7SoftwareUpdateGroup](./Get-CM7SoftwareUpdateGroup.md) - Retrieve software update group information
- [New-CM7SoftwareUpdateGroup](./New-CM7SoftwareUpdateGroup.md) - Create a new software update group
- [Get-CM7SoftwareUpdate](./Get-CM7SoftwareUpdate.md) - Retrieve software update information
- [Get-CM7Deployment](./Get-CM7Deployment.md) - Retrieve general deployment information
- [Get-CM7Collection](./Get-CM7Collection.md) - Retrieve collection information

## SEE ALSO

- `New-CMSoftwareUpdateDeployment` - Native ConfigurationManager module equivalent
- `New-CimInstance` - PowerShell CIM cmdlet for creating WMI instances
- [SMS_UpdatesAssignment WMI Class](https://learn.microsoft.com/en-us/mem/configmgr/develop/reference/sum/sms_updatesassignment-server-wmi-class)
