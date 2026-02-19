function New-CM7SoftwareUpdateDeployment {
    <#
        .SYNOPSIS
            Creates a new software update deployment in MECM using CIM.

        .DESCRIPTION
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

        .PARAMETER SoftwareUpdateGroupName
            The name of the software update group to deploy.
            Mutually exclusive with SoftwareUpdateGroupId.

        .PARAMETER SoftwareUpdateGroupId
            The CI_ID of the software update group to deploy.
            Mutually exclusive with SoftwareUpdateGroupName.

        .PARAMETER CollectionName
            The name of the target collection for the deployment.
            Mutually exclusive with CollectionId.

        .PARAMETER CollectionId
            The ID of the target collection for the deployment (e.g., "SD101C00").
            Mutually exclusive with CollectionName.

        .PARAMETER DeploymentName
            An optional name for the deployment (AssignmentName). If not specified,
            defaults to the software update group name.

        .PARAMETER Description
            An optional description for the deployment (AssignmentDescription).

        .PARAMETER DeploymentType
            The deployment type. Valid values are:
            - Required: Forces installation by the enforcement deadline.
            - Available: Makes updates available for optional installation.
            Defaults to Required.

        .PARAMETER AvailableDateTime
            The date and time when the deployment becomes available to clients.
            Defaults to the current date and time.

        .PARAMETER DeadlineDateTime
            The enforcement deadline date and time. After this time, the client will
            force installation of required deployments. Only used with DeploymentType Required.

        .PARAMETER UserNotification
            Controls user notification behavior. Valid values are:
            - DisplayAll: Show all notifications (default)
            - DisplaySoftwareCenterOnly: Show only in Software Center
            - HideAll: Hide all notifications

        .PARAMETER SoftwareInstallation
            Allows installation outside of maintenance windows. Default is $false.

        .PARAMETER AllowRestart
            Allows system restart outside of maintenance windows. Default is $false.

        .PARAMETER RestartServer
            Suppresses restart on servers when $false. Default is $true (allows restart).

        .PARAMETER RestartWorkstation
            Suppresses restart on workstations when $false. Default is $true (allows restart).

        .PARAMETER RequirePostRebootFullScan
            Requires a full scan of software updates after a restart. Default is $false.

        .PARAMETER ProtectedType
            Defines behavior for clients on protected distribution points. Valid values are:
            - NoInstall: Do not install software updates (default)
            - RemoteDistributionPoint: Install from a remote distribution point

        .PARAMETER UnprotectedType
            Defines behavior for clients on unprotected distribution points. Valid values are:
            - NoInstall: Do not install software updates
            - UnprotectedDistributionPoint: Install from an unprotected distribution point (default)

        .PARAMETER UseBranchCache
            Enables BranchCache for the deployment. Default is $false.

        .PARAMETER DownloadFromMicrosoftUpdate
            Allows clients to download from Microsoft Update if content is unavailable
            on distribution points. Default is $false.

        .PARAMETER UseGMTTimes
            Specifies whether to use UTC/GMT times. Default is $false (use local time).

        .PARAMETER Enabled
            Whether the deployment is enabled. Default is $true.

        .PARAMETER Force
            Suppresses confirmation prompts.

        .PARAMETER WhatIf
            Shows what would happen if the cmdlet runs. The cmdlet is not run.

        .PARAMETER Confirm
            Prompts you for confirmation before running the cmdlet.

        .EXAMPLE
            New-CM7SoftwareUpdateDeployment -SoftwareUpdateGroupName "SO Servers-SecurityPatches-2024-01" -CollectionName "Test-Collection-Direct" -Force
            Creates a required software update deployment targeting the specified collection.

        .EXAMPLE
            New-CM7SoftwareUpdateDeployment -SoftwareUpdateGroupName "SO Servers-SecurityPatches-2024-01" -CollectionName "Test-Collection-Direct" -DeploymentType Available -Force
            Creates an available (optional) software update deployment.

        .EXAMPLE
            New-CM7SoftwareUpdateDeployment -SoftwareUpdateGroupName "SO Servers-SecurityPatches-2024-01" -CollectionName "Test-Collection-Direct" -DeadlineDateTime (Get-Date).AddDays(7) -Force
            Creates a required deployment with a 7-day enforcement deadline.

        .EXAMPLE
            New-CM7SoftwareUpdateDeployment -SoftwareUpdateGroupId 17129359 -CollectionId "SD101C00" -DeploymentName "Custom Deployment Name" -Description "Monthly patching" -Force
            Creates a deployment using CI_ID and collection ID with a custom name and description.

        .EXAMPLE
            New-CM7SoftwareUpdateDeployment -SoftwareUpdateGroupName "SO Servers-SecurityPatches-2024-01" -CollectionName "Test-Collection-Direct" -WhatIf
            Shows what would happen without actually creating the deployment.

        .NOTES
            Requires an active connection established via Connect-CM7.

            The SMS_UpdateGroupAssignment WMI class is used to represent software update deployments in MECM.

            This function is the CIM-based equivalent of the New-CMSoftwareUpdateDeployment cmdlet
            from the ConfigurationManager PowerShell module but uses direct CIM queries
            over WinRM instead of requiring the ConfigMgr console or PowerShell drive.
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium', DefaultParameterSetName = 'ByGroupNameCollectionName')]
    param(
        [Parameter(Mandatory = $true, ParameterSetName = 'ByGroupNameCollectionName')]
        [Parameter(Mandatory = $true, ParameterSetName = 'ByGroupNameCollectionId')]
        [ValidateNotNullOrEmpty()]
        [string]$SoftwareUpdateGroupName,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByGroupIdCollectionName')]
        [Parameter(Mandatory = $true, ParameterSetName = 'ByGroupIdCollectionId')]
        [ValidateNotNullOrEmpty()]
        [int]$SoftwareUpdateGroupId,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByGroupNameCollectionName')]
        [Parameter(Mandatory = $true, ParameterSetName = 'ByGroupIdCollectionName')]
        [ValidateNotNullOrEmpty()]
        [string]$CollectionName,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByGroupNameCollectionId')]
        [Parameter(Mandatory = $true, ParameterSetName = 'ByGroupIdCollectionId')]
        [ValidateNotNullOrEmpty()]
        [string]$CollectionId,

        [Parameter()]
        [string]$DeploymentName,

        [Parameter()]
        [string]$Description = '',

        [Parameter()]
        [ValidateSet('Required', 'Available')]
        [string]$DeploymentType = 'Required',

        [Parameter()]
        [datetime]$AvailableDateTime,

        [Parameter()]
        [datetime]$DeadlineDateTime,

        [Parameter()]
        [ValidateSet('DisplayAll', 'DisplaySoftwareCenterOnly', 'HideAll')]
        [string]$UserNotification = 'DisplayAll',

        [Parameter()]
        [Boolean]$SoftwareInstallation = $false,

        [Parameter()]
        [Boolean]$AllowRestart = $false,

        [Parameter()]
        [Boolean]$RestartServer = $true,

        [Parameter()]
        [Boolean]$RestartWorkstation = $true,

        [Parameter()]
        [Boolean]$RequirePostRebootFullScan = $false,

        [Parameter()]
        [ValidateSet('NoInstall', 'RemoteDistributionPoint')]
        [string]$ProtectedType = 'NoInstall',

        [Parameter()]
        [ValidateSet('NoInstall', 'UnprotectedDistributionPoint')]
        [string]$UnprotectedType = 'UnprotectedDistributionPoint',

        [Parameter()]
        [Boolean]$UseBranchCache = $false,

        [Parameter()]
        [Boolean]$DownloadFromMicrosoftUpdate = $false,

        [Parameter()]
        [Boolean]$UseGMTTimes = $false,

        [Parameter()]
        [Boolean]$Enabled = $true,

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

        # Mapping tables
        $deploymentTypeMap = @{
            'Required'  = 1
            'Available' = 2
        }

        $userNotificationMap = @{
            'DisplayAll'                = $true
            'DisplaySoftwareCenterOnly' = $true
            'HideAll'                   = $false
        }

        $protectedTypeMap = @{
            'NoInstall'                = 0
            'RemoteDistributionPoint'  = 1
        }

        $unprotectedTypeMap = @{
            'NoInstall'                     = 0
            'UnprotectedDistributionPoint'  = 1
        }

        # Reverse maps for display
        $deploymentTypeReverse = @{
            1 = 'Required'
            2 = 'Available'
        }

        $assignmentActionMap = @{
            0 = 'Detect'
            1 = 'Apply'
            2 = 'Apply'
        }
    }

    process {
        try {
            # ---- Resolve Software Update Group ----
            $resolvedGroup = $null
            if ($PSBoundParameters.ContainsKey('SoftwareUpdateGroupName')) {
                $groupQuery = "SELECT CI_ID, LocalizedDisplayName FROM SMS_AuthorizationList WHERE LocalizedDisplayName = '$SoftwareUpdateGroupName'"
                Write-Verbose "Resolving software update group by name: $groupQuery"
                $resolvedGroup = Get-CimInstance @cimParams -Query $groupQuery

                if (-not $resolvedGroup) {
                    throw "Software update group '$SoftwareUpdateGroupName' not found."
                }
                if (@($resolvedGroup).Count -gt 1) {
                    throw "Multiple software update groups found matching '$SoftwareUpdateGroupName'. Please specify using -SoftwareUpdateGroupId."
                }
                $groupCIID = [int]$resolvedGroup.CI_ID
                $groupDisplayName = $resolvedGroup.LocalizedDisplayName
                Write-Verbose "Resolved software update group: '$groupDisplayName' (CI_ID: $groupCIID)"
            } else {
                $groupQuery = "SELECT CI_ID, LocalizedDisplayName FROM SMS_AuthorizationList WHERE CI_ID = $SoftwareUpdateGroupId"
                Write-Verbose "Resolving software update group by ID: $groupQuery"
                $resolvedGroup = Get-CimInstance @cimParams -Query $groupQuery

                if (-not $resolvedGroup) {
                    throw "Software update group with CI_ID '$SoftwareUpdateGroupId' not found."
                }
                $groupCIID = [int]$resolvedGroup.CI_ID
                $groupDisplayName = $resolvedGroup.LocalizedDisplayName
                Write-Verbose "Resolved software update group: '$groupDisplayName' (CI_ID: $groupCIID)"
            }

            # ---- Resolve the updates in the group ----
            # The Updates property on SMS_AuthorizationList is a lazy property.
            # A direct WQL query does not load lazy properties, so we must pipe
            # through Get-CimInstance to force the provider to retrieve them.
            $groupDetailQuery = "SELECT * FROM SMS_AuthorizationList WHERE CI_ID = $groupCIID"
            Write-Verbose "Retrieving software update group details: $groupDetailQuery"
            $groupDetail = Get-CimInstance @cimParams -Query $groupDetailQuery | Get-CimInstance

            if (-not $groupDetail.Updates -or $groupDetail.Updates.Count -eq 0) {
                throw "Software update group '$groupDisplayName' (CI_ID: $groupCIID) contains no updates. Cannot create a deployment for an empty software update group."
            }

            # ---- Resolve Collection ----
            $resolvedCollectionId = $null
            $resolvedCollectionName = $null
            if ($PSBoundParameters.ContainsKey('CollectionName')) {
                $collQuery = "SELECT CollectionID, Name FROM SMS_Collection WHERE Name = '$CollectionName'"
                Write-Verbose "Resolving collection by name: $collQuery"
                $resolvedCollection = Get-CimInstance @cimParams -Query $collQuery

                if (-not $resolvedCollection) {
                    throw "Collection '$CollectionName' not found."
                }
                if (@($resolvedCollection).Count -gt 1) {
                    throw "Multiple collections found matching '$CollectionName'. Please specify using -CollectionId."
                }
                $resolvedCollectionId = $resolvedCollection.CollectionID
                $resolvedCollectionName = $resolvedCollection.Name
                Write-Verbose "Resolved collection: '$resolvedCollectionName' (ID: $resolvedCollectionId)"
            } else {
                $collQuery = "SELECT CollectionID, Name FROM SMS_Collection WHERE CollectionID = '$CollectionId'"
                Write-Verbose "Resolving collection by ID: $collQuery"
                $resolvedCollection = Get-CimInstance @cimParams -Query $collQuery

                if (-not $resolvedCollection) {
                    throw "Collection '$CollectionId' not found."
                }
                $resolvedCollectionId = $resolvedCollection.CollectionID
                $resolvedCollectionName = $resolvedCollection.Name
                Write-Verbose "Resolved collection: '$resolvedCollectionName' (ID: $resolvedCollectionId)"
            }

            # ---- Determine deployment name ----
            $actualDeploymentName = if ($DeploymentName) { $DeploymentName } else { $groupDisplayName }
            Write-Verbose "Deployment name: '$actualDeploymentName'"

            # ---- Set available and deadline times ----
            $now = Get-Date
            $actualAvailableDateTime = if ($PSBoundParameters.ContainsKey('AvailableDateTime')) { $AvailableDateTime } else { $now }

            # For Required deployments, set a default deadline if not specified
            $actualDeadlineDateTime = $null
            if ($DeploymentType -eq 'Required') {
                if ($PSBoundParameters.ContainsKey('DeadlineDateTime')) {
                    $actualDeadlineDateTime = $DeadlineDateTime
                } else {
                    # Default: available time (no enforcement delay - immediate)
                    $actualDeadlineDateTime = $actualAvailableDateTime
                }
            }

            # ---- Prepare datetime values ----
            # CIM cmdlets expect DateTime objects for datetime properties.
            # The CIM layer handles DMTF datetime conversion internally.
            $startTimeValue = [datetime]$actualAvailableDateTime

            # ---- Build SuppressReboot value ----
            # SuppressReboot in SMS_UpdatesAssignment: 0 = no suppress, 1 = suppress servers, 2 = suppress workstations, 3 = suppress both
            $suppressReboot = 0
            if (-not $RestartServer) { $suppressReboot = $suppressReboot -bor 1 }
            if (-not $RestartWorkstation) { $suppressReboot = $suppressReboot -bor 2 }

            # ---- Build notification behavior ----
            $notifyUser = $userNotificationMap[$UserNotification]

            # ---- Build AssignedCIs from the group updates ----
            [int32[]]$assignedCIs = @()
            if ($groupDetail.Updates -and $groupDetail.Updates.Count -gt 0) {
                $assignedCIs = [int32[]]$groupDetail.Updates
            }

            # ---- Create the deployment ----
            $actionDescription = "Create software update deployment '$actualDeploymentName' targeting collection '$resolvedCollectionName' ($resolvedCollectionId) with type '$DeploymentType'"
            if ($Force -or $PSCmdlet.ShouldProcess($actualDeploymentName, $actionDescription)) {
                Write-Verbose "Creating software update deployment: $actionDescription"

                # Build properties for SMS_UpdateGroupAssignment
                # This is the correct class for software update group deployments (confirmed via New-CMSoftwareUpdateDeployment verbose output)
                # Property types must match CIM class schema exactly
                $deploymentProperties = @{
                    AssignmentName                  = [string]$actualDeploymentName
                    AssignmentDescription           = [string]$(if ($Description) { $Description } else { '' })
                    AssignmentAction                = [int32]2   # 2 = Apply
                    AssignmentType                  = [int32]5   # 5 = Software Update Group
                    AssignedUpdateGroup             = [int32]$groupCIID
                    DesiredConfigType               = [int32]$deploymentTypeMap[$DeploymentType]
                    TargetCollectionID              = [string]$resolvedCollectionId
                    StartTime                       = [datetime]$startTimeValue
                    SuppressReboot                  = [uint32]$suppressReboot
                    UseGMTTimes                     = [bool]$UseGMTTimes
                    NotifyUser                      = [bool]$notifyUser
                    UserUIExperience                = [bool]$true
                    OverrideServiceWindows          = [bool]$SoftwareInstallation
                    RebootOutsideOfServiceWindows   = [bool]$AllowRestart
                    Enabled                         = [bool]$Enabled
                    AssignedCIs                     = [int32[]]$assignedCIs
                    StateMessagePriority            = [uint32]5
                    DPLocality                      = [uint32]16
                    UseBranchCache                  = [bool]$UseBranchCache
                    RequirePostRebootFullScan       = [bool]$RequirePostRebootFullScan
                    PreDownloadUpdateContent        = [bool]$false
                    ApplyToSubTargets               = [bool]$false
                    LogComplianceToWinEvent         = [bool]$false
                    DisableMomAlerts                = [bool]$false
                    RaiseMomAlertsOnFailure         = [bool]$false
                    PersistOnWriteFilterDevices     = [bool]$true
                    SoftDeadlineEnabled             = [bool]$false
                    WoLEnabled                      = [bool]$false
                    SendDetailedNonComplianceStatus = [bool]$false
                    LimitStateMessageVerbosity      = [bool]$true
                    StateMessageVerbosity           = [uint32]5
                }

                # Set enforcement deadline for Required deployments
                if ($DeploymentType -eq 'Required' -and $actualDeadlineDateTime) {
                    $deploymentProperties['EnforcementDeadline'] = [datetime]$actualDeadlineDateTime
                }

                Write-Verbose "Deployment properties: Name='$actualDeploymentName', Collection='$resolvedCollectionName', Type='$DeploymentType', Updates=$($assignedCIs.Count)"

                # Create the software update deployment using New-CimInstance
                $newDeployment = New-CimInstance @cimParams -ClassName 'SMS_UpdateGroupAssignment' -Property $deploymentProperties

                if (-not $newDeployment) {
                    throw "Failed to create software update deployment '$actualDeploymentName'. New-CimInstance returned null."
                }

                $assignmentId = $newDeployment.AssignmentID
                Write-Verbose "Software update deployment '$actualDeploymentName' created successfully with AssignmentID: $assignmentId"

                # ---- Retrieve the full deployment object to return ----
                $resultQuery = "SELECT * FROM SMS_UpdateGroupAssignment WHERE AssignmentID = $assignmentId"
                Write-Verbose "Retrieving created deployment: $resultQuery"
                $result = Get-CimInstance @cimParams -Query $resultQuery

                if ($result) {
                    # Map action type
                    $actionName = if ($assignmentActionMap.ContainsKey([int]$result.AssignmentAction)) {
                        $assignmentActionMap[[int]$result.AssignmentAction]
                    } else {
                        "Unknown ($($result.AssignmentAction))"
                    }

                    # Map desired config type
                    $configTypeName = if ($deploymentTypeReverse.ContainsKey([int]$result.DesiredConfigType)) {
                        $deploymentTypeReverse[[int]$result.DesiredConfigType]
                    } else {
                        "Unknown ($($result.DesiredConfigType))"
                    }

                    $output = [PSCustomObject]@{
                        PSTypeName                    = 'MECM7.SoftwareUpdateDeployment'
                        AssignmentID                  = [int]$result.AssignmentID
                        AssignmentName                = $result.AssignmentName
                        TargetCollectionID            = $result.TargetCollectionID
                        CollectionName                = $resolvedCollectionName
                        AssignmentDescription         = $result.AssignmentDescription
                        AssignmentAction              = $actionName
                        DesiredConfigType             = $configTypeName
                        StartTime                     = $result.StartTime
                        EnforcementDeadline           = $result.EnforcementDeadline
                        SuppressReboot                = [bool]$result.SuppressReboot
                        UseGMTTimes                   = [bool]$result.UseGMTTimes
                        NotifyUser                    = [bool]$result.NotifyUser
                        OverrideServiceWindows        = [bool]$result.OverrideServiceWindows
                        RebootOutsideOfServiceWindows = [bool]$result.RebootOutsideOfServiceWindows
                        Enabled                       = [bool]$result.Enabled
                    }

                    # Set the type name
                    $output.PSObject.TypeNames.Insert(0, 'MECM7.SoftwareUpdateDeployment')

                    # Add all extra properties
                    $result.CimInstanceProperties | ForEach-Object {
                        if ($_.Name -notin $output.PSObject.Properties.Name) {
                            $output | Add-Member -MemberType NoteProperty -Name $_.Name -Value $_.Value -Force
                        }
                    }

                    Write-Output $output
                } else {
                    Write-Warning "Software update deployment was created but could not retrieve the result. AssignmentID: $assignmentId"
                }
            }
        }
        catch {
            throw $_
        }
    }
}
