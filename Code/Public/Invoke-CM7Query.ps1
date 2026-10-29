function Invoke-CM7Query {
    <#
        .SYNOPSIS
            Runs a saved Configuration Manager query using CIM.

        .DESCRIPTION
            Resolves a saved query by name or ID, or accepts a query object from the pipeline,
            then runs its WQL expression through the SMS Provider using the active CIM session.
            Queries configured with a collection limit are rejected because direct CIM execution
            cannot apply the SMS Provider's collection-limit context.

        .PARAMETER Id
            The QueryID of the saved query to run. The alias QueryId is also supported.

        .PARAMETER Name
            The exact name of the saved query to run.

        .PARAMETER InputObject
            A saved SMS_Query object with an Expression property. Accepts pipeline input.

        .EXAMPLE
            Invoke-CM7Query -Id 'SMS012'

            Runs the saved query with QueryID SMS012 and returns the result objects.

        .EXAMPLE
            Get-CimInstance -ClassName SMS_Query -Filter "QueryID = 'SMS012'" |
                Invoke-CM7Query

            Runs a saved query object through the active MECM CIM connection.

        .OUTPUTS
            Microsoft.Management.Infrastructure.CimInstance

        .NOTES
            Requires an active MECM connection established via Connect-CM7.
            Saved queries with a non-empty LimitToCollectionID are not supported.

        .LINK
            Connect-CM7
    #>
    [CmdletBinding(SupportsShouldProcess = $true, DefaultParameterSetName = 'ById')]
    param(
        [Parameter(Mandatory = $true, ParameterSetName = 'ById')]
        [Alias('QueryId')]
        [ValidateNotNullOrEmpty()]
        [string]$Id,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByName')]
        [Alias('QueryName')]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ParameterSetName = 'ByInputObject')]
        [ValidateNotNull()]
        [object]$InputObject
    )

    begin {
        $function = $($MyInvocation.MyCommand.Name)
        Write-Verbose "Running $function"

        if (-not $script:CMConnection.CimSession) {
            throw 'Not connected to MECM. Please run Connect-CM7 first.'
        }

        $namespace = "root/SMS/site_$($script:CMConnection.SiteCode)"
        $cimParams = @{
            CimSession = $script:CMConnection.CimSession
            Namespace  = $namespace
        }
    }

    process {
        if ($PSCmdlet.ParameterSetName -eq 'ByInputObject') {
            $queries = @($InputObject)
        }
        else {
            $queryProperty = if ($PSCmdlet.ParameterSetName -eq 'ById') { 'QueryID' } else { 'Name' }
            $queryValue = if ($PSCmdlet.ParameterSetName -eq 'ById') { $Id } else { $Name }
            $queryIdentifier = if ($queryProperty -eq 'QueryID') { 'ID' } else { 'name' }
            $escapedQueryValue = $queryValue.Replace("'", "''")
            $queryLookup = "SELECT * FROM SMS_Query WHERE $queryProperty = '$escapedQueryValue'"
            Write-Verbose "Resolving saved query: $queryLookup"
            $queries = @(Get-CimInstance @cimParams -Query $queryLookup -ErrorAction Stop)

            if ($queries.Count -eq 0) {
                throw "Could not find saved query with $queryIdentifier '$queryValue'."
            }
        }

        if ($queries.Count -gt 1) {
            throw 'More than one saved query was resolved. Specify a unique query ID or name.'
        }

        foreach ($query in $queries) {
            if (-not $query.PSObject.Properties['Expression']) {
                throw 'The input object is not a saved query because it has no Expression property.'
            }

            if ([string]::IsNullOrWhiteSpace([string]$query.Expression)) {
                throw "Saved query '$($query.Name)' has an empty WQL expression."
            }

            $collectionLimit = [string]$query.LimitToCollectionID
            if (-not [string]::IsNullOrWhiteSpace($collectionLimit)) {
                throw "Saved query '$($query.Name)' is limited to collection '$collectionLimit'. Collection-limited queries cannot be executed through direct CIM."
            }

            $queryLabel = if ($query.Name) { $query.Name } elseif ($query.QueryID) { $query.QueryID } else { 'input query' }
            if ($PSCmdlet.ShouldProcess($queryLabel, 'Execute MECM query')) {
                Write-Verbose "Executing saved query '$queryLabel' through the SMS Provider."
                Get-CimInstance @cimParams -Query $query.Expression -ErrorAction Stop
            }
        }
    }
}