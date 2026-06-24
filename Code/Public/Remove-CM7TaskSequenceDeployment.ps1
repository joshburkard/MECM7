function Remove-CM7TaskSequenceDeployment {
    <#
        .SYNOPSIS
            Removes a task sequence deployment from MECM using CIM.

        .DESCRIPTION
            Removes (deletes) a task sequence deployment (SMS_Advertisement with ProgramName = '*')
            from Microsoft Endpoint Configuration Manager (MECM) using CIM.

            This is the CIM-based equivalent of the Remove-CMTaskSequenceDeployment cmdlet from the
            ConfigurationManager PowerShell module, but uses direct CIM queries over WinRM
            instead of requiring the ConfigMgr console or PowerShell drive.

            The function performs the following actions:
            1. Validates an active connection exists (established via Connect-CM7)
            2. Resolves the deployment by advertisement ID, collection name, task sequence name,
               task sequence PackageID, deployment name, or input object
            3. Verifies the advertisement is a task sequence deployment (ProgramName = '*')
            4. Removes the SMS_Advertisement instance via CIM (with confirmation by default)

            Key features:
            - Multiple Identification: Remove by AdvertisementID, collection name, task sequence,
              deployment name, or pipeline input object
            - Wildcard Support: Use * and ? in collection names, task sequence names, and
              deployment names to match multiple deployments
            - Pipeline Support: Accept deployment objects from Get-CM7TaskSequenceDeployment via pipeline
            - Force Parameter: Bypass confirmation prompts for scripted scenarios
            - WhatIf/Confirm: Full ShouldProcess support for safe operations

        .PARAMETER AdvertisementID
            The unique advertisement ID (deployment ID) of the task sequence deployment to remove.
            This is the AdvertisementID property (string), e.g. "SD120BD2".

        .PARAMETER CollectionName
            The name of the collection targeted by the task sequence deployment(s) to remove.
            Supports wildcard characters (* and ?). If multiple deployments match, all are removed.

        .PARAMETER TaskSequenceName
            The name of the task sequence associated with the deployment(s) to remove.
            Supports wildcard characters (* and ?). If multiple deployments match, all are removed.

        .PARAMETER TaskSequencePackageId
            The PackageID of the task sequence associated with the deployment(s) to remove.
            If multiple deployments match, all are removed.

        .PARAMETER DeploymentName
            The name of the deployment (AdvertisementName) to remove.
            Supports wildcard characters (* and ?). If multiple deployments match, all are removed.

        .PARAMETER InputObject
            A task sequence deployment object (e.g., from Get-CM7TaskSequenceDeployment) to remove.
            Must have an AdvertisementID property.

        .PARAMETER Force
            Suppresses confirmation prompts and removes the deployment without asking.
            By default, the function prompts for confirmation before deletion.

        .PARAMETER WhatIf
            Shows what would happen if the cmdlet runs. The cmdlet is not run.

        .PARAMETER Confirm
            Prompts you for confirmation before running the cmdlet.

        .EXAMPLE
            Remove-CM7TaskSequenceDeployment -AdvertisementID "SD120BD2" -Force
            Removes the task sequence deployment with the specified advertisement ID without confirmation.

        .EXAMPLE
            Remove-CM7TaskSequenceDeployment -CollectionName "Test-Collection-Direct" -Force
            Removes all task sequence deployments targeting the specified collection.

        .EXAMPLE
            Remove-CM7TaskSequenceDeployment -TaskSequenceName "Test Josh" -Force
            Removes all deployments of the task sequence named "Test Josh".

        .EXAMPLE
            Remove-CM7TaskSequenceDeployment -TaskSequencePackageId "SD100FAD" -Force
            Removes all deployments of the task sequence with PackageID "SD100FAD".

        .EXAMPLE
            Remove-CM7TaskSequenceDeployment -DeploymentName "Test Josh - Test-Collection-Direct" -Force
            Removes the deployment with the specified name.

        .EXAMPLE
            Get-CM7TaskSequenceDeployment -CollectionName "Test-*" | Remove-CM7TaskSequenceDeployment -Force
            Removes all task sequence deployments targeting collections whose names start with "Test-" via pipeline.

        .EXAMPLE
            Remove-CM7TaskSequenceDeployment -DeploymentName "Test*" -WhatIf
            Shows what would happen without actually removing the deployment(s).

        .EXAMPLE
            $deployment = Get-CM7TaskSequenceDeployment -AdvertisementID "SD120BD2"
            Remove-CM7TaskSequenceDeployment -InputObject $deployment -Force
            Removes a deployment using a previously retrieved deployment object.

        .NOTES
            Requires an active connection established via Connect-CM7.

            The SMS_Advertisement WMI class is used to represent task sequence deployments in MECM.
            Task sequence deployments are distinguished from other deployments by ProgramName = '*'.

            This function is the CIM-based equivalent of the Remove-CMTaskSequenceDeployment cmdlet
            from the ConfigurationManager PowerShell module but uses direct CIM queries over WinRM
            instead of requiring the ConfigMgr console or PowerShell drive.
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High', DefaultParameterSetName = 'ByAdvertisementID')]
    param(
        [Parameter(ParameterSetName = 'ByAdvertisementID', Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$AdvertisementID,

        [Parameter(ParameterSetName = 'ByCollectionName', Mandatory = $true)]
        [SupportsWildcards()]
        [ValidateNotNullOrEmpty()]
        [string]$CollectionName,

        [Parameter(ParameterSetName = 'ByTaskSequenceName', Mandatory = $true)]
        [SupportsWildcards()]
        [ValidateNotNullOrEmpty()]
        [string]$TaskSequenceName,

        [Parameter(ParameterSetName = 'ByTaskSequencePackageId', Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$TaskSequencePackageId,

        [Parameter(ParameterSetName = 'ByDeploymentName', Mandatory = $true)]
        [SupportsWildcards()]
        [ValidateNotNullOrEmpty()]
        [string]$DeploymentName,

        [Parameter(ParameterSetName = 'ByInputObject', Mandatory = $true, ValueFromPipeline = $true)]
        [ValidateNotNull()]
        [PSObject]$InputObject,

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

        # Namespace and CIM params
        $namespace = "root/SMS/site_$($script:CMConnection.SiteCode)"
        $cimParams = @{
            CimSession = $script:CMConnection.CimSession
            Namespace  = $namespace
        }

        # Lookups for resolving names
        $collectionNameLookup = @{}
        $tsNameLookup = @{}
    }

    process {
        try {
            # ---- Resolve deployments to remove ----
            $deploymentsToRemove = @()

            switch ($PSCmdlet.ParameterSetName) {
                'ByAdvertisementID' {
                    $query = "SELECT * FROM SMS_Advertisement WHERE AdvertisementID = '$AdvertisementID' AND ProgramName = '*'"
                    Write-Verbose "Looking up deployment by AdvertisementID: $query"
                    $advertisement = Get-CimInstance @cimParams -Query $query

                    if (-not $advertisement) {
                        throw "Task sequence deployment with AdvertisementID '$AdvertisementID' was not found."
                    }

                    $deploymentsToRemove = @($advertisement)
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
                        throw "Collection '$CollectionName' was not found."
                    }

                    foreach ($coll in @($collections)) {
                        $collectionNameLookup[$coll.CollectionID] = $coll.Name
                    }

                    $collectionIds = @($collections | ForEach-Object { $_.CollectionID })
                    foreach ($collId in $collectionIds) {
                        $advQuery = "SELECT * FROM SMS_Advertisement WHERE CollectionID = '$collId' AND ProgramName = '*'"
                        Write-Verbose "Querying deployments for collection '$collId': $advQuery"
                        $advertisements = @(Get-CimInstance @cimParams -Query $advQuery)
                        $deploymentsToRemove += $advertisements
                    }

                    if ($deploymentsToRemove.Count -eq 0) {
                        Write-Verbose "No task sequence deployments found for collection(s) matching '$CollectionName'."
                        return
                    }
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
                        throw "No task sequences found matching '$TaskSequenceName'."
                    }

                    foreach ($ts in @($taskSequences)) {
                        $tsNameLookup[$ts.PackageID] = $ts.Name
                    }

                    $packageIds = @($taskSequences | ForEach-Object { $_.PackageID })
                    foreach ($pkgId in $packageIds) {
                        $advQuery = "SELECT * FROM SMS_Advertisement WHERE PackageID = '$pkgId' AND ProgramName = '*'"
                        Write-Verbose "Querying deployments for PackageID '$pkgId': $advQuery"
                        $advertisements = @(Get-CimInstance @cimParams -Query $advQuery)
                        $deploymentsToRemove += $advertisements
                    }

                    if ($deploymentsToRemove.Count -eq 0) {
                        Write-Verbose "No task sequence deployments found for task sequence(s) matching '$TaskSequenceName'."
                        return
                    }
                }
                'ByTaskSequencePackageId' {
                    $advQuery = "SELECT * FROM SMS_Advertisement WHERE PackageID = '$TaskSequencePackageId' AND ProgramName = '*'"
                    Write-Verbose "Looking up deployments by TaskSequencePackageId: $advQuery"
                    $advertisements = @(Get-CimInstance @cimParams -Query $advQuery)

                    if (-not $advertisements -or $advertisements.Count -eq 0) {
                        throw "No task sequence deployments found for PackageID '$TaskSequencePackageId'."
                    }

                    $deploymentsToRemove = $advertisements
                }
                'ByDeploymentName' {
                    $wqlName = $DeploymentName.Replace('*', '%').Replace('?', '_')
                    if ($wqlName -like '*%*' -or $wqlName -like '*_*') {
                        $advQuery = "SELECT * FROM SMS_Advertisement WHERE AdvertisementName LIKE '$wqlName' AND ProgramName = '*'"
                    } else {
                        $advQuery = "SELECT * FROM SMS_Advertisement WHERE AdvertisementName = '$DeploymentName' AND ProgramName = '*'"
                    }

                    Write-Verbose "Looking up deployments by name: $advQuery"
                    $advertisements = @(Get-CimInstance @cimParams -Query $advQuery)

                    if (-not $advertisements -or $advertisements.Count -eq 0) {
                        throw "No task sequence deployments found matching name '$DeploymentName'."
                    }

                    $deploymentsToRemove = $advertisements
                }
                'ByInputObject' {
                    # Extract AdvertisementID from input object
                    $inputAdvId = $null
                    if ($InputObject.PSObject.Properties['AdvertisementID']) {
                        $inputAdvId = $InputObject.AdvertisementID
                    }

                    if (-not $inputAdvId) {
                        throw "InputObject does not have an AdvertisementID property."
                    }

                    # Re-fetch from CIM to ensure we have the actual instance
                    $query = "SELECT * FROM SMS_Advertisement WHERE AdvertisementID = '$inputAdvId' AND ProgramName = '*'"
                    Write-Verbose "Looking up deployment from InputObject: $query"
                    $advertisement = Get-CimInstance @cimParams -Query $query

                    if (-not $advertisement) {
                        throw "Task sequence deployment with AdvertisementID '$inputAdvId' from InputObject was not found in MECM."
                    }

                    $deploymentsToRemove = @($advertisement)
                }
            }

            # ---- Remove each deployment ----
            foreach ($deployment in $deploymentsToRemove) {
                # Resolve collection name for display
                $resolvedCollectionName = $null
                if ($collectionNameLookup.ContainsKey($deployment.CollectionID)) {
                    $resolvedCollectionName = $collectionNameLookup[$deployment.CollectionID]
                } else {
                    $collLookupQuery = "SELECT Name FROM SMS_Collection WHERE CollectionID = '$($deployment.CollectionID)'"
                    $collResult = Get-CimInstance @cimParams -Query $collLookupQuery
                    if ($collResult) {
                        $resolvedCollectionName = $collResult.Name
                        $collectionNameLookup[$deployment.CollectionID] = $resolvedCollectionName
                    }
                }

                # Resolve task sequence name for display
                $resolvedTsName = $null
                if ($tsNameLookup.ContainsKey($deployment.PackageID)) {
                    $resolvedTsName = $tsNameLookup[$deployment.PackageID]
                } else {
                    $tsLookupQuery = "SELECT Name FROM SMS_TaskSequencePackage WHERE PackageID = '$($deployment.PackageID)'"
                    $tsResult = Get-CimInstance @cimParams -Query $tsLookupQuery
                    if ($tsResult) {
                        $resolvedTsName = $tsResult.Name
                        $tsNameLookup[$deployment.PackageID] = $resolvedTsName
                    }
                }

                $displayName = "$($deployment.AdvertisementName) ($($deployment.AdvertisementID))"
                $actionDescription = "Remove task sequence deployment '$($deployment.AdvertisementName)' ($($deployment.AdvertisementID)) for task sequence '$resolvedTsName' ($($deployment.PackageID)) targeting collection '$resolvedCollectionName' ($($deployment.CollectionID))"

                if ($Force -or $PSCmdlet.ShouldProcess($displayName, $actionDescription)) {
                    Write-Verbose "Removing deployment: $actionDescription"

                    Remove-CimInstance -CimSession $script:CMConnection.CimSession -InputObject $deployment

                    Write-Verbose "Task sequence deployment '$($deployment.AdvertisementName)' ($($deployment.AdvertisementID)) removed successfully."

                    # Return a result object with information about the removed deployment
                    [PSCustomObject]@{
                        PSTypeName        = 'MECM7.RemovedTaskSequenceDeployment'
                        AdvertisementID   = $deployment.AdvertisementID
                        AdvertisementName = $deployment.AdvertisementName
                        CollectionID      = $deployment.CollectionID
                        CollectionName    = $resolvedCollectionName
                        PackageID         = $deployment.PackageID
                        TaskSequenceName  = $resolvedTsName
                        Status            = 'Removed'
                    }
                }
            }
        }
        catch {
            throw $_
        }
    }
}
