function Set-CM7Boundary {
    <#
        .SYNOPSIS
            Modifies an existing boundary in MECM using CIM.

        .DESCRIPTION
            Updates the properties of an existing SMS_Boundary instance in Microsoft Endpoint
            Configuration Manager (MECM) using CIM over WinRM.

            Supports modifying boundaries by:
            - InputObject: a boundary object piped in or retrieved via Get-CM7Boundary
            - Id:          unambiguous identification by integer BoundaryID
            - Type+Value:  locate the boundary by its current type and value combination

            Any combination of -NewName, -NewType, -NewValue, and -ValueStartsWith can be
            supplied to update the corresponding properties.

            This is the CIM-based equivalent of the Set-CMBoundary cmdlet from the
            ConfigurationManager PowerShell module, but uses direct CIM queries over WinRM.

        .PARAMETER InputObject
            A boundary object (e.g., from Get-CM7Boundary) whose properties are to be updated.
            Accepts pipeline input. Must have a BoundaryID property.

        .PARAMETER Id
            The BoundaryID (integer) of the boundary to modify. Alias: BoundaryId.

        .PARAMETER Type
            The current boundary type used to locate the boundary (combined with -Value).
            Valid values: IPSubnet, ADSite, IPv6Prefix, IPRange, Vpn.
            Alias: BoundaryType.

        .PARAMETER Value
            The current value of the boundary used to locate it (combined with -Type).

        .PARAMETER NewName
            A new display name to assign to the boundary. Aliases: DisplayName, Name.

        .PARAMETER NewType
            The new boundary type to assign. Accepted values: IPSubnet, ADSite, IPv6Prefix, IPRange, Vpn.
            Alias: NewBoundaryType.

        .PARAMETER NewValue
            The new value to assign to the boundary (e.g., a new subnet address or IP range).

        .PARAMETER ValueStartsWith
            When set to $true, the VPN boundary is matched by the start of the connection name
            rather than an exact match. Relevant only for VPN boundary types.

        .PARAMETER PassThru
            Returns the updated boundary object. By default this cmdlet returns no output.

        .PARAMETER Force
            Suppresses confirmation prompts.

        .PARAMETER WhatIf
            Shows what would happen if the cmdlet runs without actually running it.

        .PARAMETER Confirm
            Prompts for confirmation before performing the update.

        .EXAMPLE
            Set-CM7Boundary -Id 16777223 -NewName "Renamed-TestSubnet"
            Renames the boundary with BoundaryID 16777223.

        .EXAMPLE
            Set-CM7Boundary -Id 16777223 -NewType IPRange -NewValue "192.168.1.1-192.168.1.255" -PassThru
            Changes the type and value of a boundary and returns the updated object.

        .EXAMPLE
            Set-CM7Boundary -Type IPSubnet -Value "192.168.1.0" -NewName "Updated-Subnet" -NewValue "192.168.10.0"
            Locates the IP Subnet boundary with value "192.168.1.0" and updates its name and value.

        .EXAMPLE
            Get-CM7Boundary -Name "TestSubnet-192.168.1.0" | Set-CM7Boundary -NewName "UpdatedSubnet" -Force
            Uses pipeline input to rename a boundary.

        .NOTES
            Requires an active connection established via Connect-CM7.
            The SMS_Boundary WMI class is used to represent boundaries in MECM.
            BoundaryType integer mapping: 0=IPSubnet, 1=ADSite, 2=IPv6Prefix, 3=IPRange, 4=Vpn.
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium', DefaultParameterSetName = 'SetByValue')]
    param(
        # ---- Identification ----
        [Parameter(ParameterSetName = 'SetByValue', Mandatory = $true, ValueFromPipeline = $true)]
        [ValidateNotNull()]
        [PSObject]$InputObject,

        [Parameter(ParameterSetName = 'SetById', Mandatory = $true)]
        [Alias('BoundaryId')]
        [int]$Id,

        [Parameter(ParameterSetName = 'SetByName', Mandatory = $true)]
        [ValidateSet('IPSubnet', 'ADSite', 'IPv6Prefix', 'IPRange', 'Vpn')]
        [Alias('BoundaryType')]
        [string]$Type,

        [Parameter(ParameterSetName = 'SetByName', Mandatory = $true)]
        [string]$Value,

        # ---- What to change ----
        [Parameter()]
        [Alias('DisplayName', 'Name')]
        [string]$NewName,

        [Parameter()]
        [ValidateSet('IPSubnet', 'ADSite', 'IPv6Prefix', 'IPRange', 'Vpn')]
        [Alias('NewBoundaryType')]
        [string]$NewType,

        [Parameter()]
        [string]$NewValue,

        [Parameter()]
        [boolean]$ValueStartsWith,

        [Parameter()]
        [switch]$PassThru,

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

        # BoundaryType string-to-int mapping
        $typeMap = @{
            'IPSubnet'   = 0
            'ADSite'     = 1
            'IPv6Prefix' = 2
            'IPRange'    = 3
            'Vpn'        = 4
        }

        # Reverse mapping for display/lookup
        $typeReverseMap = @{
            0 = 'IPSubnet'
            1 = 'ADSite'
            2 = 'IPv6Prefix'
            3 = 'IPRange'
            4 = 'Vpn'
        }
    }

    process {
        try {
            # ---- Step 1: Resolve the target boundary ----
            $cimBoundary = $null

            switch ($PSCmdlet.ParameterSetName) {

                'SetByValue' {
                    $boundaryId = $InputObject.BoundaryID
                    if (-not $boundaryId) {
                        throw "InputObject does not have a valid BoundaryID property."
                    }
                    $cimBoundary = Get-CimInstance @cimParams -Query "SELECT * FROM SMS_Boundary WHERE BoundaryID = $boundaryId"
                    if (-not $cimBoundary) {
                        throw "No boundary found with BoundaryID $boundaryId (from InputObject)."
                    }
                }

                'SetById' {
                    $cimBoundary = Get-CimInstance @cimParams -Query "SELECT * FROM SMS_Boundary WHERE BoundaryID = $Id"
                    if (-not $cimBoundary) {
                        throw "No boundary found with BoundaryID $Id."
                    }
                }

                'SetByName' {
                    $typeInt = $typeMap[$Type]
                    # Escape single quotes in Value for WQL
                    $wqlValue = $Value -replace "'", "''"
                    $cimBoundary = Get-CimInstance @cimParams -Query "SELECT * FROM SMS_Boundary WHERE BoundaryType = $typeInt AND Value = '$wqlValue'"
                    if (-not $cimBoundary) {
                        throw "No boundary found with Type '$Type' and Value '$Value'."
                    }
                    # If multiple are returned (edge case), take the first and warn
                    if (@($cimBoundary).Count -gt 1) {
                        Write-Warning "Multiple boundaries found with Type '$Type' and Value '$Value'. Modifying the first one (BoundaryID: $($cimBoundary[0].BoundaryID))."
                        $cimBoundary = $cimBoundary[0]
                    }
                }
            }

            # ---- Step 2: Build the set of property changes ----
            $updateProps = @{}

            if ($PSBoundParameters.ContainsKey('NewName')) {
                $updateProps['DisplayName'] = $NewName
            }
            if ($PSBoundParameters.ContainsKey('NewType')) {
                $updateProps['BoundaryType'] = [int]$typeMap[$NewType]
            }
            if ($PSBoundParameters.ContainsKey('NewValue')) {
                # Validate NewValue format against the target type (use NewType if provided, else current type)
                $targetTypeStr = if ($PSBoundParameters.ContainsKey('NewType')) { $NewType } else { $typeReverseMap[[int]$cimBoundary.BoundaryType] }
                switch ($targetTypeStr) {
                    'IPSubnet' {
                        if ($NewValue -notmatch '^\d{1,3}(\.\d{1,3}){3}$') {
                            throw "Invalid NewValue for IPSubnet. Expected format: '192.168.1.0'"
                        }
                    }
                    'ADSite' {
                        if ([string]::IsNullOrEmpty($NewValue)) {
                            throw "Invalid NewValue for ADSite. Expected a non-empty string."
                        }
                    }
                    'IPv6Prefix' {
                        if ($NewValue -notmatch '^[0-9a-fA-F:]+(/\d+)?$') {
                            throw "Invalid NewValue for IPv6Prefix. Expected format: '2001:db8::' or '2001:db8::/32'"
                        }
                    }
                    'IPRange' {
                        if ($NewValue -notmatch '^\d{1,3}(\.\d{1,3}){3}-\d{1,3}(\.\d{1,3}){3}$') {
                            throw "Invalid NewValue for IPRange. Expected format: '192.168.1.1-192.168.1.255'"
                        }
                    }
                    'Vpn' {
                        if ([string]::IsNullOrEmpty($NewValue)) {
                            throw "Invalid NewValue for Vpn. Expected a non-empty string."
                        }
                    }
                }
                $updateProps['Value'] = $NewValue
            }
            if ($PSBoundParameters.ContainsKey('ValueStartsWith')) {
                $updateProps['ValueStartsWith'] = $ValueStartsWith
            }

            if ($updateProps.Count -eq 0) {
                Write-Warning "No changes specified for boundary '$($cimBoundary.DisplayName)' (BoundaryID: $($cimBoundary.BoundaryID)). Nothing to do."
                return
            }

            # ---- Step 3: Apply changes ----
            $displayName = $cimBoundary.DisplayName
            $boundaryIdStr = $cimBoundary.BoundaryID
            $changeDesc = ($updateProps.Keys | ForEach-Object { "$_ -> $($updateProps[$_])" }) -join '; '
            $actionDescription = "Update boundary '$displayName' (BoundaryID: $boundaryIdStr): $changeDesc"

            if ($Force -or $PSCmdlet.ShouldProcess("Boundary '$displayName' (BoundaryID: $boundaryIdStr)", $actionDescription)) {
                Set-CimInstance -CimSession $Script:CMConnection.CimSession -InputObject $cimBoundary -Property $updateProps

                if ($PassThru) {
                    # Re-query to return the updated state
                    $updated = Get-CimInstance @cimParams -Query "SELECT * FROM SMS_Boundary WHERE BoundaryID = $boundaryIdStr"
                    if ($updated) {
                        $output = [PSCustomObject]@{
                            PSTypeName   = 'MECM7.Boundary'
                            BoundaryID   = [int]$updated.BoundaryID
                            DisplayName  = $updated.DisplayName
                            BoundaryType = [int]$updated.BoundaryType
                            Value        = $updated.Value
                            Description  = $updated.Description
                        }
                        $output.PSObject.TypeNames.Insert(0, 'MECM7.Boundary')
                        $updated.CimInstanceProperties | ForEach-Object {
                            if ($_.Name -notin $output.PSObject.Properties.Name) {
                                $output | Add-Member -MemberType NoteProperty -Name $_.Name -Value $_.Value -Force
                            }
                        }
                        Write-Output $output
                    } else {
                        Write-Warning "Boundary was updated but could not retrieve the result. BoundaryID: $boundaryIdStr"
                    }
                }
            }
        } catch {
            throw $_
        }
    }
}
