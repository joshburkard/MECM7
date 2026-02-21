function Set-CM7TaskSequenceDeployment {
    <#
        .SYNOPSIS
            Configures an existing task sequence deployment in MECM using CIM.

        .DESCRIPTION
            Updates one or more existing task sequence deployments (SMS_Advertisement with ProgramName = '*')
            in Microsoft Endpoint Configuration Manager (MECM) using CIM.

            This is the CIM-based equivalent of the Set-CMTaskSequenceDeployment cmdlet from the
            ConfigurationManager PowerShell module, but uses direct CIM queries over WinRM.

            Supported update scenarios:
            - Update by deployment ID
            - Update by deployment input object (including pipeline)
            - Update by task sequence name/package ID with optional collection targeting
            - Update deployment flags and common scheduling/time settings

            Parameters related to full schedule-token manipulation (AddSchedule/RemoveSchedule/Schedule/ClearSchedule)
            are declared for compatibility but are currently not supported in this CIM implementation.

        .PARAMETER InputObject
            Task sequence deployment object to update. Must contain AdvertisementID.

        .PARAMETER TaskSequenceDeploymentId
            AdvertisementID (deployment ID) of the task sequence deployment to update.

        .PARAMETER TaskSequenceName
            Task sequence name used to locate deployments to update.

        .PARAMETER TaskSequencePackageId
            Task sequence package ID used to locate deployments to update.

        .PARAMETER Collection
            Collection object used to target deployments and/or set target collection.

        .PARAMETER CollectionId
            Collection ID used to target deployments and/or set target collection.

        .PARAMETER CollectionName
            Collection name used to target deployments and/or set target collection.

        .PARAMETER AlertDateTime
            Alert date time. Best-effort property mapping in CIM.

        .PARAMETER AllowFallback
            Allow fallback source location for content.

        .PARAMETER AllowSharedContent
            Allow shared content (peer cache/BranchCache equivalent behavior).

        .PARAMETER AllowUsersRunIndependently
            Allow users to run independently. Best-effort property mapping in CIM.

        .PARAMETER Comment
            Deployment comment.

        .PARAMETER CreateAlertOnFailure
            Create alert on failure. Best-effort property mapping in CIM.

        .PARAMETER CreateAlertOnSuccess
            Create alert on success. Best-effort property mapping in CIM.

        .PARAMETER DeploymentAvailableDateTime
            Deployment available date/time.

        .PARAMETER DeploymentExpireDateTime
            Deployment expiration date/time.

        .PARAMETER DeploymentOption
            Content download behavior.

        .PARAMETER InternetOption
            Allow internet clients.

        .PARAMETER MakeAvailableTo
            Controls deployment availability target (clients/media/pxe).

        .PARAMETER PercentFailure
            Failure alert threshold percentage. Best-effort property mapping in CIM.

        .PARAMETER PercentSuccess
            Success alert threshold percentage. Best-effort property mapping in CIM.

        .PARAMETER PersistOnWriteFilterDevice
            Persist content on write filter devices.

        .PARAMETER RerunBehavior
            Rerun behavior for the task sequence deployment.

        .PARAMETER ClearSchedule
            Declared for compatibility. Not supported in this CIM implementation.

        .PARAMETER RemoveSchedule
            Declared for compatibility. Not supported in this CIM implementation.

        .PARAMETER AddSchedule
            Declared for compatibility. Not supported in this CIM implementation.

        .PARAMETER Schedule
            Declared for compatibility. Not supported in this CIM implementation.

        .PARAMETER ClearScheduleEvent
            Clear all schedule event flags (AsSoonAsPossible, LogOn, LogOff).

        .PARAMETER RemoveScheduleEvent
            Remove one or more schedule events.

        .PARAMETER AddScheduleEvent
            Add one or more schedule events.

        .PARAMETER ScheduleEvent
            Set schedule event flags exactly to the specified values.

        .PARAMETER SendWakeupPacket
            Send wake-up packet before deployment.

        .PARAMETER ShowTaskSequenceProgress
            Show task sequence progress.

        .PARAMETER SoftwareInstallation
            Allow software installation outside maintenance windows.

        .PARAMETER SystemRestart
            Allow system restart outside maintenance windows.

        .PARAMETER UseMeteredNetwork
            Allow use on metered network.

        .PARAMETER UseUtcForAvailableSchedule
            Use UTC for available schedule.

        .PARAMETER UseUtcForExpireSchedule
            Use UTC for expire schedule.

        .PARAMETER PassThru
            Return updated deployment object(s).

        .PARAMETER DisableWildcardHandling
            Treat wildcard characters as literals in CollectionName filtering.

        .PARAMETER ForceWildcardHandling
            Force wildcard handling for CollectionName filtering.

        .PARAMETER Force
            Suppress confirmation prompts.

        .EXAMPLE
            Set-CM7TaskSequenceDeployment -TaskSequenceDeploymentId "SD120BD2" -Comment "Updated by automation" -ShowTaskSequenceProgress $true -PassThru

        .EXAMPLE
            Get-CM7TaskSequenceDeployment -AdvertisementID "SD120BD2" | Set-CM7TaskSequenceDeployment -UseMeteredNetwork $false -PassThru

        .EXAMPLE
            Set-CM7TaskSequenceDeployment -TaskSequencePackageId "SD100FAD" -CollectionName "Test-Collection-Direct" -AllowFallback $true -DeploymentOption RunFromDistributionPoint

        .NOTES
            Requires an active connection established via Connect-CM7.
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High', DefaultParameterSetName = 'ByDeploymentId')]
    param(
        [Parameter(ParameterSetName = 'ByInputObject', Mandatory = $true, ValueFromPipeline = $true)]
        [Alias('Deployment', 'DeploymentSummary', 'TaskSequence', 'Advertisement')]
        [ValidateNotNull()]
        [PSObject]$InputObject,

        [Parameter(ParameterSetName = 'ByDeploymentId', Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$TaskSequenceDeploymentId,

        [Parameter(ParameterSetName = 'ByTaskSequenceName', Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$TaskSequenceName,

        [Parameter(ParameterSetName = 'ByTaskSequencePackageId', Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$TaskSequencePackageId,

        [Parameter()]
        [PSObject]$Collection,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$CollectionId,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$CollectionName,

        [Parameter()]
        [datetime]$AlertDateTime,

        [Parameter()]
        [Boolean]$AllowFallback,

        [Parameter()]
        [Boolean]$AllowSharedContent,

        [Parameter()]
        [Boolean]$AllowUsersRunIndependently,

        [Parameter()]
        [string]$Comment,

        [Parameter()]
        [Boolean]$CreateAlertOnFailure,

        [Parameter()]
        [Boolean]$CreateAlertOnSuccess,

        [Parameter()]
        [datetime]$DeploymentAvailableDateTime,

        [Parameter()]
        [datetime]$DeploymentExpireDateTime,

        [Parameter()]
        [ValidateSet('DownloadContentLocallyWhenNeededByRunningTaskSequence', 'DownloadAllContentLocallyBeforeStartingTaskSequence', 'RunFromDistributionPoint')]
        [string]$DeploymentOption,

        [Parameter()]
        [Boolean]$InternetOption,

        [Parameter()]
        [ValidateSet('Clients', 'ClientsMediaAndPxe', 'MediaAndPxe', 'MediaAndPxeHidden')]
        [string]$MakeAvailableTo,

        [Parameter()]
        [ValidateRange(0, 100)]
        [int]$PercentFailure,

        [Parameter()]
        [ValidateRange(0, 100)]
        [int]$PercentSuccess,

        [Parameter()]
        [Boolean]$PersistOnWriteFilterDevice,

        [Parameter()]
        [ValidateSet('NeverRerunDeployedProgram', 'AlwaysRerunProgram', 'RerunIfFailedPreviousAttempt', 'RerunIfSucceededOnPreviousAttempt')]
        [string]$RerunBehavior,

        [Parameter()]
        [switch]$ClearSchedule,

        [Parameter()]
        [PSObject[]]$RemoveSchedule,

        [Parameter()]
        [PSObject[]]$AddSchedule,

        [Parameter()]
        [PSObject[]]$Schedule,

        [Parameter()]
        [switch]$ClearScheduleEvent,

        [Parameter()]
        [ValidateSet('AsSoonAsPossible', 'LogOn', 'LogOff')]
        [string[]]$RemoveScheduleEvent,

        [Parameter()]
        [ValidateSet('AsSoonAsPossible', 'LogOn', 'LogOff')]
        [string[]]$AddScheduleEvent,

        [Parameter()]
        [ValidateSet('AsSoonAsPossible', 'LogOn', 'LogOff')]
        [string[]]$ScheduleEvent,

        [Parameter()]
        [Boolean]$SendWakeupPacket,

        [Parameter()]
        [Boolean]$ShowTaskSequenceProgress,

        [Parameter()]
        [Boolean]$SoftwareInstallation,

        [Parameter()]
        [Boolean]$SystemRestart,

        [Parameter()]
        [Boolean]$UseMeteredNetwork,

        [Parameter()]
        [Boolean]$UseUtcForAvailableSchedule,

        [Parameter()]
        [Boolean]$UseUtcForExpireSchedule,

        [Parameter()]
        [switch]$PassThru,

        [Parameter()]
        [switch]$DisableWildcardHandling,

        [Parameter()]
        [switch]$ForceWildcardHandling,

        [Parameter()]
        [switch]$Force
    )

    begin {
        $function = $($MyInvocation.MyCommand.Name)
        Write-Verbose "Running $function"

        if (-not $script:CMConnection.CimSession) {
            throw "Not connected to MECM. Please run Connect-CM7 first."
        }

        if ($DisableWildcardHandling -and $ForceWildcardHandling) {
            throw "DisableWildcardHandling and ForceWildcardHandling cannot be used together."
        }

        if ($ClearSchedule -or $Schedule -or $AddSchedule -or $RemoveSchedule) {
            throw "Schedule token manipulation parameters (ClearSchedule, Schedule, AddSchedule, RemoveSchedule) are currently not supported in this CIM implementation."
        }

        $namespace = "root/SMS/site_$($script:CMConnection.SiteCode)"
        $cimParams = @{
            CimSession = $script:CMConnection.CimSession
            Namespace  = $namespace
        }

        $ADVERT_IMMEDIATE                      = [uint32]0x00000020
        $ADVERT_ONUSERLOGON                    = [uint32]0x00000200
        $ADVERT_ONUSERLOGOFF                   = [uint32]0x00000400
        $ADVERT_ENABLE_TS_FROM_CD_AND_PXE      = [uint32]0x00002000
        $ADVERT_NO_DISPLAY                     = [uint32]0x00008000
        $ADVERT_OVERRIDE_SERVICE_WINDOWS       = [uint32]0x00010000
        $ADVERT_REBOOT_OUTSIDE_SERVICE_WINDOWS = [uint32]0x00020000
        $ADVERT_WAKE_ON_LAN                    = [uint32]0x00040000
        $ADVERT_DONOT_FALLBACK                 = [uint32]0x00080000
        $ADVERT_SHOW_PROGRESS                  = [uint32]0x02000000

        $RCF_DOWNLOAD_FROM_REMOTE_DP           = [uint32]0x00000002
        $RCF_DONT_RUN_NO_LOCAL_DP              = [uint32]0x00000004
        $RCF_ALLOW_SHARED_CONTENT              = [uint32]0x00000010
        $RCF_ALWAYS_RERUN                      = [uint32]0x00000020
        $RCF_RERUN_IF_FAILED                   = [uint32]0x00000040
        $RCF_RERUN_IF_SUCCEEDED                = [uint32]0x00000080
        $RCF_PERSIST_ON_WRITE_FILTER           = [uint32]0x00000400
        $RCF_ALLOW_INTERNET_CLIENTS            = [uint32]0x00000800
        $RCF_TS_SHOW_PROGRESS                  = [uint32]0x00004000
        $RCF_USE_METERED_NETWORK               = [uint32]0x00008000

        $collectionLookup = @{}
        $deploymentIdList = New-Object System.Collections.Generic.List[string]
    }

    process {
        try {
            $resolvedCollections = @()

            if ($Collection) {
                $collectionObjectId = $null
                if ($Collection.PSObject.Properties['CollectionID']) {
                    $collectionObjectId = [string]$Collection.CollectionID
                }
                elseif ($Collection.PSObject.Properties['CollectionId']) {
                    $collectionObjectId = [string]$Collection.CollectionId
                }

                if ($collectionObjectId) {
                    $resolvedCollections = @(Get-CM7Collection -CollectionId $collectionObjectId -CollectionType Device)
                }
                elseif ($Collection.PSObject.Properties['Name']) {
                    $CollectionName = [string]$Collection.Name
                }
                else {
                    throw "Collection object must have CollectionID/CollectionId or Name property."
                }
            }

            if (-not $resolvedCollections -and $CollectionId) {
                $resolvedCollections = @(Get-CM7Collection -CollectionId $CollectionId -CollectionType Device)
            }

            if (-not $resolvedCollections -and $CollectionName) {
                if ($DisableWildcardHandling) {
                    $resolvedCollections = @(Get-CM7Collection -Name $CollectionName -CollectionType Device | Where-Object { $_.Name -eq $CollectionName })
                }
                elseif ($ForceWildcardHandling) {
                    $collectionPattern = if ($CollectionName -match '[\*\?]') { $CollectionName } else { "*$CollectionName*" }
                    $resolvedCollections = @(Get-CM7Collection -Name $collectionPattern -CollectionType Device)
                }
                else {
                    $resolvedCollections = @(Get-CM7Collection -Name $CollectionName -CollectionType Device)
                }
            }

            if (($Collection -or $CollectionId -or $CollectionName) -and (-not $resolvedCollections -or $resolvedCollections.Count -eq 0)) {
                $collectionIdentifier = if ($CollectionName) { $CollectionName } elseif ($CollectionId) { $CollectionId } else { '<collection object>' }
                throw "Device collection '$collectionIdentifier' not found."
            }

            foreach ($c in $resolvedCollections) {
                $resolvedCollectionId = if ($c.PSObject.Properties['CollectionID']) { $c.CollectionID } else { $c.CollectionId }
                $collectionLookup[[string]$resolvedCollectionId] = $c.Name
            }

            switch ($PSCmdlet.ParameterSetName) {
                'ByInputObject' {
                    $id = $null
                    if ($InputObject.PSObject.Properties['AdvertisementID']) {
                        $id = [string]$InputObject.AdvertisementID
                    }
                    if (-not $id) {
                        throw "InputObject does not have an AdvertisementID property."
                    }
                    $deploymentIdList.Add($id)
                }

                'ByDeploymentId' {
                    $deploymentIdList.Add($TaskSequenceDeploymentId)
                }

                'ByTaskSequenceName' {
                    $tsQuery = "SELECT PackageID, Name FROM SMS_TaskSequencePackage WHERE Name = '$TaskSequenceName'"
                    $tsRows = @(Get-CimInstance @cimParams -Query $tsQuery)
                    if (-not $tsRows) {
                        throw "Task sequence '$TaskSequenceName' not found."
                    }
                    if ($tsRows.Count -gt 1) {
                        throw "Multiple task sequences found matching '$TaskSequenceName'. Please use -TaskSequencePackageId."
                    }

                    $resolvedPkgId = [string]$tsRows[0].PackageID
                    $advFilter = @("ProgramName = '*'", "PackageID = '$resolvedPkgId'")
                    if ($resolvedCollections.Count -gt 0) {
                        $orClauses = $resolvedCollections | ForEach-Object {
                            $resolvedCollectionId = if ($_.PSObject.Properties['CollectionID']) { $_.CollectionID } else { $_.CollectionId }
                            "CollectionID = '$resolvedCollectionId'"
                        }
                        $advFilter += "(" + ($orClauses -join ' OR ') + ")"
                    }

                    $advQuery = "SELECT AdvertisementID FROM SMS_Advertisement WHERE " + ($advFilter -join ' AND ')
                    $advRows = @(Get-CimInstance @cimParams -Query $advQuery)
                    if (-not $advRows) {
                        throw "No task sequence deployments found for task sequence '$TaskSequenceName'."
                    }
                    foreach ($r in $advRows) {
                        $deploymentIdList.Add([string]$r.AdvertisementID)
                    }
                }

                'ByTaskSequencePackageId' {
                    $tsCheckQuery = "SELECT PackageID, Name FROM SMS_TaskSequencePackage WHERE PackageID = '$TaskSequencePackageId'"
                    $tsCheck = @(Get-CimInstance @cimParams -Query $tsCheckQuery)
                    if (-not $tsCheck) {
                        throw "Task sequence with PackageID '$TaskSequencePackageId' not found."
                    }
                    $advFilter = @("ProgramName = '*'", "PackageID = '$TaskSequencePackageId'")
                    if ($resolvedCollections.Count -gt 0) {
                        $orClauses = $resolvedCollections | ForEach-Object {
                            $resolvedCollectionId = if ($_.PSObject.Properties['CollectionID']) { $_.CollectionID } else { $_.CollectionId }
                            "CollectionID = '$resolvedCollectionId'"
                        }
                        $advFilter += "(" + ($orClauses -join ' OR ') + ")"
                    }

                    $advQuery = "SELECT AdvertisementID FROM SMS_Advertisement WHERE " + ($advFilter -join ' AND ')
                    $advRows = @(Get-CimInstance @cimParams -Query $advQuery)
                    if (-not $advRows) {
                        throw "No task sequence deployments found for PackageID '$TaskSequencePackageId'."
                    }
                    foreach ($r in $advRows) {
                        $deploymentIdList.Add([string]$r.AdvertisementID)
                    }
                }
            }

            $targetIds = @($deploymentIdList | Select-Object -Unique)
            if (-not $targetIds -or $targetIds.Count -eq 0) {
                throw "No task sequence deployment targets were resolved."
            }

            foreach ($advId in $targetIds) {
                # Explicit non-lazy property list avoids HRESULT 0x80041001 from Set-CimInstance.
                # SMS_Advertisement lazy properties (AssignedSchedule*, PresentTimeEnabled,
                # PresentTimeIsGMT, ExpirationTimeEnabled, ExpirationTimeIsGMT, TimeFlags) cause
                # the provider to reject ModifyInstance when the full instance is sent back.
                # Use SELECT * so the CimInstance contains all properties (including lazy ones) with their
                # real values. This is required for Required deployments: the provider validates that
                # AssignedSchedule/AssignedScheduleEnabled are non-null on any ModifyInstance call, and
                # a partial SELECT would leave those as null, causing HRESULT 0x80041001.
                $getAdvQuery = "SELECT * FROM SMS_Advertisement WHERE AdvertisementID = '$advId' AND ProgramName = '*'"
                $deployment = @(Get-CimInstance @cimParams -Query $getAdvQuery)[0]
                if (-not $deployment) {
                    throw "Task sequence deployment with AdvertisementID '$advId' was not found."
                }

                $displayName = "$($deployment.AdvertisementName) ($($deployment.AdvertisementID))"
                $actionDescription = "Update task sequence deployment '$($deployment.AdvertisementName)' ($($deployment.AdvertisementID))"

                if (-not ($Force -or $PSCmdlet.ShouldProcess($displayName, $actionDescription))) {
                    continue
                }

                [uint32]$advertFlags = [uint32]$deployment.AdvertFlags
                [uint32]$remoteClientFlags = [uint32]$deployment.RemoteClientFlags
                [uint32]$origAdvertFlags = $advertFlags
                [uint32]$origRemoteClientFlags = $remoteClientFlags

                if ($PSBoundParameters.ContainsKey('AllowFallback')) {
                    if ($AllowFallback) {
                        $advertFlags = $advertFlags -band (-bnot $ADVERT_DONOT_FALLBACK)
                    } else {
                        $advertFlags = $advertFlags -bor $ADVERT_DONOT_FALLBACK
                    }
                }

                if ($PSBoundParameters.ContainsKey('SoftwareInstallation')) {
                    if ($SoftwareInstallation) {
                        $advertFlags = $advertFlags -bor $ADVERT_OVERRIDE_SERVICE_WINDOWS
                    } else {
                        $advertFlags = $advertFlags -band (-bnot $ADVERT_OVERRIDE_SERVICE_WINDOWS)
                    }
                }

                if ($PSBoundParameters.ContainsKey('SystemRestart')) {
                    if ($SystemRestart) {
                        $advertFlags = $advertFlags -bor $ADVERT_REBOOT_OUTSIDE_SERVICE_WINDOWS
                    } else {
                        $advertFlags = $advertFlags -band (-bnot $ADVERT_REBOOT_OUTSIDE_SERVICE_WINDOWS)
                    }
                }

                if ($PSBoundParameters.ContainsKey('SendWakeupPacket')) {
                    if ($SendWakeupPacket) {
                        $advertFlags = $advertFlags -bor $ADVERT_WAKE_ON_LAN
                    } else {
                        $advertFlags = $advertFlags -band (-bnot $ADVERT_WAKE_ON_LAN)
                    }
                }

                if ($PSBoundParameters.ContainsKey('ShowTaskSequenceProgress')) {
                    if ($ShowTaskSequenceProgress) {
                        $advertFlags = $advertFlags -bor $ADVERT_SHOW_PROGRESS
                        $remoteClientFlags = $remoteClientFlags -bor $RCF_TS_SHOW_PROGRESS
                    } else {
                        $advertFlags = $advertFlags -band (-bnot $ADVERT_SHOW_PROGRESS)
                        $remoteClientFlags = $remoteClientFlags -band (-bnot $RCF_TS_SHOW_PROGRESS)
                    }
                }

                if ($PSBoundParameters.ContainsKey('MakeAvailableTo')) {
                    $advertFlags = $advertFlags -band (-bnot ($ADVERT_ENABLE_TS_FROM_CD_AND_PXE -bor $ADVERT_NO_DISPLAY))
                    switch ($MakeAvailableTo) {
                        'Clients' { }
                        'ClientsMediaAndPxe' { $advertFlags = $advertFlags -bor $ADVERT_ENABLE_TS_FROM_CD_AND_PXE }
                        'MediaAndPxe' { $advertFlags = $advertFlags -bor $ADVERT_ENABLE_TS_FROM_CD_AND_PXE }
                        'MediaAndPxeHidden' {
                            $advertFlags = $advertFlags -bor $ADVERT_ENABLE_TS_FROM_CD_AND_PXE
                            $advertFlags = $advertFlags -bor $ADVERT_NO_DISPLAY
                        }
                    }
                }

                $eventMask = ($ADVERT_IMMEDIATE -bor $ADVERT_ONUSERLOGON -bor $ADVERT_ONUSERLOGOFF)
                if ($ClearScheduleEvent) {
                    $advertFlags = $advertFlags -band (-bnot $eventMask)
                    # For Required deployments, clearing all schedule events is not allowed
                    $isRequired = ($deployment.PSObject.Properties['Mandatory'] -and $deployment.Mandatory) -or ($deployment.PSObject.Properties['AdvertFlags'] -and ($advertFlags -band $ADVERT_IMMEDIATE))
                    $hasSchedule = ($advertFlags -band $eventMask) -ne 0
                    if ($isRequired -and -not $hasSchedule) {
                        throw "Required deployments must have at least one schedule event or schedule. Clearing all schedule events is not allowed."
                    }
                }

                if ($PSBoundParameters.ContainsKey('ScheduleEvent')) {
                    $advertFlags = $advertFlags -band (-bnot $eventMask)
                    foreach ($ev in $ScheduleEvent) {
                        switch ($ev) {
                            'AsSoonAsPossible' { $advertFlags = $advertFlags -bor $ADVERT_IMMEDIATE }
                            'LogOn' { $advertFlags = $advertFlags -bor $ADVERT_ONUSERLOGON }
                            'LogOff' { $advertFlags = $advertFlags -bor $ADVERT_ONUSERLOGOFF }
                        }
                    }
                }

                if ($PSBoundParameters.ContainsKey('AddScheduleEvent')) {
                    foreach ($ev in $AddScheduleEvent) {
                        switch ($ev) {
                            'AsSoonAsPossible' { $advertFlags = $advertFlags -bor $ADVERT_IMMEDIATE }
                            'LogOn' { $advertFlags = $advertFlags -bor $ADVERT_ONUSERLOGON }
                            'LogOff' { $advertFlags = $advertFlags -bor $ADVERT_ONUSERLOGOFF }
                        }
                    }
                }

                if ($PSBoundParameters.ContainsKey('RemoveScheduleEvent')) {
                    foreach ($ev in $RemoveScheduleEvent) {
                        switch ($ev) {
                            'AsSoonAsPossible' { $advertFlags = $advertFlags -band (-bnot $ADVERT_IMMEDIATE) }
                            'LogOn' { $advertFlags = $advertFlags -band (-bnot $ADVERT_ONUSERLOGON) }
                            'LogOff' { $advertFlags = $advertFlags -band (-bnot $ADVERT_ONUSERLOGOFF) }
                        }
                    }
                }

                if ($PSBoundParameters.ContainsKey('AllowSharedContent')) {
                    if ($AllowSharedContent) {
                        $remoteClientFlags = $remoteClientFlags -bor $RCF_ALLOW_SHARED_CONTENT
                    } else {
                        $remoteClientFlags = $remoteClientFlags -band (-bnot $RCF_ALLOW_SHARED_CONTENT)
                    }
                }

                if ($PSBoundParameters.ContainsKey('PersistOnWriteFilterDevice')) {
                    if ($PersistOnWriteFilterDevice) {
                        $remoteClientFlags = $remoteClientFlags -bor $RCF_PERSIST_ON_WRITE_FILTER
                    } else {
                        $remoteClientFlags = $remoteClientFlags -band (-bnot $RCF_PERSIST_ON_WRITE_FILTER)
                    }
                }

                if ($PSBoundParameters.ContainsKey('InternetOption')) {
                    if ($InternetOption) {
                        $remoteClientFlags = $remoteClientFlags -bor $RCF_ALLOW_INTERNET_CLIENTS
                    } else {
                        $remoteClientFlags = $remoteClientFlags -band (-bnot $RCF_ALLOW_INTERNET_CLIENTS)
                    }
                }

                if ($PSBoundParameters.ContainsKey('UseMeteredNetwork')) {
                    if ($UseMeteredNetwork) {
                        $remoteClientFlags = $remoteClientFlags -bor $RCF_USE_METERED_NETWORK
                    } else {
                        $remoteClientFlags = $remoteClientFlags -band (-bnot $RCF_USE_METERED_NETWORK)
                    }
                }

                if ($PSBoundParameters.ContainsKey('RerunBehavior')) {
                    $remoteClientFlags = $remoteClientFlags -band (-bnot ($RCF_ALWAYS_RERUN -bor $RCF_RERUN_IF_FAILED -bor $RCF_RERUN_IF_SUCCEEDED))
                    switch ($RerunBehavior) {
                        'NeverRerunDeployedProgram' { }
                        'AlwaysRerunProgram' { $remoteClientFlags = $remoteClientFlags -bor $RCF_ALWAYS_RERUN }
                        'RerunIfFailedPreviousAttempt' { $remoteClientFlags = $remoteClientFlags -bor $RCF_RERUN_IF_FAILED }
                        'RerunIfSucceededOnPreviousAttempt' { $remoteClientFlags = $remoteClientFlags -bor $RCF_RERUN_IF_SUCCEEDED }
                    }
                }

                if ($PSBoundParameters.ContainsKey('DeploymentOption')) {
                    $remoteClientFlags = $remoteClientFlags -band (-bnot ($RCF_DONT_RUN_NO_LOCAL_DP -bor $RCF_DOWNLOAD_FROM_REMOTE_DP))
                    switch ($DeploymentOption) {
                        'DownloadAllContentLocallyBeforeStartingTaskSequence' { }
                        'DownloadContentLocallyWhenNeededByRunningTaskSequence' { $remoteClientFlags = $remoteClientFlags -bor $RCF_DOWNLOAD_FROM_REMOTE_DP }
                        'RunFromDistributionPoint' { $remoteClientFlags = $remoteClientFlags -bor $RCF_DONT_RUN_NO_LOCAL_DP }
                    }
                }

                $setProps = @{}
                if ($advertFlags -ne $origAdvertFlags) {
                    $setProps['AdvertFlags'] = [uint32]$advertFlags
                }
                if ($remoteClientFlags -ne $origRemoteClientFlags) {
                    $setProps['RemoteClientFlags'] = [uint32]$remoteClientFlags
                }

                if ($PSBoundParameters.ContainsKey('Comment')) {
                    $setProps['Comment'] = [string]$Comment
                }

                if ($PSBoundParameters.ContainsKey('DeploymentAvailableDateTime')) {
                    # PresentTimeEnabled and PresentTimeIsGMT are lazy SMS_Advertisement properties
                    # and cannot be set via Set-CimInstance (HRESULT 0x80041001). Only set the datetime value.
                    $setProps['PresentTime'] = [datetime]$DeploymentAvailableDateTime
                }

                if ($PSBoundParameters.ContainsKey('DeploymentExpireDateTime')) {
                    # ExpirationTimeEnabled and ExpirationTimeIsGMT are lazy SMS_Advertisement properties
                    # and cannot be set via Set-CimInstance (HRESULT 0x80041001). Only set the datetime value.
                    $setProps['ExpirationTime'] = [datetime]$DeploymentExpireDateTime
                }

                if ($resolvedCollections.Count -gt 0) {
                    if ($resolvedCollections.Count -gt 1) {
                        throw "CollectionName resolved to multiple collections. Please use a single collection name/id/object when updating target collection."
                    }

                    $resolvedCollectionId = if ($resolvedCollections[0].PSObject.Properties['CollectionID']) { $resolvedCollections[0].CollectionID } else { $resolvedCollections[0].CollectionId }
                    $setProps['CollectionID'] = [string]$resolvedCollectionId
                }

                if ($PSBoundParameters.ContainsKey('AlertDateTime')) {
                    $mapped = $false
                    foreach ($candidate in @('AlertTime', 'AlertDateTime')) {
                        if ($deployment.CimInstanceProperties[$candidate]) {
                            $setProps[$candidate] = [datetime]$AlertDateTime
                            $mapped = $true
                            break
                        }
                    }
                    if (-not $mapped) {
                        Write-Verbose "Could not map parameter 'AlertDateTime' to a known SMS_Advertisement property in this environment."
                    }
                }

                if ($PSBoundParameters.ContainsKey('CreateAlertOnFailure')) {
                    $mapped = $false
                    foreach ($candidate in @('CreateAlertOnFailure', 'RaiseMomAlertsOnFailure', 'CreateAlertBaseOnPercentFailure')) {
                        if ($deployment.CimInstanceProperties[$candidate]) {
                            $setProps[$candidate] = [bool]$CreateAlertOnFailure
                            $mapped = $true
                            break
                        }
                    }
                    if (-not $mapped) {
                        Write-Verbose "Could not map parameter 'CreateAlertOnFailure' to a known SMS_Advertisement property in this environment."
                    }
                }

                if ($PSBoundParameters.ContainsKey('CreateAlertOnSuccess')) {
                    $mapped = $false
                    foreach ($candidate in @('CreateAlertOnSuccess', 'RaiseMomAlertsOnSuccess', 'CreateAlertBaseOnPercentSuccess')) {
                        if ($deployment.CimInstanceProperties[$candidate]) {
                            $setProps[$candidate] = [bool]$CreateAlertOnSuccess
                            $mapped = $true
                            break
                        }
                    }
                    if (-not $mapped) {
                        Write-Verbose "Could not map parameter 'CreateAlertOnSuccess' to a known SMS_Advertisement property in this environment."
                    }
                }

                if ($PSBoundParameters.ContainsKey('PercentFailure')) {
                    $mapped = $false
                    foreach ($candidate in @('PercentFailure')) {
                        if ($deployment.CimInstanceProperties[$candidate]) {
                            $setProps[$candidate] = [int]$PercentFailure
                            $mapped = $true
                            break
                        }
                    }
                    if (-not $mapped) {
                        Write-Verbose "Could not map parameter 'PercentFailure' to a known SMS_Advertisement property in this environment."
                    }
                }

                if ($PSBoundParameters.ContainsKey('PercentSuccess')) {
                    $mapped = $false
                    foreach ($candidate in @('PercentSuccess')) {
                        if ($deployment.CimInstanceProperties[$candidate]) {
                            $setProps[$candidate] = [int]$PercentSuccess
                            $mapped = $true
                            break
                        }
                    }
                    if (-not $mapped) {
                        Write-Verbose "Could not map parameter 'PercentSuccess' to a known SMS_Advertisement property in this environment."
                    }
                }

                if ($PSBoundParameters.ContainsKey('AllowUsersRunIndependently')) {
                    $mapped = $false
                    foreach ($candidate in @('AllowUsersRunIndependently', 'PresentUsers')) {
                        if ($deployment.CimInstanceProperties[$candidate]) {
                            $setProps[$candidate] = [bool]$AllowUsersRunIndependently
                            $mapped = $true
                            break
                        }
                    }
                    if (-not $mapped) {
                        Write-Verbose "Could not map parameter 'AllowUsersRunIndependently' to a known SMS_Advertisement property in this environment."
                    }
                }

                if ($setProps.Count -eq 0) {
                    Write-Verbose "No properties to update for deployment '$($deployment.AdvertisementName)' ($($deployment.AdvertisementID))"
                } else {
                    Write-Verbose "Updating deployment '$($deployment.AdvertisementName)' ($($deployment.AdvertisementID)) via CIM"
                    try {
                        Set-CimInstance -CimSession $script:CMConnection.CimSession -InputObject $deployment -Property $setProps -ErrorAction Stop | Out-Null
                    } catch {
                        $errMsg = $_.Exception.Message
                        if (-not $errMsg) { $errMsg = $_.Message }
                        if ($ClearScheduleEvent -and $isRequired -and -not $hasSchedule -and $errMsg -match "HRESULT 0x80041001|Generic failure") {
                            throw "Required deployments must have at least one schedule event or schedule. Clearing all schedule events is not allowed."
                        } else {
                            throw $_
                        }
                    }
                }

                if ($PassThru) {
                    Get-CM7TaskSequenceDeployment -AdvertisementID $deployment.AdvertisementID
                }
            }
        }
        catch {
            throw $_
        }
    }
}
