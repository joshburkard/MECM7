function New-CM7SoftwareUpdateGroup {
    <#
        .SYNOPSIS
            Creates a new software update group in MECM using CIM.

        .DESCRIPTION
            Creates a new software update group (SMS_AuthorizationList) in Microsoft Endpoint
            Configuration Manager (MECM) using CIM. A software update group is a container for
            software updates that can be deployed to collections.

            This is the CIM-based equivalent of the New-CMSoftwareUpdateGroup cmdlet from the
            ConfigurationManager PowerShell module, but uses direct CIM queries over WinRM
            instead of requiring the ConfigMgr console or PowerShell drive.

            The function performs the following actions:
            1. Validates an active connection exists (established via Connect-CM7)
            2. Optionally checks for duplicate software update group names
            3. Resolves software update CI_IDs from Article IDs if provided
            4. Creates a new SMS_AuthorizationList instance via CIM
            5. Returns the created software update group as a formatted MECM7.SoftwareUpdateGroup object

        .PARAMETER Name
            The name of the new software update group (LocalizedDisplayName).
            Must be unique within the MECM environment.

        .PARAMETER Description
            An optional description for the software update group (LocalizedDescription).

        .PARAMETER UpdateId
            An array of software update CI_IDs (integers) to include in the group.
            These correspond to the CI_ID property of SMS_SoftwareUpdate instances.
            Mutually exclusive with SoftwareUpdateId.

        .PARAMETER SoftwareUpdateId
            An array of software update CI_IDs (integers) to include in the group.
            Alias for UpdateId for compatibility with New-CMSoftwareUpdateGroup syntax.
            Mutually exclusive with UpdateId.

        .PARAMETER ArticleId
            An array of software update Article IDs (KB numbers, e.g. "5041578") to include in the group.
            The function resolves these to CI_IDs by querying SMS_SoftwareUpdate.
            Mutually exclusive with UpdateId and SoftwareUpdateId.

        .PARAMETER Force
            Suppresses confirmation prompts.

        .PARAMETER WhatIf
            Shows what would happen if the cmdlet runs. The cmdlet is not run.

        .PARAMETER Confirm
            Prompts you for confirmation before running the cmdlet.

        .EXAMPLE
            New-CM7SoftwareUpdateGroup -Name "SO Servers-SecurityPatches-Test" -Description "Test group for security patches"
            Creates an empty software update group with the specified name and description.

        .EXAMPLE
            New-CM7SoftwareUpdateGroup -Name "Patching-2026-02" -UpdateId @(16788010, 16788011)
            Creates a software update group containing the specified software updates by their CI_IDs.

        .EXAMPLE
            New-CM7SoftwareUpdateGroup -Name "KB Patches" -ArticleId @("5041578", "5041580") -Force
            Creates a software update group containing updates resolved from Article IDs (KB numbers).

        .EXAMPLE
            $updates = Get-CM7SoftwareUpdate -Name "*Cumulative*" | Select-Object -ExpandProperty CI_ID
            New-CM7SoftwareUpdateGroup -Name "Cumulative Updates" -UpdateId $updates -Force
            Creates a software update group from updates retrieved via Get-CM7SoftwareUpdate.

        .EXAMPLE
            New-CM7SoftwareUpdateGroup -Name "Test Group" -WhatIf
            Shows what would happen without actually creating the software update group.

        .NOTES
            Requires an active connection established via Connect-CM7.

            The SMS_AuthorizationList WMI class is used to represent software update groups in MECM.
            The Updates property contains an array of CI_IDs referencing SMS_SoftwareUpdate instances.

            This function is the CIM-based equivalent of the New-CMSoftwareUpdateGroup cmdlet
            from the ConfigurationManager PowerShell module but uses direct CIM queries
            over WinRM instead of requiring the ConfigMgr console or PowerShell drive.
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium', DefaultParameterSetName = 'ByUpdateId')]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [Parameter()]
        [string]$Description = '',

        [Parameter(ParameterSetName = 'ByUpdateId')]
        [ValidateNotNullOrEmpty()]
        [int[]]$UpdateId,

        [Parameter(ParameterSetName = 'BySoftwareUpdateId')]
        [ValidateNotNullOrEmpty()]
        [Alias('SoftwareUpdateId')]
        [int[]]$SoftwareUpdateIds,

        [Parameter(ParameterSetName = 'ByArticleId')]
        [ValidateNotNullOrEmpty()]
        [string[]]$ArticleId,

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
            # ---- Check for duplicate software update group name ----
            $existingQuery = "SELECT CI_ID, LocalizedDisplayName FROM SMS_AuthorizationList WHERE LocalizedDisplayName = '$Name'"
            Write-Verbose "Checking for existing software update group: $existingQuery"
            $existingGroup = Get-CimInstance @cimParams -Query $existingQuery

            if ($existingGroup) {
                throw "A software update group with name '$Name' already exists (CI_ID: $($existingGroup.CI_ID))."
            }

            # ---- Resolve update CI_IDs ----
            $resolvedUpdateIds = @()

            switch ($PSCmdlet.ParameterSetName) {
                'ByUpdateId' {
                    if ($UpdateId) {
                        $resolvedUpdateIds = $UpdateId
                        Write-Verbose "Using provided UpdateId(s): $($resolvedUpdateIds -join ', ')"
                    }
                }
                'BySoftwareUpdateId' {
                    if ($SoftwareUpdateIds) {
                        $resolvedUpdateIds = $SoftwareUpdateIds
                        Write-Verbose "Using provided SoftwareUpdateId(s): $($resolvedUpdateIds -join ', ')"
                    }
                }
                'ByArticleId' {
                    if ($ArticleId) {
                        Write-Verbose "Resolving Article IDs to CI_IDs..."
                        foreach ($article in $ArticleId) {
                            $updateQuery = "SELECT CI_ID, ArticleID, LocalizedDisplayName FROM SMS_SoftwareUpdate WHERE ArticleID = '$article'"
                            Write-Verbose "  Querying: $updateQuery"
                            $updates = @(Get-CimInstance @cimParams -Query $updateQuery)

                            if ($updates.Count -eq 0) {
                                Write-Warning "No software update found for Article ID '$article'. Skipping."
                            } else {
                                foreach ($update in $updates) {
                                    $resolvedUpdateIds += [int]$update.CI_ID
                                    Write-Verbose "  Resolved Article '$article' -> CI_ID $($update.CI_ID) ($($update.LocalizedDisplayName))"
                                }
                            }
                        }
                    }
                }
            }

            # ---- Create the software update group ----
            $updateCount = $resolvedUpdateIds.Count
            $actionDescription = "Create software update group '$Name' with $updateCount update(s)"
            if ($Force -or $PSCmdlet.ShouldProcess($Name, $actionDescription)) {
                Write-Verbose "Creating software update group: $actionDescription"

                # Build the SMS_CI_LocalizedProperties embedded instance
                # SMS_AuthorizationList requires name/description via LocalizedInformation
                $localizedClass = Get-CimClass @cimParams -ClassName 'SMS_CI_LocalizedProperties'
                $localizedInstance = New-CimInstance -CimClass $localizedClass -ClientOnly -Property @{
                    DisplayName    = $Name
                    Description    = if ($Description) { $Description } else { '' }
                    LocaleID       = [uint32]0
                    InformativeURL = ''
                }

                # Build the properties for the new software update group
                $groupProperties = @{
                    LocalizedInformation = [CimInstance[]]@($localizedInstance)
                }

                if ($resolvedUpdateIds.Count -gt 0) {
                    $groupProperties['Updates'] = [int32[]]$resolvedUpdateIds
                }

                Write-Verbose "Software update group properties: Name='$Name', Description='$Description', Updates=$updateCount"

                # Create the software update group using New-CimInstance
                $newGroup = New-CimInstance @cimParams -ClassName 'SMS_AuthorizationList' -Property $groupProperties

                if (-not $newGroup) {
                    throw "Failed to create software update group '$Name'. New-CimInstance returned null."
                }

                $groupId = $newGroup.CI_ID
                Write-Verbose "Software update group '$Name' created successfully with CI_ID: $groupId"

                # ---- Retrieve the full software update group object to return ----
                $resultQuery = "SELECT * FROM SMS_AuthorizationList WHERE CI_ID = $groupId"
                Write-Verbose "Retrieving created software update group: $resultQuery"
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
                    Write-Warning "Software update group was created but could not retrieve the result. CI_ID: $groupId"
                }
            }
        }
        catch {
            throw $_
        }
    }
}
