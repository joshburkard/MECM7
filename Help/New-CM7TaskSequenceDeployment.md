# New-CM7TaskSequenceDeployment

## SYNOPSIS

Creates a new task sequence deployment in MECM using CIM.

## DESCRIPTION

Creates a new task sequence deployment (SMS_Advertisement) in Microsoft Endpoint
Configuration Manager (MECM) using CIM. A task sequence deployment assigns a task
sequence to a target collection, defining how and when the task sequence is run
on targeted clients.

This is the CIM-based equivalent of the New-CMTaskSequenceDeployment cmdlet from the
ConfigurationManager PowerShell module, but uses direct CIM queries over WinRM
instead of requiring the ConfigMgr console or PowerShell drive.

The function performs the following actions:
1. Validates an active connection exists (established via Connect-CM7)
2. Resolves the task sequence by name or PackageID
3. Resolves the target collection by name or ID
4. Computes AdvertFlags and RemoteClientFlags from the specified parameters
5. Creates a new SMS_Advertisement instance via CIM with ProgramName = '*'
6. Returns the created deployment as a formatted MECM7.TaskSequenceDeployment object

## PARAMETERS

### TaskSequencePackageId

The PackageID of the task sequence to deploy (e.g., "SD100FAD").
Mutually exclusive with TaskSequenceName.

- Type: String
- Required: true
- Accept pipeline input: false
- Accept wildcard characters: false

### TaskSequenceName

The name of the task sequence to deploy.
Mutually exclusive with TaskSequencePackageId.

- Type: String
- Required: true
- Accept pipeline input: false
- Accept wildcard characters: false

### CollectionName

The name of the target device collection for the deployment.
Mutually exclusive with CollectionId.

- Type: String
- Required: true
- Accept pipeline input: false
- Accept wildcard characters: false

### CollectionId

The ID of the target device collection for the deployment (e.g., "SD101C00").
Mutually exclusive with CollectionName.

- Type: String
- Required: true
- Accept pipeline input: false
- Accept wildcard characters: false

### DeploymentName

An optional name for the deployment (AdvertisementName). If not specified,
defaults to "{TaskSequenceName} - {CollectionName}".

- Type: String
- Required: false
- Accept pipeline input: false
- Accept wildcard characters: false

### Comment

An optional description/comment for the deployment.

- Type: String
- Required: false
- Accept pipeline input: false
- Accept wildcard characters: false

### DeployPurpose

The deployment purpose. Valid values are:
- Available: Makes the task sequence available for users to run from Software Center (default).
- Required: Forces the task sequence to run by the deadline.

- Type: String
- Required: false
- Default value: Available
- Accept pipeline input: false
- Accept wildcard characters: false

### AvailableDateTime

The date and time when the deployment becomes available to clients.
Defaults to the current date and time.

- Type: DateTime
- Required: false
- Accept pipeline input: false
- Accept wildcard characters: false

### DeadlineDateTime

The enforcement deadline date and time for Required deployments.
After this time, the task sequence will be forced to run.
For Available deployments, this sets the expiration time.

- Type: DateTime
- Required: false
- Accept pipeline input: false
- Accept wildcard characters: false

### UseUtcForAvailableSchedule

Specifies whether to use UTC/GMT times for the available schedule. Default is $false.

- Type: Boolean
- Required: false
- Default value: False
- Accept pipeline input: false
- Accept wildcard characters: false

### UseUtcForExpireSchedule

Specifies whether to use UTC/GMT times for the expiration/deadline schedule. Default is $false.

- Type: Boolean
- Required: false
- Default value: False
- Accept pipeline input: false
- Accept wildcard characters: false

### Availability

Controls where the task sequence is available. Valid values are:
- Clients: Only available to Configuration Manager clients (default)
- ClientsMediaAndPxe: Available to clients, media, and PXE
- MediaAndPxe: Available only to media and PXE
- MediaAndPxeHidden: Available only to media and PXE (hidden)

- Type: String
- Required: false
- Default value: Clients
- Accept pipeline input: false
- Accept wildcard characters: false

### RerunBehavior

Controls how the task sequence behaves if it has been previously run. Valid values are:
- NeverRerun: Never rerun the task sequence
- AlwaysRerunProgram: Always rerun the task sequence
- RerunIfFailedPreviousAttempt: Rerun only if the previous attempt failed (default)
- RerunIfSucceededOnPreviousAttempt: Rerun only if the previous attempt succeeded

- Type: String
- Required: false
- Default value: RerunIfFailedPreviousAttempt
- Accept pipeline input: false
- Accept wildcard characters: false

### ShowTaskSequenceProgress

Shows task sequence progress to the user. Default is $false.

- Type: Boolean
- Required: false
- Default value: False
- Accept pipeline input: false
- Accept wildcard characters: false

### SoftwareInstallation

Allows task sequence installation outside of maintenance windows. Default is $true.

- Type: Boolean
- Required: false
- Default value: True
- Accept pipeline input: false
- Accept wildcard characters: false

### SystemRestart

Allows system restart outside of maintenance windows. Default is $true.

- Type: Boolean
- Required: false
- Default value: True
- Accept pipeline input: false
- Accept wildcard characters: false

### AllowFallback

Allows clients to use a fallback source location for content.
Default is $false (do not fall back).

- Type: Boolean
- Required: false
- Default value: False
- Accept pipeline input: false
- Accept wildcard characters: false

### DeploymentOption

Controls how content is accessed. Valid values are:
- DownloadAllContent: Download all content locally before starting task sequence (default)
- DownloadContentLocallyWhenNeededByRunningTaskSequence: Download content as needed
- RunFromDistributionPoint: Access content directly from the distribution point

- Type: String
- Required: false
- Default value: DownloadAllContent
- Accept pipeline input: false
- Accept wildcard characters: false

### AllowSharedContent

Allows clients to use BranchCache to share content with other clients.
Default is $true.

- Type: Boolean
- Required: false
- Default value: True
- Accept pipeline input: false
- Accept wildcard characters: false

### SendWakeupPacket

Sends a Wake On LAN packet to wake up computers before the deployment runs.
Default is $false.

- Type: Boolean
- Required: false
- Default value: False
- Accept pipeline input: false
- Accept wildcard characters: false

### PersistOnWriteFilterDevice

Allows content to persist on write filter enabled devices. Default is $false.

- Type: Boolean
- Required: false
- Default value: False
- Accept pipeline input: false
- Accept wildcard characters: false

### InternetOption

Allows the task sequence to run on internet-based clients. Default is $true.

- Type: Boolean
- Required: false
- Default value: True
- Accept pipeline input: false
- Accept wildcard characters: false

### UseMeteredNetwork

Allows the task sequence to run over metered network connections. Default is $true.

- Type: Boolean
- Required: false
- Default value: True
- Accept pipeline input: false
- Accept wildcard characters: false

### ScheduleEvent

For Required deployments, controls when the task sequence is scheduled to run.
Valid values are:
- AsSoonAsPossible: Run as soon as possible after the available time (default)
- LogOn: Run at next user logon
- LogOff: Run at next user logoff
When -Schedule is specified, -ScheduleEvent is ignored unless also explicitly provided.

- Type: String
- Required: false
- Default value: AsSoonAsPossible
- Accept pipeline input: false
- Accept wildcard characters: false

### Schedule

One or more schedule token objects (from New-CM7Schedule) to assign as the deployment
schedule for Required deployments. When provided, the -ScheduleEvent flag is not set
automatically (unless -ScheduleEvent is also explicitly specified).

- Type: PSObject[]
- Required: false
- Accept pipeline input: false
- Accept wildcard characters: false

### AllowUsersRunIndependently

Allows users to run the task sequence independently of the deployment assignment.
Maps to the AllowUsersRunIndependently or PresentUsers property in SMS_Advertisement.

- Type: Boolean
- Required: false
- Default value: False
- Accept pipeline input: false
- Accept wildcard characters: false

### Force

Suppresses confirmation prompts.

- Type: SwitchParameter
- Required: false
- Default value: False
- Accept pipeline input: false
- Accept wildcard characters: false

### WhatIf

Shows what would happen if the cmdlet runs. The cmdlet is not run.

- Type: SwitchParameter
- Required: false
- Accept pipeline input: false
- Accept wildcard characters: false

### Confirm

Prompts you for confirmation before running the cmdlet.

- Type: SwitchParameter
- Required: false
- Accept pipeline input: false
- Accept wildcard characters: false

## EXAMPLES

### Example 1

```powershell
New-CM7TaskSequenceDeployment -CollectionName "Test-Collection-Direct" -TaskSequencePackageId "SD100FAD" -AvailableDateTime (Get-Date) -Force
            Creates an available task sequence deployment targeting the specified collection.
```

### Example 2

```powershell
New-CM7TaskSequenceDeployment -TaskSequenceName "Test Josh" -CollectionName "Test-Collection-Direct" -Force
            Creates an available task sequence deployment using the task sequence name.
```

### Example 3

```powershell
New-CM7TaskSequenceDeployment -TaskSequencePackageId "SD100FAD" -CollectionName "Test-Collection-Direct" -DeployPurpose Required -Force
            Creates a required (mandatory) task sequence deployment.
```

### Example 4

```powershell
New-CM7TaskSequenceDeployment -TaskSequencePackageId "SD100FAD" -CollectionId "SD101C00" -DeploymentName "Custom Deployment Name" -Comment "Monthly OS deployment" -Force
            Creates a deployment using PackageID and collection ID with a custom name and comment.
```

### Example 5

```powershell
New-CM7TaskSequenceDeployment -TaskSequencePackageId "SD100FAD" -CollectionName "Test-Collection-Direct" -WhatIf
            Shows what would happen without actually creating the deployment.
```

### Example 6

```powershell
New-CM7TaskSequenceDeployment -TaskSequencePackageId "SD100FAD" -CollectionName "Test-Collection-Direct" -DeployPurpose Required -DeadlineDateTime (Get-Date).AddDays(7) -Force
            Creates a required deployment with a 7-day enforcement deadline.
```

### Example 7

```powershell
New-CM7TaskSequenceDeployment -TaskSequencePackageId "SD100FAD" -CollectionName "Test-Collection-Direct" -SoftwareInstallation $false -SystemRestart $false -Force
            Creates a deployment that does not allow installation or restart outside of maintenance windows.
```

### Example 8

```powershell
New-CM7TaskSequenceDeployment -TaskSequencePackageId "SD100FAD" -CollectionName "Test-Collection-Direct" -ShowTaskSequenceProgress $true -Force
            Creates a deployment with task sequence progress displayed to the user.
```

### Example 9

```powershell
New-CM7TaskSequenceDeployment -TaskSequencePackageId "SD100FAD" -CollectionName "Test-Collection-Direct" `
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
                -Force
            Creates a fully configured required task sequence deployment.
```

## NOTES

Requires an active connection established via Connect-CM7.

The SMS_Advertisement WMI class is used to represent task sequence deployments in MECM.
Task sequence deployments are distinguished from other deployments by ProgramName = '*'.

This function is the CIM-based equivalent of the New-CMTaskSequenceDeployment cmdlet
from the ConfigurationManager PowerShell module but uses direct CIM queries
over WinRM instead of requiring the ConfigMgr console or PowerShell drive.

AdvertFlags and RemoteClientFlags are computed from the specified parameters to match
the behavior of the native New-CMTaskSequenceDeployment cmdlet. The default parameter
values produce the same flag values as the native cmdlet with default settings:
AdvertFlags = 0x8b0000 (9109504), RemoteClientFlags = 0x8850 (34896).
