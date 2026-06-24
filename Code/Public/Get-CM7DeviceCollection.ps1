function Get-CM7DeviceCollection {
    <#
        .SYNOPSIS
            Retrieves device collection information from MECM using CIM.

        .DESCRIPTION
            Queries the SMS_Collection WMI class to retrieve device collection information from MECM.
            This is a convenience wrapper around Get-CM7Collection that automatically filters for
            device collections (CollectionType = Device).

            Supports filtering by collection name (with wildcard support), CollectionId, and Fast mode.
            Requires an active connection established via Connect-CM7.

            This function is the CIM-based equivalent of the Get-CMDeviceCollection cmdlet from the
            ConfigurationManager PowerShell module.

        .PARAMETER Name
            The name of the device collection to retrieve. Supports wildcard characters (* and ?).

        .PARAMETER CollectionId
            The CollectionID of the device collection to retrieve.

        .PARAMETER Fast
            Returns limited properties for faster queries. Only returns essential properties like
            CollectionID, Name, CollectionType, MemberCount, and LastRefreshTime.

        .EXAMPLE
            Get-CM7DeviceCollection -Name "All Systems"
            Retrieves the device collection with the exact name "All Systems".

        .EXAMPLE
            Get-CM7DeviceCollection -Name "TEST-*"
            Retrieves all device collections whose names start with "TEST-".

        .EXAMPLE
            Get-CM7DeviceCollection -CollectionId "SMS00001"
            Retrieves the device collection with CollectionID "SMS00001".

        .EXAMPLE
            Get-CM7DeviceCollection -Fast
            Retrieves all device collections with limited properties for faster performance.

        .EXAMPLE
            Get-CM7DeviceCollection
            Retrieves all device collections (use with caution on large environments).
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
            CollectionType = 'Device'
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

        # Delegate to Get-CM7Collection with Device filter
        Get-CM7Collection @params
    }
    catch {
        throw $_
    }
}
