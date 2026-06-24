function Get-CM7CollectionVariable {
    <#
        .SYNOPSIS
            Retrieves collection variables from a MECM collection using CIM.

        .DESCRIPTION
            Queries the SMS_CollectionSettings WMI class to retrieve collection variables
            for a specified MECM collection. Collection variables are name-value pairs that
            can be used during task sequence execution and other MECM operations.
            Supports filtering by collection name, CollectionId, or variable name.
            Requires an active connection established via Connect-CM7.

        .PARAMETER CollectionName
            Specifies the name of the collection to retrieve variables for.

        .PARAMETER CollectionId
            Specifies the CollectionID of the collection to retrieve variables for.

        .PARAMETER VariableName
            Specifies the name of the variable to retrieve. Supports wildcard characters (*).
            If not specified, all variables for the collection are returned.

        .EXAMPLE
            Get-CM7CollectionVariable -CollectionName "Test-Collection-Direct"
            Retrieves all collection variables for the "Test-Collection-Direct" collection.

        .EXAMPLE
            Get-CM7CollectionVariable -CollectionId "CM101C00"
            Retrieves all collection variables for the collection with ID "CM101C00".

        .EXAMPLE
            Get-CM7CollectionVariable -CollectionName "Test-Collection-Direct" -VariableName "Test-Normal"
            Retrieves the variable named "Test-Normal" from the "Test-Collection-Direct" collection.

        .EXAMPLE
            Get-CM7CollectionVariable -CollectionName "Test-Collection-Direct" -VariableName "Test-*"
            Retrieves all variables whose names start with "Test-" from the specified collection.

        .NOTES
            This function is the CIM-based equivalent of the Get-CMCollectionVariable cmdlet
            from the ConfigurationManager PowerShell module but uses direct CIM queries
            over WinRM instead of requiring the ConfigMgr console or PowerShell drive.

            The CollectionVariables property of SMS_CollectionSettings is a lazy property,
            so the function retrieves the full instance to access it.
    #>
    [CmdletBinding(DefaultParameterSetName = 'ByCollectionName')]
    param(
        [Parameter(ParameterSetName = 'ByCollectionName', Position = 0)]
        [string]$CollectionName,

        [Parameter(ParameterSetName = 'ByCollectionId', Mandatory = $true)]
        [string]$CollectionId,

        [Parameter()]
        [SupportsWildcards()]
        [string]$VariableName
    )

    $function = $($MyInvocation.MyCommand.Name)
    Write-Verbose "Running $function"

    # Validate connection
    if (-not $script:CMConnection.CimSession) {
        throw "Not connected to MECM. Please run Connect-CM7 first."
    }

    try {
        # Determine the namespace
        $namespace = "root/SMS/site_$($script:CMConnection.SiteCode)"

        # Build query parameters
        $queryParams = @{
            CimSession = $script:CMConnection.CimSession
            Namespace  = $namespace
        }

        # Determine which collection identifier to use
        $collectionIdToUse = $null

        if ($PSCmdlet.ParameterSetName -eq 'ByCollectionName') {
            if (-not $CollectionName) {
                throw "CollectionName must be provided when using the ByCollectionName parameter set."
            }
            # Resolve collection name to ID
            $collectionQuery = "SELECT CollectionID FROM SMS_Collection WHERE Name = '$CollectionName'"
            Write-Verbose "Resolving collection name to ID: $collectionQuery"

            $collection = Get-CimInstance @queryParams -Query $collectionQuery
            if (-not $collection) {
                Write-Verbose "Collection '$CollectionName' not found."
                return
            }
            $collectionIdToUse = $collection.CollectionID
        } else {
            $collectionIdToUse = $CollectionId
        }

        Write-Verbose "Using CollectionID: $collectionIdToUse"

        # Query SMS_CollectionSettings for the collection
        $settingsQuery = "SELECT * FROM SMS_CollectionSettings WHERE CollectionID = '$collectionIdToUse'"
        Write-Verbose "Executing query: $settingsQuery"

        $settings = Get-CimInstance @queryParams -Query $settingsQuery

        if (-not $settings) {
            Write-Verbose "No collection settings found for CollectionID '$collectionIdToUse'. The collection may have no variables defined."
            return
        }

        # CollectionVariables is a lazy property - re-retrieve the instance using
        # Get-CimInstance -InputObject to force loading all lazy properties
        Write-Verbose "Retrieving full instance to load lazy property CollectionVariables..."
        $fullSettings = $settings | Get-CimInstance

        if (-not $fullSettings) {
            Write-Verbose "Could not retrieve full collection settings for CollectionID '$collectionIdToUse'."
            return
        }

        # Access the CollectionVariables property
        $variables = $fullSettings.CollectionVariables

        if (-not $variables -or $variables.Count -eq 0) {
            Write-Verbose "No collection variables found for CollectionID '$collectionIdToUse'."
            return
        }

        # Filter by variable name if specified
        if ($VariableName) {
            if ($VariableName -match '[*?]') {
                # Wildcard filter
                $variables = $variables | Where-Object { $_.Name -like $VariableName }
            } else {
                # Exact match
                $variables = $variables | Where-Object { $_.Name -eq $VariableName }
            }
        }

        if (-not $variables) {
            Write-Verbose "No variables matching the filter were found."
            return
        }

        # Output results
        foreach ($variable in $variables) {
            [PSCustomObject]@{
                PSTypeName = 'MECM7.CollectionVariable'
                Name       = $variable.Name
                Value      = $variable.Value
                IsMasked   = $variable.IsMasked
            }
        }
    }
    catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
}
