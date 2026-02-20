function New-CM7TaskSequenceDeployment {
    <#
        .SYNOPSIS
            Creates a new task sequence deployment in MECM using CIM.

        .DESCRIPTION
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

        .PARAMETER TaskSequencePackageId
            The PackageID of the task sequence to deploy (e.g., "SD100FAD").
            Mutually exclusive with TaskSequenceName.

        .PARAMETER TaskSequenceName
            The name of the task sequence to deploy.
            Mutually exclusive with TaskSequencePackageId.

        .PARAMETER CollectionName
            The name of the target device collection for the deployment.
            Mutually exclusive with CollectionId.

        .PARAMETER CollectionId
            The ID of the target device collection for the deployment (e.g., "SD101C00").
            Mutually exclusive with CollectionName.

        .PARAMETER DeploymentName
            An optional name for the deployment (AdvertisementName). If not specified,
            defaults to "{TaskSequenceName} - {CollectionName}".

        .PARAMETER Comment
            An optional description/comment for the deployment.

        .PARAMETER DeployPurpose
            The deployment purpose. Valid values are:
            - Available: Makes the task sequence available for users to run from Software Center (default).
            - Required: Forces the task sequence to run by the deadline.

        .PARAMETER AvailableDateTime
            The date and time when the deployment becomes available to clients.
            Defaults to the current date and time.

        .PARAMETER DeadlineDateTime
            The enforcement deadline date and time for Required deployments.
            After this time, the task sequence will be forced to run.
            For Available deployments, this sets the expiration time.

        .PARAMETER UseUtcForAvailableSchedule
            Specifies whether to use UTC/GMT times for the available schedule. Default is $false.

        .PARAMETER UseUtcForExpireSchedule
            Specifies whether to use UTC/GMT times for the expiration/deadline schedule. Default is $false.

        .PARAMETER Availability
            Controls where the task sequence is available. Valid values are:
            - Clients: Only available to Configuration Manager clients (default)
            - ClientsMediaAndPxe: Available to clients, media, and PXE
            - MediaAndPxe: Available only to media and PXE
            - MediaAndPxeHidden: Available only to media and PXE (hidden)

        .PARAMETER RerunBehavior
            Controls how the task sequence behaves if it has been previously run. Valid values are:
            - NeverRerun: Never rerun the task sequence
            - AlwaysRerunProgram: Always rerun the task sequence
            - RerunIfFailedPreviousAttempt: Rerun only if the previous attempt failed (default)
            - RerunIfSucceededOnPreviousAttempt: Rerun only if the previous attempt succeeded

        .PARAMETER ShowTaskSequenceProgress
            Shows task sequence progress to the user. Default is $false.

        .PARAMETER SoftwareInstallation
            Allows task sequence installation outside of maintenance windows. Default is $true.

        .PARAMETER SystemRestart
            Allows system restart outside of maintenance windows. Default is $true.

        .PARAMETER AllowFallback
            Allows clients to use a fallback source location for content.
            Default is $false (do not fall back).

        .PARAMETER DeploymentOption
            Controls how content is accessed. Valid values are:
            - DownloadAllContent: Download all content locally before starting task sequence (default)
            - DownloadContentLocallyWhenNeededByRunningTaskSequence: Download content as needed
            - RunFromDistributionPoint: Access content directly from the distribution point

        .PARAMETER AllowSharedContent
            Allows clients to use BranchCache to share content with other clients.
            Default is $true.

        .PARAMETER SendWakeupPacket
            Sends a Wake On LAN packet to wake up computers before the deployment runs.
            Default is $false.

        .PARAMETER PersistOnWriteFilterDevice
            Allows content to persist on write filter enabled devices. Default is $false.

        .PARAMETER InternetOption
            Allows the task sequence to run on internet-based clients. Default is $true.

        .PARAMETER UseMeteredNetwork
            Allows the task sequence to run over metered network connections. Default is $true.

        .PARAMETER ScheduleEvent
            For Required deployments, controls when the task sequence is scheduled to run.
            Valid values are:
            - AsSoonAsPossible: Run as soon as possible after the available time (default)
            - LogOn: Run at next user logon
            - LogOff: Run at next user logoff

        .PARAMETER Force
            Suppresses confirmation prompts.

        .PARAMETER WhatIf
            Shows what would happen if the cmdlet runs. The cmdlet is not run.

        .PARAMETER Confirm
            Prompts you for confirmation before running the cmdlet.

        .EXAMPLE
            New-CM7TaskSequenceDeployment -CollectionName "Test-Collection-Direct" -TaskSequencePackageId "SD100FAD" -AvailableDateTime (Get-Date) -Force
            Creates an available task sequence deployment targeting the specified collection.

        .EXAMPLE
            New-CM7TaskSequenceDeployment -TaskSequenceName "Test Josh" -CollectionName "Test-Collection-Direct" -Force
            Creates an available task sequence deployment using the task sequence name.

        .EXAMPLE
            New-CM7TaskSequenceDeployment -TaskSequencePackageId "SD100FAD" -CollectionName "Test-Collection-Direct" -DeployPurpose Required -Force
            Creates a required (mandatory) task sequence deployment.

        .EXAMPLE
            New-CM7TaskSequenceDeployment -TaskSequencePackageId "SD100FAD" -CollectionId "SD101C00" -DeploymentName "Custom Deployment Name" -Comment "Monthly OS deployment" -Force
            Creates a deployment using PackageID and collection ID with a custom name and comment.

        .EXAMPLE
            New-CM7TaskSequenceDeployment -TaskSequencePackageId "SD100FAD" -CollectionName "Test-Collection-Direct" -WhatIf
            Shows what would happen without actually creating the deployment.

        .EXAMPLE
            New-CM7TaskSequenceDeployment -TaskSequencePackageId "SD100FAD" -CollectionName "Test-Collection-Direct" -DeployPurpose Required -DeadlineDateTime (Get-Date).AddDays(7) -Force
            Creates a required deployment with a 7-day enforcement deadline.

        .EXAMPLE
            New-CM7TaskSequenceDeployment -TaskSequencePackageId "SD100FAD" -CollectionName "Test-Collection-Direct" -SoftwareInstallation $false -SystemRestart $false -Force
            Creates a deployment that does not allow installation or restart outside of maintenance windows.

        .EXAMPLE
            New-CM7TaskSequenceDeployment -TaskSequencePackageId "SD100FAD" -CollectionName "Test-Collection-Direct" -ShowTaskSequenceProgress $true -Force
            Creates a deployment with task sequence progress displayed to the user.

        .EXAMPLE
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

        .NOTES
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
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium', DefaultParameterSetName = 'ByTSPackageIdCollectionName')]
    param(
        [Parameter(Mandatory = $true, ParameterSetName = 'ByTSPackageIdCollectionName')]
        [Parameter(Mandatory = $true, ParameterSetName = 'ByTSPackageIdCollectionId')]
        [ValidateNotNullOrEmpty()]
        [string]$TaskSequencePackageId,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByTSNameCollectionName')]
        [Parameter(Mandatory = $true, ParameterSetName = 'ByTSNameCollectionId')]
        [ValidateNotNullOrEmpty()]
        [string]$TaskSequenceName,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByTSPackageIdCollectionName')]
        [Parameter(Mandatory = $true, ParameterSetName = 'ByTSNameCollectionName')]
        [ValidateNotNullOrEmpty()]
        [string]$CollectionName,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByTSPackageIdCollectionId')]
        [Parameter(Mandatory = $true, ParameterSetName = 'ByTSNameCollectionId')]
        [ValidateNotNullOrEmpty()]
        [string]$CollectionId,

        [Parameter()]
        [string]$DeploymentName,

        [Parameter()]
        [string]$Comment = '',

        [Parameter()]
        [ValidateSet('Available', 'Required')]
        [string]$DeployPurpose = 'Available',

        [Parameter()]
        [datetime]$AvailableDateTime,

        [Parameter()]
        [datetime]$DeadlineDateTime,

        [Parameter()]
        [Boolean]$UseUtcForAvailableSchedule = $false,

        [Parameter()]
        [Boolean]$UseUtcForExpireSchedule = $false,

        [Parameter()]
        [ValidateSet('Clients', 'ClientsMediaAndPxe', 'MediaAndPxe', 'MediaAndPxeHidden')]
        [string]$Availability = 'Clients',

        [Parameter()]
        [ValidateSet('NeverRerun', 'AlwaysRerunProgram', 'RerunIfFailedPreviousAttempt', 'RerunIfSucceededOnPreviousAttempt')]
        [string]$RerunBehavior = 'RerunIfFailedPreviousAttempt',

        [Parameter()]
        [Boolean]$ShowTaskSequenceProgress = $false,

        [Parameter()]
        [Boolean]$SoftwareInstallation = $true,

        [Parameter()]
        [Boolean]$SystemRestart = $true,

        [Parameter()]
        [Boolean]$AllowFallback = $false,

        [Parameter()]
        [ValidateSet('DownloadAllContent', 'DownloadContentLocallyWhenNeededByRunningTaskSequence', 'RunFromDistributionPoint')]
        [string]$DeploymentOption = 'DownloadAllContent',

        [Parameter()]
        [Boolean]$AllowSharedContent = $true,

        [Parameter()]
        [Boolean]$SendWakeupPacket = $false,

        [Parameter()]
        [Boolean]$PersistOnWriteFilterDevice = $false,

        [Parameter()]
        [Boolean]$InternetOption = $true,

        [Parameter()]
        [Boolean]$UseMeteredNetwork = $true,

        [Parameter()]
        [ValidateSet('AsSoonAsPossible', 'LogOn', 'LogOff')]
        [string]$ScheduleEvent = 'AsSoonAsPossible',

        [Parameter()]
        [switch]$Force
    )

    begin {
        $function = $($MyInvocation.MyCommand.Name)
        Write-Verbose "Running $function"

        # Validate connection
        if (-not $script:CMConnection.CimSession) {
            throw "Not connected to MECM. Please run Connect-CM7 first."
        }

        # Determine the namespace
        $namespace = "root/SMS/site_$($script:CMConnection.SiteCode)"

        # Build common CIM parameters
        $cimParams = @{
            CimSession = $script:CMConnection.CimSession
            Namespace  = $namespace
        }

        # ---- AdvertFlags bit definitions for SMS_Advertisement ----
        $ADVERT_IMMEDIATE                      = [uint32]0x00000020  # 32 - As soon as possible
        $ADVERT_ONSYSTEMSTARTUP                = [uint32]0x00000100  # 256
        $ADVERT_ONUSERLOGON                    = [uint32]0x00000200  # 512
        $ADVERT_ONUSERLOGOFF                   = [uint32]0x00000400  # 1024
        $ADVERT_ENABLE_TS_FROM_CD_AND_PXE      = [uint32]0x00002000  # 8192
        $ADVERT_NO_DISPLAY                     = [uint32]0x00008000  # 32768
        $ADVERT_OVERRIDE_SERVICE_WINDOWS       = [uint32]0x00010000  # 65536
        $ADVERT_REBOOT_OUTSIDE_SERVICE_WINDOWS = [uint32]0x00020000  # 131072
        $ADVERT_WAKE_ON_LAN                    = [uint32]0x00040000  # 262144
        $ADVERT_DONOT_FALLBACK                 = [uint32]0x00080000  # 524288
        $ADVERT_ENABLE_PEER_CACHING            = [uint32]0x00100000  # 1048576
        $ADVERT_SHOW_PROGRESS                  = [uint32]0x02000000  # 33554432
        $ADVERT_USE_REMOTE_DP                  = [uint32]0x00800000  # 8388608

        # ---- RemoteClientFlags bit definitions ----
        $RCF_DOWNLOAD_FROM_LOCAL_DP            = [uint32]0x00000001  # 1
        $RCF_DOWNLOAD_FROM_REMOTE_DP           = [uint32]0x00000002  # 2
        $RCF_DONT_RUN_NO_LOCAL_DP              = [uint32]0x00000004  # 4
        $RCF_DOWNLOAD_FROM_INTERNET            = [uint32]0x00000008  # 8
        $RCF_ALLOW_SHARED_CONTENT              = [uint32]0x00000010  # 16
        $RCF_ALWAYS_RERUN                      = [uint32]0x00000020  # 32
        $RCF_RERUN_IF_FAILED                   = [uint32]0x00000040  # 64
        $RCF_RERUN_IF_SUCCEEDED                = [uint32]0x00000080  # 128
        $RCF_DOWNLOAD_FROM_UNPROTECTED_DP      = [uint32]0x00000100  # 256
        $RCF_PERSIST_ON_WRITE_FILTER           = [uint32]0x00000400  # 1024
        $RCF_ALLOW_INTERNET_CLIENTS            = [uint32]0x00000800  # 2048
        $RCF_TS_SHOW_PROGRESS                  = [uint32]0x00004000  # 16384
        $RCF_USE_METERED_NETWORK               = [uint32]0x00008000  # 32768
    }

    process {
        try {
            # ---- Resolve Task Sequence ----
            $resolvedPackageId = $null
            $resolvedTSName = $null
            if ($PSBoundParameters.ContainsKey('TaskSequenceName')) {
                $tsQuery = "SELECT PackageID, Name FROM SMS_TaskSequencePackage WHERE Name = '$TaskSequenceName'"
                Write-Verbose "Resolving task sequence by name: $tsQuery"
                $resolvedTS = Get-CimInstance @cimParams -Query $tsQuery

                if (-not $resolvedTS) {
                    throw "Task sequence '$TaskSequenceName' not found."
                }
                if (@($resolvedTS).Count -gt 1) {
                    throw "Multiple task sequences found matching '$TaskSequenceName'. Please specify using -TaskSequencePackageId."
                }
                $resolvedPackageId = $resolvedTS.PackageID
                $resolvedTSName = $resolvedTS.Name
                Write-Verbose "Resolved task sequence: '$resolvedTSName' (PackageID: $resolvedPackageId)"
            } else {
                $tsQuery = "SELECT PackageID, Name FROM SMS_TaskSequencePackage WHERE PackageID = '$TaskSequencePackageId'"
                Write-Verbose "Resolving task sequence by PackageID: $tsQuery"
                $resolvedTS = Get-CimInstance @cimParams -Query $tsQuery

                if (-not $resolvedTS) {
                    throw "Task sequence with PackageID '$TaskSequencePackageId' not found."
                }
                $resolvedPackageId = $resolvedTS.PackageID
                $resolvedTSName = $resolvedTS.Name
                Write-Verbose "Resolved task sequence: '$resolvedTSName' (PackageID: $resolvedPackageId)"
            }

            # ---- Resolve Collection ----
            $resolvedCollectionId = $null
            $resolvedCollectionName = $null
            if ($PSBoundParameters.ContainsKey('CollectionName')) {
                $collQuery = "SELECT CollectionID, Name FROM SMS_Collection WHERE CollectionType = 2 AND Name = '$CollectionName'"
                Write-Verbose "Resolving collection by name: $collQuery"
                $resolvedCollection = Get-CimInstance @cimParams -Query $collQuery

                if (-not $resolvedCollection) {
                    throw "Device collection '$CollectionName' not found."
                }
                if (@($resolvedCollection).Count -gt 1) {
                    throw "Multiple collections found matching '$CollectionName'. Please specify using -CollectionId."
                }
                $resolvedCollectionId = $resolvedCollection.CollectionID
                $resolvedCollectionName = $resolvedCollection.Name
                Write-Verbose "Resolved collection: '$resolvedCollectionName' (ID: $resolvedCollectionId)"
            } else {
                $collQuery = "SELECT CollectionID, Name FROM SMS_Collection WHERE CollectionType = 2 AND CollectionID = '$CollectionId'"
                Write-Verbose "Resolving collection by ID: $collQuery"
                $resolvedCollection = Get-CimInstance @cimParams -Query $collQuery

                if (-not $resolvedCollection) {
                    throw "Device collection '$CollectionId' not found."
                }
                $resolvedCollectionId = $resolvedCollection.CollectionID
                $resolvedCollectionName = $resolvedCollection.Name
                Write-Verbose "Resolved collection: '$resolvedCollectionName' (ID: $resolvedCollectionId)"
            }

            # ---- Determine deployment name ----
            $actualDeploymentName = if ($DeploymentName) { $DeploymentName } else { "$resolvedTSName - $resolvedCollectionName" }
            Write-Verbose "Deployment name: '$actualDeploymentName'"

            # ---- Set available time ----
            $now = Get-Date
            $actualAvailableDateTime = if ($PSBoundParameters.ContainsKey('AvailableDateTime')) { $AvailableDateTime } else { $now }

            # ---- Compute AdvertFlags ----
            [uint32]$advertFlags = $ADVERT_USE_REMOTE_DP   # Always set for TS deployments

            # Service window and restart control
            if ($SoftwareInstallation) {
                $advertFlags = $advertFlags -bor $ADVERT_OVERRIDE_SERVICE_WINDOWS
            }
            if ($SystemRestart) {
                $advertFlags = $advertFlags -bor $ADVERT_REBOOT_OUTSIDE_SERVICE_WINDOWS
            }

            # Fallback behavior (inverted: AllowFallback=false means set DONOT_FALLBACK)
            if (-not $AllowFallback) {
                $advertFlags = $advertFlags -bor $ADVERT_DONOT_FALLBACK
            }

            # Wake On LAN
            if ($SendWakeupPacket) {
                $advertFlags = $advertFlags -bor $ADVERT_WAKE_ON_LAN
            }

            # Media/PXE availability
            if ($Availability -in @('ClientsMediaAndPxe', 'MediaAndPxe', 'MediaAndPxeHidden')) {
                $advertFlags = $advertFlags -bor $ADVERT_ENABLE_TS_FROM_CD_AND_PXE
            }
            if ($Availability -eq 'MediaAndPxeHidden') {
                $advertFlags = $advertFlags -bor $ADVERT_NO_DISPLAY
            }

            # Show task sequence progress in AdvertFlags
            if ($ShowTaskSequenceProgress) {
                $advertFlags = $advertFlags -bor $ADVERT_SHOW_PROGRESS
            }

            # Schedule event (for Required deployments)
            if ($DeployPurpose -eq 'Required') {
                switch ($ScheduleEvent) {
                    'AsSoonAsPossible' { $advertFlags = $advertFlags -bor $ADVERT_IMMEDIATE }
                    'LogOn'            { $advertFlags = $advertFlags -bor $ADVERT_ONUSERLOGON }
                    'LogOff'           { $advertFlags = $advertFlags -bor $ADVERT_ONUSERLOGOFF }
                }
            }

            Write-Verbose "AdvertFlags == 0x$($advertFlags.ToString('X')) / $advertFlags"

            # ---- Compute RemoteClientFlags ----
            [uint32]$remoteClientFlags = 0

            # Rerun behavior
            switch ($RerunBehavior) {
                'AlwaysRerunProgram'                  { $remoteClientFlags = $remoteClientFlags -bor $RCF_ALWAYS_RERUN }
                'RerunIfFailedPreviousAttempt'        { $remoteClientFlags = $remoteClientFlags -bor $RCF_RERUN_IF_FAILED }
                'RerunIfSucceededOnPreviousAttempt'   { $remoteClientFlags = $remoteClientFlags -bor $RCF_RERUN_IF_SUCCEEDED }
                # 'NeverRerun' → no bits
            }

            # Shared content (BranchCache)
            if ($AllowSharedContent) {
                $remoteClientFlags = $remoteClientFlags -bor $RCF_ALLOW_SHARED_CONTENT
            }

            # Write filter persistence
            if ($PersistOnWriteFilterDevice) {
                $remoteClientFlags = $remoteClientFlags -bor $RCF_PERSIST_ON_WRITE_FILTER
            }

            # Internet clients
            if ($InternetOption) {
                $remoteClientFlags = $remoteClientFlags -bor $RCF_ALLOW_INTERNET_CLIENTS
            }

            # Show TS progress in RemoteClientFlags
            if ($ShowTaskSequenceProgress) {
                $remoteClientFlags = $remoteClientFlags -bor $RCF_TS_SHOW_PROGRESS
            }

            # Metered network
            if ($UseMeteredNetwork) {
                $remoteClientFlags = $remoteClientFlags -bor $RCF_USE_METERED_NETWORK
            }

            # DeploymentOption
            switch ($DeploymentOption) {
                'RunFromDistributionPoint' {
                    $remoteClientFlags = $remoteClientFlags -bor $RCF_DONT_RUN_NO_LOCAL_DP
                }
                'DownloadContentLocallyWhenNeededByRunningTaskSequence' {
                    $remoteClientFlags = $remoteClientFlags -bor $RCF_DOWNLOAD_FROM_REMOTE_DP
                }
                # 'DownloadAllContent' → default, no additional bits
            }

            Write-Verbose "RemoteClientFlags == 0x$($remoteClientFlags.ToString('X')) / $remoteClientFlags"

            # ---- Compute DeviceFlags ----
            [uint32]$deviceFlags = 0
            Write-Verbose "DeviceFlags == 0x$($deviceFlags.ToString('X')) / $deviceFlags"

            # ---- Create the deployment ----
            $actionDescription = "Create task sequence deployment '$actualDeploymentName' for task sequence '$resolvedTSName' ($resolvedPackageId) targeting collection '$resolvedCollectionName' ($resolvedCollectionId) with purpose '$DeployPurpose'"
            if ($Force -or $PSCmdlet.ShouldProcess($actualDeploymentName, $actionDescription)) {
                Write-Verbose "Creating task sequence deployment: $actionDescription"

                # Build properties for SMS_Advertisement
                # ProgramName = '*' marks this as a task sequence deployment
                $deploymentProperties = @{
                    AdvertisementName  = [string]$actualDeploymentName
                    CollectionID       = [string]$resolvedCollectionId
                    PackageID          = [string]$resolvedPackageId
                    ProgramName        = [string]'*'
                    SourceSite         = [string]$script:CMConnection.SiteCode
                    AdvertFlags        = [uint32]$advertFlags
                    RemoteClientFlags  = [uint32]$remoteClientFlags
                    DeviceFlags        = [uint32]$deviceFlags
                    PresentTime        = [datetime]$actualAvailableDateTime
                    Comment            = [string]$(if ($Comment) { $Comment } else { '' })
                    Priority           = [uint32]2  # Medium priority
                    PresentTimeEnabled = [bool]$true
                    PresentTimeIsGMT   = [bool]$UseUtcForAvailableSchedule
                }

                # Set expiration/deadline time if specified
                if ($PSBoundParameters.ContainsKey('DeadlineDateTime')) {
                    $deploymentProperties['ExpirationTime'] = [datetime]$DeadlineDateTime
                    $deploymentProperties['ExpirationTimeEnabled'] = [bool]$true
                    $deploymentProperties['ExpirationTimeIsGMT'] = [bool]$UseUtcForExpireSchedule
                }

                # For Required deployments with AsSoonAsPossible, enable the assigned schedule
                if ($DeployPurpose -eq 'Required') {
                    $deploymentProperties['AssignedScheduleEnabled'] = [bool]$true
                    $deploymentProperties['AssignedScheduleIsGMT'] = [bool]$UseUtcForAvailableSchedule
                }

                Write-Verbose "Deployment properties: Name='$actualDeploymentName', PackageID='$resolvedPackageId', Collection='$resolvedCollectionName', Purpose='$DeployPurpose'"
                Write-Verbose "Creating instance of class 'SMS_Advertisement'"

                # Create the task sequence deployment using New-CimInstance
                $newDeployment = New-CimInstance @cimParams -ClassName 'SMS_Advertisement' -Property $deploymentProperties

                if (-not $newDeployment) {
                    throw "Failed to create task sequence deployment '$actualDeploymentName'. New-CimInstance returned null."
                }

                $advertisementId = $newDeployment.AdvertisementID
                Write-Verbose "Task sequence deployment '$actualDeploymentName' created successfully with AdvertisementID: $advertisementId"

                # ---- Retrieve the full deployment object to return ----
                $resultQuery = "SELECT * FROM SMS_Advertisement WHERE AdvertisementID = '$advertisementId'"
                Write-Verbose "Retrieving created deployment: $resultQuery"
                $result = Get-CimInstance @cimParams -Query $resultQuery

                if ($result) {
                    # Resolve task sequence name for output
                    $outputTsName = $resolvedTSName

                    $output = [PSCustomObject]@{
                        PSTypeName               = 'MECM7.TaskSequenceDeployment'
                        AdvertisementID          = $result.AdvertisementID
                        AdvertisementName        = $result.AdvertisementName
                        CollectionID             = $result.CollectionID
                        CollectionName           = $resolvedCollectionName
                        PackageID                = $result.PackageID
                        TaskSequenceName         = $outputTsName
                        ProgramName              = $result.ProgramName
                        SourceSite               = $result.SourceSite
                        AdvertFlags              = [int]$result.AdvertFlags
                        RemoteClientFlags        = [int]$result.RemoteClientFlags
                        DeviceFlags              = [int]$result.DeviceFlags
                        PresentTime              = $result.PresentTime
                        ExpirationTime           = $result.ExpirationTime
                        Comment                  = $result.Comment
                    }

                    # Set the type name
                    $output.PSObject.TypeNames.Insert(0, 'MECM7.TaskSequenceDeployment')

                    # Add all extra properties from the CIM instance
                    $result.CimInstanceProperties | ForEach-Object {
                        if ($_.Name -notin $output.PSObject.Properties.Name) {
                            $output | Add-Member -MemberType NoteProperty -Name $_.Name -Value $_.Value -Force
                        }
                    }

                    Write-Output $output
                } else {
                    Write-Warning "Task sequence deployment was created but could not retrieve the result. AdvertisementID: $advertisementId"
                }
            }
        }
        catch {
            throw $_
        }
    }
}
