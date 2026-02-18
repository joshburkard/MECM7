function Get-CM7SoftwareUpdateDeployment {
    <#
        .SYNOPSIS
            Retrieves software update deployment information from MECM using CIM.

        .DESCRIPTION
            Queries the SMS_UpdatesAssignment WMI class to retrieve software update deployment
            information from MECM. Supports filtering by assignment ID, deployment name,
            and collection name.
            Requires an active connection established via Connect-CM7.

            This function is the CIM-based equivalent of the Get-CMSoftwareUpdateDeployment cmdlet
            from the ConfigurationManager PowerShell module, but uses direct CIM queries over WinRM
            instead of requiring the ConfigMgr console or PowerShell drive.

        .PARAMETER AssignmentId
            The unique assignment ID (integer) of the software update deployment to retrieve.

        .PARAMETER Name
            The name of the software update deployment. Supports wildcard characters (* and ?).

        .PARAMETER CollectionName
            The name of the collection targeted by the software update deployment.
            Supports wildcard characters (* and ?).

        .PARAMETER Fast
            Returns limited properties for faster queries. Only returns essential properties like
            AssignmentID, AssignmentName, TargetCollectionID, AssignmentDescription, StartTime,
            EnforcementDeadline, and summary flags.

        .EXAMPLE
            Get-CM7SoftwareUpdateDeployment
            Retrieves all software update deployments.

        .EXAMPLE
            Get-CM7SoftwareUpdateDeployment -AssignmentId 16777220
            Retrieves the software update deployment with the specified assignment ID.

        .EXAMPLE
            Get-CM7SoftwareUpdateDeployment -Name "2024-01 Security Updates"
            Retrieves the software update deployment with the specified name.

        .EXAMPLE
            Get-CM7SoftwareUpdateDeployment -Name "2024*"
            Retrieves all software update deployments whose names start with "2024".

        .EXAMPLE
            Get-CM7SoftwareUpdateDeployment -CollectionName "SP_ACC_2024-01-18_18:00_00:00_automatic_reboot"
            Retrieves all software update deployments targeting the specified collection.

        .EXAMPLE
            Get-CM7SoftwareUpdateDeployment -CollectionName "SP_ACC_*"
            Retrieves all software update deployments targeting collections whose names start with "SP_ACC_".

        .EXAMPLE
            Get-CM7SoftwareUpdateDeployment -CollectionName "All Systems" -Fast
            Retrieves software update deployments for "All Systems" with limited properties.

        .NOTES
            Requires an active connection established via Connect-CM7.
    #>
    [CmdletBinding(DefaultParameterSetName = 'All')]
    param(
        [Parameter(ParameterSetName = 'ByAssignmentId', Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [int]$AssignmentId,

        [Parameter(ParameterSetName = 'ByName', Mandatory = $true)]
        [SupportsWildcards()]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [Parameter(ParameterSetName = 'ByCollectionName', Mandatory = $true)]
        [SupportsWildcards()]
        [ValidateNotNullOrEmpty()]
        [string]$CollectionName,

        [Parameter()]
        [switch]$Fast
    )

    begin {
        $function = $($MyInvocation.MyCommand.Name)
        Write-Verbose "Running $function"

        # Validate connection
        if (-not $script:CMConnection.CimSession) {
            throw "Not connected to MECM. Please run Connect-CM7 first."
        }

        # Namespace and CIM params
        $namespace = "root/SMS/site_$($script:CMConnection.SiteCode)"
        $cimParams = @{
            CimSession = $script:CMConnection.CimSession
            Namespace  = $namespace
        }

        # Assignment action type mapping for display
        $assignmentActionMap = @{
            0 = 'Detect'
            1 = 'Install'
        }

        # Desired config type mapping
        $desiredConfigTypeMap = @{
            1 = 'Required'
            2 = 'Optional'
        }
    }

    process {
        try {
            # Build WQL filter based on parameters
            $filters = @()

            switch ($PSCmdlet.ParameterSetName) {
                'ByAssignmentId' {
                    $filters += "AssignmentID = $AssignmentId"
                }
                'ByName' {
                    $wqlName = $Name.Replace('*', '%').Replace('?', '_')
                    if ($wqlName -like '*%*' -or $wqlName -like '*_*') {
                        $filters += "AssignmentName LIKE '$wqlName'"
                    } else {
                        $filters += "AssignmentName = '$Name'"
                    }
                }
                'ByCollectionName' {
                    # CollectionName is not a direct property of SMS_UpdatesAssignment.
                    # We need to resolve the collection name to a CollectionID first.
                    $wqlCollName = $CollectionName.Replace('*', '%').Replace('?', '_')
                    if ($wqlCollName -like '*%*' -or $wqlCollName -like '*_*') {
                        $collectionQuery = "SELECT CollectionID, Name FROM SMS_Collection WHERE Name LIKE '$wqlCollName'"
                    } else {
                        $collectionQuery = "SELECT CollectionID, Name FROM SMS_Collection WHERE Name = '$CollectionName'"
                    }

                    Write-Verbose "Resolving collection name: $collectionQuery"
                    $collections = Get-CimInstance @cimParams -Query $collectionQuery

                    if (-not $collections) {
                        Write-Verbose "No collections found matching '$CollectionName'."
                        return
                    }

                    $collectionIds = @($collections | ForEach-Object { $_.CollectionID })
                    if ($collectionIds.Count -eq 1) {
                        $filters += "TargetCollectionID = '$($collectionIds[0])'"
                    } else {
                        $orClauses = $collectionIds | ForEach-Object { "TargetCollectionID = '$_'" }
                        $filters += "(" + ($orClauses -join " OR ") + ")"
                    }
                }
            }

            # Build the query
            if ($Fast) {
                $properties = "AssignmentID, AssignmentName, TargetCollectionID, AssignmentDescription, StartTime, EnforcementDeadline, AssignmentAction, DesiredConfigType, SuppressReboot, UseGMTTimes, NotifyUser, OverrideServiceWindows, RebootOutsideOfServiceWindows, Enabled"
                $query = "SELECT $properties FROM SMS_UpdatesAssignment"
            } else {
                $query = "SELECT * FROM SMS_UpdatesAssignment"
            }

            if ($filters.Count -gt 0) {
                $query += " WHERE " + ($filters -join " AND ")
            }

            Write-Verbose "Executing query: $query"

            # Execute the query
            $assignments = Get-CimInstance @cimParams -Query $query

            # If we searched by collection name, also build a lookup for collection names
            $collectionNameLookup = @{}
            if ($PSCmdlet.ParameterSetName -eq 'ByCollectionName' -and $collections) {
                foreach ($coll in $collections) {
                    $collectionNameLookup[$coll.CollectionID] = $coll.Name
                }
            }

            # Output results
            if ($assignments) {
                foreach ($assignment in $assignments) {
                    # Resolve collection name if not already known
                    $resolvedCollectionName = $null
                    if ($collectionNameLookup.ContainsKey($assignment.TargetCollectionID)) {
                        $resolvedCollectionName = $collectionNameLookup[$assignment.TargetCollectionID]
                    } else {
                        # Look up collection name for this assignment
                        $collLookupQuery = "SELECT Name FROM SMS_Collection WHERE CollectionID = '$($assignment.TargetCollectionID)'"
                        $collResult = Get-CimInstance @cimParams -Query $collLookupQuery
                        if ($collResult) {
                            $resolvedCollectionName = $collResult.Name
                            $collectionNameLookup[$assignment.TargetCollectionID] = $resolvedCollectionName
                        }
                    }

                    # Map action type
                    $actionName = if ($assignmentActionMap.ContainsKey([int]$assignment.AssignmentAction)) {
                        $assignmentActionMap[[int]$assignment.AssignmentAction]
                    } else {
                        "Unknown ($($assignment.AssignmentAction))"
                    }

                    # Map desired config type
                    $configTypeName = if ($desiredConfigTypeMap.ContainsKey([int]$assignment.DesiredConfigType)) {
                        $desiredConfigTypeMap[[int]$assignment.DesiredConfigType]
                    } else {
                        "Unknown ($($assignment.DesiredConfigType))"
                    }

                    $output = [PSCustomObject]@{
                        PSTypeName                    = 'MECM7.SoftwareUpdateDeployment'
                        AssignmentID                  = [int]$assignment.AssignmentID
                        AssignmentName                = $assignment.AssignmentName
                        TargetCollectionID            = $assignment.TargetCollectionID
                        CollectionName                = $resolvedCollectionName
                        AssignmentDescription         = $assignment.AssignmentDescription
                        AssignmentAction              = $actionName
                        DesiredConfigType             = $configTypeName
                        StartTime                     = $assignment.StartTime
                        EnforcementDeadline           = $assignment.EnforcementDeadline
                        SuppressReboot                = [bool]$assignment.SuppressReboot
                        UseGMTTimes                   = [bool]$assignment.UseGMTTimes
                        NotifyUser                    = [bool]$assignment.NotifyUser
                        OverrideServiceWindows        = [bool]$assignment.OverrideServiceWindows
                        RebootOutsideOfServiceWindows = [bool]$assignment.RebootOutsideOfServiceWindows
                        Enabled                       = [bool]$assignment.Enabled
                    }

                    # Set the type name
                    $output.PSObject.TypeNames.Insert(0, 'MECM7.SoftwareUpdateDeployment')

                    # Add all properties if not Fast mode
                    if (-not $Fast) {
                        $assignment.CimInstanceProperties | ForEach-Object {
                            if ($_.Name -notin $output.PSObject.Properties.Name) {
                                $output | Add-Member -MemberType NoteProperty -Name $_.Name -Value $_.Value -Force
                            }
                        }
                    }

                    Write-Output $output
                }
            } else {
                Write-Verbose "No software update deployments found matching the criteria."
            }
        }
        catch {
            throw $_
        }
    }
}
