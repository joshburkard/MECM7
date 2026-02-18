function Get-CM7MaintenanceWindow {
    <#
        .SYNOPSIS
            Retrieves maintenance windows from a MECM collection using CIM.

        .DESCRIPTION
            Queries the SMS_ServiceWindow WMI class via the SMS_CollectionSettings class
            to retrieve maintenance windows for a specified MECM collection.
            Maintenance windows define scheduled time periods during which deployments
            and other operations can be applied to collection members.
            Supports filtering by collection name, CollectionID, or maintenance window name.
            Requires an active connection established via Connect-CM7.

        .PARAMETER CollectionName
            Specifies the name of the collection to retrieve maintenance windows for.

        .PARAMETER CollectionId
            Specifies the CollectionID of the collection to retrieve maintenance windows for.

        .PARAMETER MaintenanceWindowName
            Specifies the name of the maintenance window to retrieve. Supports wildcard characters (*).
            If not specified, all maintenance windows for the collection are returned.

        .EXAMPLE
            Get-CM7MaintenanceWindow -CollectionName "Test-Collection-Direct"
            Retrieves all maintenance windows for the "Test-Collection-Direct" collection.

        .EXAMPLE
            Get-CM7MaintenanceWindow -CollectionId "SD101C00"
            Retrieves all maintenance windows for the collection with ID "SD101C00".

        .EXAMPLE
            Get-CM7MaintenanceWindow -CollectionName "Test-Collection-Direct" -MaintenanceWindowName "Daily MW"
            Retrieves the maintenance window named "Daily MW" from the "Test-Collection-Direct" collection.

        .EXAMPLE
            Get-CM7MaintenanceWindow -CollectionName "Test-Collection-Direct" -MaintenanceWindowName "Test-*"
            Retrieves all maintenance windows whose names start with "Test-" from the specified collection.

        .NOTES
            This function is the CIM-based equivalent of the Get-CMMaintenanceWindow cmdlet
            from the ConfigurationManager PowerShell module but uses direct CIM queries
            over WinRM instead of requiring the ConfigMgr console or PowerShell drive.

            The ServiceWindows property of SMS_CollectionSettings is a lazy property,
            so the function retrieves the full instance to access it.

            Maintenance Window Types (ServiceWindowType):
                1 = All Deployments
                4 = Software Updates
                5 = Task Sequences
                6 = All Deployments (alias)

            Recurrence Types:
                1 = None (one-time)
                2 = Daily
                3 = Weekly
                4 = Monthly by weekday
                5 = Monthly by date
    #>
    [CmdletBinding(DefaultParameterSetName = 'ByCollectionName')]
    param(
        [Parameter(ParameterSetName = 'ByCollectionName', Position = 0)]
        [string]$CollectionName,

        [Parameter(ParameterSetName = 'ByCollectionId', Mandatory = $true)]
        [string]$CollectionId,

        [Parameter()]
        [SupportsWildcards()]
        [string]$MaintenanceWindowName
    )

    $function = $($MyInvocation.MyCommand.Name)
    Write-Verbose "Running $function"

    # Validate connection
    if (-not $script:CMConnection.CimSession) {
        throw "Not connected to MECM. Please run Connect-CM7 first."
    }

    try {
        # Determine the namespace
        $namespace = "root/SMS/site_$($script:CMConnection.SiteCode)"

        # Build query parameters
        $queryParams = @{
            CimSession = $script:CMConnection.CimSession
            Namespace  = $namespace
        }

        # Determine which collection identifier to use
        $collectionIdToUse = $null

        if ($PSCmdlet.ParameterSetName -eq 'ByCollectionName') {
            if (-not $CollectionName) {
                throw "CollectionName must be provided when using the ByCollectionName parameter set."
            }
            # Resolve collection name to ID
            $collectionQuery = "SELECT CollectionID FROM SMS_Collection WHERE Name = '$CollectionName'"
            Write-Verbose "Resolving collection name to ID: $collectionQuery"

            $collection = Get-CimInstance @queryParams -Query $collectionQuery
            if (-not $collection) {
                Write-Verbose "Collection '$CollectionName' not found."
                return
            }
            $collectionIdToUse = $collection.CollectionID
        } else {
            $collectionIdToUse = $CollectionId
        }

        Write-Verbose "Using CollectionID: $collectionIdToUse"

        # Query SMS_CollectionSettings for the collection
        $settingsQuery = "SELECT * FROM SMS_CollectionSettings WHERE CollectionID = '$collectionIdToUse'"
        Write-Verbose "Executing query: $settingsQuery"

        $settings = Get-CimInstance @queryParams -Query $settingsQuery

        if (-not $settings) {
            Write-Verbose "No collection settings found for CollectionID '$collectionIdToUse'. The collection may have no maintenance windows defined."
            return
        }

        # ServiceWindows is a lazy property - re-retrieve the instance using
        # Get-CimInstance -InputObject to force loading all lazy properties
        Write-Verbose "Retrieving full instance to load lazy property ServiceWindows..."
        $fullSettings = $settings | Get-CimInstance

        if (-not $fullSettings) {
            Write-Verbose "Could not retrieve full collection settings for CollectionID '$collectionIdToUse'."
            return
        }

        # Access the ServiceWindows property
        $serviceWindows = $fullSettings.ServiceWindows

        if (-not $serviceWindows -or $serviceWindows.Count -eq 0) {
            Write-Verbose "No maintenance windows found for CollectionID '$collectionIdToUse'."
            return
        }

        # Filter by maintenance window name if specified
        if ($MaintenanceWindowName) {
            if ($MaintenanceWindowName -match '[*?]') {
                # Wildcard filter
                $serviceWindows = $serviceWindows | Where-Object { $_.Name -like $MaintenanceWindowName }
            } else {
                # Exact match
                $serviceWindows = $serviceWindows | Where-Object { $_.Name -eq $MaintenanceWindowName }
            }
        }

        if (-not $serviceWindows) {
            Write-Verbose "No maintenance windows matching the filter were found."
            return
        }

        # Map ServiceWindowType to friendly names
        $serviceWindowTypeMap = @{
            1 = 'General'
            4 = 'SoftwareUpdatesOnly'
            5 = 'TaskSequencesOnly'
            6 = 'General'
        }

        # Map RecurrenceType to friendly names
        $recurrenceTypeMap = @{
            1 = 'None'
            2 = 'Daily'
            3 = 'Weekly'
            4 = 'MonthlyByWeekday'
            5 = 'MonthlyByDate'
        }

        # Output results
        foreach ($window in $serviceWindows) {
            $windowType = if ($serviceWindowTypeMap.ContainsKey([int]$window.ServiceWindowType)) {
                $serviceWindowTypeMap[[int]$window.ServiceWindowType]
            } else {
                "Unknown ($($window.ServiceWindowType))"
            }

            $recurrence = if ($recurrenceTypeMap.ContainsKey([int]$window.RecurrenceType)) {
                $recurrenceTypeMap[[int]$window.RecurrenceType]
            } else {
                "Unknown ($($window.RecurrenceType))"
            }

            # Parse duration from the schedule string
            $duration = $window.Duration
            $durationMinutes = $null
            if ($duration) {
                # Duration is stored in minutes
                $durationMinutes = $duration
            }

            [PSCustomObject]@{
                PSTypeName          = 'MECM7.MaintenanceWindow'
                Name                = $window.Name
                Description         = $window.Description
                ServiceWindowID     = $window.ServiceWindowID
                IsEnabled           = $window.IsEnabled
                ServiceWindowType   = $windowType
                StartTime           = $window.StartTime
                Duration            = $durationMinutes
                RecurrenceType      = $recurrence
                IsGMT               = $window.IsGMT
                ServiceWindowSchedules = $window.ServiceWindowSchedules
                CollectionID        = $collectionIdToUse
            }
        }
    }
    catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
}
