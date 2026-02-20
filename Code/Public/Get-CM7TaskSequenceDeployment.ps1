function Get-CM7TaskSequenceDeployment {
    <#
        .SYNOPSIS
            Retrieves task sequence deployment information from MECM using CIM.

        .DESCRIPTION
            Queries the SMS_Advertisement WMI class to retrieve task sequence deployment
            information from MECM. Supports filtering by advertisement ID (deployment ID),
            task sequence name, task sequence package ID, collection name, and deployment name.
            Requires an active connection established via Connect-CM7.

            This function is the CIM-based equivalent of the Get-CMTaskSequenceDeployment cmdlet
            from the ConfigurationManager PowerShell module, but uses direct CIM queries over WinRM
            instead of requiring the ConfigMgr console or PowerShell drive.

            The function performs the following actions:
            1. Validates an active connection exists (established via Connect-CM7)
            2. Builds a WQL query based on the provided parameters
            3. Resolves collection names and task sequence names to their respective IDs
               via the SMS_Collection and SMS_TaskSequencePackage classes
            4. Queries SMS_DeploymentSummary (FeatureType = 7) to find task sequence deployments,
               then retrieves full details from SMS_Advertisement
            5. Returns formatted task sequence deployment objects with commonly used properties

            Key features:
            - Wildcard Support: Use * and ? in deployment names, task sequence names,
              and collection names for pattern matching
            - Collection Name Filtering: Filter by collection name (resolved to CollectionID)
            - Task Sequence Filtering: Filter by task sequence name or PackageID
            - Fast Mode: Return limited properties for faster queries on large environments
            - Flexible Querying: Query by advertisement ID, task sequence, collection, or retrieve all

        .PARAMETER AdvertisementID
            The unique advertisement ID (deployment ID) of the task sequence deployment to retrieve.
            This is the AdvertisementID property (string), e.g. "SD120BD2".

        .PARAMETER TaskSequenceName
            The name of the task sequence associated with the deployment.
            Supports wildcard characters (* and ?).

        .PARAMETER TaskSequencePackageId
            The PackageID of the task sequence associated with the deployment.

        .PARAMETER CollectionName
            The name of the collection targeted by the task sequence deployment.
            Supports wildcard characters (* and ?).

        .PARAMETER DeploymentName
            The name of the deployment (AdvertisementName). Supports wildcard characters (* and ?).

        .PARAMETER Fast
            Returns limited properties for faster queries. Only returns essential properties like
            AdvertisementID, AdvertisementName, CollectionID, PackageID, ProgramName, and summary flags.

        .EXAMPLE
            Get-CM7TaskSequenceDeployment
            Retrieves all task sequence deployments.

        .EXAMPLE
            Get-CM7TaskSequenceDeployment -AdvertisementID "SD120BD2"
            Retrieves the task sequence deployment with the specified advertisement ID.

        .EXAMPLE
            Get-CM7TaskSequenceDeployment -CollectionName "SP_ACC_2025-01-30_18:00_00:00_automatic_reboot"
            Retrieves all task sequence deployments targeting the specified collection.

        .EXAMPLE
            Get-CM7TaskSequenceDeployment -CollectionName "SP_ACC_*"
            Retrieves all task sequence deployments targeting collections whose names start with "SP_ACC_".

        .EXAMPLE
            Get-CM7TaskSequenceDeployment -TaskSequenceName "Test Josh"
            Retrieves all deployments of the task sequence named "Test Josh".

        .EXAMPLE
            Get-CM7TaskSequenceDeployment -TaskSequencePackageId "SD100FAD"
            Retrieves all deployments of the task sequence with PackageID "SD100FAD".

        .EXAMPLE
            Get-CM7TaskSequenceDeployment -DeploymentName "*reboot*"
            Retrieves all task sequence deployments whose names contain "reboot".

        .EXAMPLE
            Get-CM7TaskSequenceDeployment -CollectionName "SP_ACC_2025-01-30_18:00_00:00_automatic_reboot" -Fast
            Retrieves task sequence deployments for the specified collection with limited properties.

        .EXAMPLE
            Get-CM7TaskSequenceDeployment | Select-Object AdvertisementID, AdvertisementName, CollectionID, PackageID | Format-Table -AutoSize
            Lists all task sequence deployments in a summary table.

        .NOTES
            Requires an active connection established via Connect-CM7.

            The function first queries SMS_DeploymentSummary with FeatureType = 7 (TaskSequence)
            to identify task sequence deployments, then retrieves full details from SMS_Advertisement.

            SMS_Advertisement lazy properties (cause HRESULT 0x80041001 in WQL SELECT over WinRM):
              AssignedSchedule, AssignedScheduleEnabled, AssignedScheduleIsGMT,
              ExpirationTimeEnabled, ExpirationTimeIsGMT, PresentTimeEnabled,
              PresentTimeIsGMT, TimeFlags
            These are only available in non-Fast mode (via SELECT *).

            This is the CIM-based equivalent of the Get-CMTaskSequenceDeployment cmdlet from the
            ConfigurationManager PowerShell module but uses direct CIM queries over WinRM
            instead of requiring the ConfigMgr console or PowerShell drive.
    #>
    [CmdletBinding(DefaultParameterSetName = 'All')]
    param(
        [Parameter(ParameterSetName = 'ByAdvertisementID', Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$AdvertisementID,

        [Parameter(ParameterSetName = 'ByTaskSequenceName', Mandatory = $true)]
        [SupportsWildcards()]
        [ValidateNotNullOrEmpty()]
        [string]$TaskSequenceName,

        [Parameter(ParameterSetName = 'ByTaskSequencePackageId', Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$TaskSequencePackageId,

        [Parameter(ParameterSetName = 'ByCollectionName', Mandatory = $true)]
        [SupportsWildcards()]
        [ValidateNotNullOrEmpty()]
        [string]$CollectionName,

        [Parameter(ParameterSetName = 'ByDeploymentName', Mandatory = $true)]
        [SupportsWildcards()]
        [ValidateNotNullOrEmpty()]
        [string]$DeploymentName,

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
    }

    process {
        try {
            # Build WQL filter based on parameters
            $advertisementFilters = @()
            $deploymentSummaryFilters = @("FeatureType = 7")

            switch ($PSCmdlet.ParameterSetName) {
                'ByAdvertisementID' {
                    $advertisementFilters += "AdvertisementID = '$AdvertisementID'"
                }
                'ByTaskSequenceName' {
                    # Resolve task sequence name to PackageID(s)
                    $wqlTsName = $TaskSequenceName.Replace('*', '%').Replace('?', '_')
                    if ($wqlTsName -like '*%*' -or $wqlTsName -like '*_*') {
                        $tsQuery = "SELECT PackageID, Name FROM SMS_TaskSequencePackage WHERE Name LIKE '$wqlTsName'"
                    } else {
                        $tsQuery = "SELECT PackageID, Name FROM SMS_TaskSequencePackage WHERE Name = '$TaskSequenceName'"
                    }

                    Write-Verbose "Resolving task sequence name: $tsQuery"
                    $taskSequences = Get-CimInstance @cimParams -Query $tsQuery

                    if (-not $taskSequences) {
                        Write-Verbose "No task sequences found matching '$TaskSequenceName'."
                        return
                    }

                    $packageIds = @($taskSequences | ForEach-Object { $_.PackageID })
                    if ($packageIds.Count -eq 1) {
                        $advertisementFilters += "PackageID = '$($packageIds[0])'"
                    } else {
                        $orClauses = $packageIds | ForEach-Object { "PackageID = '$_'" }
                        $advertisementFilters += "(" + ($orClauses -join " OR ") + ")"
                    }
                }
                'ByTaskSequencePackageId' {
                    $advertisementFilters += "PackageID = '$TaskSequencePackageId'"
                }
                'ByCollectionName' {
                    # Resolve collection name to CollectionID(s)
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
                        $advertisementFilters += "CollectionID = '$($collectionIds[0])'"
                        $deploymentSummaryFilters += "CollectionID = '$($collectionIds[0])'"
                    } else {
                        $orClauses = $collectionIds | ForEach-Object { "CollectionID = '$_'" }
                        $advertisementFilters += "(" + ($orClauses -join " OR ") + ")"
                        $deploymentSummaryFilters += "(" + ($orClauses -join " OR ") + ")"
                    }
                }
                'ByDeploymentName' {
                    $wqlName = $DeploymentName.Replace('*', '%').Replace('?', '_')
                    if ($wqlName -like '*%*' -or $wqlName -like '*_*') {
                        $advertisementFilters += "AdvertisementName LIKE '$wqlName'"
                    } else {
                        $advertisementFilters += "AdvertisementName = '$DeploymentName'"
                    }
                }
            }

            # Strategy: Use SMS_DeploymentSummary (FeatureType=7) to find task sequence deployments,
            # then retrieve full details from SMS_Advertisement.
            # For ByAdvertisementID, query SMS_Advertisement directly.

            $advertisementIds = @()

            if ($PSCmdlet.ParameterSetName -eq 'ByAdvertisementID') {
                # Direct query by AdvertisementID - skip DeploymentSummary lookup
                $advertisementIds = @($AdvertisementID)
            } else {
                # Query SMS_DeploymentSummary to find matching task sequence deployments
                $dsQuery = "SELECT DeploymentID FROM SMS_DeploymentSummary WHERE " + ($deploymentSummaryFilters -join " AND ")

                # Add ProgramName = '*' which is the marker for task sequence deployments in SMS_DeploymentSummary
                $dsQuery += " AND ProgramName = '*'"

                Write-Verbose "Querying deployment summary: $dsQuery"
                $deploymentSummaries = Get-CimInstance @cimParams -Query $dsQuery

                if (-not $deploymentSummaries) {
                    # If no results from deployment summary, try direct SMS_Advertisement query
                    # This handles cases where the deployment may not yet appear in DeploymentSummary
                    Write-Verbose "No task sequence deployments found in SMS_DeploymentSummary. Trying SMS_Advertisement directly."

                    # For task sequence deployments in SMS_Advertisement, ProgramName = '*'
                    $advFilters = @("ProgramName = '*'") + $advertisementFilters

                    $advQuery = if ($Fast) {
                        "SELECT AdvertisementID, AdvertisementName, CollectionID, PackageID, ProgramName, SourceSite, " +
                        "AdvertFlags, RemoteClientFlags, PresentTime, ExpirationTime " +
                        "FROM SMS_Advertisement"
                    } else {
                        "SELECT * FROM SMS_Advertisement"
                    }
                    $advQuery += " WHERE " + ($advFilters -join " AND ")

                    Write-Verbose "Executing direct SMS_Advertisement query: $advQuery"
                    $advertisements = Get-CimInstance @cimParams -Query $advQuery

                    if ($advertisements) {
                        $advertisementIds = @($advertisements | ForEach-Object { $_.AdvertisementID })
                    } else {
                        Write-Verbose "No task sequence deployments found matching the criteria."
                        return
                    }
                } else {
                    $advertisementIds = @($deploymentSummaries | ForEach-Object { $_.DeploymentID })
                }
            }

            # Now retrieve full details from SMS_Advertisement for each deployment
            # Build a lookup for collection names
            $collectionNameLookup = @{}
            if ($PSCmdlet.ParameterSetName -eq 'ByCollectionName' -and $collections) {
                foreach ($coll in $collections) {
                    $collectionNameLookup[$coll.CollectionID] = $coll.Name
                }
            }

            # Build a lookup for task sequence names
            $tsNameLookup = @{}
            if ($PSCmdlet.ParameterSetName -eq 'ByTaskSequenceName' -and $taskSequences) {
                foreach ($ts in $taskSequences) {
                    $tsNameLookup[$ts.PackageID] = $ts.Name
                }
            }

            # Filter advertisement IDs by any additional filters (e.g., PackageID for ByTaskSequenceName)
            foreach ($advId in $advertisementIds) {
                # Query the full advertisement
                if ($Fast) {
                    $advQuery = "SELECT AdvertisementID, AdvertisementName, CollectionID, PackageID, ProgramName, SourceSite, " +
                        "AdvertFlags, RemoteClientFlags, PresentTime, ExpirationTime " +
                        "FROM SMS_Advertisement WHERE AdvertisementID = '$advId'"
                } else {
                    $advQuery = "SELECT * FROM SMS_Advertisement WHERE AdvertisementID = '$advId'"
                }

                Write-Verbose "Retrieving advertisement: $advQuery"
                $advertisement = Get-CimInstance @cimParams -Query $advQuery

                if (-not $advertisement) {
                    Write-Verbose "Advertisement '$advId' not found in SMS_Advertisement."
                    continue
                }

                # Apply additional filters for parameter sets that need them
                if ($PSCmdlet.ParameterSetName -eq 'ByTaskSequenceName') {
                    $packageIds = @($taskSequences | ForEach-Object { $_.PackageID })
                    if ($advertisement.PackageID -notin $packageIds) {
                        continue
                    }
                }
                if ($PSCmdlet.ParameterSetName -eq 'ByTaskSequencePackageId') {
                    if ($advertisement.PackageID -ne $TaskSequencePackageId) {
                        continue
                    }
                }
                if ($PSCmdlet.ParameterSetName -eq 'ByDeploymentName') {
                    if ($DeploymentName -notlike '*`**' -and $DeploymentName -notlike '*`?*') {
                        # Exact match
                        if ($advertisement.AdvertisementName -ne $DeploymentName) {
                            continue
                        }
                    } else {
                        # Wildcard match
                        if ($advertisement.AdvertisementName -notlike $DeploymentName) {
                            continue
                        }
                    }
                }

                # Verify this is a task sequence deployment (ProgramName = '*')
                if ($advertisement.ProgramName -ne '*') {
                    continue
                }

                # Resolve collection name
                $resolvedCollectionName = $null
                if ($collectionNameLookup.ContainsKey($advertisement.CollectionID)) {
                    $resolvedCollectionName = $collectionNameLookup[$advertisement.CollectionID]
                } else {
                    $collLookupQuery = "SELECT Name FROM SMS_Collection WHERE CollectionID = '$($advertisement.CollectionID)'"
                    $collResult = Get-CimInstance @cimParams -Query $collLookupQuery
                    if ($collResult) {
                        $resolvedCollectionName = $collResult.Name
                        $collectionNameLookup[$advertisement.CollectionID] = $resolvedCollectionName
                    }
                }

                # Resolve task sequence name
                $resolvedTsName = $null
                if ($tsNameLookup.ContainsKey($advertisement.PackageID)) {
                    $resolvedTsName = $tsNameLookup[$advertisement.PackageID]
                } else {
                    $tsLookupQuery = "SELECT Name FROM SMS_TaskSequencePackage WHERE PackageID = '$($advertisement.PackageID)'"
                    $tsResult = Get-CimInstance @cimParams -Query $tsLookupQuery
                    if ($tsResult) {
                        $resolvedTsName = $tsResult.Name
                        $tsNameLookup[$advertisement.PackageID] = $resolvedTsName
                    }
                }

                # SMS_Advertisement lazy properties (cause HRESULT 0x80041001 in WQL SELECT over WinRM):
                #   AssignedSchedule, AssignedScheduleEnabled, AssignedScheduleIsGMT,
                #   ExpirationTimeEnabled, ExpirationTimeIsGMT, PresentTimeEnabled,
                #   PresentTimeIsGMT, TimeFlags
                # These are only available via SELECT * (non-Fast mode).
                $output = [PSCustomObject]@{
                    PSTypeName               = 'MECM7.TaskSequenceDeployment'
                    AdvertisementID          = $advertisement.AdvertisementID
                    AdvertisementName        = $advertisement.AdvertisementName
                    CollectionID             = $advertisement.CollectionID
                    CollectionName           = $resolvedCollectionName
                    PackageID                = $advertisement.PackageID
                    TaskSequenceName         = $resolvedTsName
                    ProgramName              = $advertisement.ProgramName
                    SourceSite               = $advertisement.SourceSite
                    AdvertFlags              = [int]$advertisement.AdvertFlags
                    RemoteClientFlags        = [int]$advertisement.RemoteClientFlags
                    PresentTime              = $advertisement.PresentTime
                    ExpirationTime           = $advertisement.ExpirationTime
                }

                # Set the type name
                $output.PSObject.TypeNames.Insert(0, 'MECM7.TaskSequenceDeployment')

                # Add all properties if not Fast mode
                if (-not $Fast) {
                    $advertisement.CimInstanceProperties | ForEach-Object {
                        if ($_.Name -notin $output.PSObject.Properties.Name) {
                            $output | Add-Member -MemberType NoteProperty -Name $_.Name -Value $_.Value -Force
                        }
                    }
                }

                Write-Output $output
            }
        }
        catch {
            throw $_
        }
    }
}
