function New-CM7BoundaryGroup {
    <#
        .SYNOPSIS
            Creates a new boundary group in MECM using CIM.

        .DESCRIPTION
            Creates a new boundary group (SMS_BoundaryGroup) in Microsoft Endpoint Configuration Manager
            (MECM) using CIM. Supports setting a name, description, default site code for automatic site
            assignment, and optionally associating site system servers.
            Requires an active connection via Connect-CM7.

            This is the CIM-based equivalent of the New-CMBoundaryGroup cmdlet from the
            ConfigurationManager PowerShell module, but uses direct CIM queries over WinRM.

        .PARAMETER Name
            The name of the new boundary group. Must be unique within the MECM environment. (Mandatory)

        .PARAMETER Description
            An optional description for the new boundary group.

        .PARAMETER DefaultSiteCode
            The default site code to use for automatic site assignment for clients in this boundary group.

        .PARAMETER AddSiteSystemServerName
            One or more site system server fully qualified domain names (FQDNs) to associate with the
            new boundary group. These servers will be added as site system references for the group.
            Alias: AddSiteSystemServerNames

        .PARAMETER DisableWildcardHandling
            Treats wildcard characters as literal character values.
            Cannot be combined with ForceWildcardHandling.

        .PARAMETER ForceWildcardHandling
            Forces wildcard character processing even in contexts where it is not normally supported.
            May lead to unexpected behavior (not recommended).
            Cannot be combined with DisableWildcardHandling.

        .PARAMETER Force
            Suppresses confirmation prompts.

        .PARAMETER WhatIf
            Shows what would happen if the cmdlet runs. The cmdlet is not run.

        .PARAMETER Confirm
            Prompts you for confirmation before running the cmdlet.

        .EXAMPLE
            New-CM7BoundaryGroup -Name "Test"
            Creates a new boundary group named "Test".

        .EXAMPLE
            New-CM7BoundaryGroup -Name "BGroup05" -Description "My boundary group" -DefaultSiteCode "PS1"
            Creates a new boundary group with a description and default site code.

        .EXAMPLE
            New-CM7BoundaryGroup -Name "BGroup06" -AddSiteSystemServerName "server01.contoso.com" -Force
            Creates a boundary group and associates a site system server without prompting for confirmation.

        .NOTES
            Requires an active connection established via Connect-CM7.
            The SMS_BoundaryGroup WMI class is used to represent boundary groups in MECM.
            Site system server associations are stored in the SMS_BoundaryGroupSiteSystems WMI class.
            For more information on return object properties, see SMS_BoundaryGroup server WMI class:
            https://learn.microsoft.com/en-us/mem/configmgr/develop/reference/core/servers/configure/sms_boundarygroup-server-wmi-class
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [Parameter()]
        [string]$Description,

        [Parameter()]
        [string]$DefaultSiteCode,

        [Parameter()]
        [Alias('AddSiteSystemServerNames')]
        [string[]]$AddSiteSystemServerName,

        [Parameter()]
        [switch]$DisableWildcardHandling,

        [Parameter()]
        [switch]$ForceWildcardHandling,

        [Parameter()]
        [switch]$Force
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
            # Check for duplicate boundary group name
            $existingQuery = "SELECT GroupID, Name FROM SMS_BoundaryGroup WHERE Name = '$Name'"
            $existingGroup = Get-CimInstance @cimParams -Query $existingQuery
            if ($existingGroup) {
                throw "A boundary group with name '$Name' already exists (GroupID: $($existingGroup.GroupID))."
            }

            # Build the properties hashtable for the new boundary group
            $groupProps = @{
                Name = $Name
            }

            if ($PSBoundParameters.ContainsKey('Description')) {
                $groupProps['Description'] = $Description
            }

            if ($PSBoundParameters.ContainsKey('DefaultSiteCode')) {
                $groupProps['DefaultSiteCode'] = $DefaultSiteCode
            }

            $actionDescription = "Create boundary group '$Name'"
            if ($Force -or $PSCmdlet.ShouldProcess($Name, $actionDescription)) {

                # Create the boundary group
                $newGroup = New-CimInstance @cimParams -ClassName 'SMS_BoundaryGroup' -Property $groupProps
                if (-not $newGroup) {
                    throw "Failed to create boundary group '$Name'. New-CimInstance returned null."
                }

                $groupId = $newGroup.GroupID

                # Associate site system servers if provided, using the AddSiteSystem instance method
                if ($AddSiteSystemServerName -and $AddSiteSystemServerName.Count -gt 0) {
                    try {
                        # Build parallel NAL path and Flags arrays required by AddSiteSystem
                        $nalPaths = $AddSiteSystemServerName | ForEach-Object {
                            "[`"Display=\\$_\`"]MSWNET:[`"SMS_SITE=$($script:CMConnection.SiteCode)`"]\\$_\"
                        }
                        $flags = [uint32[]](@(0) * $AddSiteSystemServerName.Count)

                        Write-Verbose "Calling AddSiteSystem on boundary group '$Name' (GroupID: $groupId) for $($AddSiteSystemServerName.Count) server(s)"

                        # Retrieve the CIM instance to invoke the method on
                        $groupInstance = Get-CimInstance @cimParams -Query "SELECT * FROM SMS_BoundaryGroup WHERE GroupID = $groupId"
                        $methodResult  = Invoke-CimMethod -InputObject $groupInstance -MethodName 'AddSiteSystem' -Arguments @{
                            ServerNALPath = [string[]]$nalPaths
                            Flags         = $flags
                        }
                        if ($methodResult.ReturnValue -ne 0) {
                            Write-Warning "AddSiteSystem returned non-zero exit code $($methodResult.ReturnValue) for boundary group '$Name'."
                        }
                    } catch {
                        Write-Warning "Could not associate site system server(s) with boundary group '$Name': $_"
                    }
                }

                # Retrieve the created boundary group to return full object
                $resultQuery = "SELECT * FROM SMS_BoundaryGroup WHERE GroupID = $groupId"
                $result = Get-CimInstance @cimParams -Query $resultQuery

                if ($result) {
                    $output = [PSCustomObject]@{
                        PSTypeName      = 'MECM7.BoundaryGroup'
                        GroupID         = [int]$result.GroupID
                        Name            = $result.Name
                        Description     = $result.Description
                        DefaultSiteCode = $result.DefaultSiteCode
                        MemberCount     = $result.MemberCount
                    }
                    $output.PSObject.TypeNames.Insert(0, 'MECM7.BoundaryGroup')
                    $result.CimInstanceProperties | ForEach-Object {
                        if ($_.Name -notin $output.PSObject.Properties.Name) {
                            $output | Add-Member -MemberType NoteProperty -Name $_.Name -Value $_.Value -Force
                        }
                    }
                    Write-Output $output
                } else {
                    Write-Warning "Boundary group was created but could not retrieve the result. GroupID: $groupId"
                }
            }
        } catch {
            throw $_
        }
    }
}
