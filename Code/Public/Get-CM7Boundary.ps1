function Get-CM7Boundary {
    <#
        .SYNOPSIS
            Retrieves boundary information from MECM using CIM.

        .DESCRIPTION
            Queries the SMS_Boundary WMI class to retrieve boundary information from MECM.
            Supports filtering by Name, BoundaryID, BoundaryType, and Value.
            Requires an active connection established via Connect-CM7.

            This function is the CIM-based equivalent of the Get-CMBoundary cmdlet
            from the ConfigurationManager PowerShell module, but uses direct CIM queries over WinRM.

        .PARAMETER Name
            The name of the boundary to retrieve. Supports wildcard characters (* and ?).

        .PARAMETER BoundaryId
            The BoundaryID of the boundary to retrieve.

        .PARAMETER BoundaryType
            The type of the boundary. Valid values are: 0 (IP Subnet), 1 (Active Directory Site), 2 (IPv6 Prefix), 3 (IP Address Range).

        .PARAMETER Value
            The value of the boundary (e.g., subnet, AD site name, IP range).

        .PARAMETER Fast
            Returns limited properties for faster queries. Only returns essential properties like BoundaryID, Name, BoundaryType, and Value.

        .EXAMPLE
            Get-CM7Boundary -Name "TEST GINO"
            Retrieves the boundary named "TEST GINO".

        .EXAMPLE
            Get-CM7Boundary -BoundaryId 12345678
            Retrieves the boundary with the specified BoundaryID.

        .EXAMPLE
            Get-CM7Boundary
            Retrieves all boundaries.
    #>
    [CmdletBinding(DefaultParameterSetName = 'All')]
    param(
        [Parameter(ParameterSetName = 'ByName', Position = 0)]
        [SupportsWildcards()]
        [string]$Name,

        [Parameter(ParameterSetName = 'ByBoundaryId', Mandatory = $true)]
        [int]$BoundaryId,

        [Parameter()]
        [ValidateSet(0, 1, 2, 3)]
        [int]$BoundaryType,

        [Parameter()]
        [string]$Value,

        [Parameter()]
        [switch]$Fast
    )

    # Ensure connection
    if (-not $script:CMConnection) {
        throw "Not connected. Please run Connect-CM7 first."
    }

    $namespace = "root/SMS/site_$($script:CMConnection.SiteCode)"

    # Build query parameters
    $queryParams = @{
        CimSession = $script:CMConnection.CimSession
        Namespace  = $namespace
    }

    $filter = @()
    if ($PSBoundParameters.ContainsKey('Name')) {
        $filter += "DisplayName LIKE '$Name'"
    }
    if ($PSBoundParameters.ContainsKey('BoundaryId')) {
        $filter += "BoundaryID = $BoundaryId"
    }
    if ($PSBoundParameters.ContainsKey('BoundaryType')) {
        $filter += "BoundaryType = $BoundaryType"
    }
    if ($PSBoundParameters.ContainsKey('Value')) {
        $filter += "Value LIKE '$Value'"
    }
    $wql = if ($filter) { "WHERE " + ($filter -join ' AND ') } else { '' }

    $query = "SELECT * FROM SMS_Boundary $wql"
    $boundaries = Get-CimInstance @queryParams -Query $query

    if ($Fast) {
        $boundaries | Select-Object BoundaryID, DisplayName, BoundaryType, Value
    } else {
        $boundaries
    }
}
