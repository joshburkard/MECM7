function Add-CM7SoftwareUpdateToGroup {
    <#
        .SYNOPSIS
            Adds one or more software updates to a software update group in MECM using CIM.

        .DESCRIPTION
            Adds software updates to an existing software update group (SMS_AuthorizationList) in
            Microsoft Endpoint Configuration Manager (MECM) using CIM. Software updates can be
            specified by CI_ID, Article ID, name, or by passing software update objects from
            Get-CM7SoftwareUpdate.

            This is the CIM-based equivalent of the Add-CMSoftwareUpdateToGroup cmdlet from the
            ConfigurationManager PowerShell module, but uses direct CIM queries over WinRM
            instead of requiring the ConfigMgr console or PowerShell drive.

            The function performs the following actions:
            1. Validates an active connection exists (established via Connect-CM7)
            2. Resolves the target software update group by name, CI_ID, or input object
            3. Resolves the software updates to add by CI_ID, Article ID, name, or input object
            4. Merges the new update CI_IDs with the existing group's Updates array (skipping duplicates)
            5. Saves the updated group via CIM
            6. Returns the updated software update group as a formatted MECM7.SoftwareUpdateGroup object

        .PARAMETER SoftwareUpdateGroupName
            The name (LocalizedDisplayName) of the software update group to add updates to.
            Mutually exclusive with SoftwareUpdateGroupId and SoftwareUpdateGroup.

        .PARAMETER SoftwareUpdateGroupId
            The CI_ID (integer) of the software update group to add updates to.
            Mutually exclusive with SoftwareUpdateGroupName and SoftwareUpdateGroup.

        .PARAMETER SoftwareUpdateGroup
            A software update group object (as returned by Get-CM7SoftwareUpdateGroup) to add updates to.
            Accepts pipeline input.
            Mutually exclusive with SoftwareUpdateGroupName and SoftwareUpdateGroupId.

        .PARAMETER SoftwareUpdate
            One or more software update objects (as returned by Get-CM7SoftwareUpdate) to add to the group.
            The CI_ID property is extracted from each object.
            Mutually exclusive with UpdateId, ArticleId, and SoftwareUpdateName.

        .PARAMETER UpdateId
            An array of software update CI_IDs (integers) to add to the group.
            Mutually exclusive with SoftwareUpdate, ArticleId, and SoftwareUpdateName.

        .PARAMETER ArticleId
            An array of software update Article IDs (KB numbers, e.g. "4038779") to add to the group.
            The function resolves these to CI_IDs by querying SMS_SoftwareUpdate.
            Mutually exclusive with SoftwareUpdate, UpdateId, and SoftwareUpdateName.

        .PARAMETER SoftwareUpdateName
            The name (LocalizedDisplayName) of the software update(s) to add. Supports wildcard characters (* and ?).
            The function resolves the name to CI_IDs by querying SMS_SoftwareUpdate.
            Mutually exclusive with SoftwareUpdate, UpdateId, and ArticleId.

        .PARAMETER Force
            Suppresses confirmation prompts.

        .PARAMETER WhatIf
            Shows what would happen if the cmdlet runs. The cmdlet is not run.

        .PARAMETER Confirm
            Prompts you for confirmation before running the cmdlet.

        .EXAMPLE
            Add-CM7SoftwareUpdateToGroup -SoftwareUpdateGroupName "Test-SUG" -UpdateId @(16788010) -Force
            Adds a software update by CI_ID to the specified software update group.

        .EXAMPLE
            Add-CM7SoftwareUpdateToGroup -SoftwareUpdateGroupName "Test-SUG" -ArticleId @("4038779") -Force
            Adds software updates by Article ID (KB number) to the specified software update group.

        .EXAMPLE
            $updates = Get-CM7SoftwareUpdate -ArticleId "4038779"
            Add-CM7SoftwareUpdateToGroup -SoftwareUpdateGroupName "Test-SUG" -SoftwareUpdate $updates -Force
            Retrieves software updates and adds them to a software update group using input objects.

        .EXAMPLE
            Get-CM7SoftwareUpdateGroup -Name "Test-SUG" | Add-CM7SoftwareUpdateToGroup -UpdateId @(16788010, 16788011) -Force
            Pipes a software update group object and adds updates to it.

        .EXAMPLE
            Add-CM7SoftwareUpdateToGroup -SoftwareUpdateGroupId 17164572 -ArticleId @("4038779") -Force
            Adds software updates by Article ID to a group specified by its CI_ID.

        .EXAMPLE
            Add-CM7SoftwareUpdateToGroup -SoftwareUpdateGroupName "Test-SUG" -SoftwareUpdateName "*Cumulative*" -Force
            Adds all software updates matching a name wildcard pattern to the specified group.

        .EXAMPLE
            Add-CM7SoftwareUpdateToGroup -SoftwareUpdateGroupName "Test-SUG" -UpdateId @(16788010) -WhatIf
            Shows what would happen without actually modifying the software update group.

        .NOTES
            Requires an active connection established via Connect-CM7.

            The SMS_AuthorizationList WMI class is used to represent software update groups in MECM.
            The Updates property contains an array of CI_IDs referencing SMS_SoftwareUpdate instances.

            Updates that are already members of the group are silently skipped (no duplicates are added).

            This function is the CIM-based equivalent of the Add-CMSoftwareUpdateToGroup cmdlet
            from the ConfigurationManager PowerShell module but uses direct CIM queries
            over WinRM instead of requiring the ConfigMgr console or PowerShell drive.
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium', DefaultParameterSetName = 'ByGroupNameAndUpdateId')]
    param(
        [Parameter(Mandatory = $true, ParameterSetName = 'ByGroupNameAndUpdateId')]
        [Parameter(Mandatory = $true, ParameterSetName = 'ByGroupNameAndArticleId')]
        [Parameter(Mandatory = $true, ParameterSetName = 'ByGroupNameAndSoftwareUpdate')]
        [Parameter(Mandatory = $true, ParameterSetName = 'ByGroupNameAndSoftwareUpdateName')]
        [ValidateNotNullOrEmpty()]
        [string]$SoftwareUpdateGroupName,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByGroupIdAndUpdateId')]
        [Parameter(Mandatory = $true, ParameterSetName = 'ByGroupIdAndArticleId')]
        [Parameter(Mandatory = $true, ParameterSetName = 'ByGroupIdAndSoftwareUpdate')]
        [Parameter(Mandatory = $true, ParameterSetName = 'ByGroupIdAndSoftwareUpdateName')]
        [ValidateNotNullOrEmpty()]
        [int]$SoftwareUpdateGroupId,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByGroupObjectAndUpdateId', ValueFromPipeline = $true)]
        [Parameter(Mandatory = $true, ParameterSetName = 'ByGroupObjectAndArticleId', ValueFromPipeline = $true)]
        [Parameter(Mandatory = $true, ParameterSetName = 'ByGroupObjectAndSoftwareUpdate', ValueFromPipeline = $true)]
        [Parameter(Mandatory = $true, ParameterSetName = 'ByGroupObjectAndSoftwareUpdateName', ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        [PSObject]$SoftwareUpdateGroup,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByGroupNameAndSoftwareUpdate')]
        [Parameter(Mandatory = $true, ParameterSetName = 'ByGroupIdAndSoftwareUpdate')]
        [Parameter(Mandatory = $true, ParameterSetName = 'ByGroupObjectAndSoftwareUpdate')]
        [ValidateNotNullOrEmpty()]
        [PSObject[]]$SoftwareUpdate,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByGroupNameAndUpdateId')]
        [Parameter(Mandatory = $true, ParameterSetName = 'ByGroupIdAndUpdateId')]
        [Parameter(Mandatory = $true, ParameterSetName = 'ByGroupObjectAndUpdateId')]
        [ValidateNotNullOrEmpty()]
        [int[]]$UpdateId,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByGroupNameAndArticleId')]
        [Parameter(Mandatory = $true, ParameterSetName = 'ByGroupIdAndArticleId')]
        [Parameter(Mandatory = $true, ParameterSetName = 'ByGroupObjectAndArticleId')]
        [ValidateNotNullOrEmpty()]
        [string[]]$ArticleId,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByGroupNameAndSoftwareUpdateName')]
        [Parameter(Mandatory = $true, ParameterSetName = 'ByGroupIdAndSoftwareUpdateName')]
        [Parameter(Mandatory = $true, ParameterSetName = 'ByGroupObjectAndSoftwareUpdateName')]
        [SupportsWildcards()]
        [ValidateNotNullOrEmpty()]
        [string]$SoftwareUpdateName,

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

        # Determine the namespace
        $namespace = "root/SMS/site_$($script:CMConnection.SiteCode)"

        # Build common CIM parameters
        $cimParams = @{
            CimSession = $script:CMConnection.CimSession
            Namespace  = $namespace
        }
    }

    process {
        try {
            # ---- Resolve the software update group ----
            $group = $null

            if ($PSBoundParameters.ContainsKey('SoftwareUpdateGroupName')) {
                $groupQuery = "SELECT * FROM SMS_AuthorizationList WHERE LocalizedDisplayName = '$SoftwareUpdateGroupName'"
                Write-Verbose "Querying software update group: $groupQuery"
                $group = Get-CimInstance @cimParams -Query $groupQuery

                if (-not $group) {
                    throw "Software update group '$SoftwareUpdateGroupName' not found."
                }
                if (@($group).Count -gt 1) {
                    throw "Multiple software update groups found with name '$SoftwareUpdateGroupName'. Use -SoftwareUpdateGroupId instead."
                }
            }
            elseif ($PSBoundParameters.ContainsKey('SoftwareUpdateGroupId')) {
                $groupQuery = "SELECT * FROM SMS_AuthorizationList WHERE CI_ID = $SoftwareUpdateGroupId"
                Write-Verbose "Querying software update group: $groupQuery"
                $group = Get-CimInstance @cimParams -Query $groupQuery

                if (-not $group) {
                    throw "Software update group with CI_ID '$SoftwareUpdateGroupId' not found."
                }
            }
            elseif ($PSBoundParameters.ContainsKey('SoftwareUpdateGroup')) {
                # Validate the input object has a CI_ID
                if (-not $SoftwareUpdateGroup.CI_ID) {
                    throw "The SoftwareUpdateGroup object does not have a valid CI_ID property."
                }

                $groupQuery = "SELECT * FROM SMS_AuthorizationList WHERE CI_ID = $($SoftwareUpdateGroup.CI_ID)"
                Write-Verbose "Querying software update group by CI_ID: $groupQuery"
                $group = Get-CimInstance @cimParams -Query $groupQuery

                if (-not $group) {
                    throw "Software update group with CI_ID '$($SoftwareUpdateGroup.CI_ID)' not found."
                }
            }

            $groupName = $group.LocalizedDisplayName
            $groupId = $group.CI_ID
            Write-Verbose "Resolved software update group: '$groupName' (CI_ID: $groupId)"

            # Re-fetch the group instance to load lazy properties (Updates is a lazy property in SMS_AuthorizationList)
            Write-Verbose "Loading lazy properties for software update group CI_ID: $groupId"
            $group = $script:CMConnection.CimSession.GetInstance($namespace, $group)

            # Get the current Updates array (may be null for empty groups)
            $currentUpdates = @()
            if ($group.Updates) {
                $currentUpdates = @($group.Updates)
            }
            Write-Verbose "Current update count in group: $($currentUpdates.Count)"

            # ---- Resolve the software updates to add ----
            $newUpdateIds = @()

            if ($PSBoundParameters.ContainsKey('UpdateId')) {
                $newUpdateIds = $UpdateId
                Write-Verbose "Using provided UpdateId(s): $($newUpdateIds -join ', ')"
            }
            elseif ($PSBoundParameters.ContainsKey('SoftwareUpdate')) {
                foreach ($su in $SoftwareUpdate) {
                    if ($su.CI_ID) {
                        $newUpdateIds += [int]$su.CI_ID
                    } else {
                        Write-Warning "Software update object does not have a CI_ID property. Skipping."
                    }
                }
                Write-Verbose "Extracted CI_ID(s) from SoftwareUpdate objects: $($newUpdateIds -join ', ')"
            }
            elseif ($PSBoundParameters.ContainsKey('ArticleId')) {
                Write-Verbose "Resolving Article IDs to CI_IDs..."
                foreach ($article in $ArticleId) {
                    $updateQuery = "SELECT CI_ID, ArticleID, LocalizedDisplayName FROM SMS_SoftwareUpdate WHERE ArticleID = '$article'"
                    Write-Verbose "  Querying: $updateQuery"
                    $updates = @(Get-CimInstance @cimParams -Query $updateQuery)

                    if ($updates.Count -eq 0) {
                        Write-Warning "No software update found for Article ID '$article'. Skipping."
                    } else {
                        foreach ($update in $updates) {
                            $newUpdateIds += [int]$update.CI_ID
                            Write-Verbose "  Resolved Article '$article' -> CI_ID $($update.CI_ID) ($($update.LocalizedDisplayName))"
                        }
                    }
                }
            }
            elseif ($PSBoundParameters.ContainsKey('SoftwareUpdateName')) {
                $wqlName = $SoftwareUpdateName.Replace('*', '%').Replace('?', '_')
                if ($wqlName -like '*%*' -or $wqlName -like '*_*') {
                    $updateQuery = "SELECT CI_ID, ArticleID, LocalizedDisplayName FROM SMS_SoftwareUpdate WHERE LocalizedDisplayName LIKE '$wqlName'"
                } else {
                    $updateQuery = "SELECT CI_ID, ArticleID, LocalizedDisplayName FROM SMS_SoftwareUpdate WHERE LocalizedDisplayName = '$SoftwareUpdateName'"
                }
                Write-Verbose "Querying software updates by name: $updateQuery"
                $updates = @(Get-CimInstance @cimParams -Query $updateQuery)

                if ($updates.Count -eq 0) {
                    Write-Warning "No software updates found matching name '$SoftwareUpdateName'."
                } else {
                    foreach ($update in $updates) {
                        $newUpdateIds += [int]$update.CI_ID
                        Write-Verbose "  Resolved '$($update.LocalizedDisplayName)' -> CI_ID $($update.CI_ID)"
                    }
                }
            }

            if ($newUpdateIds.Count -eq 0) {
                Write-Warning "No software updates to add. Operation skipped."
                return
            }

            # ---- Merge updates (skip duplicates) ----
            $existingSet = [System.Collections.Generic.HashSet[int]]::new([int[]]$currentUpdates)
            $addedIds = @()
            $skippedIds = @()

            foreach ($id in $newUpdateIds) {
                if ($existingSet.Contains($id)) {
                    $skippedIds += $id
                } else {
                    $addedIds += $id
                    $null = $existingSet.Add($id)
                }
            }

            if ($skippedIds.Count -gt 0) {
                Write-Verbose "Skipping $($skippedIds.Count) update(s) already in group: $($skippedIds -join ', ')"
            }

            if ($addedIds.Count -eq 0) {
                Write-Verbose "All specified updates are already in the group. No changes needed."
                return
            }

            $mergedUpdates = [uint32[]]@($existingSet)
            $actionDescription = "Add $($addedIds.Count) software update(s) to group '$groupName' (CI_ID: $groupId)"
            Write-Verbose "$actionDescription"

            # ---- Apply the update ----
            if ($Force -or $PSCmdlet.ShouldProcess("SoftwareUpdateToGroup: LocalizedDisplayName=`"$groupName`"", "Add")) {
                Write-Verbose "Updating software update group '$groupName' with $($mergedUpdates.Count) total updates (was $($currentUpdates.Count))"

                # Directly set the Updates property via Set-CimInstance
                $group | Set-CimInstance -Property @{
                    Updates = $mergedUpdates
                }

                Write-Verbose "Successfully added $($addedIds.Count) update(s) to software update group '$groupName'"
                Write-Verbose "Added CI_IDs: $($addedIds -join ', ')"

                # ---- Retrieve the updated software update group object to return ----
                $resultQuery = "SELECT * FROM SMS_AuthorizationList WHERE CI_ID = $groupId"
                Write-Verbose "Retrieving updated software update group: $resultQuery"
                $result = Get-CimInstance @cimParams -Query $resultQuery

                if ($result) {
                    $output = [PSCustomObject]@{
                        PSTypeName                      = 'MECM7.SoftwareUpdateGroup'
                        CI_ID                           = [int]$result.CI_ID
                        CI_UniqueID                     = $result.CI_UniqueID
                        LocalizedDisplayName            = $result.LocalizedDisplayName
                        LocalizedDescription            = $result.LocalizedDescription
                        IsDeployed                      = [bool]$result.IsDeployed
                        IsExpired                       = [bool]$result.IsExpired
                        IsSuperseded                    = [bool]$result.IsSuperseded
                        NumberOfUpdates                 = [int]$result.NumberOfUpdates
                        DateCreated                     = $result.DateCreated
                        DateLastModified                = $result.DateLastModified
                        LocalizedCategoryInstanceNames  = $result.LocalizedCategoryInstanceNames
                    }

                    # Set the type name
                    $output.PSObject.TypeNames.Insert(0, 'MECM7.SoftwareUpdateGroup')

                    # Add all extra properties
                    $result.CimInstanceProperties | ForEach-Object {
                        if ($_.Name -notin $output.PSObject.Properties.Name) {
                            $output | Add-Member -MemberType NoteProperty -Name $_.Name -Value $_.Value -Force
                        }
                    }

                    Write-Output $output
                } else {
                    Write-Warning "Updates were added but could not retrieve the updated software update group. CI_ID: $groupId"
                }
            }
        }
        catch {
            throw $_
        }
    }
}
