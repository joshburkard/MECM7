function Get-CM7User {
	<#
		.SYNOPSIS
			Retrieves user information from MECM using CIM connectivity.

		.DESCRIPTION
			Queries the SMS_R_User WMI class to retrieve user information from MECM via CIM.
			Supports filtering by Name, ResourceId, and wildcards. Equivalent to Get-CMUser in ConfigurationManager module, but uses CIM.
			Requires an active connection via Connect-CM7.

		.PARAMETER Name
			The name of the user to retrieve

        .PARAMETER AllowWildcards
            Allows using wildcards (* and ?) in the Name parameter for pattern matching.

		.PARAMETER ResourceId
			The ResourceID of the user to retrieve.

		.PARAMETER Fast
			Returns limited properties for faster queries.

		.EXAMPLE
			Get-CM7User -Name "dan001\sd221778"
			Retrieves the user with the specified name.

		.EXAMPLE
			Get-CM7User -ResourceId 2063632223
			Retrieves the user with the specified ResourceID.

		.EXAMPLE
			Get-CM7User -Name "dan001*"
			Retrieves all users whose names start with "dan001".

		.EXAMPLE
			Get-CM7User -Fast
			Retrieves all users with limited properties for faster performance.

	#>
	[CmdletBinding(DefaultParameterSetName = 'All')]
	param(
		[Parameter(ParameterSetName = 'ByName', Position = 0)]
		[string]$Name,

        [Parameter(ParameterSetName = 'ByName', Position = 1)]
		[switch]$AllowWildcards,

		[Parameter(ParameterSetName = 'ByResourceId', Mandatory = $true)]
		[int]$ResourceId,

		[Parameter()]
		[switch]$Fast
	)

	$function = $($MyInvocation.MyCommand.Name)
	Write-Verbose "Running $function"

	try {
		# Get connection info
		$conn = $script:CMConnection
		if (-not $conn) {
			throw "No active MECM connection. Run Connect-CM7 first."
		}

		$query = "SELECT * FROM SMS_R_User"
		$where = @()

		switch ($PSCmdlet.ParameterSetName) {
			'ByName' {
				if ($Name) {
                    $Name = $Name -replace '\\', '\\'
                    if ($AllowWildcards) {
                        $Name = $Name -replace '\*', '%'
                        $Name = $Name -replace '\?', '_'
                        $Name = "%$($Name)%"
                    } else {
                        $Name = $Name -replace '([%_])', '[$1]'
                    }
					$where += "UniqueUserName LIKE '$($Name)'"
				}
			}
			'ByResourceId' {
				$where += "ResourceId = $ResourceId"
			}
		}

		if ($where.Count) {
			$query += " WHERE " + ($where -join ' AND ')
		}

		$properties = if ($Fast) {
			@('ResourceId','Name','DistinguishedName','UserPrincipalName','Domain','FullDomainName')
		} else {
			$null
		}

		$result = Get-CimInstance -Query $query -Namespace "root\SMS\site_$($conn.SiteCode)" -CimSession $conn.CimSession

		if ($properties) {
			$result | Select-Object $properties
		} else {
			$result
		}
	}
	catch {
		throw $_
	}
}
