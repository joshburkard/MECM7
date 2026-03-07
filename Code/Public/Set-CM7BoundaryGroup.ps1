function Set-CM7BoundaryGroup {
    <#
        .SYNOPSIS
            Modifies the properties of a boundary group in MECM using CIM.

        .DESCRIPTION
            Modifies properties of an existing boundary group (SMS_BoundaryGroup) in Microsoft Endpoint
            Configuration Manager (MECM) using CIM.
            Supports renaming, updating description, assigning a default site code, managing site system
            server associations, and configuring peer download options.
            Requires an active connection via Connect-CM7.

            This is the CIM-based equivalent of the Set-CMBoundaryGroup cmdlet from the
            ConfigurationManager PowerShell module, but uses direct CIM queries over WinRM.

            The function supports identifying boundary groups by:
            - Name:        looks up the boundary group by name
            - Id (GroupID): looks up the boundary group by its integer GroupID
            - InputObject:  accepts a boundary group object from the pipeline (e.g., from Get-CM7BoundaryGroup)

        .PARAMETER Name
            The name of the boundary group to modify.

        .PARAMETER Id
            The GroupID of the boundary group to modify.
            Alias: GroupId

        .PARAMETER InputObject
            A boundary group object (e.g., from Get-CM7BoundaryGroup) to modify.
            Accepts pipeline input. Must have a GroupID property.

        .PARAMETER NewName
            A new name to rename the boundary group to.

        .PARAMETER Description
            A new description for the boundary group.

        .PARAMETER DefaultSiteCode
            The site code to set for automatic site assignment. Set to $null or empty string to disable
            site assignment for this boundary group.

        .PARAMETER AddSiteSystemServerName
            One or more site system server fully qualified domain names (FQDNs) to add to the
            boundary group. Alias: AddSiteSystemServerNames

        .PARAMETER RemoveSiteSystemServerName
            One or more site system server fully qualified domain names (FQDNs) to remove from the
            boundary group. Alias: RemoveSiteSystemServerNames

        .PARAMETER ClearSiteSystemServer
            Remove all site system server associations from the boundary group.
            Alias: ClearSiteSystemServers

        .PARAMETER AllowPeerDownload
            Configure whether peer downloads are enabled in this boundary group.
            Corresponds to bit 0x0002 in the Flags property of SMS_BoundaryGroup.

        .PARAMETER SubnetPeerDownloadOnly
            Configure whether only peers within the same subnet are used for peer downloads.
            Requires AllowPeerDownload to be enabled.
            Corresponds to bit 0x0004 in the Flags property of SMS_BoundaryGroup.
            Alias: PeerWithinSameSubnetOnly

        .PARAMETER PreferDPOverPeer
            Configure whether distribution points are preferred over peers within the same subnet.
            Requires AllowPeerDownload to be enabled.
            Corresponds to bit 0x0008 in the Flags property of SMS_BoundaryGroup.
            Alias: PreferDistributionPointOverPeerInSubnet

        .PARAMETER PreferCloudDPOverDP
            Configure whether cloud-based sources are preferred over on-CM7mises distribution points.
            Corresponds to bit 0x0010 in the Flags property of SMS_BoundaryGroup.
            Alias: PreferCloudDistributionPointOverDistributionPoint

        .PARAMETER PassThru
            Returns the modified boundary group object. By default this cmdlet does not generate output.

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
            Set-CM7BoundaryGroup -Name "BGroup01" -NewName "BGroup00"
            Renames the boundary group "BGroup01" to "BGroup00".

        .EXAMPLE
            Set-CM7BoundaryGroup -Name "Test" -Description "Updated description" -DefaultSiteCode "PS1"
            Updates the description and default site code of the boundary group named "Test".

        .EXAMPLE
            Set-CM7BoundaryGroup -Name "Remote BG" -AddSiteSystemServerName "server01.contoso.com"
            Adds a site system server to the boundary group.

        .EXAMPLE
            Set-CM7BoundaryGroup -Name "Remote BG" -ClearSiteSystemServer
            Removes all site system server associations from the boundary group.

        .EXAMPLE
            Set-CM7BoundaryGroup -Name "Test" -AllowPeerDownload $true -SubnetPeerDownloadOnly $true
            Enables peer downloads and restricts them to same-subnet peers.

        .EXAMPLE
            Get-CM7BoundaryGroup -Name "BGroup01" | Set-CM7BoundaryGroup -NewName "BGroup00"
            Renames a boundary group using the pipeline.

        .EXAMPLE
            Set-CM7BoundaryGroup -Id "16777219" -Description "Updated via ID" -PassThru
            Updates the description of the boundary group with GroupID 16777219 and returns the modified object.

        .NOTES
            Requires an active connection established via Connect-CM7.
            The SMS_BoundaryGroup WMI class is used to represent boundary groups in MECM.
            Site system server associations are managed via the AddSiteSystem / RemoveSiteSystem CIM methods.
            Peer download options are stored as bit flags in the Flags property of SMS_BoundaryGroup:
                0x0002 = AllowPeerDownload
                0x0004 = SubnetPeerDownloadOnly
                0x0008 = PreferDPOverPeer
                0x0010 = PreferCloudDPOverDP
            For more information, see:
            https://learn.microsoft.com/en-us/mem/configmgr/develop/reference/core/servers/configure/sms_boundarygroup-server-wmi-class
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium', DefaultParameterSetName = 'ByName')]
    param(
        [Parameter(ParameterSetName = 'ByName', Mandatory = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [Parameter(ParameterSetName = 'ById', Mandatory = $true)]
        [Alias('GroupId')]
        [string]$Id,

        [Parameter(ParameterSetName = 'ByInputObject', Mandatory = $true, ValueFromPipeline = $true)]
        [ValidateNotNull()]
        [PSObject]$InputObject,

        [Parameter()]
        [string]$NewName,

        [Parameter()]
        [string]$Description,

        [Parameter()]
        [AllowNull()]
        [AllowEmptyString()]
        [string]$DefaultSiteCode,

        [Parameter()]
        [Alias('AddSiteSystemServerNames')]
        [string[]]$AddSiteSystemServerName,

        [Parameter()]
        [Alias('RemoveSiteSystemServerNames')]
        [string[]]$RemoveSiteSystemServerName,

        [Parameter()]
        [Alias('ClearSiteSystemServers')]
        [switch]$ClearSiteSystemServer,

        [Parameter()]
        [System.Boolean]$AllowPeerDownload,

        [Parameter()]
        [Alias('PeerWithinSameSubnetOnly')]
        [System.Boolean]$SubnetPeerDownloadOnly,

        [Parameter()]
        [Alias('PreferDistributionPointOverPeerInSubnet')]
        [System.Boolean]$PreferDPOverPeer,

        [Parameter()]
        [Alias('PreferCloudDistributionPointOverDistributionPoint')]
        [System.Boolean]$PreferCloudDPOverDP,

        [Parameter()]
        [switch]$PassThru,

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

        # Flags bit flags for peer download settings (SMS_BoundaryGroup.Flags property)
        $optionBitAllowPeerDownload    = [uint32]0x0002
        $optionBitSubnetPeerOnly       = [uint32]0x0004
        $optionBitPreferDPOverPeer     = [uint32]0x0008
        $optionBitPreferCloudDPOverDP  = [uint32]0x0010
    }

    process {
        try {
            # ---- Resolve Boundary Group ----
            $group = $null

            switch ($PSCmdlet.ParameterSetName) {
                'ByName' {
                    $safeName = $Name -replace "'", "''"
                    $query = "SELECT * FROM SMS_BoundaryGroup WHERE Name = '$safeName'"
                    $group = Get-CimInstance @cimParams -Query $query

                    if (-not $group) {
                        throw "No boundary group found with name '$Name'."
                    }
                    if (@($group).Count -gt 1) {
                        throw "Multiple boundary groups found matching name '$Name'. Use a more specific name or use -Id."
                    }
                }

                'ById' {
                    $query = "SELECT * FROM SMS_BoundaryGroup WHERE GroupID = $Id"
                    $group = Get-CimInstance @cimParams -Query $query

                    if (-not $group) {
                        throw "No boundary group found with GroupID $Id."
                    }
                }

                'ByInputObject' {
                    $groupId = $null
                    if ($InputObject.PSObject.Properties['GroupID']) {
                        $groupId = $InputObject.GroupID
                    } elseif ($InputObject.PSObject.Properties['GroupId']) {
                        $groupId = $InputObject.GroupId
                    } else {
                        throw "InputObject does not have a GroupID property. Please provide a valid boundary group object from Get-CM7BoundaryGroup."
                    }

                    $query = "SELECT * FROM SMS_BoundaryGroup WHERE GroupID = $groupId"
                    $group = Get-CimInstance @cimParams -Query $query

                    if (-not $group) {
                        throw "No boundary group found with GroupID $groupId (from InputObject)."
                    }
                }
            }

            $groupName = $group.Name
            $groupId   = $group.GroupID

            if ($PSCmdlet.ShouldProcess("$groupName (GroupID: $groupId)", "Modify boundary group")) {

                # ---- Build the property update hashtable ----
                $propertyUpdate = @{}
                $hasPropertyChange = $false

                if ($PSBoundParameters.ContainsKey('NewName')) {
                    $propertyUpdate['Name'] = $NewName
                    $hasPropertyChange = $true
                }

                if ($PSBoundParameters.ContainsKey('Description')) {
                    $propertyUpdate['Description'] = $Description
                    $hasPropertyChange = $true
                }

                if ($PSBoundParameters.ContainsKey('DefaultSiteCode')) {
                    $propertyUpdate['DefaultSiteCode'] = if ([string]::IsNullOrEmpty($DefaultSiteCode)) { '' } else { $DefaultSiteCode }
                    $hasPropertyChange = $true
                }

                # ---- Handle Flags bit flags (SMS_BoundaryGroup.Flags property) ----
                $optionsChanged = $PSBoundParameters.ContainsKey('AllowPeerDownload') -or
                                  $PSBoundParameters.ContainsKey('SubnetPeerDownloadOnly') -or
                                  $PSBoundParameters.ContainsKey('PreferDPOverPeer') -or
                                  $PSBoundParameters.ContainsKey('PreferCloudDPOverDP')

                if ($optionsChanged) {
                    $currentOptions = [uint32]$group.Flags

                    if ($PSBoundParameters.ContainsKey('AllowPeerDownload')) {
                        if ($AllowPeerDownload) { $currentOptions = $currentOptions -bor $optionBitAllowPeerDownload }
                        else                    { $currentOptions = $currentOptions -band (-bnot $optionBitAllowPeerDownload) }
                    }

                    if ($PSBoundParameters.ContainsKey('SubnetPeerDownloadOnly')) {
                        if ($SubnetPeerDownloadOnly) { $currentOptions = $currentOptions -bor $optionBitSubnetPeerOnly }
                        else                         { $currentOptions = $currentOptions -band (-bnot $optionBitSubnetPeerOnly) }
                    }

                    if ($PSBoundParameters.ContainsKey('PreferDPOverPeer')) {
                        if ($PreferDPOverPeer) { $currentOptions = $currentOptions -bor $optionBitPreferDPOverPeer }
                        else                   { $currentOptions = $currentOptions -band (-bnot $optionBitPreferDPOverPeer) }
                    }

                    if ($PSBoundParameters.ContainsKey('PreferCloudDPOverDP')) {
                        if ($PreferCloudDPOverDP) { $currentOptions = $currentOptions -bor $optionBitPreferCloudDPOverDP }
                        else                      { $currentOptions = $currentOptions -band (-bnot $optionBitPreferCloudDPOverDP) }
                    }

                    $propertyUpdate['Flags'] = $currentOptions
                    $hasPropertyChange = $true
                }

                # ---- Apply property changes via Set-CimInstance ----
                if ($hasPropertyChange) {
                    Write-Verbose "Updating properties for boundary group '$groupName' (GroupID: $groupId)"
                    Set-CimInstance -CimSession $script:CMConnection.CimSession -InputObject $group -Property $propertyUpdate
                }

                # ---- Site system server management ----
                # Re-fetch the group instance after property changes for method invocation
                $groupInstance = Get-CimInstance @cimParams -Query "SELECT * FROM SMS_BoundaryGroup WHERE GroupID = $groupId"

                # Clear all site system servers
                if ($ClearSiteSystemServer) {
                    try {
                        $existingServers = Get-CimInstance @cimParams -Query "SELECT * FROM SMS_BoundaryGroupSiteSystems WHERE GroupID = $groupId" -ErrorAction SilentlyContinue
                        if ($existingServers) {
                            $nalPathsToRemove = @($existingServers | ForEach-Object { $_.ServerNALPath })
                            Write-Verbose "Clearing $($nalPathsToRemove.Count) site system server(s) from boundary group '$groupName'"
                            $methodResult = Invoke-CimMethod -InputObject $groupInstance -MethodName 'RemoveSiteSystem' -Arguments @{
                                ServerNALPath = [string[]]$nalPathsToRemove
                            }
                            if ($methodResult.ReturnValue -ne 0) {
                                Write-Warning "RemoveSiteSystem (ClearAll) returned non-zero exit code $($methodResult.ReturnValue) for boundary group '$groupName'."
                            }
                        } else {
                            Write-Verbose "No site system servers to clear for boundary group '$groupName'."
                        }
                    } catch {
                        Write-Warning "Could not clear site system servers from boundary group '$groupName': $_"
                    }
                }

                # Remove specified site system servers
                if ($RemoveSiteSystemServerName -and $RemoveSiteSystemServerName.Count -gt 0) {
                    try {
                        $nalPathsToRemove = $RemoveSiteSystemServerName | ForEach-Object {
                            "[`"Display=\\$_\`"]MSWNET:[`"SMS_SITE=$($script:CMConnection.SiteCode)`"]\\$_\"
                        }
                        Write-Verbose "Removing $($RemoveSiteSystemServerName.Count) site system server(s) from boundary group '$groupName'"
                        $methodResult = Invoke-CimMethod -InputObject $groupInstance -MethodName 'RemoveSiteSystem' -Arguments @{
                            ServerNALPath = [string[]]$nalPathsToRemove
                        }
                        if ($methodResult.ReturnValue -ne 0) {
                            Write-Warning "RemoveSiteSystem returned non-zero exit code $($methodResult.ReturnValue) for boundary group '$groupName'."
                        }
                    } catch {
                        Write-Warning "Could not remove site system server(s) from boundary group '$groupName': $_"
                    }
                }

                # Add specified site system servers
                if ($AddSiteSystemServerName -and $AddSiteSystemServerName.Count -gt 0) {
                    try {
                        $nalPathsToAdd = $AddSiteSystemServerName | ForEach-Object {
                            "[`"Display=\\$_\`"]MSWNET:[`"SMS_SITE=$($script:CMConnection.SiteCode)`"]\\$_\"
                        }
                        $flags = [uint32[]](@(0) * $AddSiteSystemServerName.Count)
                        Write-Verbose "Adding $($AddSiteSystemServerName.Count) site system server(s) to boundary group '$groupName'"
                        $methodResult = Invoke-CimMethod -InputObject $groupInstance -MethodName 'AddSiteSystem' -Arguments @{
                            ServerNALPath = [string[]]$nalPathsToAdd
                            Flags         = $flags
                        }
                        if ($methodResult.ReturnValue -ne 0) {
                            Write-Warning "AddSiteSystem returned non-zero exit code $($methodResult.ReturnValue) for boundary group '$groupName'."
                        }
                    } catch {
                        Write-Warning "Could not add site system server(s) to boundary group '$groupName': $_"
                    }
                }

                # ---- PassThru: return updated object ----
                if ($PassThru) {
                    $effectiveName = if ($PSBoundParameters.ContainsKey('NewName')) { $NewName } else { $groupName }
                    $resultQuery = "SELECT * FROM SMS_BoundaryGroup WHERE GroupID = $groupId"
                    $result = Get-CimInstance @cimParams -Query $resultQuery

                    if ($result) {
                        $output = [PSCustomObject]@{
                            PSTypeName                      = 'MECM7.BoundaryGroup'
                            GroupID                         = [int]$result.GroupID
                            Name                            = $result.Name
                            Description                     = $result.Description
                            DefaultSiteCode                 = $result.DefaultSiteCode
                            MemberCount                     = $result.MemberCount
                            Flags           = $result.Flags
                        }
                        $output.PSObject.TypeNames.Insert(0, 'MECM7.BoundaryGroup')
                        $result.CimInstanceProperties | ForEach-Object {
                            if ($_.Name -notin $output.PSObject.Properties.Name) {
                                $output | Add-Member -MemberType NoteProperty -Name $_.Name -Value $_.Value -Force
                            }
                        }
                        Write-Output $output
                    } else {
                        Write-Warning "Could not retrieve boundary group after modification. GroupID: $groupId"
                    }
                }
            }
        } catch {
            throw $_
        }
    }
}
