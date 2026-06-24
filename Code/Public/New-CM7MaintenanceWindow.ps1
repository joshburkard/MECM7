function New-CM7MaintenanceWindow {
    <#
        .SYNOPSIS
            Creates a new maintenance window on a MECM collection using CIM.

        .DESCRIPTION
            Creates a new maintenance window (service window) on a specified collection in
            Microsoft Endpoint Configuration Manager (MECM) using CIM. Maintenance windows
            define scheduled time periods during which deployments and other operations can
            be applied to collection members.

            This is the CIM-based equivalent of the New-CMMaintenanceWindow cmdlet from the
            ConfigurationManager PowerShell module but uses direct CIM queries over WinRM
            instead of requiring the ConfigMgr console or PowerShell drive.

            The function performs the following actions:
            1. Validates an active connection exists (established via Connect-CM7)
            2. Resolves the collection (by name or ID)
            3. Builds a schedule token using SMS_ScheduleMethods::WriteToString
            4. Retrieves existing SMS_CollectionSettings (or creates new settings if none exist)
            5. Creates and appends the SMS_ServiceWindow embedded instance
            6. Writes the updated settings back via CIM

            Supports multiple recurrence types:
            - None (one-time window)
            - Daily (every N days)
            - Weekly (every N weeks on a specific day)
            - MonthlyByWeekday (e.g., 2nd Tuesday of every N months)
            - MonthlyByDate (e.g., 15th of every N months)

            Alternatively, a raw schedule token string can be provided for advanced scenarios.

        .PARAMETER CollectionName
            Specifies the name of the collection to add the maintenance window to.
            Mutually exclusive with CollectionId.

        .PARAMETER CollectionId
            Specifies the CollectionID of the collection to add the maintenance window to.
            Mutually exclusive with CollectionName.

        .PARAMETER Name
            Specifies the name of the maintenance window. This name is displayed in the
            MECM console and used to identify the window.

        .PARAMETER Description
            Specifies an optional description for the maintenance window. Defaults to an empty string.

        .PARAMETER StartTime
            Specifies the start date and time of the maintenance window. For recurring windows,
            this is the start time of the first occurrence.

        .PARAMETER DurationMinutes
            Specifies the duration of the maintenance window in minutes.
            Valid range: 1 to 43200 (30 days).

        .PARAMETER RecurrenceType
            Specifies the recurrence type for the maintenance window.
            Valid values: None, Daily, Weekly, MonthlyByWeekday, MonthlyByDate.
            Defaults to 'None' (one-time window).

        .PARAMETER DaySpan
            Specifies the interval in days for a Daily recurrence. For example, DaySpan=2 means
            every other day. Valid range: 1 to 31. Defaults to 1.
            Only used when RecurrenceType is 'Daily'.

        .PARAMETER DayOfWeek
            Specifies the day of the week for Weekly and MonthlyByWeekday recurrences.
            Valid values: Sunday, Monday, Tuesday, Wednesday, Thursday, Friday, Saturday.
            Required when RecurrenceType is 'Weekly' or 'MonthlyByWeekday'.

        .PARAMETER ForNumberOfWeeks
            Specifies the weekly recurrence interval. For example, ForNumberOfWeeks=2 means
            every other week. Valid range: 1 to 4. Defaults to 1.
            Only used when RecurrenceType is 'Weekly'.

        .PARAMETER WeekOrder
            Specifies which week of the month for MonthlyByWeekday recurrence.
            Valid values: First, Second, Third, Fourth, Last.
            Defaults to 'First'. Only used when RecurrenceType is 'MonthlyByWeekday'.

        .PARAMETER MonthDay
            Specifies the day of the month for MonthlyByDate recurrence.
            Valid range: 0 to 31. Use 0 for the last day of the month.
            Required when RecurrenceType is 'MonthlyByDate'.

        .PARAMETER ForNumberOfMonths
            Specifies the monthly recurrence interval. For example, ForNumberOfMonths=2 means
            every other month. Valid range: 1 to 12. Defaults to 1.
            Only used when RecurrenceType is 'MonthlyByWeekday' or 'MonthlyByDate'.

        .PARAMETER Schedule
            Specifies a raw SMS schedule token string. Use this parameter for advanced scenarios
            where you have a pre-built schedule token (e.g., copied from an existing maintenance
            window's ServiceWindowSchedules property). Mutually exclusive with StartTime,
            DurationMinutes, and RecurrenceType parameters.

        .PARAMETER ApplyTo
            Specifies the type of maintenance window. Determines which deployments can run
            during this window.
            Valid values:
            - Any: All deployments (general maintenance window)
            - SoftwareUpdatesOnly: Only software update deployments
            - TaskSequencesOnly: Only task sequence deployments
            Defaults to 'Any'.

        .PARAMETER IsEnabled
            Specifies whether the maintenance window is enabled. Defaults to $true.
            Set to $false to create a disabled maintenance window.

        .PARAMETER IsUtc
            Specifies that the maintenance window schedule uses UTC time.
            When not specified, the schedule uses local time of the site server.

        .PARAMETER Force
            Suppresses confirmation prompts.

        .PARAMETER WhatIf
            Shows what would happen if the cmdlet runs. The cmdlet is not run.

        .PARAMETER Confirm
            Prompts you for confirmation before running the cmdlet.

        .EXAMPLE
            New-CM7MaintenanceWindow -CollectionName "Test-Collection-Direct" -Name "Daily MW" -StartTime "2026-02-20 22:00" -DurationMinutes 60 -RecurrenceType Daily -Force
            Creates a daily maintenance window starting at 10 PM, lasting 1 hour.

        .EXAMPLE
            New-CM7MaintenanceWindow -CollectionId "CM101C00" -Name "Weekly Updates" -StartTime "2026-02-21 02:00" -DurationMinutes 120 -RecurrenceType Weekly -DayOfWeek Saturday -ApplyTo SoftwareUpdatesOnly -Force
            Creates a weekly maintenance window for software updates only, every Saturday at 2 AM for 2 hours.

        .EXAMPLE
            New-CM7MaintenanceWindow -CollectionName "Servers" -Name "Monthly Patch Window" -StartTime "2026-03-01 01:00" -DurationMinutes 240 -RecurrenceType MonthlyByWeekday -DayOfWeek Tuesday -WeekOrder Second -ApplyTo SoftwareUpdatesOnly -Force
            Creates a monthly maintenance window on the second Tuesday of each month at 1 AM for 4 hours.

        .EXAMPLE
            New-CM7MaintenanceWindow -CollectionName "Test-Collection-Direct" -Name "One-Time MW" -StartTime "2026-03-15 23:00" -DurationMinutes 30 -RecurrenceType None -Force
            Creates a one-time maintenance window on March 15 at 11 PM for 30 minutes.

        .EXAMPLE
            New-CM7MaintenanceWindow -CollectionName "Test-Collection-Direct" -Name "Disabled MW" -StartTime "2026-02-20 22:00" -DurationMinutes 60 -RecurrenceType Daily -IsEnabled $false -Force
            Creates a disabled daily maintenance window. It can be enabled later.

        .EXAMPLE
            $existingMW = Get-CM7MaintenanceWindow -CollectionName "Source-Collection" -MaintenanceWindowName "Existing MW"
            New-CM7MaintenanceWindow -CollectionName "Target-Collection" -Name "Copied MW" -Schedule $existingMW.ServiceWindowSchedules -Force
            Copies a maintenance window schedule from one collection to another using the raw schedule token.

        .EXAMPLE
            New-CM7MaintenanceWindow -CollectionName "Test-Collection-Direct" -Name "UTC MW" -StartTime "2026-02-20 22:00" -DurationMinutes 60 -RecurrenceType None -IsUtc -Force
            Creates a maintenance window using UTC time instead of local time.

        .NOTES
            This function is the CIM-based equivalent of the New-CMMaintenanceWindow cmdlet
            from the ConfigurationManager PowerShell module but uses direct CIM queries
            over WinRM instead of requiring the ConfigMgr console or PowerShell drive.

            The function builds SMS schedule tokens using the SMS_ScheduleMethods::WriteToString
            WMI method, which is the same method used internally by MECM. This ensures proper
            encoding of schedule information including start time, duration, and recurrence.

            Schedule Token Classes Used:
                SMS_ST_NonRecurring         - One-time schedules
                SMS_ST_RecurInterval        - Daily recurring schedules
                SMS_ST_RecurWeekly          - Weekly recurring schedules
                SMS_ST_RecurMonthlyByWeekday - Monthly by weekday schedules
                SMS_ST_RecurMonthlyByDate    - Monthly by date schedules

            Maintenance Window Types (ServiceWindowType):
                1 = All Deployments (Any)
                4 = Software Updates Only
                5 = Task Sequences Only
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium', DefaultParameterSetName = 'ByCollectionName')]
    param(
        [Parameter(ParameterSetName = 'ByCollectionName', Mandatory = $true, Position = 0)]
        [Parameter(ParameterSetName = 'ByCollectionNameScheduleToken', Mandatory = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$CollectionName,

        [Parameter(ParameterSetName = 'ByCollectionId', Mandatory = $true)]
        [Parameter(ParameterSetName = 'ByCollectionIdScheduleToken', Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$CollectionId,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [Parameter()]
        [string]$Description = '',

        # Schedule parameters (for building schedule tokens)
        [Parameter(ParameterSetName = 'ByCollectionName', Mandatory = $true)]
        [Parameter(ParameterSetName = 'ByCollectionId', Mandatory = $true)]
        [datetime]$StartTime,

        [Parameter(ParameterSetName = 'ByCollectionName', Mandatory = $true)]
        [Parameter(ParameterSetName = 'ByCollectionId', Mandatory = $true)]
        [ValidateRange(1, 43200)]
        [int]$DurationMinutes,

        [Parameter(ParameterSetName = 'ByCollectionName')]
        [Parameter(ParameterSetName = 'ByCollectionId')]
        [ValidateSet('None', 'Daily', 'Weekly', 'MonthlyByWeekday', 'MonthlyByDate')]
        [string]$RecurrenceType = 'None',

        [Parameter(ParameterSetName = 'ByCollectionName')]
        [Parameter(ParameterSetName = 'ByCollectionId')]
        [ValidateRange(1, 31)]
        [int]$DaySpan = 1,

        [Parameter(ParameterSetName = 'ByCollectionName')]
        [Parameter(ParameterSetName = 'ByCollectionId')]
        [ValidateSet('Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday')]
        [string]$DayOfWeek,

        [Parameter(ParameterSetName = 'ByCollectionName')]
        [Parameter(ParameterSetName = 'ByCollectionId')]
        [ValidateRange(1, 4)]
        [int]$ForNumberOfWeeks = 1,

        [Parameter(ParameterSetName = 'ByCollectionName')]
        [Parameter(ParameterSetName = 'ByCollectionId')]
        [ValidateSet('First', 'Second', 'Third', 'Fourth', 'Last')]
        [string]$WeekOrder = 'First',

        [Parameter(ParameterSetName = 'ByCollectionName')]
        [Parameter(ParameterSetName = 'ByCollectionId')]
        [ValidateRange(0, 31)]
        [int]$MonthDay,

        [Parameter(ParameterSetName = 'ByCollectionName')]
        [Parameter(ParameterSetName = 'ByCollectionId')]
        [ValidateRange(1, 12)]
        [int]$ForNumberOfMonths = 1,

        # Raw schedule token or schedule object from New-CM7Schedule (alternative to building schedule)
        [Parameter(ParameterSetName = 'ByCollectionNameScheduleToken', Mandatory = $true)]
        [Parameter(ParameterSetName = 'ByCollectionIdScheduleToken', Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [object]$Schedule,

        [Parameter()]
        [ValidateSet('Any', 'SoftwareUpdatesOnly', 'TaskSequencesOnly')]
        [string]$ApplyTo = 'Any',

        [Parameter()]
        [boolean]$IsEnabled = $true,

        [Parameter()]
        [switch]$IsUtc,

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

        # Map ApplyTo to ServiceWindowType integer
        $serviceWindowTypeMap = @{
            'Any'                 = [uint32]1
            'SoftwareUpdatesOnly' = [uint32]4
            'TaskSequencesOnly'   = [uint32]5
        }

        # Map DayOfWeek to bitmask values used by SMS schedule classes
        $dayOfWeekMap = @{
            'Sunday'    = [uint32]1
            'Monday'    = [uint32]2
            'Tuesday'   = [uint32]4
            'Wednesday' = [uint32]8
            'Thursday'  = [uint32]16
            'Friday'    = [uint32]32
            'Saturday'  = [uint32]64
        }

        # Map WeekOrder to SMS integer values
        $weekOrderMap = @{
            'Last'   = [uint32]0
            'First'  = [uint32]1
            'Second' = [uint32]2
            'Third'  = [uint32]3
            'Fourth' = [uint32]4
        }

        # Reverse maps for output
        $serviceWindowTypeMapReverse = @{
            1 = 'General'
            4 = 'SoftwareUpdatesOnly'
            5 = 'TaskSequencesOnly'
            6 = 'General'
        }

        $recurrenceTypeMapReverse = @{
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

            switch -Wildcard ($PSCmdlet.ParameterSetName) {
                'ByCollectionName*' {
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
                'ByCollectionId*' {
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

            # ---- Build or use schedule token ----
            $scheduleString = $null

            if ($PSCmdlet.ParameterSetName -like '*ScheduleToken') {
                # Extract the schedule token string from object or use string directly
                if ($Schedule -is [string]) {
                    $scheduleString = $Schedule
                }
                elseif ($null -ne $Schedule.ScheduleString) {
                    $scheduleString = $Schedule.ScheduleString
                    # Inherit IsGMT from the schedule object when -IsUtc is not explicitly specified
                    if (-not $PSBoundParameters.ContainsKey('IsUtc') -and $null -ne $Schedule.IsGMT) {
                        $IsUtc = [switch]([bool]$Schedule.IsGMT)
                    }
                }
                else {
                    throw "The -Schedule parameter must be a schedule token string or an object with a ScheduleString property (e.g., from New-CM7Schedule)."
                }
                Write-Verbose "Using provided schedule token: $scheduleString"
            }
            else {
                # Validate recurrence-specific parameters
                if ($RecurrenceType -eq 'Weekly' -and -not $DayOfWeek) {
                    throw "The -DayOfWeek parameter is required when RecurrenceType is 'Weekly'."
                }
                if ($RecurrenceType -eq 'MonthlyByWeekday' -and -not $DayOfWeek) {
                    throw "The -DayOfWeek parameter is required when RecurrenceType is 'MonthlyByWeekday'."
                }
                if ($RecurrenceType -eq 'MonthlyByDate' -and -not $PSBoundParameters.ContainsKey('MonthDay')) {
                    throw "The -MonthDay parameter is required when RecurrenceType is 'MonthlyByDate'."
                }

                # Calculate duration components from total minutes
                $dayDuration = [uint32][Math]::Floor($DurationMinutes / 1440)
                $hourDuration = [uint32][Math]::Floor(($DurationMinutes % 1440) / 60)
                $minuteDuration = [uint32]($DurationMinutes % 60)

                # CIM cmdlets expect DateTime objects for StartTime properties.
                # The CIM layer handles DMTF datetime conversion internally.
                $startTimeFormatted = $StartTime

                Write-Verbose "Schedule: StartTime=$($StartTime.ToString('yyyy-MM-dd HH:mm:ss')), Duration=${dayDuration}d ${hourDuration}h ${minuteDuration}m, Recurrence=$RecurrenceType"

                # Build the schedule token instance based on recurrence type
                $scheduleToken = $null

                switch ($RecurrenceType) {
                    'None' {
                        $scheduleClass = Get-CimClass @cimParams -ClassName 'SMS_ST_NonRecurring'
                        $scheduleToken = New-CimInstance -CimClass $scheduleClass -ClientOnly -Property @{
                            StartTime      = $startTimeFormatted
                            DayDuration    = $dayDuration
                            HourDuration   = $hourDuration
                            MinuteDuration = $minuteDuration
                            IsGMT          = [bool]$IsUtc.IsPresent
                        }
                    }
                    'Daily' {
                        $scheduleClass = Get-CimClass @cimParams -ClassName 'SMS_ST_RecurInterval'
                        $scheduleToken = New-CimInstance -CimClass $scheduleClass -ClientOnly -Property @{
                            StartTime      = $startTimeFormatted
                            DayDuration    = $dayDuration
                            HourDuration   = $hourDuration
                            MinuteDuration = $minuteDuration
                            IsGMT          = [bool]$IsUtc.IsPresent
                            DaySpan        = [uint32]$DaySpan
                            HourSpan       = [uint32]0
                            MinuteSpan     = [uint32]0
                        }
                    }
                    'Weekly' {
                        $scheduleClass = Get-CimClass @cimParams -ClassName 'SMS_ST_RecurWeekly'
                        $scheduleToken = New-CimInstance -CimClass $scheduleClass -ClientOnly -Property @{
                            StartTime        = $startTimeFormatted
                            DayDuration      = $dayDuration
                            HourDuration     = $hourDuration
                            MinuteDuration   = $minuteDuration
                            IsGMT            = [bool]$IsUtc.IsPresent
                            Day              = $dayOfWeekMap[$DayOfWeek]
                            ForNumberOfWeeks = [uint32]$ForNumberOfWeeks
                        }
                    }
                    'MonthlyByWeekday' {
                        $scheduleClass = Get-CimClass @cimParams -ClassName 'SMS_ST_RecurMonthlyByWeekday'
                        $scheduleToken = New-CimInstance -CimClass $scheduleClass -ClientOnly -Property @{
                            StartTime         = $startTimeFormatted
                            DayDuration       = $dayDuration
                            HourDuration      = $hourDuration
                            MinuteDuration    = $minuteDuration
                            IsGMT             = [bool]$IsUtc.IsPresent
                            Day               = $dayOfWeekMap[$DayOfWeek]
                            WeekOrder         = $weekOrderMap[$WeekOrder]
                            ForNumberOfMonths = [uint32]$ForNumberOfMonths
                        }
                    }
                    'MonthlyByDate' {
                        $scheduleClass = Get-CimClass @cimParams -ClassName 'SMS_ST_RecurMonthlyByDate'
                        $scheduleToken = New-CimInstance -CimClass $scheduleClass -ClientOnly -Property @{
                            StartTime         = $startTimeFormatted
                            DayDuration       = $dayDuration
                            HourDuration      = $hourDuration
                            MinuteDuration    = $minuteDuration
                            IsGMT             = [bool]$IsUtc.IsPresent
                            MonthDay          = [uint32]$MonthDay
                            ForNumberOfMonths = [uint32]$ForNumberOfMonths
                        }
                    }
                }

                # Convert schedule token to string using SMS_ScheduleMethods
                # Note: Explicitly pass -WhatIf:$false because WriteToString is a read-only
                # operation and must always execute, even when the caller uses -WhatIf.
                Write-Verbose "Converting schedule token to string via SMS_ScheduleMethods::WriteToString..."
                $writeResult = Invoke-CimMethod @cimParams -ClassName 'SMS_ScheduleMethods' -MethodName 'WriteToString' -Arguments @{
                    TokenData = [CimInstance[]]@($scheduleToken)
                } -WhatIf:$false -Confirm:$false

                if (-not $writeResult -or $writeResult.ReturnValue -ne 0) {
                    throw "SMS_ScheduleMethods::WriteToString failed with return value $($writeResult.ReturnValue)."
                }

                $scheduleString = $writeResult.StringData
                Write-Verbose "Generated schedule token: $scheduleString"
            }

            # ---- Retrieve or Create SMS_CollectionSettings ----
            $settingsQuery = "SELECT * FROM SMS_CollectionSettings WHERE CollectionID = '$collectionIdToUse'"
            Write-Verbose "Querying collection settings: $settingsQuery"
            $settings = Get-CimInstance @cimParams -Query $settingsQuery

            $isNewSettings = $false

            if ($settings) {
                # Retrieve full instance to load lazy properties (ServiceWindows)
                Write-Verbose "Retrieving full instance to load lazy property ServiceWindows..."
                $fullSettings = $settings | Get-CimInstance

                if (-not $fullSettings) {
                    throw "Could not retrieve full collection settings for CollectionID '$collectionIdToUse'."
                }
            }
            else {
                Write-Verbose "No existing SMS_CollectionSettings found for CollectionID '$collectionIdToUse'. Will create new settings."
                $isNewSettings = $true
                $fullSettings = $null
            }

            # ---- Get existing service windows ----
            $existingWindows = @()
            if ($fullSettings -and $fullSettings.ServiceWindows) {
                $existingWindows = @($fullSettings.ServiceWindows)
            }

            # ---- Check for duplicate name (warn but don't block) ----
            $duplicateWindow = $existingWindows | Where-Object { $_.Name -eq $Name }
            if ($duplicateWindow) {
                Write-Warning "A maintenance window named '$Name' already exists on collection '$collectionDisplayName' ($collectionIdToUse). A new window with the same name will be created."
            }

            # ---- Build new service window ----
            Write-Verbose "Creating new SMS_ServiceWindow: Name='$Name', Type=$ApplyTo, Enabled=$IsEnabled"
            $serviceWindowClass = Get-CimClass @cimParams -ClassName 'SMS_ServiceWindow'
            $newWindow = New-CimInstance -CimClass $serviceWindowClass -ClientOnly -Property @{
                Name                   = $Name
                Description            = $Description
                ServiceWindowType      = $serviceWindowTypeMap[$ApplyTo]
                ServiceWindowSchedules = $scheduleString
                IsEnabled              = $IsEnabled
                IsGMT                  = [bool]$IsUtc.IsPresent
            }

            # ---- Build updated windows list ----
            $updatedWindows = [System.Collections.Generic.List[CimInstance]]::new()
            foreach ($w in $existingWindows) {
                $updatedWindows.Add($w)
            }
            $updatedWindows.Add($newWindow)

            # ---- ShouldProcess ----
            $actionDescription = "Create maintenance window '$Name' (Type: $ApplyTo, Enabled: $IsEnabled) on collection '$collectionDisplayName' ($collectionIdToUse)"

            if ($Force -or $PSCmdlet.ShouldProcess($actionDescription, "New-CM7MaintenanceWindow")) {

                if ($isNewSettings) {
                    # Create new SMS_CollectionSettings, then re-retrieve to get full instance
                    Write-Verbose "Creating new SMS_CollectionSettings for CollectionID '$collectionIdToUse'..."

                    $null = New-CimInstance @cimParams -ClassName 'SMS_CollectionSettings' -Property @{
                        CollectionID = $collectionIdToUse
                    }

                    # Re-retrieve the full instance (loads lazy properties)
                    Write-Verbose "Re-retrieving newly created SMS_CollectionSettings..."
                    $fullSettings = Get-CimInstance @cimParams -ClassName 'SMS_CollectionSettings' -Filter "CollectionID = '$collectionIdToUse'" |
                        Get-CimInstance

                    if (-not $fullSettings) {
                        throw "Failed to create or retrieve SMS_CollectionSettings for CollectionID '$collectionIdToUse'."
                    }
                }

                # Update the ServiceWindows property and commit
                Write-Verbose "Updating SMS_CollectionSettings with new maintenance window..."
                $fullSettings.CimInstanceProperties['ServiceWindows'].Value = [CimInstance[]]$updatedWindows.ToArray()
                $fullSettings | Set-CimInstance -ErrorAction Stop

                Write-Verbose "Successfully created maintenance window '$Name' on collection '$collectionDisplayName' ($collectionIdToUse)."

                # Re-read to get the server-assigned properties (ServiceWindowID, parsed schedule, etc.)
                $updatedSettings = Get-CimInstance @cimParams -ClassName 'SMS_CollectionSettings' -Filter "CollectionID = '$collectionIdToUse'" |
                    Get-CimInstance

                $createdWindow = $null
                if ($updatedSettings -and $updatedSettings.ServiceWindows) {
                    # Find the newly created window (match by name, take last if duplicates)
                    $createdWindow = @($updatedSettings.ServiceWindows) | Where-Object { $_.Name -eq $Name } | Select-Object -Last 1
                }

                if ($createdWindow) {
                    $windowType = if ($serviceWindowTypeMapReverse.ContainsKey([int]$createdWindow.ServiceWindowType)) {
                        $serviceWindowTypeMapReverse[[int]$createdWindow.ServiceWindowType]
                    } else { "Unknown ($($createdWindow.ServiceWindowType))" }

                    $recurrence = if ($recurrenceTypeMapReverse.ContainsKey([int]$createdWindow.RecurrenceType)) {
                        $recurrenceTypeMapReverse[[int]$createdWindow.RecurrenceType]
                    } else { "Unknown ($($createdWindow.RecurrenceType))" }

                    [PSCustomObject]@{
                        PSTypeName             = 'MECM7.MaintenanceWindow'
                        Name                   = $createdWindow.Name
                        Description            = $createdWindow.Description
                        ServiceWindowID        = $createdWindow.ServiceWindowID
                        IsEnabled              = $createdWindow.IsEnabled
                        ServiceWindowType      = $windowType
                        StartTime              = $createdWindow.StartTime
                        Duration               = $createdWindow.Duration
                        RecurrenceType         = $recurrence
                        IsGMT                  = $createdWindow.IsGMT
                        ServiceWindowSchedules = $createdWindow.ServiceWindowSchedules
                        CollectionID           = $collectionIdToUse
                    }
                }
                else {
                    # Fallback output if re-read fails
                    Write-Warning "Could not re-read the created maintenance window. Returning basic information."
                    [PSCustomObject]@{
                        PSTypeName             = 'MECM7.MaintenanceWindow'
                        Name                   = $Name
                        Description            = $Description
                        ServiceWindowID        = $null
                        IsEnabled              = $IsEnabled
                        ServiceWindowType      = $ApplyTo
                        StartTime              = if ($PSBoundParameters.ContainsKey('StartTime')) { $StartTime } else { $null }
                        Duration               = if ($PSBoundParameters.ContainsKey('DurationMinutes')) { $DurationMinutes } else { $null }
                        RecurrenceType         = if ($PSBoundParameters.ContainsKey('RecurrenceType')) { $RecurrenceType } else { $null }
                        IsGMT                  = $IsUtc.IsPresent
                        ServiceWindowSchedules = $scheduleString
                        CollectionID           = $collectionIdToUse
                    }
                }
            }
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}
