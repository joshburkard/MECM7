function Remove-CM7BoundaryFromGroup {
    <#
        .SYNOPSIS
            Removes a boundary from a boundary group in MECM using CIM.

        .DESCRIPTION
            Removes an existing boundary from an existing boundary group in Microsoft Endpoint
            Configuration Manager (MECM) using CIM. The boundary group and the boundary can each
            be identified by their ID, name, or by passing an object from Get-CM7BoundaryGroup /
            Get-CM7Boundary respectively.

            Internally, the function invokes the RemoveBoundary instance method on the
            SMS_BoundaryGroup WMI class.

            This is the CIM-based equivalent of the Remove-CMBoundaryFromGroup cmdlet from the
            ConfigurationManager PowerShell module, but uses direct CIM queries over WinRM
            instead of requiring the ConfigMgr console or PowerShell drive.

        .PARAMETER BoundaryGroupId
            The GroupID (integer) of the boundary group to remove the boundary from.

        .PARAMETER BoundaryGroupName
            The name of the boundary group to remove the boundary from.

        .PARAMETER BoundaryGroupInputObject
            A boundary group object (e.g. from Get-CM7BoundaryGroup) to remove the boundary from.
            Alias: BoundaryGroup

        .PARAMETER BoundaryId
            The BoundaryID (integer) of the boundary to remove.

        .PARAMETER BoundaryName
            The name of the boundary to remove.

        .PARAMETER BoundaryInputObject
            A boundary object (e.g. from Get-CM7Boundary) to remove.
            Alias: Boundary

        .PARAMETER Force
            Suppresses confirmation prompts and removes the boundary from the group without asking.

        .PARAMETER DisableWildcardHandling
            Treats wildcard characters as literal character values.
            Cannot be combined with ForceWildcardHandling.

        .PARAMETER ForceWildcardHandling
            Forces wildcard character processing even in contexts where it is not normally
            supported. May lead to unexpected behavior (not recommended).
            Cannot be combined with DisableWildcardHandling.

        .PARAMETER WhatIf
            Shows what would happen if the cmdlet runs. The cmdlet is not run.

        .PARAMETER Confirm
            Prompts you for confirmation before running the cmdlet.

        .EXAMPLE
            Remove-CM7BoundaryFromGroup -BoundaryGroupId 16777219 -BoundaryName "CLBound03"
            Removes the boundary named "CLBound03" from the boundary group with GroupID 16777219.

        .EXAMPLE
            Remove-CM7BoundaryFromGroup -BoundaryGroupName "MyBoundaryGroup" -BoundaryId 16777230 -Force
            Removes the boundary with BoundaryID 16777230 from the named group without prompting.

        .EXAMPLE
            $group    = Get-CM7BoundaryGroup -Name "MyBoundaryGroup"
            $boundary = Get-CM7Boundary     -Name "MyBoundary"
            Remove-CM7BoundaryFromGroup -BoundaryGroupInputObject $group -BoundaryInputObject $boundary -Force
            Removes the boundary from the group using objects from Get-CM7BoundaryGroup and Get-CM7Boundary.

        .EXAMPLE
            Remove-CM7BoundaryFromGroup -BoundaryGroupName "MyBoundaryGroup" -BoundaryId 16777230 -WhatIf
            Shows what would happen without actually removing the boundary from the group.

        .NOTES
            Requires an active connection established via Connect-CM7.

            The SMS_BoundaryGroup WMI class is used to represent boundary groups in MECM.
            The RemoveBoundary instance method accepts an array of uint32 BoundaryIDs and removes
            them from the boundary group.

            For more information on the SMS_BoundaryGroup class and the RemoveBoundary method, see:
            https://learn.microsoft.com/en-us/mem/configmgr/develop/reference/core/servers/configure/sms_boundarygroup-server-wmi-class

            Related functions:
            - Add-CM7BoundaryToGroup
            - Get-CM7Boundary
            - Get-CM7BoundaryGroup
    #>
    [CmdletBinding(
        SupportsShouldProcess = $true,
        ConfirmImpact         = 'Medium',
        DefaultParameterSetName = 'ByGroupId_ByBoundaryId'
    )]
    param(
        # ---- Boundary Group: by ID ----
        [Parameter(ParameterSetName = 'ByGroupId_ByBoundaryId',     Mandatory = $true)]
        [Parameter(ParameterSetName = 'ByGroupId_ByBoundaryName',   Mandatory = $true)]
        [Parameter(ParameterSetName = 'ByGroupId_ByBoundaryObject', Mandatory = $true)]
        [int]$BoundaryGroupId,

        # ---- Boundary Group: by Name ----
        [Parameter(ParameterSetName = 'ByGroupName_ByBoundaryId',     Mandatory = $true)]
        [Parameter(ParameterSetName = 'ByGroupName_ByBoundaryName',   Mandatory = $true)]
        [Parameter(ParameterSetName = 'ByGroupName_ByBoundaryObject', Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$BoundaryGroupName,

        # ---- Boundary Group: by Object ----
        [Parameter(ParameterSetName = 'ByGroupObject_ByBoundaryId',     Mandatory = $true)]
        [Parameter(ParameterSetName = 'ByGroupObject_ByBoundaryName',   Mandatory = $true)]
        [Parameter(ParameterSetName = 'ByGroupObject_ByBoundaryObject', Mandatory = $true)]
        [Alias('BoundaryGroup')]
        [ValidateNotNull()]
        [PSObject]$BoundaryGroupInputObject,

        # ---- Boundary: by ID ----
        [Parameter(ParameterSetName = 'ByGroupId_ByBoundaryId',     Mandatory = $true)]
        [Parameter(ParameterSetName = 'ByGroupName_ByBoundaryId',   Mandatory = $true)]
        [Parameter(ParameterSetName = 'ByGroupObject_ByBoundaryId', Mandatory = $true)]
        [int]$BoundaryId,

        # ---- Boundary: by Name ----
        [Parameter(ParameterSetName = 'ByGroupId_ByBoundaryName',     Mandatory = $true)]
        [Parameter(ParameterSetName = 'ByGroupName_ByBoundaryName',   Mandatory = $true)]
        [Parameter(ParameterSetName = 'ByGroupObject_ByBoundaryName', Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$BoundaryName,

        # ---- Boundary: by Object ----
        [Parameter(ParameterSetName = 'ByGroupId_ByBoundaryObject',     Mandatory = $true)]
        [Parameter(ParameterSetName = 'ByGroupName_ByBoundaryObject',   Mandatory = $true)]
        [Parameter(ParameterSetName = 'ByGroupObject_ByBoundaryObject', Mandatory = $true)]
        [Alias('Boundary')]
        [ValidateNotNull()]
        [PSObject]$BoundaryInputObject,

        # ---- Confirmation / Wildcard handling ----
        [Parameter()]
        [switch]$Force,

        [Parameter()]
        [switch]$DisableWildcardHandling,

        [Parameter()]
        [switch]$ForceWildcardHandling
    )

    begin {
        $function = $($MyInvocation.MyCommand.Name)
        Write-Verbose "Running $function"

        # Validate mutually exclusive wildcard parameters
        if ($DisableWildcardHandling -and $ForceWildcardHandling) {
            throw "DisableWildcardHandling and ForceWildcardHandling cannot be used together."
        }

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
            # ------------------------------------------------------------------
            # 1. Resolve Boundary Group CIM instance
            # ------------------------------------------------------------------
            $groupInstance = $null

            switch -Regex ($PSCmdlet.ParameterSetName) {
                '^ByGroupId_' {
                    Write-Verbose "Resolving boundary group by GroupID: $BoundaryGroupId"
                    $groupInstance = Get-CimInstance @cimParams -Query "SELECT * FROM SMS_BoundaryGroup WHERE GroupID = $BoundaryGroupId"
                    if (-not $groupInstance) {
                        throw "No boundary group found with GroupID $BoundaryGroupId."
                    }
                }
                '^ByGroupName_' {
                    Write-Verbose "Resolving boundary group by Name: $BoundaryGroupName"
                    $safeName = $BoundaryGroupName -replace "'", "''"
                    $groupInstance = Get-CimInstance @cimParams -Query "SELECT * FROM SMS_BoundaryGroup WHERE Name = '$safeName'"
                    if (-not $groupInstance) {
                        throw "No boundary group found with name '$BoundaryGroupName'."
                    }
                }
                '^ByGroupObject_' {
                    $resolvedGroupId = $null
                    if ($BoundaryGroupInputObject.PSObject.Properties['GroupID']) {
                        $resolvedGroupId = $BoundaryGroupInputObject.GroupID
                    } elseif ($BoundaryGroupInputObject.PSObject.Properties['GroupId']) {
                        $resolvedGroupId = $BoundaryGroupInputObject.GroupId
                    } else {
                        throw "BoundaryGroupInputObject does not have a GroupID property. Please provide a valid boundary group object from Get-CM7BoundaryGroup."
                    }
                    Write-Verbose "Resolving boundary group from InputObject with GroupID: $resolvedGroupId"
                    $groupInstance = Get-CimInstance @cimParams -Query "SELECT * FROM SMS_BoundaryGroup WHERE GroupID = $resolvedGroupId"
                    if (-not $groupInstance) {
                        throw "No boundary group found with GroupID $resolvedGroupId (from BoundaryGroupInputObject)."
                    }
                }
            }

            # ------------------------------------------------------------------
            # 2. Resolve Boundary ID
            # ------------------------------------------------------------------
            $resolvedBoundaryId = $null

            switch -Regex ($PSCmdlet.ParameterSetName) {
                '_ByBoundaryId$' {
                    Write-Verbose "Using BoundaryID directly: $BoundaryId"
                    $boundaryCheck = Get-CimInstance @cimParams -Query "SELECT BoundaryID FROM SMS_Boundary WHERE BoundaryID = $BoundaryId"
                    if (-not $boundaryCheck) {
                        throw "No boundary found with BoundaryID $BoundaryId."
                    }
                    $resolvedBoundaryId = $BoundaryId
                }
                '_ByBoundaryName$' {
                    Write-Verbose "Resolving boundary by Name: $BoundaryName"
                    $safeName = $BoundaryName -replace "'", "''"
                    $boundaryResult = Get-CimInstance @cimParams -Query "SELECT BoundaryID, DisplayName FROM SMS_Boundary WHERE DisplayName = '$safeName'"
                    if (-not $boundaryResult) {
                        throw "No boundary found with name '$BoundaryName'."
                    }
                    if (@($boundaryResult).Count -gt 1) {
                        throw "Multiple boundaries found with name '$BoundaryName'. Please use BoundaryId or BoundaryInputObject to be more specific."
                    }
                    $resolvedBoundaryId = $boundaryResult.BoundaryID
                }
                '_ByBoundaryObject$' {
                    if ($BoundaryInputObject.PSObject.Properties['BoundaryID']) {
                        $resolvedBoundaryId = $BoundaryInputObject.BoundaryID
                    } elseif ($BoundaryInputObject.PSObject.Properties['BoundaryId']) {
                        $resolvedBoundaryId = $BoundaryInputObject.BoundaryId
                    } else {
                        throw "BoundaryInputObject does not have a BoundaryID property. Please provide a valid boundary object from Get-CM7Boundary."
                    }
                    Write-Verbose "Using BoundaryID from BoundaryInputObject: $resolvedBoundaryId"
                    $boundaryCheck = Get-CimInstance @cimParams -Query "SELECT BoundaryID FROM SMS_Boundary WHERE BoundaryID = $resolvedBoundaryId"
                    if (-not $boundaryCheck) {
                        throw "No boundary found with BoundaryID $resolvedBoundaryId (from BoundaryInputObject)."
                    }
                }
            }

            # ------------------------------------------------------------------
            # 3. Invoke RemoveBoundary method on the boundary group
            # ------------------------------------------------------------------
            $groupName = $groupInstance.Name
            $groupId   = $groupInstance.GroupID

            $shouldProcessTarget = "Boundary '$resolvedBoundaryId' from boundary group '$groupName' (GroupID: $groupId)"
            $shouldProcessAction = "Remove boundary from group"

            if ($Force -or $PSCmdlet.ShouldProcess($shouldProcessTarget, $shouldProcessAction)) {
                Write-Verbose "Calling RemoveBoundary on boundary group '$groupName' (GroupID: $groupId) for BoundaryID $resolvedBoundaryId"

                $methodResult = Invoke-CimMethod -InputObject $groupInstance -MethodName 'RemoveBoundary' -Arguments @{
                    BoundaryID = [uint32[]]@($resolvedBoundaryId)
                }

                if ($methodResult.ReturnValue -ne 0) {
                    throw "RemoveBoundary method returned non-zero exit code $($methodResult.ReturnValue) for boundary group '$groupName' (GroupID: $groupId)."
                }

                Write-Verbose "Successfully removed BoundaryID $resolvedBoundaryId from boundary group '$groupName' (GroupID: $groupId)."
            }
        } catch {
            throw $_
        }
    }
}
