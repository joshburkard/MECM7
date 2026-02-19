function Get-CM7ScriptExecutionStatus {
    <#
        .SYNOPSIS
            Retrieves the execution status of MECM scripts using CIM.

        .DESCRIPTION
            Returns the current execution status and results of MECM scripts that have been
            invoked via Invoke-CM7Script or through the MECM console. This function is the
            CIM-based equivalent of querying SMS_ScriptsExecutionTask and SMS_ScriptsExecutionStatus
            WMI classes.

            The function supports multiple query modes:

            - **By ClientOperationId**: Retrieve detailed status and results for a specific script execution
            - **By ScriptName**: Filter executions by the script name
            - **By CollectionName**: Filter executions by the target collection name
            - **By CollectionId**: Filter executions by the target collection ID
            - **Combined filters**: Combine ScriptName with CollectionName or CollectionId
            - **No filter (list mode)**: When no parameters are specified, returns a summary list of all
              script executions with Operation ID, Script Name, Script GUID, Collection info, and Last Update Time
              but without detailed per-device results

            When a ClientOperationId is provided and completed clients exist, the function retrieves
            per-device results including script output, exit codes, and parsed output objects.

        .PARAMETER ClientOperationId
            The client operation ID returned by Invoke-CM7Script. When specified, retrieves detailed
            execution status and per-device results for that specific operation.

            This parameter is not mandatory. If omitted, a summary list of all script executions
            is returned without per-device results.

        .PARAMETER ScriptName
            Filter script executions by the script name. Can be combined with CollectionName or
            CollectionId for more specific filtering.

        .PARAMETER CollectionName
            Filter script executions by the target collection name. Can be combined with ScriptName
            for more specific filtering.

        .PARAMETER CollectionId
            Filter script executions by the target collection ID. Can be combined with ScriptName
            for more specific filtering.

        .EXAMPLE
            Get-CM7ScriptExecutionStatus

            Returns a summary list of all script executions without detailed results.

        .EXAMPLE
            Get-CM7ScriptExecutionStatus -ClientOperationId 16819576

            Retrieves detailed execution status and per-device results for operation ID 16819576.

        .EXAMPLE
            Get-CM7ScriptExecutionStatus -ScriptName "get pending reboot"

            Returns execution status for all runs of the script "get pending reboot".

        .EXAMPLE
            Get-CM7ScriptExecutionStatus -CollectionName "Test-Collection-Direct"

            Returns execution status for all scripts run against the collection "Test-Collection-Direct".

        .EXAMPLE
            Get-CM7ScriptExecutionStatus -CollectionId "CM101129" -ScriptName "get pending reboot"

            Returns execution status for the script "get pending reboot" run against collection "CM101129".

        .OUTPUTS
            PSCustomObject (MECM7.ScriptExecutionStatus) with properties:
            - OperationID: The client operation ID
            - ScriptName: The name of the executed script
            - ScriptVersion: The version of the script
            - ScriptGuid: The GUID of the script
            - CollectionID: The target collection ID
            - CollectionName: The target collection name
            - Results: Array of per-device results (only when ClientOperationId is specified and clients have completed)
            - Status: Current execution status text
            - TotalClients: Total number of targeted clients
            - CompletedClients: Number of clients that completed execution
            - FailedClients: Number of clients that failed
            - OfflineClients: Number of offline clients
            - NotApplicableClients: Number of not-applicable clients
            - UnknownClients: Number of clients with unknown status
            - LastUpdateTime: Last time the status was updated

            When no ClientOperationId is specified (list mode), returns summary objects
            (MECM7.ScriptExecutionSummary) with:
            - OperationID, ScriptName, ScriptGuid, CollectionID, CollectionName, LastUpdateTime,
              TotalClients, CompletedClients, FailedClients, OfflineClients

        .NOTES
            Requires an active MECM connection established via Connect-CM7.
            Use Invoke-CM7Script to execute scripts and obtain the ClientOperationId for tracking.

        .LINK
            Connect-CM7
            Invoke-CM7Script
    #>
    [CmdletBinding(DefaultParameterSetName = 'noFilter')]
    param(
        [Parameter(Mandatory = $false, ParameterSetName = 'ByClientOperationId')]
        [ValidateNotNullOrEmpty()]
        [int]$ClientOperationId,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByScriptName')]
        [Parameter(Mandatory = $false, ParameterSetName = 'ByCollectionName_ScriptName')]
        [Parameter(Mandatory = $false, ParameterSetName = 'ByCollectionId_ScriptName')]
        [ValidateNotNullOrEmpty()]
        [string]$ScriptName,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByCollectionName')]
        [Parameter(Mandatory = $true, ParameterSetName = 'ByCollectionName_ScriptName')]
        [ValidateNotNullOrEmpty()]
        [string]$CollectionName,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByCollectionId')]
        [Parameter(Mandatory = $true, ParameterSetName = 'ByCollectionId_ScriptName')]
        [ValidateNotNullOrEmpty()]
        [string]$CollectionId
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

        # ── Build WMI query based on parameter set ──────────────────────
        if ($PSCmdlet.ParameterSetName -eq 'ByClientOperationId') {
            $WMIQuery = "SELECT * FROM SMS_ScriptsExecutionTask WHERE ClientOperationId = $ClientOperationId"
        }
        elseif ($PSCmdlet.ParameterSetName -eq 'ByCollectionName_ScriptName') {
            $WMIQuery = "SELECT * FROM SMS_ScriptsExecutionTask WHERE CollectionName = '$CollectionName' AND ScriptName = '$ScriptName'"
        }
        elseif ($PSCmdlet.ParameterSetName -eq 'ByCollectionName') {
            $WMIQuery = "SELECT * FROM SMS_ScriptsExecutionTask WHERE CollectionName = '$CollectionName'"
        }
        elseif ($PSCmdlet.ParameterSetName -eq 'ByCollectionId_ScriptName') {
            $WMIQuery = "SELECT * FROM SMS_ScriptsExecutionTask WHERE CollectionId = '$CollectionId' AND ScriptName = '$ScriptName'"
        }
        elseif ($PSCmdlet.ParameterSetName -eq 'ByCollectionId') {
            $WMIQuery = "SELECT * FROM SMS_ScriptsExecutionTask WHERE CollectionId = '$CollectionId'"
        }
        elseif ($PSCmdlet.ParameterSetName -eq 'ByScriptName') {
            $WMIQuery = "SELECT * FROM SMS_ScriptsExecutionTask WHERE ScriptName = '$ScriptName'"
        }
        else {
            # noFilter - list all
            $WMIQuery = "SELECT * FROM SMS_ScriptsExecutionTask"
        }

        Write-Verbose "Querying: $WMIQuery"
        $TaskStatus = Get-CimInstance @cimParams -Query $WMIQuery

        if ([string]::IsNullOrEmpty($TaskStatus)) {
            Write-Verbose "No script execution tasks found matching the query."
            $output = [PSCustomObject]@{
                PSTypeName           = 'MECM7.ScriptExecutionStatus'
                OperationID          = $null
                ScriptName           = 'Operation not found'
                ScriptVersion        = $null
                ScriptGuid           = $null
                CollectionID         = $null
                CollectionName       = $null
                Results              = $null
                Status               = 'not found'
                TotalClients         = $null
                CompletedClients     = $null
                FailedClients        = $null
                OfflineClients       = $null
                NotApplicableClients = $null
                UnknownClients       = $null
                LastUpdateTime       = $null
            }
            $output.PSObject.TypeNames.Insert(0, 'MECM7.ScriptExecutionStatus')
            Write-Output $output
            return
        }

        # ── Determine if we should include detailed results ─────────────
        # Only include per-device results when a specific ClientOperationId was requested
        $includeResults = ($PSCmdlet.ParameterSetName -eq 'ByClientOperationId')

        foreach ($ts in $TaskStatus) {
            if (-not $includeResults) {
                # Summary mode - return list without per-device results
                $output = [PSCustomObject]@{
                    PSTypeName       = 'MECM7.ScriptExecutionSummary'
                    OperationID      = $ts.ClientOperationId
                    ScriptName       = $ts.ScriptName
                    ScriptGuid       = $ts.ScriptGuid
                    CollectionID     = $ts.CollectionId
                    CollectionName   = $ts.CollectionName
                    LastUpdateTime   = $ts.LastUpdateTime
                    TotalClients     = $ts.TotalClients
                    CompletedClients = $ts.CompletedClients
                    FailedClients    = $ts.FailedClients
                    OfflineClients   = $ts.OfflineClients
                }
                $output.PSObject.TypeNames.Insert(0, 'MECM7.ScriptExecutionSummary')
                Write-Output $output
            }
            else {
                # Detail mode - include per-device results
                if ($ts.CompletedClients -gt 0) {
                    $statusQuery = "SELECT * FROM SMS_ScriptsExecutionStatus WHERE ClientOperationId = $($ts.ClientOperationId)"
                    Write-Verbose "Querying per-device results: $statusQuery"
                    $ClientStatus = Get-CimInstance @cimParams -Query $statusQuery

                    $Results = @()
                    if ($ts.CompletedClients -eq $ts.TotalClients) {
                        $Status = "all clients completed"
                    }
                    else {
                        $Status = "some clients completed"
                    }

                    foreach ($c in $ClientStatus) {
                        $ScriptOutput = $c.ScriptOutput
                        try {
                            $ScriptOutput = $ScriptOutput -replace '\\r\\n', [System.Environment]::NewLine
                            $ScriptOutput = $ScriptOutput -replace '\\"', '"'
                            $ScriptOutput = $ScriptOutput -replace '\\\\', '\'
                            $OutputObject = $ScriptOutput | ConvertFrom-Json
                        }
                        catch {
                            $OutputObject = $c.ScriptOutput
                        }

                        $Results += [PSCustomObject]@{
                            ResourceID           = $c.ResourceId
                            DeviceName           = $c.DeviceName
                            ScriptExecutionState = $c.ScriptExecutionState
                            ScriptExitCode       = $c.ScriptExitCode
                            ScriptOutput         = $c.ScriptOutput
                            OutputObject         = $OutputObject
                        }
                    }

                    $output = [PSCustomObject]@{
                        PSTypeName           = 'MECM7.ScriptExecutionStatus'
                        OperationID          = $ts.ClientOperationId
                        ScriptName           = $ts.ScriptName
                        ScriptVersion        = $ts.ScriptVersion
                        ScriptGuid           = $ts.ScriptGuid
                        CollectionID         = $ts.CollectionId
                        CollectionName       = $ts.CollectionName
                        Results              = $Results
                        Status               = $Status
                        TotalClients         = $ts.TotalClients
                        CompletedClients     = $ts.CompletedClients
                        FailedClients        = $ts.FailedClients
                        OfflineClients       = $ts.OfflineClients
                        NotApplicableClients = $ts.NotApplicableClients
                        UnknownClients       = $ts.UnknownClients
                        LastUpdateTime       = $ts.LastUpdateTime
                    }
                    $output.PSObject.TypeNames.Insert(0, 'MECM7.ScriptExecutionStatus')
                    Write-Output $output
                }
                else {
                    $output = [PSCustomObject]@{
                        PSTypeName           = 'MECM7.ScriptExecutionStatus'
                        OperationID          = $ts.ClientOperationId
                        ScriptName           = $ts.ScriptName
                        ScriptVersion        = $ts.ScriptVersion
                        ScriptGuid           = $ts.ScriptGuid
                        CollectionID         = $ts.CollectionId
                        CollectionName       = $ts.CollectionName
                        Results              = $null
                        Status               = 'no client completed'
                        TotalClients         = $ts.TotalClients
                        CompletedClients     = $ts.CompletedClients
                        FailedClients        = $ts.FailedClients
                        OfflineClients       = $ts.OfflineClients
                        NotApplicableClients = $ts.NotApplicableClients
                        UnknownClients       = $ts.UnknownClients
                        LastUpdateTime       = $ts.LastUpdateTime
                    }
                    $output.PSObject.TypeNames.Insert(0, 'MECM7.ScriptExecutionStatus')
                    Write-Output $output
                }
            }
        }
    }
    catch {
        Write-Error "Failed to get script execution status: $($_.Exception.Message)"
    }
}
