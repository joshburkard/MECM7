function Remove-CM7BoundaryGroup {
    <#
        .SYNOPSIS
            Removes a boundary group from MECM using CIM.

        .DESCRIPTION
            Removes (deletes) a boundary group from Microsoft Endpoint Configuration Manager (MECM)
            using CIM. This function deletes an SMS_BoundaryGroup instance via CIM.

            This is the CIM-based equivalent of the Remove-CMBoundaryGroup cmdlet from the
            ConfigurationManager PowerShell module, but uses direct CIM queries over WinRM.

            The function supports removing boundary groups by:
            - Name:        resolves the boundary group by name (supports wildcard characters)
            - Id (GroupID): resolves one or more boundary groups by their integer GroupID
            - InputObject:  accepts a boundary group object from the pipeline (e.g., from Get-CM7BoundaryGroup)

        .PARAMETER Name
            The name of the boundary group to remove. Supports wildcard characters (* and ?).
            If multiple boundary groups match the name pattern, all matching groups are removed.

        .PARAMETER Id
            One or more GroupIDs of boundary groups to remove.
            Alias: GroupId

        .PARAMETER InputObject
            A boundary group object (e.g., from Get-CM7BoundaryGroup) to remove.
            Accepts pipeline input. Must have a GroupID property.

        .PARAMETER Force
            Suppresses confirmation prompts and removes the boundary group without asking.
            By default the function prompts for confirmation before deletion.

        .PARAMETER DisableWildcardHandling
            Treats wildcard characters as literal character values.
            Cannot be combined with ForceWildcardHandling.

        .PARAMETER ForceWildcardHandling
            Forces wildcard character processing even in contexts where it is not normally supported.
            May lead to unexpected behavior (not recommended).
            Cannot be combined with DisableWildcardHandling.

        .PARAMETER WhatIf
            Shows what would happen if the cmdlet runs. The cmdlet is not run.

        .PARAMETER Confirm
            Prompts you for confirmation before running the cmdlet.

        .EXAMPLE
            Remove-CM7BoundaryGroup -Name "Test"
            Removes the boundary group named "Test" after confirmation.

        .EXAMPLE
            Remove-CM7BoundaryGroup -Id "16777219" -Force
            Removes the boundary group with GroupID 16777219 without prompting for confirmation.

        .EXAMPLE
            Remove-CM7BoundaryGroup -Id "16777219", "16777220" -Force
            Removes multiple boundary groups by their GroupIDs without prompting.

        .EXAMPLE
            Get-CM7BoundaryGroup -Name "Test*" | Remove-CM7BoundaryGroup -Force
            Removes all boundary groups whose names start with "Test" via pipeline.

        .EXAMPLE
            Remove-CM7BoundaryGroup -Name "TestGroup" -WhatIf
            Shows what would happen without actually removing the boundary group.

        .NOTES
            Requires an active connection established via Connect-CM7.
            The SMS_BoundaryGroup WMI class is used to represent boundary groups in MECM.
            For more information on return object properties, see SMS_BoundaryGroup server WMI class:
            https://learn.microsoft.com/en-us/mem/configmgr/develop/reference/core/servers/configure/sms_boundarygroup-server-wmi-class
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High', DefaultParameterSetName = 'ByInputObject')]
    param(
        [Parameter(ParameterSetName = 'ByName', Mandatory = $true, Position = 0)]
        [SupportsWildcards()]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [Parameter(ParameterSetName = 'ById', Mandatory = $true)]
        [Alias('GroupId')]
        [string[]]$Id,

        [Parameter(ParameterSetName = 'ByInputObject', Mandatory = $true, ValueFromPipeline = $true)]
        [ValidateNotNull()]
        [PSObject]$InputObject,

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
            # ---- Resolve Boundary Group(s) ----
            $groups = @()

            switch ($PSCmdlet.ParameterSetName) {
                'ByName' {
                    if ($DisableWildcardHandling) {
                        # Treat name as a literal string (escape single quotes for WQL safety)
                        $safeName = $Name -replace "'", "''"
                        $query = "SELECT * FROM SMS_BoundaryGroup WHERE Name = '$safeName'"
                    } else {
                        # Convert wildcard pattern to WQL LIKE pattern
                        $wqlPattern = $Name -replace '\*', '%' -replace '\?', '_'
                        $query = "SELECT * FROM SMS_BoundaryGroup WHERE Name LIKE '$wqlPattern'"
                    }

                    $groups = @(Get-CimInstance @cimParams -Query $query)

                    if ($groups.Count -eq 0) {
                        Write-Warning "No boundary group found with name matching '$Name'."
                        return
                    }
                }

                'ById' {
                    foreach ($groupId in $Id) {
                        $query = "SELECT * FROM SMS_BoundaryGroup WHERE GroupID = $groupId"
                        $result = Get-CimInstance @cimParams -Query $query
                        if (-not $result) {
                            Write-Warning "No boundary group found with GroupID $groupId."
                        } else {
                            $groups += $result
                        }
                    }

                    if ($groups.Count -eq 0) {
                        return
                    }
                }

                'ByInputObject' {
                    # Resolve GroupID from the input object
                    $groupId = $null
                    if ($InputObject.PSObject.Properties['GroupID']) {
                        $groupId = $InputObject.GroupID
                    } elseif ($InputObject.PSObject.Properties['GroupId']) {
                        $groupId = $InputObject.GroupId
                    } else {
                        throw "InputObject does not have a GroupID property. Please provide a valid boundary group object from Get-CM7BoundaryGroup."
                    }

                    $query = "SELECT * FROM SMS_BoundaryGroup WHERE GroupID = $groupId"
                    $result = Get-CimInstance @cimParams -Query $query
                    if (-not $result) {
                        Write-Warning "No boundary group found with GroupID $groupId (from InputObject)."
                        return
                    }
                    $groups = @($result)
                }
            }

            # ---- Remove each resolved boundary group ----
            foreach ($group in $groups) {
                $groupName = $group.Name
                $groupId   = $group.GroupID

                if ($Force -or $PSCmdlet.ShouldProcess("$groupName (GroupID: $groupId)", "Remove boundary group")) {
                    Write-Verbose "Removing boundary group '$groupName' (GroupID: $groupId)"
                    Remove-CimInstance -CimSession $script:CMConnection.CimSession -InputObject $group
                    Write-Verbose "Boundary group '$groupName' (GroupID: $groupId) removed successfully."
                }
            }
        } catch {
            throw $_
        }
    }
}
