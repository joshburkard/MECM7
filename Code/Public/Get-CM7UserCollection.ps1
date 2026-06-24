function Get-CM7UserCollection {
    <#
        .SYNOPSIS
            Retrieves user collection information from MECM using CIM.

        .DESCRIPTION
            Queries the SMS_Collection WMI class to retrieve user collection information from MECM.
            This is a convenience wrapper around Get-CM7Collection that automatically filters for
            user collections (CollectionType = User).

            Supports filtering by collection name (with wildcard support), CollectionId, and Fast mode.
            Requires an active connection established via Connect-CM7.

            This function is the CIM-based equivalent of the Get-CMUserCollection cmdlet from the
            ConfigurationManager PowerShell module.

        .PARAMETER Name
            The name of the user collection to retrieve. Supports wildcard characters (* and ?).

        .PARAMETER CollectionId
            The CollectionID of the user collection to retrieve.

        .PARAMETER Fast
            Returns limited properties for faster queries. Only returns essential properties like
            CollectionID, Name, CollectionType, MemberCount, and LastRefreshTime.

        .EXAMPLE
            Get-CM7UserCollection -Name "All Users"
            Retrieves the user collection with the exact name "All Users".

        .EXAMPLE
            Get-CM7UserCollection -Name "TEST-*"
            Retrieves all user collections whose names start with "TEST-".

        .EXAMPLE
            Get-CM7UserCollection -CollectionId "SMS00002"
            Retrieves the user collection with CollectionID "SMS00002".

        .EXAMPLE
            Get-CM7UserCollection -Fast
            Retrieves all user collections with limited properties for faster performance.

        .EXAMPLE
            Get-CM7UserCollection
            Retrieves all user collections (use with caution on large environments).
    #>
    [CmdletBinding(DefaultParameterSetName = 'All')]
    param(
        [Parameter(ParameterSetName = 'ByName', Position = 0)]
        [SupportsWildcards()]
        [string]$Name,

        [Parameter(ParameterSetName = 'ByCollectionId', Mandatory = $true)]
        [string]$CollectionId,

        [Parameter()]
        [switch]$Fast
    )

    $function = $($MyInvocation.MyCommand.Name)
    Write-Verbose "Running $function"

    try {
        # Build parameters to pass to Get-CM7Collection
        $params = @{
            CollectionType = 'User'
        }

        switch ($PSCmdlet.ParameterSetName) {
            'ByName' {
                if ($Name) {
                    $params.Name = $Name
                }
            }
            'ByCollectionId' {
                $params.CollectionId = $CollectionId
            }
        }

        if ($Fast) {
            $params.Fast = $true
        }

        # Pass verbose preference through
        if ($PSBoundParameters.ContainsKey('Verbose')) {
            $params.Verbose = $PSBoundParameters['Verbose']
        }

        # Delegate to Get-CM7Collection with User filter
        Get-CM7Collection @params
    }
    catch {
        throw $_
    }
}
