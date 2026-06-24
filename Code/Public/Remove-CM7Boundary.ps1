function Remove-CM7Boundary {
    <#
        .SYNOPSIS
            Removes a boundary from MECM using CIM.

        .DESCRIPTION
            Removes (deletes) a boundary from Microsoft Endpoint Configuration Manager (MECM)
            using CIM. This function deletes an SMS_Boundary instance via CIM.

            This is the CIM-based equivalent of the Remove-CMBoundary cmdlet from the
            ConfigurationManager PowerShell module, but uses direct CIM queries over WinRM.

            The function supports removing boundaries by:
            - Name (DisplayName): resolves the boundary by display name
            - Id (BoundaryID):    resolves the boundary by its integer ID
            - InputObject:        accepts a boundary object from the pipeline (e.g., from Get-CM7Boundary)

        .PARAMETER Name
            The display name of the boundary to remove. Supports wildcard characters (* and ?).
            If multiple boundaries match the name, all matching boundaries are removed.

        .PARAMETER Id
            The BoundaryID (integer) of the boundary to remove. Provides unambiguous identification.

        .PARAMETER InputObject
            A boundary object (e.g., from Get-CM7Boundary) to remove.
            Accepts pipeline input. Must have a BoundaryID property.

        .PARAMETER Force
            Suppresses confirmation prompts and removes the boundary without asking.
            By default, the function prompts for confirmation before deletion.

        .PARAMETER WhatIf
            Shows what would happen if the cmdlet runs. The cmdlet is not run.

        .PARAMETER Confirm
            Prompts you for confirmation before running the cmdlet.

        .EXAMPLE
            Remove-CM7Boundary -Name "TestSubnet-192.168.1.0"
            Removes the boundary named "TestSubnet-192.168.1.0" after confirmation.

        .EXAMPLE
            Remove-CM7Boundary -Id 16777223 -Force
            Removes the boundary with the specified BoundaryID without prompting for confirmation.

        .EXAMPLE
            Get-CM7Boundary -BoundaryType 0 | Remove-CM7Boundary -Force
            Removes all IP Subnet boundaries via pipeline.

        .EXAMPLE
            Remove-CM7Boundary -Name "TestSubnet-*" -WhatIf
            Shows what would happen without actually removing the matching boundaries.

        .EXAMPLE
            $boundary = Get-CM7Boundary -BoundaryId 16777223
            Remove-CM7Boundary -InputObject $boundary -Force
            Removes a boundary using a previously retrieved boundary object.

        .NOTES
            Requires an active connection established via Connect-CM7.
            The SMS_Boundary WMI class is used to represent boundaries in MECM.
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High', DefaultParameterSetName = 'ByName')]
    param(
        [Parameter(ParameterSetName = 'ByName', Mandatory = $true, Position = 0)]
        [SupportsWildcards()]
        [ValidateNotNullOrEmpty()]
        [Alias('DisplayName')]
        [string]$Name,

        [Parameter(ParameterSetName = 'ById', Mandatory = $true)]
        [Alias('BoundaryId')]
        [int]$Id,

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

        $namespace = "root/SMS/site_$($script:CMConnection.SiteCode)"
        $cimParams = @{
            CimSession = $script:CMConnection.CimSession
            Namespace  = $namespace
        }
    }

    process {
        try {
            # ---- Resolve Boundary ----
            $boundaries = @()

            switch ($PSCmdlet.ParameterSetName) {
                'ByName' {
                    # Convert wildcard pattern to WQL LIKE pattern
                    $wqlPattern = $Name -replace '\*', '%' -replace '\?', '_'
                    $query = "SELECT * FROM SMS_Boundary WHERE DisplayName LIKE '$wqlPattern'"
                    $boundaries = @(Get-CimInstance @cimParams -Query $query)

                    if ($boundaries.Count -eq 0) {
                        Write-Warning "No boundary found with name matching '$Name'."
                        return
                    }
                }
                'ById' {
                    $query = "SELECT * FROM SMS_Boundary WHERE BoundaryID = $Id"
                    $result = Get-CimInstance @cimParams -Query $query
                    if (-not $result) {
                        Write-Warning "No boundary found with BoundaryID $Id."
                        return
                    }
                    $boundaries = @($result)
                }
                'ByInputObject' {
                    # Resolve BoundaryID from the input object
                    $boundaryId = $null
                    if ($InputObject.PSObject.Properties['BoundaryID']) {
                        $boundaryId = $InputObject.BoundaryID
                    } elseif ($InputObject.PSObject.Properties['BoundaryId']) {
                        $boundaryId = $InputObject.BoundaryId
                    } else {
                        throw "InputObject does not have a BoundaryID property. Please provide a valid boundary object from Get-CM7Boundary."
                    }

                    $query = "SELECT * FROM SMS_Boundary WHERE BoundaryID = $boundaryId"
                    $result = Get-CimInstance @cimParams -Query $query
                    if (-not $result) {
                        Write-Warning "No boundary found with BoundaryID $boundaryId (from InputObject)."
                        return
                    }
                    $boundaries = @($result)
                }
            }

            # ---- Remove each resolved boundary ----
            foreach ($boundary in $boundaries) {
                $displayName = $boundary.DisplayName
                $boundaryId  = $boundary.BoundaryID
                $actionDescription = "Remove boundary '$displayName' (BoundaryID: $boundaryId)"

                if ($Force -or $PSCmdlet.ShouldProcess("$displayName (BoundaryID: $boundaryId)", "Remove boundary")) {
                    Write-Verbose $actionDescription
                    Remove-CimInstance -CimSession $script:CMConnection.CimSession -InputObject $boundary
                    Write-Verbose "Boundary '$displayName' (BoundaryID: $boundaryId) removed successfully."
                }
            }
        } catch {
            throw $_
        }
    }
}
