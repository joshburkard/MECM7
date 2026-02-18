function Remove-CM7MaintenanceWindow {
    <#
        .SYNOPSIS
            Removes a maintenance window from a MECM collection using CIM.

        .DESCRIPTION
            Removes one or more maintenance windows (service windows) from a specified collection in
            Microsoft Endpoint Configuration Manager (MECM) using CIM. Maintenance windows
            define scheduled time periods during which deployments and other operations can
            be applied to collection members.

            This is the CIM-based equivalent of the Remove-CMMaintenanceWindow cmdlet from the
            ConfigurationManager PowerShell module but uses direct CIM queries over WinRM
            instead of requiring the ConfigMgr console or PowerShell drive.

            The function performs the following actions:
            1. Validates an active connection exists (established via Connect-CM7)
            2. Resolves the collection (by name or ID)
            3. Retrieves existing SMS_CollectionSettings and loads the ServiceWindows lazy property
            4. Finds the matching maintenance window(s) by exact name, wildcard pattern, or ServiceWindowID
            5. Removes the matching window(s) from the array
            6. Writes the updated settings back via CIM

        .PARAMETER CollectionName
            Specifies the name of the collection to remove the maintenance window from.
            Mutually exclusive with CollectionId.

        .PARAMETER CollectionId
            Specifies the CollectionID of the collection to remove the maintenance window from.
            Mutually exclusive with CollectionName.

        .PARAMETER MaintenanceWindowName
            Specifies the name of the maintenance window to remove. Supports wildcard characters (* and ?)
            to remove multiple maintenance windows matching a pattern.
            When used together with ServiceWindowID, both criteria must match.

        .PARAMETER ServiceWindowID
            Specifies the unique ServiceWindowID (GUID) of the maintenance window to remove.
            When used together with MaintenanceWindowName, both criteria must match.

        .PARAMETER Force
            Suppresses confirmation prompts.

        .PARAMETER WhatIf
            Shows what would happen if the cmdlet runs. The cmdlet is not run.

        .PARAMETER Confirm
            Prompts you for confirmation before running the cmdlet.

        .EXAMPLE
            Remove-CM7MaintenanceWindow -CollectionName "Test-Collection-Direct" -MaintenanceWindowName "Daily MW"
            Removes the maintenance window named "Daily MW" from the specified collection.

        .EXAMPLE
            Remove-CM7MaintenanceWindow -CollectionId "CM101C00" -MaintenanceWindowName "Weekly Updates" -Force
            Removes the maintenance window from the collection identified by its CollectionID without prompting for confirmation.

        .EXAMPLE
            Remove-CM7MaintenanceWindow -CollectionName "Test-Collection-Direct" -MaintenanceWindowName "Test-*"
            Removes all maintenance windows whose names match the wildcard pattern "Test-*".

        .EXAMPLE
            Remove-CM7MaintenanceWindow -CollectionName "Test-Collection-Direct" -ServiceWindowID "a1b2c3d4-e5f6-7890-abcd-ef1234567890" -Force
            Removes the maintenance window with the specified ServiceWindowID.

        .EXAMPLE
            Remove-CM7MaintenanceWindow -CollectionName "Test-Collection-Direct" -MaintenanceWindowName "Old MW" -WhatIf
            Shows what would happen without actually removing the maintenance window.

        .NOTES
            This function is the CIM-based equivalent of the Remove-CMMaintenanceWindow cmdlet
            from the ConfigurationManager PowerShell module but uses direct CIM queries
            over WinRM instead of requiring the ConfigMgr console or PowerShell drive.

            The ServiceWindows property of SMS_CollectionSettings is a lazy property,
            so the function retrieves the full instance to access it.

            If the maintenance window does not exist, a warning is written but no error is thrown.

            Maintenance Window Types (ServiceWindowType):
                1 = All Deployments (Any)
                4 = Software Updates Only
                5 = Task Sequences Only
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High', DefaultParameterSetName = 'ByCollectionName')]
    param(
        [Parameter(ParameterSetName = 'ByCollectionName', Mandatory = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$CollectionName,

        [Parameter(ParameterSetName = 'ByCollectionId', Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$CollectionId,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [SupportsWildcards()]
        [string]$MaintenanceWindowName,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$ServiceWindowID,

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

        # At least one identification parameter must be provided
        if (-not $PSBoundParameters.ContainsKey('MaintenanceWindowName') -and -not $PSBoundParameters.ContainsKey('ServiceWindowID')) {
            throw "You must specify at least one of -MaintenanceWindowName or -ServiceWindowID to identify the maintenance window(s) to remove."
        }

        # Determine the namespace
        $namespace = "root/SMS/site_$($script:CMConnection.SiteCode)"

        # Build common CIM parameters
        $cimParams = @{
            CimSession = $script:CMConnection.CimSession
            Namespace  = $namespace
        }

        # Reverse maps for output
        $serviceWindowTypeMap = @{
            1 = 'General'
            4 = 'SoftwareUpdatesOnly'
            5 = 'TaskSequencesOnly'
            6 = 'General'
        }

        $recurrenceTypeMap = @{
            1 = 'None'
            2 = 'Daily'
            3 = 'Weekly'
            4 = 'MonthlyByWeekday'
            5 = 'MonthlyByDate'
        }
    }

    process {
        try {
            # ---- Resolve Collection ----
            $collectionIdToUse = $null
            $collectionDisplayName = $null

            switch ($PSCmdlet.ParameterSetName) {
                'ByCollectionName' {
                    $collectionQuery = "SELECT CollectionID, Name FROM SMS_Collection WHERE Name = '$CollectionName'"
                    Write-Verbose "Resolving collection name: $collectionQuery"
                    $collection = Get-CimInstance @cimParams -Query $collectionQuery

                    if (-not $collection) {
                        throw "Collection '$CollectionName' not found."
                    }

                    if (@($collection).Count -gt 1) {
                        throw "Multiple collections found with name '$CollectionName'. Please use -CollectionId instead."
                    }

                    $collectionIdToUse = $collection.CollectionID
                    $collectionDisplayName = $CollectionName
                    Write-Verbose "Resolved collection '$CollectionName' to ID '$collectionIdToUse'"
                }
                'ByCollectionId' {
                    $collectionQuery = "SELECT CollectionID, Name FROM SMS_Collection WHERE CollectionID = '$CollectionId'"
                    Write-Verbose "Validating collection: $collectionQuery"
                    $collection = Get-CimInstance @cimParams -Query $collectionQuery

                    if (-not $collection) {
                        throw "Collection with ID '$CollectionId' not found."
                    }

                    $collectionIdToUse = $CollectionId
                    $collectionDisplayName = $collection.Name
                    Write-Verbose "Collection '$collectionDisplayName' ($CollectionId) validated."
                }
            }

            # ---- Retrieve SMS_CollectionSettings ----
            $settingsQuery = "SELECT * FROM SMS_CollectionSettings WHERE CollectionID = '$collectionIdToUse'"
            Write-Verbose "Querying collection settings: $settingsQuery"
            $settings = Get-CimInstance @cimParams -Query $settingsQuery

            if (-not $settings) {
                Write-Warning "No collection settings found for collection '$collectionDisplayName' ($collectionIdToUse). The collection has no maintenance windows."
                return
            }

            # Retrieve full instance to load lazy properties (ServiceWindows)
            Write-Verbose "Retrieving full instance to load lazy property ServiceWindows..."
            $fullSettings = $settings | Get-CimInstance

            if (-not $fullSettings) {
                throw "Could not retrieve full collection settings for CollectionID '$collectionIdToUse'."
            }

            # ---- Get existing service windows ----
            $existingWindows = @()
            if ($fullSettings.ServiceWindows) {
                $existingWindows = @($fullSettings.ServiceWindows)
            }

            if ($existingWindows.Count -eq 0) {
                Write-Warning "No maintenance windows found for collection '$collectionDisplayName' ($collectionIdToUse)."
                return
            }

            # ---- Find matching maintenance windows ----
            $matchingWindows = $existingWindows

            if ($PSBoundParameters.ContainsKey('MaintenanceWindowName')) {
                $isWildcard = $MaintenanceWindowName -match '[*?]'
                if ($isWildcard) {
                    $matchingWindows = @($matchingWindows | Where-Object { $_.Name -like $MaintenanceWindowName })
                } else {
                    $matchingWindows = @($matchingWindows | Where-Object { $_.Name -eq $MaintenanceWindowName })
                }
            }

            if ($PSBoundParameters.ContainsKey('ServiceWindowID')) {
                $matchingWindows = @($matchingWindows | Where-Object { $_.ServiceWindowID -eq $ServiceWindowID })
            }

            if ($matchingWindows.Count -eq 0) {
                $filterDesc = @()
                if ($PSBoundParameters.ContainsKey('MaintenanceWindowName')) { $filterDesc += "Name='$MaintenanceWindowName'" }
                if ($PSBoundParameters.ContainsKey('ServiceWindowID')) { $filterDesc += "ServiceWindowID='$ServiceWindowID'" }
                Write-Warning "No maintenance window matching ($($filterDesc -join ' AND ')) found on collection '$collectionDisplayName' ($collectionIdToUse)."
                return
            }

            Write-Verbose "Found $($matchingWindows.Count) maintenance window(s) matching the criteria."

            # ---- Capture match data before CIM modification ----
            # CIM embedded instances may become stale after modifying the parent
            # instance, so we store the data in plain PowerShell objects first.
            $removedWindowInfo = @($matchingWindows | ForEach-Object {
                $windowType = if ($serviceWindowTypeMap.ContainsKey([int]$_.ServiceWindowType)) {
                    $serviceWindowTypeMap[[int]$_.ServiceWindowType]
                } else { "Unknown ($($_.ServiceWindowType))" }

                $recurrence = if ($recurrenceTypeMap.ContainsKey([int]$_.RecurrenceType)) {
                    $recurrenceTypeMap[[int]$_.RecurrenceType]
                } else { "Unknown ($($_.RecurrenceType))" }

                @{
                    Name                   = [string]$_.Name
                    Description            = [string]$_.Description
                    ServiceWindowID        = [string]$_.ServiceWindowID
                    IsEnabled              = [bool]$_.IsEnabled
                    ServiceWindowType      = $windowType
                    StartTime              = $_.StartTime
                    Duration               = $_.Duration
                    RecurrenceType         = $recurrence
                    IsGMT                  = [bool]$_.IsGMT
                    ServiceWindowSchedules = [string]$_.ServiceWindowSchedules
                }
            })

            # ---- Build updated windows list (excluding matched ones) ----
            $matchingIDs = $removedWindowInfo | ForEach-Object { $_.ServiceWindowID }
            $updatedWindows = [System.Collections.Generic.List[CimInstance]]::new()

            foreach ($w in $existingWindows) {
                if ($w.ServiceWindowID -notin $matchingIDs) {
                    $updatedWindows.Add($w)
                }
            }

            # ---- ShouldProcess ----
            $windowNameDisplay = ($removedWindowInfo | ForEach-Object { $_.Name }) -join ', '
            $actionDescription = "Remove maintenance window(s) '$windowNameDisplay' from collection '$collectionDisplayName' ($collectionIdToUse)"

            if ($Force -or $PSCmdlet.ShouldProcess($actionDescription, "Remove-CM7MaintenanceWindow")) {

                # Modify the ServiceWindows property and commit
                Write-Verbose "Updating SMS_CollectionSettings for CollectionID '$collectionIdToUse'..."

                if ($updatedWindows.Count -eq 0) {
                    # All windows removed - set to empty array
                    $fullSettings.CimInstanceProperties['ServiceWindows'].Value = [CimInstance[]]@()
                } else {
                    $fullSettings.CimInstanceProperties['ServiceWindows'].Value = [CimInstance[]]$updatedWindows.ToArray()
                }

                $null = ($fullSettings | Set-CimInstance)

                Write-Verbose "Successfully removed maintenance window(s) '$windowNameDisplay' from collection '$collectionDisplayName' ($collectionIdToUse)."

                # Return info about removed maintenance windows using pre-captured data
                foreach ($info in $removedWindowInfo) {
                    [PSCustomObject]@{
                        PSTypeName             = 'MECM7.RemovedMaintenanceWindow'
                        Name                   = $info.Name
                        Description            = $info.Description
                        ServiceWindowID        = $info.ServiceWindowID
                        IsEnabled              = $info.IsEnabled
                        ServiceWindowType      = $info.ServiceWindowType
                        StartTime              = $info.StartTime
                        Duration               = $info.Duration
                        RecurrenceType         = $info.RecurrenceType
                        IsGMT                  = $info.IsGMT
                        ServiceWindowSchedules = $info.ServiceWindowSchedules
                        CollectionID           = $collectionIdToUse
                        Status                 = 'Removed'
                    }
                }
            }
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}
