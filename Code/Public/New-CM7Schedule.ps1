function New-CM7Schedule {
    <#
        .SYNOPSIS
            Creates an SMS schedule token for use with MECM CIM-based functions.

        .DESCRIPTION
            Creates an SMS schedule token that can be used with other MECM7 functions
            such as New-CM7Collection, New-CM7MaintenanceWindow, and Set-CM7Collection.

            This is the CIM-based equivalent of the New-CMSchedule cmdlet from the
            ConfigurationManager PowerShell module, but uses direct CIM queries over WinRM
            instead of requiring the ConfigMgr console or PowerShell drive.

            The function uses the same parameters and behaviour as New-CMSchedule:
            - Nonrecurring (one-time schedule, default)
            - RecurInterval (every N days/hours/minutes)
            - RecurWeekly (every N weeks on a specific day)
            - RecurMonthlyByWeekday (e.g., 2nd Tuesday of every N months)
            - RecurMonthlyByDate (e.g., 15th of every N months)
            - RecurMonthlyLastDayOfMonth (last day of every N months)

            Duration can be specified using -DurationInterval/-DurationCount or -End.

            By default the function returns a CIM instance. Use the -ScheduleString switch
            to return the schedule as a hex-encoded token string instead.

        .PARAMETER Nonrecurring
            Indicates that the schedule does not recur. This creates an SMS_ST_NonRecurring
            schedule token. This is the default behaviour when no recurrence parameters
            are specified.

        .PARAMETER RecurInterval
            Specifies the unit of time for the interval-based recurrence. Used together
            with -RecurCount to define how often the schedule repeats.
            Valid values: Minutes, Hours, Days.

        .PARAMETER RecurCount
            Specifies the number of recurrence intervals. The meaning depends on the
            parameter set:
            - With -RecurInterval: the number of minutes, hours, or days between occurrences.
              Mandatory in this parameter set.
            - With -DayOfWeek (weekly): the number of weeks between occurrences. Default 1.
            - With -DayOfMonth or -LastDayOfMonth: the number of months between occurrences. Default 1.
            - With -DayOfWeek and -WeekOrder: the number of months between occurrences. Default 1.

        .PARAMETER DayOfWeek
            The day of the week for weekly or monthly-by-weekday schedules.
            Valid values: Sunday, Monday, Tuesday, Wednesday, Thursday, Friday, Saturday.
            When used without -WeekOrder, creates a weekly schedule.
            When used with -WeekOrder, creates a monthly-by-weekday schedule.

        .PARAMETER WeekOrder
            Specifies which week of the month for monthly-by-weekday schedules.
            Valid values: First, Second, Third, Fourth, Last.
            Requires -DayOfWeek.

        .PARAMETER DayOfMonth
            The day of the month for monthly-by-date schedules.
            Valid range: 1 to 31.

        .PARAMETER LastDayOfMonth
            Indicates that the schedule recurs on the last day of each month.
            Creates an SMS_ST_RecurMonthlyByDate token with MonthDay set to 0.

        .PARAMETER OffsetDay
            Specifies an offset in days for monthly-by-weekday schedules.
            Valid range: 0 to 7. Default is 0.
            Only used with -DayOfWeek and -WeekOrder.

        .PARAMETER Start
            The start date and time for the schedule. Defaults to the current date and time.
            For recurring schedules, this is the start time of the first occurrence.

        .PARAMETER IsUtc
            Specifies that the schedule uses UTC time instead of local time.

        .PARAMETER ScheduleString
            Switch parameter that indicates the schedule token should be returned as a
            hex-encoded string instead of a CIM instance. When this switch is specified,
            the function returns the schedule token string directly.

        .PARAMETER DurationInterval
            Specifies the unit of time for the schedule duration. Used together with
            -DurationCount. Mutually exclusive with -End.
            Valid values: Minutes, Hours, Days.

        .PARAMETER DurationCount
            Specifies the number of duration intervals. Used together with -DurationInterval.
            Valid range: 0 to 31.

        .PARAMETER End
            Specifies the end date and time for the schedule. The duration is calculated
            from -Start to -End. Mutually exclusive with -DurationInterval/-DurationCount.

        .EXAMPLE
            New-CM7Schedule -Nonrecurring -Start "2026-03-15 22:00"
            Creates a one-time (non-recurring) schedule starting at March 15, 2026 at 10 PM.

        .EXAMPLE
            New-CM7Schedule -RecurInterval Days -RecurCount 1 -Start "2026-03-01 01:00"
            Creates a daily recurring schedule starting at March 1, 2026 at 1 AM.

        .EXAMPLE
            New-CM7Schedule -RecurInterval Hours -RecurCount 4 -Start "2026-03-01 01:00"
            Creates a schedule recurring every 4 hours.

        .EXAMPLE
            New-CM7Schedule -DayOfWeek Saturday -Start "2026-03-01 02:00"
            Creates a weekly schedule recurring every Saturday at 2 AM.

        .EXAMPLE
            New-CM7Schedule -DayOfWeek Saturday -RecurCount 2 -Start "2026-03-01 02:00"
            Creates a bi-weekly schedule recurring every other Saturday.

        .EXAMPLE
            New-CM7Schedule -DayOfWeek Tuesday -WeekOrder Second -Start "2026-03-01 01:00"
            Creates a monthly schedule on the second Tuesday of each month.

        .EXAMPLE
            New-CM7Schedule -DayOfMonth 15 -Start "2026-03-01 03:00"
            Creates a monthly schedule on the 15th of each month.

        .EXAMPLE
            New-CM7Schedule -LastDayOfMonth -Start "2026-03-01 03:00"
            Creates a monthly schedule on the last day of each month.

        .EXAMPLE
            New-CM7Schedule -RecurInterval Days -RecurCount 7 -Start "2026-03-01 22:00" -DurationInterval Hours -DurationCount 2
            Creates a weekly recurring schedule with a 2-hour duration window.

        .EXAMPLE
            New-CM7Schedule -Nonrecurring -Start "2026-03-15 22:00" -End "2026-03-16 00:00"
            Creates a non-recurring schedule with duration calculated from Start to End.

        .EXAMPLE
            $schedule = New-CM7Schedule -RecurInterval Days -RecurCount 7 -Start "2026-03-01 22:00" -ScheduleString
            New-CM7MaintenanceWindow -CollectionName "Test-Collection-Direct" -Name "Weekly MW" -Schedule $schedule -Force
            Creates a recurring schedule as a token string and passes it to New-CM7MaintenanceWindow.

        .EXAMPLE
            New-CM7Schedule -Nonrecurring -Start "2026-03-15 22:00" -DurationInterval Hours -DurationCount 1 -IsUtc
            Creates a one-time schedule using UTC time with a 1-hour duration.

        .NOTES
            Requires an active connection established via Connect-CM7.

            The function builds SMS schedule tokens using the SMS_ScheduleMethods::WriteToString
            WMI method, which is the same method used internally by MECM.

            Schedule Token Classes Used:
                SMS_ST_NonRecurring          - One-time schedules
                SMS_ST_RecurInterval         - Interval-based recurring schedules (days/hours/minutes)
                SMS_ST_RecurWeekly           - Weekly recurring schedules
                SMS_ST_RecurMonthlyByWeekday - Monthly by weekday schedules
                SMS_ST_RecurMonthlyByDate    - Monthly by date schedules (including last day of month)

            This is the CIM-based equivalent of the New-CMSchedule cmdlet from the
            ConfigurationManager PowerShell module but uses direct CIM queries over WinRM
            instead of requiring the ConfigMgr console or PowerShell drive.
    #>
    [CmdletBinding(DefaultParameterSetName = 'RecurrenceNone')]
    [OutputType([Microsoft.Management.Infrastructure.CimInstance])]
    [OutputType([string])]
    param(
        # ---- Recurrence type switches/parameters ----
        [Parameter(ParameterSetName = 'RecurrenceNone')]
        [switch]$Nonrecurring,

        [Parameter(Mandatory = $true, ParameterSetName = 'RecurrenceInterval')]
        [ValidateSet('Minutes', 'Hours', 'Days')]
        [string]$RecurInterval,

        [Parameter(Mandatory = $true, ParameterSetName = 'RecurrenceInterval')]
        [Parameter(ParameterSetName = 'RecurrenceWeekly')]
        [Parameter(ParameterSetName = 'RecurMonthlyByWeekday')]
        [Parameter(ParameterSetName = 'RecurrenceMonthlyByDate')]
        [Parameter(ParameterSetName = 'RecurMonthlyLastDayOfMonth')]
        [ValidateRange(1, 31)]
        [int]$RecurCount,

        [Parameter(Mandatory = $true, ParameterSetName = 'RecurrenceWeekly')]
        [Parameter(Mandatory = $true, ParameterSetName = 'RecurMonthlyByWeekday')]
        [ValidateSet('Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday')]
        [string]$DayOfWeek,

        [Parameter(Mandatory = $true, ParameterSetName = 'RecurMonthlyByWeekday')]
        [ValidateSet('First', 'Second', 'Third', 'Fourth', 'Last')]
        [string]$WeekOrder,

        [Parameter(ParameterSetName = 'RecurMonthlyByWeekday')]
        [ValidateRange(0, 7)]
        [int]$OffsetDay = 0,

        [Parameter(Mandatory = $true, ParameterSetName = 'RecurrenceMonthlyByDate')]
        [ValidateRange(1, 31)]
        [int]$DayOfMonth,

        [Parameter(Mandatory = $true, ParameterSetName = 'RecurMonthlyLastDayOfMonth')]
        [switch]$LastDayOfMonth,

        # ---- Common parameters ----
        [Parameter()]
        [datetime]$Start,

        [Parameter()]
        [switch]$IsUtc,

        [Parameter()]
        [switch]$ScheduleString,

        # ---- Duration parameters ----
        [Parameter()]
        [ValidateSet('Minutes', 'Hours', 'Days')]
        [string]$DurationInterval,

        [Parameter()]
        [ValidateRange(0, 31)]
        [int]$DurationCount,

        [Parameter()]
        [datetime]$End
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
    }

    process {
        try {
            # Set default Start time
            $actualStart = if ($PSBoundParameters.ContainsKey('Start')) { $Start } else { Get-Date }

            # ---- Validate duration parameters ----
            if ($PSBoundParameters.ContainsKey('End') -and ($PSBoundParameters.ContainsKey('DurationInterval') -or $PSBoundParameters.ContainsKey('DurationCount'))) {
                throw "Cannot use -End together with -DurationInterval or -DurationCount. Use one approach or the other."
            }
            if ($PSBoundParameters.ContainsKey('DurationInterval') -xor $PSBoundParameters.ContainsKey('DurationCount')) {
                throw "The -DurationInterval and -DurationCount parameters must be used together."
            }

            # Calculate duration components
            [uint32]$dayDuration = 0
            [uint32]$hourDuration = 0
            [uint32]$minuteDuration = 0

            if ($PSBoundParameters.ContainsKey('DurationInterval') -and $PSBoundParameters.ContainsKey('DurationCount')) {
                switch ($DurationInterval) {
                    'Days'    { $dayDuration = [uint32]$DurationCount }
                    'Hours'   { $hourDuration = [uint32]$DurationCount }
                    'Minutes' { $minuteDuration = [uint32]$DurationCount }
                }
            }
            elseif ($PSBoundParameters.ContainsKey('End')) {
                if ($End -le $actualStart) {
                    throw "The -End value must be later than the -Start value."
                }
                $totalMinutes = [int]($End - $actualStart).TotalMinutes
                $dayDuration = [uint32][Math]::Floor($totalMinutes / 1440)
                $hourDuration = [uint32][Math]::Floor(($totalMinutes % 1440) / 60)
                $minuteDuration = [uint32]($totalMinutes % 60)
            }

            # Set default RecurCount if not specified
            if (-not $PSBoundParameters.ContainsKey('RecurCount')) {
                $RecurCount = 1
            }

            Write-Verbose "Creating schedule: ParameterSet=$($PSCmdlet.ParameterSetName), Start=$($actualStart.ToString('yyyy-MM-dd HH:mm:ss')), Duration=${dayDuration}d ${hourDuration}h ${minuteDuration}m, IsUTC=$($IsUtc.IsPresent)"

            # Build the schedule token instance based on parameter set
            $scheduleToken = $null

            switch ($PSCmdlet.ParameterSetName) {
                'RecurrenceNone' {
                    Write-Verbose "Creating SMS_ST_NonRecurring schedule token"
                    $scheduleClass = Get-CimClass @cimParams -ClassName 'SMS_ST_NonRecurring'
                    $scheduleToken = New-CimInstance -CimClass $scheduleClass -ClientOnly -Property @{
                        StartTime      = [datetime]$actualStart
                        DayDuration    = $dayDuration
                        HourDuration   = $hourDuration
                        MinuteDuration = $minuteDuration
                        IsGMT          = [bool]$IsUtc.IsPresent
                    }
                }
                'RecurrenceInterval' {
                    [uint32]$daySpan = 0
                    [uint32]$hourSpan = 0
                    [uint32]$minuteSpan = 0
                    switch ($RecurInterval) {
                        'Days'    { $daySpan = [uint32]$RecurCount }
                        'Hours'   { $hourSpan = [uint32]$RecurCount }
                        'Minutes' { $minuteSpan = [uint32]$RecurCount }
                    }
                    Write-Verbose "Creating SMS_ST_RecurInterval schedule token: DaySpan=$daySpan, HourSpan=$hourSpan, MinuteSpan=$minuteSpan"
                    $scheduleClass = Get-CimClass @cimParams -ClassName 'SMS_ST_RecurInterval'
                    $scheduleToken = New-CimInstance -CimClass $scheduleClass -ClientOnly -Property @{
                        StartTime      = [datetime]$actualStart
                        DayDuration    = $dayDuration
                        HourDuration   = $hourDuration
                        MinuteDuration = $minuteDuration
                        IsGMT          = [bool]$IsUtc.IsPresent
                        DaySpan        = $daySpan
                        HourSpan       = $hourSpan
                        MinuteSpan     = $minuteSpan
                    }
                }
                'RecurrenceWeekly' {
                    Write-Verbose "Creating SMS_ST_RecurWeekly schedule token: DayOfWeek=$DayOfWeek, ForNumberOfWeeks=$RecurCount"
                    $scheduleClass = Get-CimClass @cimParams -ClassName 'SMS_ST_RecurWeekly'
                    $scheduleToken = New-CimInstance -CimClass $scheduleClass -ClientOnly -Property @{
                        StartTime        = [datetime]$actualStart
                        DayDuration      = $dayDuration
                        HourDuration     = $hourDuration
                        MinuteDuration   = $minuteDuration
                        IsGMT            = [bool]$IsUtc.IsPresent
                        Day              = $dayOfWeekMap[$DayOfWeek]
                        ForNumberOfWeeks = [uint32]$RecurCount
                    }
                }
                'RecurMonthlyByWeekday' {
                    Write-Verbose "Creating SMS_ST_RecurMonthlyByWeekday schedule token: DayOfWeek=$DayOfWeek, WeekOrder=$WeekOrder, ForNumberOfMonths=$RecurCount, OffsetDay=$OffsetDay"
                    $scheduleClass = Get-CimClass @cimParams -ClassName 'SMS_ST_RecurMonthlyByWeekday'
                    $scheduleToken = New-CimInstance -CimClass $scheduleClass -ClientOnly -Property @{
                        StartTime         = [datetime]$actualStart
                        DayDuration       = $dayDuration
                        HourDuration      = $hourDuration
                        MinuteDuration    = $minuteDuration
                        IsGMT             = [bool]$IsUtc.IsPresent
                        Day               = $dayOfWeekMap[$DayOfWeek]
                        WeekOrder         = $weekOrderMap[$WeekOrder]
                        ForNumberOfMonths = [uint32]$RecurCount
                    }
                }
                'RecurrenceMonthlyByDate' {
                    Write-Verbose "Creating SMS_ST_RecurMonthlyByDate schedule token: DayOfMonth=$DayOfMonth, ForNumberOfMonths=$RecurCount"
                    $scheduleClass = Get-CimClass @cimParams -ClassName 'SMS_ST_RecurMonthlyByDate'
                    $scheduleToken = New-CimInstance -CimClass $scheduleClass -ClientOnly -Property @{
                        StartTime         = [datetime]$actualStart
                        DayDuration       = $dayDuration
                        HourDuration      = $hourDuration
                        MinuteDuration    = $minuteDuration
                        IsGMT             = [bool]$IsUtc.IsPresent
                        MonthDay          = [uint32]$DayOfMonth
                        ForNumberOfMonths = [uint32]$RecurCount
                    }
                }
                'RecurMonthlyLastDayOfMonth' {
                    Write-Verbose "Creating SMS_ST_RecurMonthlyByDate schedule token for last day of month: ForNumberOfMonths=$RecurCount"
                    $scheduleClass = Get-CimClass @cimParams -ClassName 'SMS_ST_RecurMonthlyByDate'
                    $scheduleToken = New-CimInstance -CimClass $scheduleClass -ClientOnly -Property @{
                        StartTime         = [datetime]$actualStart
                        DayDuration       = $dayDuration
                        HourDuration      = $hourDuration
                        MinuteDuration    = $minuteDuration
                        IsGMT             = [bool]$IsUtc.IsPresent
                        MonthDay          = [uint32]0
                        ForNumberOfMonths = [uint32]$RecurCount
                    }
                }
            }

            # Convert schedule token to string using SMS_ScheduleMethods
            Write-Verbose "Converting schedule token to string via SMS_ScheduleMethods::WriteToString..."
            $writeResult = Invoke-CimMethod @cimParams -ClassName 'SMS_ScheduleMethods' -MethodName 'WriteToString' -Arguments @{
                TokenData = [CimInstance[]]@($scheduleToken)
            }

            if (-not $writeResult -or $writeResult.ReturnValue -ne 0) {
                throw "SMS_ScheduleMethods::WriteToString failed with return value $($writeResult.ReturnValue)."
            }

            $scheduleStringResult = $writeResult.StringData
            Write-Verbose "Generated schedule token: $scheduleStringResult"

            if ($ScheduleString.IsPresent) {
                # Return the schedule token as a string
                Write-Output $scheduleStringResult
            }
            else {
                # Add ScheduleString as a NoteProperty on the CIM instance for convenience
                $scheduleToken | Add-Member -MemberType NoteProperty -Name ScheduleString -Value $scheduleStringResult -Force
                Write-Output $scheduleToken
            }
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}
