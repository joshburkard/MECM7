# New-CM7SoftwareUpdateDeployment

## SYNOPSIS

Creates a new software update deployment in MECM using CIM.

## DESCRIPTION

Creates a new software update deployment (SMS_UpdateGroupAssignment) in Microsoft Endpoint
Configuration Manager (MECM) using CIM. A software update deployment assigns a software
update group to a target collection, defining how and when the updates are installed.

This is the CIM-based equivalent of the New-CMSoftwareUpdateDeployment cmdlet from the
ConfigurationManager PowerShell module, but uses direct CIM queries over WinRM
instead of requiring the ConfigMgr console or PowerShell drive.

The function performs the following actions:
1. Validates an active connection exists (established via Connect-CM7)
2. Resolves the software update group by name or CI_ID
3. Resolves the target collection by name or ID
4. Creates a new SMS_UpdateGroupAssignment instance via CIM with the specified deployment settings
5. Returns the created deployment as a formatted MECM7.SoftwareUpdateDeployment object

## PARAMETERS

### SoftwareUpdateGroupName

The name of the software update group to deploy.
Mutually exclusive with SoftwareUpdateGroupId.

- Type: String
- Required: true
- Accept pipeline input: false
- Accept wildcard characters: false

### SoftwareUpdateGroupId

The CI_ID of the software update group to deploy.
Mutually exclusive with SoftwareUpdateGroupName.

- Type: Int32
- Required: true
- Default value: 0
- Accept pipeline input: false
- Accept wildcard characters: false

### CollectionName

The name of the target collection for the deployment.
Mutually exclusive with CollectionId.

- Type: String
- Required: true
- Accept pipeline input: false
- Accept wildcard characters: false

### CollectionId

The ID of the target collection for the deployment (e.g., "CM101C00").
Mutually exclusive with CollectionName.

- Type: String
- Required: true
- Accept pipeline input: false
- Accept wildcard characters: false

### DeploymentName

An optional name for the deployment (AssignmentName). If not specified,
defaults to the software update group name.

- Type: String
- Required: false
- Accept pipeline input: false
- Accept wildcard characters: false

### Description

An optional description for the deployment (AssignmentDescription).

- Type: String
- Required: false
- Accept pipeline input: false
- Accept wildcard characters: false

### DeploymentType

The deployment type. Valid values are:
- Required: Forces installation by the enforcement deadline.
- Available: Makes updates available for optional installation.
Defaults to Required.

- Type: String
- Required: false
- Default value: Required
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

The enforcement deadline date and time. After this time, the client will
force installation of required deployments. Only used with DeploymentType Required.

- Type: DateTime
- Required: false
- Accept pipeline input: false
- Accept wildcard characters: false

### UserNotification

Controls user notification behavior. Valid values are:
- DisplayAll: Show all notifications (default)
- DisplaySoftwareCenterOnly: Show only in Software Center
- HideAll: Hide all notifications

- Type: String
- Required: false
- Default value: DisplayAll
- Accept pipeline input: false
- Accept wildcard characters: false

### SoftwareInstallation

Allows installation outside of maintenance windows. Default is $false.

- Type: Boolean
- Required: false
- Default value: False
- Accept pipeline input: false
- Accept wildcard characters: false

### AllowRestart

Allows system restart outside of maintenance windows. Default is $false.

- Type: Boolean
- Required: false
- Default value: False
- Accept pipeline input: false
- Accept wildcard characters: false

### RestartServer

Suppresses restart on servers when $false. Default is $true (allows restart).

- Type: Boolean
- Required: false
- Default value: True
- Accept pipeline input: false
- Accept wildcard characters: false

### RestartWorkstation

Suppresses restart on workstations when $false. Default is $true (allows restart).

- Type: Boolean
- Required: false
- Default value: True
- Accept pipeline input: false
- Accept wildcard characters: false

### RequirePostRebootFullScan

Requires a full scan of software updates after a restart. Default is $false.

- Type: Boolean
- Required: false
- Default value: False
- Accept pipeline input: false
- Accept wildcard characters: false

### ProtectedType

Defines behavior for clients on protected distribution points. Valid values are:
- NoInstall: Do not install software updates (default)
- RemoteDistributionPoint: Install from a remote distribution point

- Type: String
- Required: false
- Default value: NoInstall
- Accept pipeline input: false
- Accept wildcard characters: false

### UnprotectedType

Defines behavior for clients on unprotected distribution points. Valid values are:
- NoInstall: Do not install software updates
- UnprotectedDistributionPoint: Install from an unprotected distribution point (default)

- Type: String
- Required: false
- Default value: UnprotectedDistributionPoint
- Accept pipeline input: false
- Accept wildcard characters: false

### UseBranchCache

Enables BranchCache for the deployment. Default is $false.

- Type: Boolean
- Required: false
- Default value: False
- Accept pipeline input: false
- Accept wildcard characters: false

### DownloadFromMicrosoftUpdate

Allows clients to download from Microsoft Update if content is unavailable
on distribution points. Default is $false.

- Type: Boolean
- Required: false
- Default value: False
- Accept pipeline input: false
- Accept wildcard characters: false

### UseGMTTimes

Specifies whether to use UTC/GMT times. Default is $false (use local time).

- Type: Boolean
- Required: false
- Default value: False
- Accept pipeline input: false
- Accept wildcard characters: false

### Enabled

Whether the deployment is enabled. Default is $true.

- Type: Boolean
- Required: false
- Default value: True
- Accept pipeline input: false
- Accept wildcard characters: false

### VerbosityLevel

Controls the verbosity of state messages reported by clients. Valid values are:
- AllMessages: Report all messages
- OnlySuccessAndErrorMessages: Report only success and error messages (default)
- OnlyErrorMessages: Report only error messages

- Type: String
- Required: false
- Default value: OnlySuccessAndErrorMessages
- Accept pipeline input: false
- Accept wildcard characters: false

### AcceptEula

When $true, automatically accepts any End User License Agreements (EULAs) for software
updates in the group that have EulaExists = $true and have not yet been accepted.
This calls the AcceptEULA() instance method on each qualifying SMS_SoftwareUpdate object
before the deployment is created. Default is $false.

- Type: Boolean
- Required: false
- Default value: False
- Accept pipeline input: false
- Accept wildcard characters: false

### DisableOperationsManagerAlert

Disables Operations Manager (MOM/SCOM) alerts during the deployment. Default is $false.

- Type: Boolean
- Required: false
- Default value: False
- Accept pipeline input: false
- Accept wildcard characters: false

### PersistOnWriteFilterDevice

Enables the write filter committal on devices that use a write filter (e.g., embedded
devices). When $true, changes are committed to the device. Default is $true.

- Type: Boolean
- Required: false
- Default value: True
- Accept pipeline input: false
- Accept wildcard characters: false

### PreDownloadUpdateContent

Pre-downloads update content before the deployment deadline. Default is $false.

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
New-CM7SoftwareUpdateDeployment -SoftwareUpdateGroupName "Test-SUG" -CollectionName "Test-Collection-Direct" -Force
            Creates a required software update deployment targeting the specified collection.
```

### Example 2

```powershell
New-CM7SoftwareUpdateDeployment -SoftwareUpdateGroupName "Test-SUG" -CollectionName "Test-Collection-Direct" -DeploymentType Available -Force
            Creates an available (optional) software update deployment.
```

### Example 3

```powershell
New-CM7SoftwareUpdateDeployment -SoftwareUpdateGroupName "Test-SUG" -CollectionName "Test-Collection-Direct" -DeadlineDateTime (Get-Date).AddDays(7) -Force
            Creates a required deployment with a 7-day enforcement deadline.
```

### Example 4

```powershell
New-CM7SoftwareUpdateDeployment -SoftwareUpdateGroupId 17129359 -CollectionId "CM101C00" -DeploymentName "Custom Deployment Name" -Description "Monthly patching" -Force
            Creates a deployment using CI_ID and collection ID with a custom name and description.
```

### Example 5

```powershell
New-CM7SoftwareUpdateDeployment -SoftwareUpdateGroupName "Test-SUG" -CollectionName "Test-Collection-Direct" -WhatIf
            Shows what would happen without actually creating the deployment.
```

## NOTES

Requires an active connection established via Connect-CM7.

The SMS_UpdateGroupAssignment WMI class is used to represent software update deployments in MECM.

This function is the CIM-based equivalent of the New-CMSoftwareUpdateDeployment cmdlet
from the ConfigurationManager PowerShell module but uses direct CIM queries
over WinRM instead of requiring the ConfigMgr console or PowerShell drive.
