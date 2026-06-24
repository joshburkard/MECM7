function Get-CM7Deployment {
    <#
        .SYNOPSIS
            Retrieves deployment information from MECM using CIM.

        .DESCRIPTION
            Queries the SMS_DeploymentSummary WMI class to retrieve deployment information from MECM.
            Supports filtering by deployment ID, collection name, software name, and feature type.
            Requires an active connection established via Connect-CM7.

            This function is the CIM-based equivalent of the Get-CMDeployment cmdlet from the
            ConfigurationManager PowerShell module, but uses direct CIM queries over WinRM instead
            of requiring the ConfigMgr console or PowerShell drive.

        .PARAMETER DeploymentId
            The unique identifier of the deployment to retrieve.

        .PARAMETER CollectionName
            The name of the collection targeted by the deployment. Supports wildcard characters (* and ?).

        .PARAMETER SoftwareName
            The name of the software being deployed. Supports wildcard characters (* and ?).

        .PARAMETER FeatureType
            The feature type of the deployment. Valid values are:
            - Application (1)
            - Program (2)
            - SoftwareUpdateGroup (5)
            - ConfigurationBaseline (6)
            - TaskSequence (7)

        .PARAMETER Fast
            Returns limited properties for faster queries. Only returns essential properties like
            DeploymentID, CollectionName, SoftwareName, FeatureType, and summary counts.

        .EXAMPLE
            Get-CM7Deployment
            Retrieves all deployments.

        .EXAMPLE
            Get-CM7Deployment -DeploymentId "{12345678-1234-1234-1234-123456789012}"
            Retrieves the deployment with the specified deployment ID.

        .EXAMPLE
            Get-CM7Deployment -CollectionName "Test-Collection-Direct"
            Retrieves all deployments targeting the specified collection.

        .EXAMPLE
            Get-CM7Deployment -CollectionName "Test-*"
            Retrieves all deployments targeting collections whose names start with "Test-".

        .EXAMPLE
            Get-CM7Deployment -SoftwareName "Microsoft*"
            Retrieves all deployments for software whose names start with "Microsoft".

        .EXAMPLE
            Get-CM7Deployment -FeatureType Application
            Retrieves all application deployments.

        .EXAMPLE
            Get-CM7Deployment -CollectionName "All Systems" -FeatureType SoftwareUpdateGroup -Fast
            Retrieves software update group deployments for "All Systems" with limited properties.

        .NOTES
            Requires an active connection established via Connect-CM7.
    #>
    [CmdletBinding(DefaultParameterSetName = 'All')]
    param(
        [Parameter(ParameterSetName = 'ByDeploymentId', Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$DeploymentId,

        [Parameter(ParameterSetName = 'ByCollectionName', Mandatory = $true)]
        [SupportsWildcards()]
        [ValidateNotNullOrEmpty()]
        [string]$CollectionName,

        [Parameter(ParameterSetName = 'BySoftwareName', Mandatory = $true)]
        [SupportsWildcards()]
        [ValidateNotNullOrEmpty()]
        [string]$SoftwareName,

        [Parameter(ParameterSetName = 'ByFeatureType', Mandatory = $true)]
        [ValidateSet('Application', 'Program', 'SoftwareUpdateGroup', 'ConfigurationBaseline', 'TaskSequence')]
        [string]$FeatureType,

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

        # Feature type mapping
        $featureTypeMap = @{
            'Application'            = 1
            'Program'                = 2
            'SoftwareUpdateGroup'    = 5
            'ConfigurationBaseline'  = 6
            'TaskSequence'           = 7
        }

        # Reverse feature type mapping for display
        $featureTypeReverse = @{
            1 = 'Application'
            2 = 'Program'
            5 = 'SoftwareUpdateGroup'
            6 = 'ConfigurationBaseline'
            7 = 'TaskSequence'
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
            $filters = @()

            switch ($PSCmdlet.ParameterSetName) {
                'ByDeploymentId' {
                    $filters += "DeploymentID = '$DeploymentId'"
                }
                'ByCollectionName' {
                    $wqlName = $CollectionName.Replace('*', '%').Replace('?', '_')
                    if ($wqlName -like '*%*' -or $wqlName -like '*_*') {
                        $filters += "CollectionName LIKE '$wqlName'"
                    } else {
                        $filters += "CollectionName = '$CollectionName'"
                    }
                }
                'BySoftwareName' {
                    $wqlName = $SoftwareName.Replace('*', '%').Replace('?', '_')
                    if ($wqlName -like '*%*' -or $wqlName -like '*_*') {
                        $filters += "SoftwareName LIKE '$wqlName'"
                    } else {
                        $filters += "SoftwareName = '$SoftwareName'"
                    }
                }
                'ByFeatureType' {
                    $featureTypeValue = $featureTypeMap[$FeatureType]
                    $filters += "FeatureType = $featureTypeValue"
                }
            }

            # Build the query
            if ($Fast) {
                $properties = "DeploymentID, CollectionID, CollectionName, SoftwareName, PackageID, FeatureType, NumberTargeted, NumberSuccess, NumberInProgress, NumberErrors, NumberOther, NumberUnknown"
                $query = "SELECT $properties FROM SMS_DeploymentSummary"
            } else {
                $query = "SELECT * FROM SMS_DeploymentSummary"
            }

            if ($filters.Count -gt 0) {
                $query += " WHERE " + ($filters -join " AND ")
            }

            Write-Verbose "Executing query: $query"

            # Execute the query
            $deployments = Get-CimInstance @cimParams -Query $query

            # Output results
            if ($deployments) {
                foreach ($deployment in $deployments) {
                    # Map feature type to friendly name
                    $featureTypeName = if ($featureTypeReverse.ContainsKey([int]$deployment.FeatureType)) {
                        $featureTypeReverse[[int]$deployment.FeatureType]
                    } else {
                        "Unknown ($($deployment.FeatureType))"
                    }

                    $output = [PSCustomObject]@{
                        PSTypeName       = 'MECM7.Deployment'
                        DeploymentID     = $deployment.DeploymentID
                        CollectionID     = $deployment.CollectionID
                        CollectionName   = $deployment.CollectionName
                        SoftwareName     = $deployment.SoftwareName
                        PackageID        = $deployment.PackageID
                        FeatureType      = $featureTypeName
                        NumberTargeted   = [int]$deployment.NumberTargeted
                        NumberSuccess    = [int]$deployment.NumberSuccess
                        NumberInProgress = [int]$deployment.NumberInProgress
                        NumberErrors     = [int]$deployment.NumberErrors
                        NumberOther      = [int]$deployment.NumberOther
                        NumberUnknown    = [int]$deployment.NumberUnknown
                    }

                    # Set the type name
                    $output.PSObject.TypeNames.Insert(0, 'MECM7.Deployment')

                    # Add all properties if not Fast mode
                    if (-not $Fast) {
                        $deployment.CimInstanceProperties | ForEach-Object {
                            if ($_.Name -notin $output.PSObject.Properties.Name) {
                                $output | Add-Member -MemberType NoteProperty -Name $_.Name -Value $_.Value -Force
                            }
                        }
                    }

                    Write-Output $output
                }
            } else {
                Write-Verbose "No deployments found matching the criteria."
            }
        }
        catch {
            throw $_
        }
    }
}
