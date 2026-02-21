# Set-CM7TaskSequenceDeployment

## SYNOPSIS

Configures an existing task sequence deployment in MECM using CIM.

## DESCRIPTION

`Set-CM7TaskSequenceDeployment` updates one or more existing task sequence deployments (`SMS_Advertisement` with `ProgramName = '*'`) through CIM/WinRM.

This function is the CIM-based equivalent of `Set-CMTaskSequenceDeployment` from the ConfigurationManager module.

Supported scenarios include:
- update by deployment ID (`-TaskSequenceDeploymentId`)
- update by input object (`-InputObject` / pipeline)
- update by task sequence (`-TaskSequenceName` or `-TaskSequencePackageId`) with optional collection targeting
- update common deployment behavior flags, timing, and schedule event flags

For compatibility, schedule token parameters are exposed (`-ClearSchedule`, `-Schedule`, `-AddSchedule`, `-RemoveSchedule`) but are currently not supported in this CIM implementation.

## PARAMETERS

### -InputObject
Task sequence deployment object to update. Must contain `AdvertisementID`.

### -TaskSequenceDeploymentId
Deployment ID (`AdvertisementID`) to update.

### -TaskSequenceName
Task sequence name used to locate deployments.

### -TaskSequencePackageId
Task sequence package ID used to locate deployments.

### -Collection
Collection object used to target deployments and/or change target collection.

### -CollectionId
Collection ID used to target deployments and/or change target collection.

### -CollectionName
Collection name used to target deployments and/or change target collection.

### -AlertDateTime
Alert date/time (best-effort CIM mapping).

### -AllowFallback
Allow fallback source for content.

### -AllowSharedContent
Allow shared content behavior.

### -AllowUsersRunIndependently
Allow users to run independently (best-effort CIM mapping).

### -Comment
Deployment comment.

### -CreateAlertOnFailure
Create alert on failure (best-effort CIM mapping).

### -CreateAlertOnSuccess
Create alert on success (best-effort CIM mapping).

### -DeploymentAvailableDateTime
Sets deployment available date/time.

### -DeploymentExpireDateTime
Sets deployment expiration date/time.

### -DeploymentOption
Content behavior. Accepted values:
- `DownloadContentLocallyWhenNeededByRunningTaskSequence`
- `DownloadAllContentLocallyBeforeStartingTaskSequence`
- `RunFromDistributionPoint`

### -InternetOption
Allow deployment on internet clients.

### -MakeAvailableTo
Availability target. Accepted values:
- `Clients`
- `ClientsMediaAndPxe`
- `MediaAndPxe`
- `MediaAndPxeHidden`

### -PercentFailure
Failure threshold percentage (best-effort CIM mapping).

### -PercentSuccess
Success threshold percentage (best-effort CIM mapping).

### -PersistOnWriteFilterDevice
Persist content on write filter devices.

### -RerunBehavior
Rerun behavior. Accepted values:
- `NeverRerunDeployedProgram`
- `AlwaysRerunProgram`
- `RerunIfFailedPreviousAttempt`
- `RerunIfSucceededOnPreviousAttempt`

### -ClearSchedule
Declared for compatibility. Not supported in current CIM implementation.

### -RemoveSchedule
Declared for compatibility. Not supported in current CIM implementation.

### -AddSchedule
Declared for compatibility. Not supported in current CIM implementation.

### -Schedule
Declared for compatibility. Not supported in current CIM implementation.

### -ClearScheduleEvent
Clears schedule event flags (`AsSoonAsPossible`, `LogOn`, `LogOff`).

### -RemoveScheduleEvent
Removes one or more schedule event flags.

### -AddScheduleEvent
Adds one or more schedule event flags.

### -ScheduleEvent
Sets schedule event flags exactly to provided values.

### -SendWakeupPacket
Enable/disable Wake On LAN for deployment.

### -ShowTaskSequenceProgress
Show/hide task sequence progress UI.

### -SoftwareInstallation
Allow/disallow install outside maintenance windows.

### -SystemRestart
Allow/disallow restart outside maintenance windows.

### -UseMeteredNetwork
Allow/disallow metered network usage.

### -UseUtcForAvailableSchedule
Set available schedule to UTC/local semantics.

### -UseUtcForExpireSchedule
Set expire schedule to UTC/local semantics.

### -PassThru
Returns updated deployment object(s).

### -DisableWildcardHandling
Treat wildcard characters as literals for collection-name filtering.

### -ForceWildcardHandling
Force wildcard processing for collection-name filtering.

### -Force
Suppress confirmation prompts.

## EXAMPLES

### Example 1: Update by deployment ID

```powershell
Set-CM7TaskSequenceDeployment -TaskSequenceDeploymentId "SD120BD2" -Comment "Updated by automation" -ShowTaskSequenceProgress $true -PassThru
```

### Example 2: Update from pipeline object

```powershell
Get-CM7TaskSequenceDeployment -AdvertisementID "SD120BD2" |
    Set-CM7TaskSequenceDeployment -UseMeteredNetwork $false -AllowFallback $true -PassThru
```

### Example 3: Update by task sequence package and collection

```powershell
Set-CM7TaskSequenceDeployment -TaskSequencePackageId "SD100FAD" -CollectionName "Test-Collection-Direct" -DeploymentOption RunFromDistributionPoint -Force
```

## NOTES

- Requires an active connection created with `Connect-CM7`.
- Works over CIM/WinRM and does not require the ConfigurationManager PowerShell drive.

## RELATED LINKS

- [Get-CM7TaskSequenceDeployment](./Get-CM7TaskSequenceDeployment.md)
- [New-CM7TaskSequenceDeployment](./New-CM7TaskSequenceDeployment.md)
- [Remove-CM7TaskSequenceDeployment](./Remove-CM7TaskSequenceDeployment.md)
- [Connect-CM7](./Connect-CM7.md)
