function Get-CM7SoftwareUpdate {
    <#
        .SYNOPSIS
            Retrieves software update information from MECM using CIM.

        .DESCRIPTION
            Queries the SMS_SoftwareUpdate WMI class to retrieve software update information
            from MECM. Supports filtering by article ID, bulletin ID, name, severity,
            deployment status, and supersedence status.
            Requires an active connection established via Connect-CM7.

            This function is the CIM-based equivalent of the Get-CMSoftwareUpdate cmdlet
            from the ConfigurationManager PowerShell module, but uses direct CIM queries over WinRM
            instead of requiring the ConfigMgr console or PowerShell drive.

        .PARAMETER ArticleId
            The KB article ID of the software update to retrieve (e.g. "4038779").

        .PARAMETER BulletinId
            The security bulletin ID of the software update to retrieve (e.g. "MS17-010").
            Supports wildcard characters (* and ?).

        .PARAMETER Name
            The localized display name of the software update. Supports wildcard characters (* and ?).

        .PARAMETER Severity
            The severity of the software update. Valid values are:
            None, Low, Moderate, Important, Critical.

        .PARAMETER IsDeployed
            Filter by deployment status. When $true, only returns updates that have been deployed.
            When $false, only returns updates that have not been deployed.

        .PARAMETER IsSuperseded
            Filter by supersedence status. When $true, only returns superseded updates.
            When $false, only returns non-superseded updates.

        .PARAMETER CategoryName
            Filter by update classification or product category name.
            Supports wildcard characters (* and ?).
            Note: This performs a sub-query against SMS_CIToCategory and SMS_CategoryInstance.

        .PARAMETER Fast
            Returns limited properties for faster queries. Only returns essential properties like
            CI_ID, ArticleID, BulletinID, LocalizedDisplayName, LocalizedDescription,
            DatePosted, DateRevised, IsDeployed, IsSuperseded, NumMissing, NumPresent,
            NumTotal, SeverityName, and PercentCompliant.

        .EXAMPLE
            Get-CM7SoftwareUpdate
            Retrieves all software updates.

        .EXAMPLE
            Get-CM7SoftwareUpdate -ArticleId "4038779"
            Retrieves the software update with the specified KB article ID.

        .EXAMPLE
            Get-CM7SoftwareUpdate -Name "*Cumulative*"
            Retrieves all software updates whose names contain "Cumulative".

        .EXAMPLE
            Get-CM7SoftwareUpdate -Severity Critical -IsDeployed $false
            Retrieves all critical software updates that have not yet been deployed.

        .EXAMPLE
            Get-CM7SoftwareUpdate -IsSuperseded $false -Fast
            Retrieves all non-superseded software updates with limited properties.

        .NOTES
            Requires an active connection established via Connect-CM7.
    #>
    [CmdletBinding(DefaultParameterSetName = 'All')]
    param(
        [Parameter(ParameterSetName = 'ByArticleId', Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ArticleId,

        [Parameter(ParameterSetName = 'ByBulletinId', Mandatory = $true)]
        [SupportsWildcards()]
        [ValidateNotNullOrEmpty()]
        [string]$BulletinId,

        [Parameter(ParameterSetName = 'ByName', Mandatory = $true)]
        [SupportsWildcards()]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [Parameter()]
        [ValidateSet('None', 'Low', 'Moderate', 'Important', 'Critical')]
        [string]$Severity,

        [Parameter()]
        [Boolean]$IsDeployed,

        [Parameter()]
        [Boolean]$IsSuperseded,

        [Parameter(ParameterSetName = 'ByCategoryName', Mandatory = $true)]
        [SupportsWildcards()]
        [ValidateNotNullOrEmpty()]
        [string]$CategoryName,

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

        # Severity name to integer mapping
        $severityMap = @{
            'None'      = 0
            'Low'       = 2
            'Moderate'  = 6
            'Important' = 8
            'Critical'  = 10
        }

        # Reverse severity map for display
        $severityReverseMap = @{
            0  = 'None'
            2  = 'Low'
            6  = 'Moderate'
            8  = 'Important'
            10 = 'Critical'
        }
    }

    process {
        try {
            # Build WQL filter based on parameters
            $filters = @()

            switch ($PSCmdlet.ParameterSetName) {
                'ByArticleId' {
                    $filters += "ArticleID = '$ArticleId'"
                }
                'ByBulletinId' {
                    $wqlBulletinId = $BulletinId.Replace('*', '%').Replace('?', '_')
                    if ($wqlBulletinId -like '*%*' -or $wqlBulletinId -like '*_*') {
                        $filters += "BulletinID LIKE '$wqlBulletinId'"
                    } else {
                        $filters += "BulletinID = '$BulletinId'"
                    }
                }
                'ByName' {
                    $wqlName = $Name.Replace('*', '%').Replace('?', '_')
                    if ($wqlName -like '*%*' -or $wqlName -like '*_*') {
                        $filters += "LocalizedDisplayName LIKE '$wqlName'"
                    } else {
                        $filters += "LocalizedDisplayName = '$Name'"
                    }
                }
                'ByCategoryName' {
                    # Resolve category name to CI_IDs through SMS_CIToCategory and SMS_CategoryInstance
                    $wqlCatName = $CategoryName.Replace('*', '%').Replace('?', '_')
                    if ($wqlCatName -like '*%*' -or $wqlCatName -like '*_*') {
                        $categoryQuery = "SELECT CategoryInstanceID FROM SMS_CategoryInstance WHERE LocalizedCategoryInstanceName LIKE '$wqlCatName'"
                    } else {
                        $categoryQuery = "SELECT CategoryInstanceID FROM SMS_CategoryInstance WHERE LocalizedCategoryInstanceName = '$CategoryName'"
                    }

                    Write-Verbose "Resolving category name: $categoryQuery"
                    $categories = Get-CimInstance @cimParams -Query $categoryQuery

                    if (-not $categories) {
                        Write-Verbose "No categories found matching '$CategoryName'."
                        return
                    }

                    $categoryIds = @($categories | ForEach-Object { $_.CategoryInstanceID })
                    Write-Verbose "Found $($categoryIds.Count) matching categories."

                    # Get CI_IDs from the category relationship class
                    $ciIds = @()
                    foreach ($catId in $categoryIds) {
                        $relQuery = "SELECT CI_ID FROM SMS_CIToCategory WHERE CategoryInstance_UniqueID IN (SELECT CategoryInstance_UniqueID FROM SMS_CategoryInstance WHERE CategoryInstanceID = $catId)"
                        # Use a simpler approach: query the category unique ID first
                        $catUniqueQuery = "SELECT CategoryInstance_UniqueID FROM SMS_CategoryInstance WHERE CategoryInstanceID = $catId"
                        $catUnique = Get-CimInstance @cimParams -Query $catUniqueQuery
                        if ($catUnique) {
                            $uniqueId = $catUnique.CategoryInstance_UniqueID
                            $ciToCategory = Get-CimInstance @cimParams -Query "SELECT CI_ID FROM SMS_CIToCategory WHERE CategoryInstance_UniqueID = '$uniqueId'"
                            if ($ciToCategory) {
                                $ciIds += @($ciToCategory | ForEach-Object { $_.CI_ID })
                            }
                        }
                    }

                    if ($ciIds.Count -eq 0) {
                        Write-Verbose "No software updates found in the specified category."
                        return
                    }

                    # Build filter with CI_IDs (batch to avoid overly long queries)
                    $ciIds = $ciIds | Select-Object -Unique
                    Write-Verbose "Found $($ciIds.Count) software update CI_IDs in the matching categories."
                    # We'll filter in post-processing if too many
                    if ($ciIds.Count -le 100) {
                        $orClauses = $ciIds | ForEach-Object { "CI_ID = $_" }
                        $filters += "(" + ($orClauses -join " OR ") + ")"
                    }
                    # If more than 100, we'll filter in post-processing
                }
            }

            # Additional filters (appended regardless of parameter set)
            if ($PSBoundParameters.ContainsKey('Severity')) {
                $filters += "SeverityName = '$Severity'"
            }

            if ($PSBoundParameters.ContainsKey('IsDeployed')) {
                $filters += "IsDeployed = $(if ($IsDeployed) { 1 } else { 0 })"
            }

            if ($PSBoundParameters.ContainsKey('IsSuperseded')) {
                $filters += "IsSuperseded = $(if ($IsSuperseded) { 1 } else { 0 })"
            }

            # Build the query
            if ($Fast) {
                $properties = "CI_ID, ArticleID, BulletinID, LocalizedDisplayName, LocalizedDescription, DatePosted, DateRevised, IsDeployed, IsSuperseded, NumMissing, NumPresent, NumTotal, SeverityName, PercentCompliant"
                $query = "SELECT $properties FROM SMS_SoftwareUpdate"
            } else {
                $query = "SELECT * FROM SMS_SoftwareUpdate"
            }

            if ($filters.Count -gt 0) {
                $query += " WHERE " + ($filters -join " AND ")
            }

            Write-Verbose "Executing query: $query"

            # Execute the query
            $updates = Get-CimInstance @cimParams -Query $query

            # Post-processing filter for large category queries
            if ($PSCmdlet.ParameterSetName -eq 'ByCategoryName' -and $ciIds.Count -gt 100) {
                $ciIdSet = [System.Collections.Generic.HashSet[int]]::new([int[]]$ciIds)
                $updates = $updates | Where-Object { $ciIdSet.Contains([int]$_.CI_ID) }
            }

            # Output results
            if ($updates) {
                foreach ($update in $updates) {
                    # SeverityName is already a friendly string in SMS_SoftwareUpdate
                    $severityName = if ($update.SeverityName) {
                        $update.SeverityName
                    } else {
                        'None'
                    }

                    $output = [PSCustomObject]@{
                        PSTypeName           = 'MECM7.SoftwareUpdate'
                        CI_ID                = [int]$update.CI_ID
                        ArticleID            = $update.ArticleID
                        BulletinID           = $update.BulletinID
                        LocalizedDisplayName = $update.LocalizedDisplayName
                        LocalizedDescription = $update.LocalizedDescription
                        Severity             = $severityName
                        DatePosted           = $update.DatePosted
                        DateRevised          = $update.DateRevised
                        IsDeployed           = [bool]$update.IsDeployed
                        IsSuperseded         = [bool]$update.IsSuperseded
                        NumMissing           = [int]$update.NumMissing
                        NumPresent           = [int]$update.NumPresent
                        NumTotal             = [int]$update.NumTotal
                        PercentCompliant     = [int]$update.PercentCompliant
                    }

                    # Set the type name
                    $output.PSObject.TypeNames.Insert(0, 'MECM7.SoftwareUpdate')

                    # Add all properties if not Fast mode
                    if (-not $Fast) {
                        $update.CimInstanceProperties | ForEach-Object {
                            if ($_.Name -notin $output.PSObject.Properties.Name) {
                                $output | Add-Member -MemberType NoteProperty -Name $_.Name -Value $_.Value -Force
                            }
                        }
                    }

                    Write-Output $output
                }
            } else {
                Write-Verbose "No software updates found matching the criteria."
            }
        }
        catch {
            throw $_
        }
    }
}
