function New-CM7Boundary {
    <#
        .SYNOPSIS
            Creates a new boundary in MECM using CIM.

        .DESCRIPTION
            Creates a new boundary (SMS_Boundary) in Microsoft Endpoint Configuration Manager (MECM) using CIM.
            Supports creation of boundaries by Name, BoundaryType, and Value. Requires an active connection via Connect-CM7.
            This is the CIM-based equivalent of the New-CMBoundary cmdlet from the ConfigurationManager PowerShell module, but uses direct CIM queries over WinRM.

        .PARAMETER Name
            The name of the boundary to create. Must be unique within the MECM environment.

        .PARAMETER BoundaryType
            The type of the boundary. Valid values are: 0 (IP Subnet), 1 (Active Directory Site), 2 (IPv6 Prefix), 3 (IP Address Range).

        .PARAMETER Value
            The value of the boundary (e.g., subnet, AD site name, IP range).

        .PARAMETER Force
            Suppresses confirmation prompts.

        .PARAMETER WhatIf
            Shows what would happen if the cmdlet runs. The cmdlet is not run.

        .PARAMETER Confirm
            Prompts you for confirmation before running the cmdlet.

        .EXAMPLE
            New-CM7Boundary -Name "TestSubnet" -BoundaryType 0 -Value "192.168.1.0"
            Creates a new IP Subnet boundary named "TestSubnet".

        .EXAMPLE
            New-CM7Boundary -Name "TestRange" -BoundaryType 3 -Value "192.168.2.1-192.168.3.255"
            Creates a new IP Address Range boundary named "TestRange".

        .NOTES
            Requires an active connection established via Connect-CM7.
            The SMS_Boundary WMI class is used to represent boundaries in MECM.
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Name,

        [Parameter(Mandatory = $true, Position = 1)]
        [ValidateSet('IPSubnet', 'ADSite', 'IPv6Prefix', 'IPRange')]
        [Alias('Type')]
        [object]$BoundaryType,

        [Parameter(Mandatory = $true, Position = 2)]
        [string]$Value,

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

        # verify Value Input based on BoundaryType
        switch ($BoundaryType) {
            'IPSubnet' {
                if ($Value -notmatch '^\d{1,3}(\.\d{1,3}){3}$') {
                    throw "Invalid Value for IPSubnet. Expected format: '192.168.1.0'"
                }
            }
            'ADSite' {
                if (-not $Value) {
                    throw "Invalid Value for ADSite. Expected a non-empty string."
                }
            }
            'IPv6Prefix' {
                if ($Value -notmatch '^[0-9a-fA-F:]+$') {
                    throw "Invalid Value for IPv6Prefix. Expected format: '2001:0db8::/32'"
                }
            }
            'IPRange' {
                if ($Value -notmatch '^\d{1,3}(\.\d{1,3}){3}-\d{1,3}(\.\d{1,3}){3}$') {
                    throw "Invalid Value for IPRange. Expected format: '192.168.1.1-192.168.1.255'"
                }
            }
        }

    }

    process {
        try {
            # Check for duplicate boundary name
            $existingQuery = "SELECT BoundaryID, DisplayName FROM SMS_Boundary WHERE DisplayName = '$Name'"
            $existingBoundary = Get-CimInstance @cimParams -Query $existingQuery
            if ($existingBoundary) {
                throw "A boundary with name '$Name' already exists (BoundaryID: $($existingBoundary.BoundaryID))."
            }

            # Map string to integer if needed
            $typeMap = @{
                'IPSubnet'   = 0
                'ADSite'     = 1
                'IPv6Prefix' = 2
                'IPRange'    = 3
            }
            $boundaryTypeInt = $typeMap."$BoundaryType" -as [int]
            if ($null -eq $boundaryTypeInt -or $boundaryTypeInt -notin 0,1,2,3) {
                throw "Invalid BoundaryType. Use one of: IPSubnet, ADSite, IPv6Prefix, IPRange, or 0-3."
            }

            $boundaryProps = @{
                DisplayName  = $Name
                BoundaryType = $boundaryTypeInt
                Value        = $Value
            }

            $actionDescription = "Create boundary '$Name' of type $boundaryTypeInt with value '$Value'"
            if ($Force -or $PSCmdlet.ShouldProcess($Name, $actionDescription)) {
                $newBoundary = New-CimInstance @cimParams -ClassName 'SMS_Boundary' -Property $boundaryProps
                if (-not $newBoundary) {
                    throw "Failed to create boundary '$Name'. New-CimInstance returned null."
                }
                $boundaryId = $newBoundary.BoundaryID
                $resultQuery = "SELECT * FROM SMS_Boundary WHERE BoundaryID = $boundaryId"
                $result = Get-CimInstance @cimParams -Query $resultQuery
                if ($result) {
                    $output = [PSCustomObject]@{
                        PSTypeName     = 'MECM7.Boundary'
                        BoundaryID     = [int]$result.BoundaryID
                        DisplayName    = $result.DisplayName
                        BoundaryType   = [int]$result.BoundaryType
                        Value          = $result.Value
                        Description    = $result.Description
                    }
                    $output.PSObject.TypeNames.Insert(0, 'MECM7.Boundary')
                    $result.CimInstanceProperties | ForEach-Object {
                        if ($_.Name -notin $output.PSObject.Properties.Name) {
                            $output | Add-Member -MemberType NoteProperty -Name $_.Name -Value $_.Value -Force
                        }
                    }
                    Write-Output $output
                } else {
                    Write-Warning "Boundary was created but could not retrieve the result. BoundaryID: $boundaryId"
                }
            }
        } catch {
            throw $_
        }
    }
}
