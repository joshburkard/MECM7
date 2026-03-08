function Get-CM7Application {
    <#
        .SYNOPSIS
            Retrieves application information from MECM using CIM.

        .DESCRIPTION
            Queries the SMS_Application WMI class to retrieve application information from MECM.
            Supports filtering by application name, CI_ID, or other properties.
            Requires an active connection established via Connect-CM7.

        .PARAMETER Name
            The name of the application to retrieve. Supports wildcard characters (*).

        .PARAMETER ID
            The ID of the application to retrieve.

        .PARAMETER IsEnabled
            Filter applications by their enabled state.

        .PARAMETER IsLatest
            Filter to only return the latest version of each application.

        .PARAMETER ShowHidden
            Include hidden applications in the results.

        .PARAMETER Fast
            Returns only lazy properties for faster queries.

        .EXAMPLE
            Get-CM7Application -Name "Microsoft PowerShell 7.4.3"
            Retrieves the application with the exact name "Microsoft PowerShell 7.4.3".

        .EXAMPLE
            Get-CM7Application -ID 17123456
            Retrieves the application with ID 17123456.

        .EXAMPLE
            Get-CM7Application -Name "PowerShell*"
            Retrieves all applications whose names start with "PowerShell".

        .EXAMPLE
            Get-CM7Application
            Retrieves all applications (use with caution on large environments).
    #>
    [CmdletBinding(DefaultParameterSetName = 'All')]
    param(
        [Parameter(ParameterSetName = 'ByName', Position = 0)]
        [SupportsWildcards()]
        [string]$Name,

        [Parameter(ParameterSetName = 'ByID', Mandatory = $true)]
        [int]$ID,

        [Parameter()]
        [boolean]$IsEnabled = $true,

        [Parameter()]
        [switch]$IsLatest,

        [Parameter()]
        [switch]$ShowHidden,

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
        $filter = $null
        switch ($PSCmdlet.ParameterSetName) {
            'ByName' {
                if ($Name) {
                    $wqlName = $Name.Replace('*', '%').Replace('?', '_')
                    if ($wqlName -like '*%*' -or $wqlName -like '*_*') {
                        $filter = "LocalizedDisplayName LIKE '$wqlName'"
                    } else {
                        $filter = "LocalizedDisplayName = '$Name'"
                    }
                }
            }
            'ByID' {
                $filter = "CI_ID = $ID"
            }
        }
        # check if IsEnabled filter is set
        if ($IsEnabled -ne $null) {
            $enabledFilter = "IsEnabled = $([int]$IsEnabled)"
            $filter = if ($filter) { "$filter AND $enabledFilter" } else { $enabledFilter }
        }
        if (-not $ShowHidden) {
            $hiddenFilter = "IsHidden = 0"
            $filter = if ($filter) { "$filter AND $hiddenFilter" } else { $hiddenFilter }
        }
        $namespace = "root/SMS/site_$($script:CMConnection.SiteCode)"
        $queryParams = @{
            CimSession = $script:CMConnection.CimSession
            Namespace  = $namespace
        }
        $query = "SELECT * FROM SMS_Application"
        if ( [boolean]$filter) {
            $query += " WHERE $filter"
        }
        if ( ( -not [boolean]$Name ) -and ( -not [boolean]$ID ) -and ( -not [boolean]$Fast ) ) {
            Write-Warning "No filter specified for Get-CM7Application. This may return a large number of results and impact performance. Consider using filters or the -Fast switch."
        }
        Write-Verbose "Executing query: $query"
        $appsFast = Get-CimInstance @queryParams -Query $query
        if ($IsLatest) {
            $appsFast = $appsFast | Sort-Object -Property LocalizedDisplayName, Version -Descending | Group-Object LocalizedDisplayName | ForEach-Object { $_.Group | Select-Object -First 1 }
        }
        if ($appsFast) {
            if ($Fast) {
                return $appsFast
            }
            else {
                $apps = Get-CM7FullCimInstance -Instance $appsFast
                return $apps
            }
        } else {
            Write-Verbose "No applications found matching the criteria."
        }
    } catch {
        throw $_
    }
}
