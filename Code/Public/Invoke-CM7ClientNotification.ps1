function Invoke-CM7ClientNotification {
    <#
        .SYNOPSIS
            Sends a client notification action to target devices or a collection using CIM.

        .DESCRIPTION
            Sends a client notification to MECM-managed devices, triggering actions like policy
            refresh, inventory cycles, software update scans, and more. This function is the
            CIM-based equivalent of the Invoke-CMClientNotification cmdlet from the
            ConfigurationManager PowerShell module, but uses direct CIM queries over WinRM
            instead of requiring the ConfigMgr console or PowerShell drive.

            The function performs the following actions:

            1. Validates an active connection exists (established via Connect-CM7)
            2. Maps the requested ActionType to the corresponding SMS_ClientOperation type code
            3. Resolves target devices by name or collection name if needed
            4. Invokes the SMS_ClientOperation.InitiateClientOperationEx CIM method
            5. Returns the client operation result including the OperationID

            Supported notification action types:

            Client Notifications:
            - **ClientNotificationRequestMachinePolicyNow**: Machine Policy Retrieval & Evaluation Cycle
            - **ClientNotificationRequestUsersPolicyNow**: User Policy Retrieval & Evaluation Cycle
            - **ClientNotificationRequestDDRNow**: Discovery Data Collection Cycle
            - **ClientNotificationRequestHWInvNow**: Hardware Inventory Cycle
            - **ClientNotificationRequestSWInvNow**: Software Inventory Cycle
            - **ClientNotificationAppDeplEvalNow**: Application Deployment Evaluation Cycle
            - **ClientNotificationSUMDeplEvalNow**: Software Updates Deployment Evaluation Cycle
            - **ClientNotificationCheckComplianceNow**: Check Compliance Now
            - **ClientRequestSUPChangeNow**: Request SUP Change Now
            - **ClientRequestDHAChangeNow**: Request DHA Change Now
            - **ClientNotificationRebootMachine**: Restart Computer
            - **ClientNotificationWakeUpClientNow**: Wake Up Client Now

            Diagnostics:
            - **DiagnosticsEnableVerboseLogging**: Enable Verbose Logging
            - **DiagnosticsDisableVerboseLogging**: Disable Verbose Logging
            - **DiagnosticsCollectFiles**: Collect Diagnostic Files

            Endpoint Protection:
            - **EndpointProtectionFullScan**: Full Scan
            - **EndpointProtectionQuickScan**: Quick Scan
            - **EndpointProtectionDownloadDefinition**: Download Definition
            - **EndpointProtectionEvaluateSoftwareUpdate**: Evaluate Software Update
            - **EndpointProtectionExcludeScanPaths**: Exclude Scan Paths
            - **EndpointProtectionAllowThreat**: Allow Threat
            - **EndpointProtectionRestoreQuarantinedItems**: Restore Quarantined Items
            - **EndpointProtectionRestoreWithDeps**: Restore With Dependencies

        .PARAMETER ActionType
            The type of client notification action to send. Must be one of the supported
            notification action types listed in the description.

        .PARAMETER DeviceName
            The name of the target device to send the notification to. The device is resolved
            to its ResourceID via the SMS_R_System class. Cannot be used together with
            ResourceId, CollectionId, or CollectionName.

        .PARAMETER ResourceId
            The ResourceID of the target device(s) to send the notification to. Accepts a
            single integer or an array of integers for targeting multiple devices. Cannot be
            used together with DeviceName, CollectionId, or CollectionName.

        .PARAMETER CollectionId
            The CollectionID of the target collection. The notification will be sent to all
            members of the specified collection. Cannot be used together with DeviceName,
            ResourceId, or CollectionName.

        .PARAMETER CollectionName
            The name of the target collection. The collection is resolved to its CollectionID.
            The notification will be sent to all members of the specified collection. Cannot be
            used together with DeviceName, ResourceId, or CollectionId.

        .EXAMPLE
            Invoke-CM7ClientNotification -ActionType ClientNotificationRequestMachinePolicyNow -DeviceName "SERVER01"

            Sends a machine policy refresh notification to the device "SERVER01".

        .EXAMPLE
            Invoke-CM7ClientNotification -ActionType ClientNotificationRequestHWInvNow -ResourceId 16893210

            Triggers a hardware inventory cycle on the device with ResourceID 16893210.

        .EXAMPLE
            Invoke-CM7ClientNotification -ActionType ClientNotificationSUMDeplEvalNow -CollectionId "SD101C00"

            Triggers a software updates deployment evaluation cycle on all members of the collection with ID "SD101C00".

        .EXAMPLE
            Invoke-CM7ClientNotification -ActionType ClientNotificationSUMDeplEvalNow -CollectionName "Test-Collection-Direct"

            Triggers a software updates deployment evaluation cycle on all members of the collection named "Test-Collection-Direct".

        .EXAMPLE
            Invoke-CM7ClientNotification -ActionType ClientNotificationRebootMachine -DeviceName "SERVER01"

            Restarts the device "SERVER01".

        .EXAMPLE
            Invoke-CM7ClientNotification -ActionType ClientNotificationRequestMachinePolicyNow -ResourceId @(16893210, 16893465)

            Sends a machine policy refresh notification to multiple devices specified by their ResourceIDs.

        .EXAMPLE
            Invoke-CM7ClientNotification -ActionType EndpointProtectionQuickScan -DeviceName "SERVER01"

            Triggers an Endpoint Protection quick scan on the device "SERVER01".

        .OUTPUTS
            PSCustomObject (MECM7.ClientNotification) with properties:
            - OperationID: The client operation ID for tracking
            - ActionType: The notification action type that was sent
            - ReturnValue: The return value from the CIM method invocation (0 = success)

        .NOTES
            Requires an active MECM connection established via Connect-CM7.
            The device must be an active MECM client to receive the notification.
            Some actions like ClientNotificationRebootMachine require appropriate MECM permissions.
            Use -WhatIf or -Confirm for actions like ClientNotificationRebootMachine to preview or confirm before executing.

        .LINK
            Connect-CM7
            Get-CM7Device
            Get-CM7Collection
    #>
    [CmdletBinding(DefaultParameterSetName = 'ByDeviceName', SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet(
            'ClientNotificationRequestMachinePolicyNow',
            'ClientNotificationRequestUsersPolicyNow',
            'ClientNotificationRequestDDRNow',
            'ClientNotificationRequestHWInvNow',
            'ClientNotificationRequestSWInvNow',
            'ClientNotificationAppDeplEvalNow',
            'ClientNotificationSUMDeplEvalNow',
            'ClientNotificationCheckComplianceNow',
            'ClientRequestSUPChangeNow',
            'ClientRequestDHAChangeNow',
            'ClientNotificationRebootMachine',
            'ClientNotificationWakeUpClientNow',
            'DiagnosticsEnableVerboseLogging',
            'DiagnosticsDisableVerboseLogging',
            'DiagnosticsCollectFiles',
            'EndpointProtectionFullScan',
            'EndpointProtectionQuickScan',
            'EndpointProtectionDownloadDefinition',
            'EndpointProtectionEvaluateSoftwareUpdate',
            'EndpointProtectionExcludeScanPaths',
            'EndpointProtectionAllowThreat',
            'EndpointProtectionRestoreQuarantinedItems',
            'EndpointProtectionRestoreWithDeps'
        )]
        [string]$ActionType,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByDeviceName')]
        [ValidateNotNullOrEmpty()]
        [string]$DeviceName,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByResourceId')]
        [ValidateNotNullOrEmpty()]
        [int[]]$ResourceId,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByCollectionId')]
        [ValidateNotNullOrEmpty()]
        [string]$CollectionId,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByCollectionName')]
        [ValidateNotNullOrEmpty()]
        [string]$CollectionName
    )

    $function = $($MyInvocation.MyCommand.Name)
    Write-Verbose "Running $function"

    # Validate connection
    if (-not $script:CMConnection.CimSession) {
        throw "Not connected to MECM. Please run Connect-CM7 first."
    }

    try {
        $namespace = "root/SMS/site_$($script:CMConnection.SiteCode)"
        $cimParams = @{
            CimSession = $script:CMConnection.CimSession
            Namespace  = $namespace
        }

        # ── Map ActionType to SMS_ClientOperation Type code ─────────────
        $actionTypeMap = @{
            # Client Notifications
            'ClientNotificationRequestMachinePolicyNow'    = [UInt32]8
            'ClientNotificationRequestUsersPolicyNow'      = [UInt32]9
            'ClientNotificationRequestDDRNow'              = [UInt32]10
            'ClientNotificationRequestSWInvNow'            = [UInt32]11
            'ClientNotificationRequestHWInvNow'            = [UInt32]12
            'ClientNotificationAppDeplEvalNow'             = [UInt32]13
            'ClientNotificationSUMDeplEvalNow'             = [UInt32]14
            'ClientRequestSUPChangeNow'                    = [UInt32]15
            'ClientRequestDHAChangeNow'                    = [UInt32]16
            'ClientNotificationRebootMachine'              = [UInt32]17
            'ClientNotificationCheckComplianceNow'         = [UInt32]125
            'ClientNotificationWakeUpClientNow'            = [UInt32]0  # WOL - may require specific permissions
            # Diagnostics
            'DiagnosticsEnableVerboseLogging'              = [UInt32]20
            'DiagnosticsDisableVerboseLogging'             = [UInt32]21
            'DiagnosticsCollectFiles'                      = [UInt32]22
            # Endpoint Protection
            'EndpointProtectionFullScan'                   = [UInt32]1
            'EndpointProtectionQuickScan'                  = [UInt32]2
            'EndpointProtectionDownloadDefinition'         = [UInt32]3
            'EndpointProtectionEvaluateSoftwareUpdate'     = [UInt32]4
            'EndpointProtectionExcludeScanPaths'           = [UInt32]5
            'EndpointProtectionAllowThreat'                = [UInt32]6
            'EndpointProtectionRestoreQuarantinedItems'    = [UInt32]7
            'EndpointProtectionRestoreWithDeps'            = [UInt32]100
        }

        $operationType = $actionTypeMap[$ActionType]
        Write-Verbose "Client action type: $ActionType (Operation Type: $operationType)"

        # ── Resolve target ──────────────────────────────────────────────
        $targetCollectionID = ""
        $targetResourceIDs = @()

        if ($DeviceName) {
            Write-Verbose "Resolving device by name: $DeviceName"
            $deviceQuery = "SELECT ResourceID FROM SMS_R_System WHERE Name = '$DeviceName'"
            $device = Get-CimInstance @cimParams -Query $deviceQuery
            if (-not $device) {
                throw "Could not find device with name '$DeviceName'."
            }
            if ($device -is [array]) {
                $targetResourceIDs = @($device | ForEach-Object { [UInt32]$_.ResourceID })
            }
            else {
                $targetResourceIDs = @([UInt32]$device.ResourceID)
            }
            Write-Verbose "Resolved device '$DeviceName' to ResourceID(s): $($targetResourceIDs -join ', ')"
        }
        elseif ($ResourceId) {
            $targetResourceIDs = @($ResourceId | ForEach-Object { [UInt32]$_ })
            Write-Verbose "Targeting ResourceID(s): $($targetResourceIDs -join ', ')"
        }
        elseif ($CollectionName) {
            Write-Verbose "Resolving collection by name: $CollectionName"
            $collectionQuery = "SELECT CollectionID FROM SMS_Collection WHERE Name = '$CollectionName'"
            $collection = Get-CimInstance @cimParams -Query $collectionQuery
            if (-not $collection) {
                throw "Could not find collection with name '$CollectionName'."
            }
            if ($collection -is [array]) {
                $collection = $collection[0]
                Write-Warning "Multiple collections found with name '$CollectionName'. Using first match: $($collection.CollectionID)"
            }
            $targetCollectionID = $collection.CollectionID
            Write-Verbose "Resolved collection '$CollectionName' to CollectionID: $targetCollectionID"
        }
        elseif ($CollectionId) {
            $targetCollectionID = $CollectionId
            Write-Verbose "Targeting collection: $CollectionId"
        }

        # Validate we have a target
        if ([string]::IsNullOrEmpty($targetCollectionID) -and $targetResourceIDs.Count -eq 0) {
            throw "No valid target specified. Provide DeviceName, ResourceId, CollectionId, or CollectionName."
        }

        # ── Build target description for ShouldProcess ──────────────────
        $targetDescription = if ($DeviceName) { "Name=`"$DeviceName`"" }
            elseif ($ResourceId) { "ResourceID=$($targetResourceIDs -join ', ')" }
            elseif ($CollectionName) { "Collection=`"$CollectionName`"" }
            else { "CollectionID=`"$CollectionId`"" }

        if ($PSCmdlet.ShouldProcess("ClientAction: $targetDescription", "Invoke")) {
            # ── Invoke the CIM method ───────────────────────────────────
            $methodParams = @{
                Param              = ""
                RandomizationWindow = [UInt32]0
                TargetCollectionID = $targetCollectionID
                TargetResourceIDs  = [UInt32[]]$targetResourceIDs
                Type               = $operationType
            }

            Write-Verbose "Invoking InitiateClientOperationEx on SMS_ClientOperation (Type: $operationType)..."

            $result = Invoke-CimMethod @cimParams `
                -ClassName 'SMS_ClientOperation' `
                -MethodName 'InitiateClientOperationEx' `
                -Arguments $methodParams

            Write-Verbose "Method invocation completed. OperationID: $($result.OperationID), ReturnValue: $($result.ReturnValue)"

            # ── Return result object ────────────────────────────────────
            $output = [PSCustomObject]@{
                PSTypeName  = 'MECM7.ClientNotification'
                OperationID = $result.OperationID
                ActionType  = $ActionType
                ReturnValue = $result.ReturnValue
            }
            $output.PSObject.TypeNames.Insert(0, 'MECM7.ClientNotification')

            Write-Output $output
        }
    }
    catch {
        Write-Error "Failed to send client notification: $($_.Exception.Message)"
    }
}
