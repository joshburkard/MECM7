# New-CM7TaskSequenceDeployment

## SYNOPSIS

Creates a new task sequence deployment in Microsoft Endpoint Configuration Manager (MECM) using CIM.

## DESCRIPTION

The `New-CM7TaskSequenceDeployment` function creates a new task sequence deployment (`SMS_Advertisement` with `ProgramName = '*'`) in MECM using CIM. A task sequence deployment assigns a task sequence to a target device collection, defining how and when the task sequence is run on targeted clients.

This function is the CIM-based equivalent of the `New-CMTaskSequenceDeployment` cmdlet from the ConfigurationManager PowerShell module, but uses direct CIM queries over WinRM instead of requiring the ConfigMgr console or PowerShell drive.

The function performs the following actions:

1. Validates an active connection exists (established via `Connect-CM7`)
2. Resolves the task sequence by name or PackageID
3. Resolves the target device collection by name or ID
4. Computes `AdvertFlags` and `RemoteClientFlags` from the specified parameters
5. Creates a new `SMS_Advertisement` instance via CIM with `ProgramName = '*'`
6. Returns the created deployment as a formatted `MECM7.TaskSequenceDeployment` object

Key features:
- **Flexible Task Sequence Selection**: Specify the task sequence by name or PackageID
- **Flexible Collection Selection**: Specify the target collection by name or ID
- **Deployment Purpose**: Create Available (optional) or Required (mandatory) deployments
- **Scheduling**: Control available date/time and enforcement deadline
- **Media/PXE Availability**: Control whether the TS is available via media and PXE
- **Rerun Behavior**: Control how the TS behaves on re-execution
- **Service Window Override**: Allow installation and restarts outside of maintenance windows
- **Content Download Options**: Control how content is accessed during the task sequence
- **WhatIf/Confirm**: Full ShouldProcess support for safe operations
- **Force**: Suppress confirmation prompts for automation scenarios

## PARAMETERS

### -TaskSequencePackageId

Specifies the PackageID of the task sequence to deploy (e.g., "CM100FAD").
Mutually exclusive with `-TaskSequenceName`.

- **Type**: String
- **Position**: Named
- **Default**: None
- **Required**: Yes (for ByTSPackageIdCollectionName and ByTSPackageIdCollectionId parameter sets)
- **Parameter Set**: ByTSPackageIdCollectionName, ByTSPackageIdCollectionId
- **Accept pipeline input**: False
- **Accept wildcard characters**: No

Example: `"CM100FAD"`

### -TaskSequenceName

Specifies the name of the task sequence to deploy.
Mutually exclusive with `-TaskSequencePackageId`.

- **Type**: String
- **Position**: Named
- **Default**: None
- **Required**: Yes (for ByTSNameCollectionName and ByTSNameCollectionId parameter sets)
- **Parameter Set**: ByTSNameCollectionName, ByTSNameCollectionId
- **Accept pipeline input**: False
- **Accept wildcard characters**: No

Example: `"Test Josh"`

### -CollectionName

Specifies the name of the target device collection for the deployment.
Mutually exclusive with `-CollectionId`.

- **Type**: String
- **Position**: Named
- **Default**: None
- **Required**: Yes (for ByTSPackageIdCollectionName and ByTSNameCollectionName parameter sets)
- **Parameter Set**: ByTSPackageIdCollectionName, ByTSNameCollectionName
- **Accept pipeline input**: False
- **Accept wildcard characters**: No

Example: `"Test-Collection-Direct"`

### -CollectionId

Specifies the ID of the target device collection for the deployment (e.g., "CM101C00").
Mutually exclusive with `-CollectionName`.

- **Type**: String
- **Position**: Named
- **Default**: None
- **Required**: Yes (for ByTSPackageIdCollectionId and ByTSNameCollectionId parameter sets)
- **Parameter Set**: ByTSPackageIdCollectionId, ByTSNameCollectionId
- **Accept pipeline input**: False
- **Accept wildcard characters**: No

Example: `"CM101C00"`

### -DeploymentName

Specifies an optional name for the deployment (AdvertisementName). If not specified, defaults to "{TaskSequenceName} - {CollectionName}".

- **Type**: String
- **Position**: Named
- **Default**: "{TaskSequenceName} - {CollectionName}"
- **Required**: No
- **Parameter Set**: All
- **Accept pipeline input**: False
- **Accept wildcard characters**: No

### -Comment

Specifies an optional description/comment for the deployment.

- **Type**: String
- **Position**: Named
- **Default**: Empty string
- **Required**: No
- **Parameter Set**: All
- **Accept pipeline input**: False
- **Accept wildcard characters**: No

### -DeployPurpose

Specifies the deployment purpose. Valid values are:
- `Available`: Makes the task sequence available in Software Center for users to run on demand (default)
- `Required`: Forces the task sequence to run by the deadline / as soon as possible

- **Type**: String
- **Position**: Named
- **Default**: Available
- **Required**: No
- **Parameter Set**: All
- **Accept pipeline input**: False
- **Accepted values**: Available, Required

### -AvailableDateTime

Specifies the date and time when the deployment becomes available to clients. Defaults to the current date and time.

- **Type**: DateTime
- **Position**: Named
- **Default**: Current date/time
- **Required**: No
- **Parameter Set**: All
- **Accept pipeline input**: False

### -DeadlineDateTime

Specifies the enforcement deadline date and time. For Required deployments, this sets when the task sequence is forced to run. For Available deployments, this sets the expiration time.

- **Type**: DateTime
- **Position**: Named
- **Default**: None
- **Required**: No
- **Parameter Set**: All
- **Accept pipeline input**: False

### -UseUtcForAvailableSchedule

Specifies whether to use UTC/GMT times for the available schedule. Default is `$false` (use local client time).

- **Type**: Boolean
- **Position**: Named
- **Default**: False
- **Required**: No
- **Parameter Set**: All
- **Accept pipeline input**: False

### -UseUtcForExpireSchedule

Specifies whether to use UTC/GMT times for the expiration/deadline schedule. Default is `$false` (use local client time).

- **Type**: Boolean
- **Position**: Named
- **Default**: False
- **Required**: No
- **Parameter Set**: All
- **Accept pipeline input**: False

### -Availability

Controls where the task sequence is available. Valid values are:
- `Clients`: Only available to Configuration Manager clients (default)
- `ClientsMediaAndPxe`: Available to clients, media, and PXE
- `MediaAndPxe`: Available only to media and PXE
- `MediaAndPxeHidden`: Available only to media and PXE (hidden from Software Center)

- **Type**: String
- **Position**: Named
- **Default**: Clients
- **Required**: No
- **Parameter Set**: All
- **Accept pipeline input**: False
- **Accepted values**: Clients, ClientsMediaAndPxe, MediaAndPxe, MediaAndPxeHidden

### -RerunBehavior

Controls how the task sequence behaves if it has been previously run on the client. Valid values are:
- `NeverRerun`: Never rerun the task sequence on the client
- `AlwaysRerunProgram`: Always rerun the task sequence regardless of previous results
- `RerunIfFailedPreviousAttempt`: Rerun only if the previous attempt failed (default)
- `RerunIfSucceededOnPreviousAttempt`: Rerun only if the previous attempt succeeded

- **Type**: String
- **Position**: Named
- **Default**: RerunIfFailedPreviousAttempt
- **Required**: No
- **Parameter Set**: All
- **Accept pipeline input**: False
- **Accepted values**: NeverRerun, AlwaysRerunProgram, RerunIfFailedPreviousAttempt, RerunIfSucceededOnPreviousAttempt

### -ShowTaskSequenceProgress

Shows task sequence progress to the user during execution. Default is `$false`.

- **Type**: Boolean
- **Position**: Named
- **Default**: False
- **Required**: No
- **Parameter Set**: All
- **Accept pipeline input**: False

### -SoftwareInstallation

Allows task sequence installation outside of maintenance windows. Default is `$true`.

- **Type**: Boolean
- **Position**: Named
- **Default**: True
- **Required**: No
- **Parameter Set**: All
- **Accept pipeline input**: False

### -SystemRestart

Allows system restart outside of maintenance windows. Default is `$true`.

- **Type**: Boolean
- **Position**: Named
- **Default**: True
- **Required**: No
- **Parameter Set**: All
- **Accept pipeline input**: False

### -AllowFallback

Allows clients to use a fallback source location for content. When `$false`, clients will not fall back to unprotected distribution points. Default is `$false`.

- **Type**: Boolean
- **Position**: Named
- **Default**: False
- **Required**: No
- **Parameter Set**: All
- **Accept pipeline input**: False

### -DeploymentOption

Controls how content is accessed during the task sequence. Valid values are:
- `DownloadAllContent`: Download all content locally before starting the task sequence (default)
- `DownloadContentLocallyWhenNeededByRunningTaskSequence`: Download content as needed during execution
- `RunFromDistributionPoint`: Access content directly from the distribution point

- **Type**: String
- **Position**: Named
- **Default**: DownloadAllContent
- **Required**: No
- **Parameter Set**: All
- **Accept pipeline input**: False
- **Accepted values**: DownloadAllContent, DownloadContentLocallyWhenNeededByRunningTaskSequence, RunFromDistributionPoint

### -AllowSharedContent

Allows clients to use BranchCache to share content with other clients on the same subnet. Default is `$true`.

- **Type**: Boolean
- **Position**: Named
- **Default**: True
- **Required**: No
- **Parameter Set**: All
- **Accept pipeline input**: False

### -SendWakeupPacket

Sends a Wake On LAN packet to wake up computers before the deployment runs. Default is `$false`.

- **Type**: Boolean
- **Position**: Named
- **Default**: False
- **Required**: No
- **Parameter Set**: All
- **Accept pipeline input**: False

### -PersistOnWriteFilterDevice

Allows content to persist on Windows Embedded write filter enabled devices. Default is `$false`.

- **Type**: Boolean
- **Position**: Named
- **Default**: False
- **Required**: No
- **Parameter Set**: All
- **Accept pipeline input**: False

### -InternetOption

Allows the task sequence to run on internet-based clients. Default is `$true`.

- **Type**: Boolean
- **Position**: Named
- **Default**: True
- **Required**: No
- **Parameter Set**: All
- **Accept pipeline input**: False

### -UseMeteredNetwork

Allows the task sequence to run over metered (cellular/pay-per-use) network connections. Default is `$true`.

- **Type**: Boolean
- **Position**: Named
- **Default**: True
- **Required**: No
- **Parameter Set**: All
- **Accept pipeline input**: False

### -ScheduleEvent

For Required deployments, controls when the task sequence is scheduled to run. Valid values are:
- `AsSoonAsPossible`: Run as soon as possible after the available time (default)
- `LogOn`: Run at next user logon
- `LogOff`: Run at next user logoff

This parameter is only effective with `-DeployPurpose Required`.

- **Type**: String
- **Position**: Named
- **Default**: AsSoonAsPossible
- **Required**: No
- **Parameter Set**: All
- **Accept pipeline input**: False
- **Accepted values**: AsSoonAsPossible, LogOn, LogOff

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

### EXAMPLE 1: Create a basic available deployment

```powershell
New-CM7TaskSequenceDeployment -CollectionName "Test-Collection-Direct" -TaskSequencePackageId "CM100FAD" -AvailableDateTime (Get-Date) -Force
```

Creates an available task sequence deployment targeting the specified collection, equivalent to the native `New-CMTaskSequenceDeployment` with default settings.

### EXAMPLE 2: Create a deployment using task sequence name

```powershell
New-CM7TaskSequenceDeployment -TaskSequenceName "Test Josh" -CollectionName "Test-Collection-Direct" -Force
```

Creates an available task sequence deployment using the task sequence name instead of PackageID.

### EXAMPLE 3: Create a required (mandatory) deployment

```powershell
New-CM7TaskSequenceDeployment -TaskSequencePackageId "CM100FAD" -CollectionName "Test-Collection-Direct" -DeployPurpose Required -Force
```

Creates a required deployment that will run as soon as possible on targeted clients.

### EXAMPLE 4: Create a required deployment with a deadline

```powershell
New-CM7TaskSequenceDeployment -TaskSequencePackageId "CM100FAD" -CollectionName "Test-Collection-Direct" -DeployPurpose Required -DeadlineDateTime (Get-Date).AddDays(7) -Force
```

Creates a required deployment with a 7-day enforcement deadline.

### EXAMPLE 5: Create a deployment with custom name and comment

```powershell
New-CM7TaskSequenceDeployment -TaskSequencePackageId "CM100FAD" -CollectionId "CM101C00" -DeploymentName "Custom Deployment Name" -Comment "Monthly OS deployment" -Force
```

Creates a deployment using PackageID and collection ID with a custom name and comment.

### EXAMPLE 6: Create a deployment with no restart outside maintenance windows

```powershell
New-CM7TaskSequenceDeployment -TaskSequencePackageId "CM100FAD" -CollectionName "Test-Collection-Direct" -SoftwareInstallation $false -SystemRestart $false -Force
```

Creates a deployment that does not allow installation or restart outside of maintenance windows.

### EXAMPLE 7: Create a deployment available from media and PXE

```powershell
New-CM7TaskSequenceDeployment -TaskSequencePackageId "CM100FAD" -CollectionName "Test-Collection-Direct" -Availability ClientsMediaAndPxe -Force
```

Creates a deployment that is available to clients, media, and PXE boot.

### EXAMPLE 8: Preview deployment creation with WhatIf

```powershell
New-CM7TaskSequenceDeployment -TaskSequencePackageId "CM100FAD" -CollectionName "Test-Collection-Direct" -WhatIf
```

Shows what would happen without actually creating the deployment.

### EXAMPLE 9: Create a deployment and inspect the result

```powershell
$deployment = New-CM7TaskSequenceDeployment -TaskSequencePackageId "CM100FAD" -CollectionName "Test-Collection-Direct" -Force
Write-Host "Created: $($deployment.AdvertisementName) (ID: $($deployment.AdvertisementID), Collection: $($deployment.CollectionName))"
```

Creates a deployment and captures the result for further processing.

### EXAMPLE 10: Create a deployment with verbose output

```powershell
New-CM7TaskSequenceDeployment -CollectionName "Test-Collection-Direct" -TaskSequencePackageId "CM100FAD" -AvailableDateTime (Get-Date) -Force -Verbose
```

Creates a deployment with verbose output showing the WQL queries, flag computations, and operations being performed.

### EXAMPLE 11: Create a fully configured required deployment

```powershell
New-CM7TaskSequenceDeployment `
    -TaskSequencePackageId "CM100FAD" `
    -CollectionName "Test-Collection-Direct" `
    -DeploymentName "OS Deployment - February 2026" `
    -Comment "Monthly OS deployment for test collection" `
    -DeployPurpose Required `
    -AvailableDateTime (Get-Date) `
    -DeadlineDateTime (Get-Date).AddDays(7) `
    -SoftwareInstallation $true `
    -SystemRestart $true `
    -AllowFallback $false `
    -RerunBehavior RerunIfFailedPreviousAttempt `
    -ShowTaskSequenceProgress $true `
    -AllowSharedContent $true `
    -UseMeteredNetwork $true `
    -InternetOption $true `
    -Force
```

Creates a fully configured required task sequence deployment with explicit settings for all options.

## OUTPUTS

### PSCustomObject (MECM7.TaskSequenceDeployment)

The function returns a custom object of type `MECM7.TaskSequenceDeployment` with the following commonly used properties:

| Property | Type | Description |
|----------|------|-------------|
| AdvertisementID | string | Unique advertisement/deployment identifier |
| AdvertisementName | string | Name of the deployment |
| CollectionID | string | Target collection ID |
| CollectionName | string | Target collection name (resolved from ID) |
| PackageID | string | PackageID of the associated task sequence |
| TaskSequenceName | string | Name of the associated task sequence |
| ProgramName | string | Program name (always `*` for task sequence deployments) |
| SourceSite | string | Source site code |
| AdvertFlags | int | Advertisement flags (computed from parameters) |
| RemoteClientFlags | int | Remote client flags (computed from parameters) |
| DeviceFlags | int | Device flags |
| PresentTime | datetime | Available time (when deployment becomes available) |
| ExpirationTime | datetime | Expiration/deadline time |
| Comment | string | Deployment description/comment |

All additional WMI properties from the `SMS_Advertisement` class are also included in the output.

Example object:

```powershell
PSTypeName              : MECM7.TaskSequenceDeployment
AdvertisementID         : CM120CE8
AdvertisementName       : Test Josh - Test-Collection-Direct
CollectionID            : CM101C00
CollectionName          : Test-Collection-Direct
PackageID               : CM100FAD
TaskSequenceName        : Test Josh
ProgramName             : *
SourceSite              : CM1
AdvertFlags             : 9109504
RemoteClientFlags       : 34896
DeviceFlags             : 0
PresentTime             : 2026-02-20 10:00:00
ExpirationTime          :
Comment                 :
```

## REQUIREMENTS

- An active MECM/SCCM connection established via `Connect-CM7`
- PowerShell 5.1 or higher
- Access to the MECM SMS Provider via WinRM
- Sufficient MECM permissions to create task sequence deployments (SMS_Advertisement)
- A valid task sequence must exist
- A valid target device collection must exist

## NOTES

- The function creates task sequence deployments using the `SMS_Advertisement` WMI class directly via CIM sessions.
- Task sequence deployments are distinguished from other deployments by `ProgramName = '*'`.
- The function validates that the specified task sequence and collection exist before creating the deployment.
- If no `-DeploymentName` is specified, it defaults to "{TaskSequenceName} - {CollectionName}".
- The `PSTypeName` is automatically set to `MECM7.TaskSequenceDeployment` for improved formatting and type safety.
- The returned object is identical in structure to objects returned by `Get-CM7TaskSequenceDeployment`.

### Parameter Sets

| Parameter Set | Required Parameters |
|---------------|---------------------|
| ByTSPackageIdCollectionName | `-TaskSequencePackageId`, `-CollectionName` |
| ByTSPackageIdCollectionId | `-TaskSequencePackageId`, `-CollectionId` |
| ByTSNameCollectionName | `-TaskSequenceName`, `-CollectionName` |
| ByTSNameCollectionId | `-TaskSequenceName`, `-CollectionId` |

### Comparison with Native Cmdlet

| Feature | New-CMTaskSequenceDeployment | New-CM7TaskSequenceDeployment |
|---------|------------------------------|-------------------------------|
| Requires ConfigMgr Console | Yes | No |
| Connection Method | PSDrive | CIM/WinRM |
| PowerShell 7 Support | Limited | Full |
| Remote Management | Local only | Remote via WinRM |
| Task Sequence by PackageID | Yes | Yes |
| Task Sequence by Name | Yes | Yes |
| Collection by Name | Yes | Yes |
| Collection by ID | Yes | Yes |
| Deploy Purpose | Available/Required | Available/Required |
| Available DateTime | Yes | Yes |
| Deadline/Expiration | Yes | Yes |
| Media/PXE Availability | Yes | Yes |
| Rerun Behavior | Yes | Yes |
| Service Window Override | Yes | Yes |
| Restart Control | Yes | Yes |
| Content Download Options | Yes | Yes |
| Wake On LAN | Yes | Yes |
| Show TS Progress | Yes | Yes |
| Internet Clients | Yes | Yes |
| Metered Network | Yes | Yes |
| WhatIf Support | Yes | Yes |
| Returns | SMS objects | PSCustomObject |

### AdvertFlags Bit Definitions

| Bit | Hex Value | Description | Parameter |
|-----|-----------|-------------|-----------|
| 5 | 0x00000020 | IMMEDIATE (as soon as possible) | `-DeployPurpose Required -ScheduleEvent AsSoonAsPossible` |
| 9 | 0x00000200 | ONUSERLOGON | `-ScheduleEvent LogOn` |
| 10 | 0x00000400 | ONUSERLOGOFF | `-ScheduleEvent LogOff` |
| 13 | 0x00002000 | ENABLE_TS_FROM_CD_AND_PXE | `-Availability ClientsMediaAndPxe/MediaAndPxe/MediaAndPxeHidden` |
| 15 | 0x00008000 | NO_DISPLAY | `-Availability MediaAndPxeHidden` |
| 16 | 0x00010000 | OVERRIDE_SERVICE_WINDOWS | `-SoftwareInstallation $true` |
| 17 | 0x00020000 | REBOOT_OUTSIDE_SERVICE_WINDOWS | `-SystemRestart $true` |
| 18 | 0x00040000 | WAKE_ON_LAN | `-SendWakeupPacket $true` |
| 19 | 0x00080000 | DONOT_FALLBACK | `-AllowFallback $false` |
| 23 | 0x00800000 | USE_REMOTE_DP | Always set |
| 25 | 0x02000000 | SHOW_PROGRESS | `-ShowTaskSequenceProgress $true` |

### RemoteClientFlags Bit Definitions

| Bit | Hex Value | Description | Parameter |
|-----|-----------|-------------|-----------|
| 1 | 0x00000002 | DOWNLOAD_FROM_REMOTE_DP | `-DeploymentOption DownloadContentLocallyWhenNeededByRunningTaskSequence` |
| 2 | 0x00000004 | DONT_RUN_NO_LOCAL_DP | `-DeploymentOption RunFromDistributionPoint` |
| 4 | 0x00000010 | ALLOW_SHARED_CONTENT | `-AllowSharedContent $true` |
| 5 | 0x00000020 | ALWAYS_RERUN | `-RerunBehavior AlwaysRerunProgram` |
| 6 | 0x00000040 | RERUN_IF_FAILED | `-RerunBehavior RerunIfFailedPreviousAttempt` |
| 7 | 0x00000080 | RERUN_IF_SUCCEEDED | `-RerunBehavior RerunIfSucceededOnPreviousAttempt` |
| 10 | 0x00000400 | PERSIST_ON_WRITE_FILTER | `-PersistOnWriteFilterDevice $true` |
| 11 | 0x00000800 | ALLOW_INTERNET_CLIENTS | `-InternetOption $true` |
| 14 | 0x00004000 | TS_SHOW_PROGRESS | `-ShowTaskSequenceProgress $true` |
| 15 | 0x00008000 | USE_METERED_NETWORK | `-UseMeteredNetwork $true` |

### Default Flag Values

With all default parameter values, the computed flags match the native `New-CMTaskSequenceDeployment` defaults:

| Flag | Default Value (Hex) | Default Value (Decimal) |
|------|---------------------|-------------------------|
| AdvertFlags | 0x8b0000 | 9109504 |
| RemoteClientFlags | 0x8850 | 34896 |
| DeviceFlags | 0x0 | 0 |

### Error Handling

| Error | Cause | Resolution |
|-------|-------|------------|
| "Not connected to MECM" | No active CIM connection | Run `Connect-CM7` first |
| "Task sequence 'X' not found" | Invalid task sequence name or PackageID | Verify the task sequence exists in MECM |
| "Device collection 'X' not found" | Invalid collection name or ID | Verify the device collection exists in MECM |
| "Multiple task sequences found" | Ambiguous task sequence name | Use `-TaskSequencePackageId` instead |
| "Multiple collections found" | Ambiguous collection name | Use `-CollectionId` instead |
| Access denied | Insufficient permissions | Ensure MECM permissions to create SMS_Advertisement |

## RELATED LINKS

- [Connect-CM7](./Connect-CM7.md) - Establish connection to MECM
- [Get-CM7TaskSequenceDeployment](./Get-CM7TaskSequenceDeployment.md) - Retrieve task sequence deployment information
- [Get-CM7TaskSequence](./Get-CM7TaskSequence.md) - Retrieve task sequence information
- [Get-CM7Collection](./Get-CM7Collection.md) - Retrieve collection information
- [Get-CM7Deployment](./Get-CM7Deployment.md) - Retrieve general deployment information
- [New-CM7SoftwareUpdateDeployment](./New-CM7SoftwareUpdateDeployment.md) - Create a software update deployment

## SEE ALSO

- `New-CMTaskSequenceDeployment` - Native ConfigurationManager module equivalent
- `New-CimInstance` - PowerShell CIM cmdlet for creating WMI instances
- [SMS_Advertisement Server WMI Class](https://learn.microsoft.com/en-us/mem/configmgr/develop/reference/core/servers/configure/sms_advertisement-server-wmi-class)
