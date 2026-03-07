function Add-CM7BoundaryToGroup {
    <#
        .SYNOPSIS
            Assigns a boundary to a boundary group in MECM using CIM.

        .DESCRIPTION
            Assigns an existing boundary to an existing boundary group in Microsoft Endpoint
            Configuration Manager (MECM) using CIM. The boundary group and the boundary can each
            be identified by their ID, name, or by passing an object from Get-CM7BoundaryGroup /
            Get-CM7Boundary respectively.

            Internally, the function invokes the AddBoundary instance method on the
            SMS_BoundaryGroup WMI class.

            This is the CIM-based equivalent of the Add-CMBoundaryToGroup cmdlet from the
            ConfigurationManager PowerShell module, but uses direct CIM queries over WinRM
            instead of requiring the ConfigMgr console or PowerShell drive.

        .PARAMETER BoundaryGroupId
            The GroupID (integer) of the existing boundary group to assign the boundary to.

        .PARAMETER BoundaryGroupName
            The name of the existing boundary group to assign the boundary to.

        .PARAMETER BoundaryGroupInputObject
            A boundary group object (e.g. from Get-CM7BoundaryGroup) to assign the boundary to.
            Alias: BoundaryGroup

        .PARAMETER BoundaryId
            The BoundaryID (integer) of the boundary to assign.

        .PARAMETER BoundaryName
            The name of the boundary to assign.

        .PARAMETER InputObject
            A boundary object (e.g. from Get-CM7Boundary) to assign.
            Accepts pipeline input.
            Aliases: Boundary, BoundaryInputObject

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
            Add-CM7BoundaryToGroup -BoundaryGroupId 16777219 -BoundaryName "CLBound03"
            Assigns the boundary named "CLBound03" to the boundary group with GroupID 16777219.

        .EXAMPLE
            Add-CM7BoundaryToGroup -BoundaryGroupName "MyBoundaryGroup" -BoundaryId 16777230
            Assigns the boundary with BoundaryID 16777230 to the boundary group named "MyBoundaryGroup".

        .EXAMPLE
            $group    = Get-CM7BoundaryGroup -Name "MyBoundaryGroup"
            $boundary = Get-CM7Boundary     -Name "MyBoundary"
            Add-CM7BoundaryToGroup -BoundaryGroupInputObject $group -InputObject $boundary
            Assigns the boundary to the group using objects from Get-CM7BoundaryGroup and Get-CM7Boundary.

        .EXAMPLE
            Get-CM7Boundary -Name "MyBoundary" | Add-CM7BoundaryToGroup -BoundaryGroupName "MyBoundaryGroup"
            Pipes a boundary object to the function and assigns it to the named group.

        .EXAMPLE
            Add-CM7BoundaryToGroup -BoundaryGroupName "MyBoundaryGroup" -BoundaryName "MyBoundary" -WhatIf
            Shows what would happen without actually making the assignment.

        .NOTES
            Requires an active connection established via Connect-CM7.

            The SMS_BoundaryGroup WMI class is used to represent boundary groups in MECM.
            The AddBoundary instance method accepts an array of uint32 BoundaryIDs and adds them
            to the boundary group.

            For more information on the SMS_BoundaryGroup class and the AddBoundary method, see:
            https://learn.microsoft.com/en-us/mem/configmgr/develop/reference/core/servers/configure/sms_boundarygroup-server-wmi-class

            Related functions:
            - Get-CM7Boundary
            - Get-CM7BoundaryGroup
            - New-CM7BoundaryGroup
            - New-CM7Boundary
    #>
    [CmdletBinding(
        SupportsShouldProcess = $true,
        ConfirmImpact         = 'Medium',
        DefaultParameterSetName = 'ByGroupObject_ByBoundaryObject'
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
        [Parameter(ParameterSetName = 'ByGroupId_ByBoundaryObject',     Mandatory = $true, ValueFromPipeline = $true)]
        [Parameter(ParameterSetName = 'ByGroupName_ByBoundaryObject',   Mandatory = $true, ValueFromPipeline = $true)]
        [Parameter(ParameterSetName = 'ByGroupObject_ByBoundaryObject', Mandatory = $true, ValueFromPipeline = $true)]
        [Alias('Boundary', 'BoundaryInputObject')]
        [ValidateNotNull()]
        [PSObject]$InputObject,

        # ---- Wildcard handling ----
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
                    # Resolve GroupID from the object
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
                    # Verify the boundary exists
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
                        throw "Multiple boundaries found with name '$BoundaryName'. Please use BoundaryId or InputObject to be more specific."
                    }
                    $resolvedBoundaryId = $boundaryResult.BoundaryID
                }
                '_ByBoundaryObject$' {
                    # Resolve BoundaryID from the object
                    if ($InputObject.PSObject.Properties['BoundaryID']) {
                        $resolvedBoundaryId = $InputObject.BoundaryID
                    } elseif ($InputObject.PSObject.Properties['BoundaryId']) {
                        $resolvedBoundaryId = $InputObject.BoundaryId
                    } else {
                        throw "InputObject does not have a BoundaryID property. Please provide a valid boundary object from Get-CM7Boundary."
                    }
                    Write-Verbose "Using BoundaryID from InputObject: $resolvedBoundaryId"
                    # Verify the boundary exists
                    $boundaryCheck = Get-CimInstance @cimParams -Query "SELECT BoundaryID FROM SMS_Boundary WHERE BoundaryID = $resolvedBoundaryId"
                    if (-not $boundaryCheck) {
                        throw "No boundary found with BoundaryID $resolvedBoundaryId (from InputObject)."
                    }
                }
            }

            # ------------------------------------------------------------------
            # 3. Invoke AddBoundary method on the boundary group
            # ------------------------------------------------------------------
            $groupName = $groupInstance.Name
            $groupId   = $groupInstance.GroupID

            $shouldProcessTarget  = "Boundary '$resolvedBoundaryId' to boundary group '$groupName' (GroupID: $groupId)"
            $shouldProcessAction  = "Add boundary to group"

            if ($PSCmdlet.ShouldProcess($shouldProcessTarget, $shouldProcessAction)) {
                Write-Verbose "Calling AddBoundary on boundary group '$groupName' (GroupID: $groupId) for BoundaryID $resolvedBoundaryId"

                $methodResult = Invoke-CimMethod -InputObject $groupInstance -MethodName 'AddBoundary' -Arguments @{
                    BoundaryID = [uint32[]]@($resolvedBoundaryId)
                }

                if ($methodResult.ReturnValue -ne 0) {
                    throw "AddBoundary method returned non-zero exit code $($methodResult.ReturnValue) for boundary group '$groupName' (GroupID: $groupId)."
                }

                Write-Verbose "Successfully added BoundaryID $resolvedBoundaryId to boundary group '$groupName' (GroupID: $groupId)."
            }
        } catch {
            throw $_
        }
    }
}
