function Get-CM7Collection {
    <#
        .SYNOPSIS
            Retrieves collection information from MECM using CIM.

        .DESCRIPTION
            Queries the SMS_Collection WMI class to retrieve collection information from MECM.
            Supports filtering by collection name, CollectionId, or collection type.
            Requires an active connection established via Connect-CM7.

        .PARAMETER Name
            The name of the collection to retrieve. Supports wildcard characters (*).

        .PARAMETER CollectionId
            The CollectionID of the collection to retrieve.

        .PARAMETER CollectionType
            Filter collections by type. Valid values are 'Device', 'User', or 'Both'.
            Device collections contain device objects. User collections contain user objects.

        .PARAMETER Fast
            Returns limited properties for faster queries. Only returns essential properties like
            CollectionID, Name, CollectionType, MemberCount, and CreatedDate.

        .EXAMPLE
            Get-CM7Collection -Name "All Systems"
            Retrieves the collection with the exact name "All Systems".

        .EXAMPLE
            Get-CM7Collection -Name "TEST-*"
            Retrieves all collections whose names start with "TEST-".

        .EXAMPLE
            Get-CM7Collection -CollectionId "SMS00001"
            Retrieves the collection with CollectionID "SMS00001".

        .EXAMPLE
            Get-CM7Collection -CollectionType Device -Fast
            Retrieves all device collections with limited properties.

        .EXAMPLE
            Get-CM7Collection
            Retrieves all collections (use with caution on large environments).
    #>
    [CmdletBinding(DefaultParameterSetName = 'All')]
    param(
        [Parameter(ParameterSetName = 'ByName', Position = 0)]
        [SupportsWildcards()]
        [string]$Name,

        [Parameter(ParameterSetName = 'ByCollectionId', Mandatory = $true)]
        [string]$CollectionId,

        [Parameter()]
        [ValidateSet('Device', 'User', 'Both')]
        [string]$CollectionType,

        [Parameter()]
        [switch]$Fast
    )

    $function = $($MyInvocation.MyCommand.Name)
    Write-Verbose "Running $function"

    # Validate connection
    if (-not $script:CMConnection.CimSession) {
        throw "Not connected to MECM. Please run Connect-CM7 first."
    }

    try {
        # Build the WQL filter based on parameters
        $filter = $null
        $filters = @()

        switch ($PSCmdlet.ParameterSetName) {
            'ByName' {
                if ($Name) {
                    # Convert PowerShell wildcard to WQL LIKE pattern
                    $wqlName = $Name.Replace('*', '%').Replace('?', '_')
                    if ($wqlName -like '*%*' -or $wqlName -like '*_*') {
                        $filters += "Name LIKE '$wqlName'"
                    } else {
                        $filters += "Name = '$Name'"
                    }
                }
            }
            'ByCollectionId' {
                $filters += "CollectionID = '$CollectionId'"
            }
        }

        # Add collection type filter if specified
        if ($CollectionType) {
            $typeValue = switch ($CollectionType) {
                'Device' { 2 }
                'User' { 1 }
                'Both' { $null }
            }

            if ($typeValue) {
                $filters += "CollectionType = $typeValue"
            }
        }

        if ($filters.Count -gt 0) {
            $filter = $filters -join ' AND '
        }

        # Determine the namespace
        $namespace = "root/SMS/site_$($script:CMConnection.SiteCode)"

        # Build query parameters
        $queryParams = @{
            CimSession = $script:CMConnection.CimSession
            Namespace  = $namespace
        }

        # Build the query
        if ($Fast) {
            $properties = "CollectionID, Name, CollectionType, MemberCount, LastRefreshTime"
            $query = "SELECT $properties FROM SMS_Collection"
        } else {
            $query = "SELECT * FROM SMS_Collection"
        }

        if ($filter) {
            $query += " WHERE $filter"
        }

        Write-Verbose "Executing query: $query"

        # Execute the query
        $collections = Get-CimInstance @queryParams -Query $query

        # Output results
        if ($collections) {
            foreach ($collection in $collections) {
                # Map collection type number to friendly name
                $typeDisplay = switch ($collection.CollectionType) {
                    1 { 'User' }
                    2 { 'Device' }
                    default { 'Unknown' }
                }

                # Create a custom object with commonly used properties
                $output = [PSCustomObject]@{
                    PSTypeName      = 'MECM7.Collection'
                    CollectionId    = $collection.CollectionID
                    Name            = $collection.Name
                    CollectionType  = $typeDisplay
                    TypeValue       = $collection.CollectionType
                    MemberCount     = $collection.MemberCount
                    LastRefreshTime = $collection.LastRefreshTime
                    LastChangeTime  = $collection.LastChangeTime
                    Comments        = $collection.Comments
                    OwnedByThisSite = $collection.OwnedByThisSite
                    RefreshType     = $collection.RefreshType
                }

                # Set the type name as well
                $output.PSObject.TypeNames.Insert(0, 'MECM7.Collection')

                # Add all properties if not Fast mode
                if (-not $Fast) {
                    $collection.CimInstanceProperties | ForEach-Object {
                        if ($_.Name -notin $output.PSObject.Properties.Name) {
                            $output | Add-Member -MemberType NoteProperty -Name $_.Name -Value $_.Value -Force
                        }
                    }
                }

                Write-Output $output
            }
        } else {
            Write-Verbose "No collections found matching the criteria."
        }
    }
    catch {
        throw $_
    }
}
