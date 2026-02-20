# Functional Tests for New-CM7Schedule
# Tests the New-CM7Schedule function behavior and return values
# Uses the same parameters as the ConfigurationManager module's New-CMSchedule

BeforeAll {
    # Load test declarations
    . (Join-Path $PSScriptRoot "declarations.ps1")

    # Load all functions
    $CodePath = Join-Path (Get-Item $PSScriptRoot).Parent.FullName "Code"
    Get-ChildItem -Path (Join-Path $CodePath "Private") -Filter "*.ps1" | ForEach-Object { . $_.FullName }
    Get-ChildItem -Path (Join-Path $CodePath "Public") -Filter "*.ps1" | ForEach-Object { . $_.FullName }

    # Get test data for this function
    $script:TestScheduleData = $script:TestData['New-CM7Schedule']
    $script:TestConnectData = $script:TestData['Connect-CM7']

    # Establish connection for all tests
    $connectParams = @{
        SiteServer = $script:TestConnectData.Valid.SiteServer
        Credential = $script:TestConnectData.Valid.Credential
    }
    if ($script:TestConnectData.Valid.SkipCertificateCheck) {
        $connectParams.SkipCertificateCheck = $true
    }
    if ($script:TestConnectData.Valid.UseSsl) {
        $connectParams.UseSsl = $true
    }
    Connect-CM7 @connectParams

    # DayOfWeek bitmask map for assertions
    $script:DayOfWeekBitmask = @{
        'Sunday'    = 1
        'Monday'    = 2
        'Tuesday'   = 4
        'Wednesday' = 8
        'Thursday'  = 16
        'Friday'    = 32
        'Saturday'  = 64
    }

    # WeekOrder map for assertions
    $script:WeekOrderMap = @{
        'Last'   = 0
        'First'  = 1
        'Second' = 2
        'Third'  = 3
        'Fourth' = 4
    }
}

Describe "New-CM7Schedule Function Tests" -Tag "Integration", "Schedule" {

    Context "Test Data Validation" {

        It "Should have test data defined in declarations.ps1" {
            $script:TestScheduleData | Should -Not -BeNullOrEmpty
            $script:TestData.ContainsKey('New-CM7Schedule') | Should -Be $true
        }

        It "Should have required test data parameter sets" {
            $script:TestScheduleData.ContainsKey('NonRecurring') | Should -Be $true
            $script:TestScheduleData.ContainsKey('RecurInterval_Daily') | Should -Be $true
            $script:TestScheduleData.ContainsKey('RecurWeekly') | Should -Be $true
            $script:TestScheduleData.ContainsKey('RecurMonthlyByWeekday') | Should -Be $true
            $script:TestScheduleData.ContainsKey('RecurMonthlyByDate') | Should -Be $true
            $script:TestScheduleData.ContainsKey('RecurMonthlyLastDayOfMonth') | Should -Be $true
        }

        It "Should output test data for verification" {
            Write-Host "`n=== Test Data for New-CM7Schedule ===" -ForegroundColor Cyan
            Write-Host "NonRecurring:" -ForegroundColor Yellow
            Write-Host "  DurationInterval: $($script:TestScheduleData.NonRecurring.DurationInterval)" -ForegroundColor White
            Write-Host "  DurationCount: $($script:TestScheduleData.NonRecurring.DurationCount)" -ForegroundColor White

            Write-Host "RecurInterval_Daily:" -ForegroundColor Yellow
            Write-Host "  RecurInterval: $($script:TestScheduleData.RecurInterval_Daily.RecurInterval)" -ForegroundColor White
            Write-Host "  RecurCount: $($script:TestScheduleData.RecurInterval_Daily.RecurCount)" -ForegroundColor White

            Write-Host "RecurWeekly:" -ForegroundColor Yellow
            Write-Host "  DayOfWeek: $($script:TestScheduleData.RecurWeekly.DayOfWeek)" -ForegroundColor White

            Write-Host "RecurMonthlyByWeekday:" -ForegroundColor Yellow
            Write-Host "  DayOfWeek: $($script:TestScheduleData.RecurMonthlyByWeekday.DayOfWeek)" -ForegroundColor White
            Write-Host "  WeekOrder: $($script:TestScheduleData.RecurMonthlyByWeekday.WeekOrder)" -ForegroundColor White

            Write-Host "RecurMonthlyByDate:" -ForegroundColor Yellow
            Write-Host "  DayOfMonth: $($script:TestScheduleData.RecurMonthlyByDate.DayOfMonth)" -ForegroundColor White
            Write-Host "============================================================`n" -ForegroundColor Cyan

            $true | Should -Be $true
        }
    }

    Context "Connection Requirement" {

        It "Should fail if not connected to MECM" {
            # Arrange - Backup and clear connection
            $backupConnection = $script:CMConnection.Clone()
            $script:CMConnection.CimSession = $null

            # Act & Assert
            { New-CM7Schedule -Nonrecurring } | Should -Throw "*not connected*"

            # Restore connection
            $script:CMConnection = $backupConnection
        }
    }

    Context "Create NonRecurring Schedule" {

        It "Should create a non-recurring schedule token returning SMS_ST_NonRecurring" {
            # Arrange
            $testData = $script:TestScheduleData.NonRecurring

            # Act
            $result = New-CM7Schedule -Nonrecurring `
                -Start $testData.Start `
                -DurationInterval $testData.DurationInterval `
                -DurationCount $testData.DurationCount

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result | Should -BeOfType [Microsoft.Management.Infrastructure.CimInstance]
            $result.CimClass.CimClassName | Should -Be 'SMS_ST_NonRecurring'
            $result.ScheduleString | Should -Not -BeNullOrEmpty
        }

        It "Should set correct duration from DurationInterval/DurationCount" {
            # Arrange
            $testData = $script:TestScheduleData.NonRecurring

            # Act
            $result = New-CM7Schedule -Nonrecurring `
                -Start $testData.Start `
                -DurationInterval $testData.DurationInterval `
                -DurationCount $testData.DurationCount

            # Assert - DurationInterval=Hours, DurationCount=2 → 0 days, 2 hours, 0 minutes
            $result.DayDuration | Should -Be 0
            $result.HourDuration | Should -Be 2
            $result.MinuteDuration | Should -Be 0
        }

        It "Should create a non-recurring schedule with -End parameter" {
            # Arrange
            $testData = $script:TestScheduleData.NonRecurringWithEnd

            # Act
            $result = New-CM7Schedule -Nonrecurring `
                -Start $testData.Start `
                -End $testData.End

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.CimClass.CimClassName | Should -Be 'SMS_ST_NonRecurring'
            $result.ScheduleString | Should -Not -BeNullOrEmpty
            # Duration should be calculated from Start to End (2 hours)
            $result.HourDuration | Should -Be 2
        }

        It "Should default to NonRecurring when no recurrence parameters specified" {
            # Act
            $result = New-CM7Schedule -Start (Get-Date).AddDays(1)

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.CimClass.CimClassName | Should -Be 'SMS_ST_NonRecurring'
        }
    }

    Context "Create RecurInterval Schedule - Daily" {

        It "Should create a daily recurring schedule token returning SMS_ST_RecurInterval" {
            # Arrange
            $testData = $script:TestScheduleData.RecurInterval_Daily

            # Act
            $result = New-CM7Schedule `
                -RecurInterval $testData.RecurInterval `
                -RecurCount $testData.RecurCount `
                -Start $testData.Start

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result | Should -BeOfType [Microsoft.Management.Infrastructure.CimInstance]
            $result.CimClass.CimClassName | Should -Be 'SMS_ST_RecurInterval'
            $result.ScheduleString | Should -Not -BeNullOrEmpty
            $result.DaySpan | Should -Be 1
        }
    }

    Context "Create RecurInterval Schedule - Hourly" {

        It "Should create an hourly recurring schedule token" {
            # Arrange
            $testData = $script:TestScheduleData.RecurInterval_Hourly

            # Act
            $result = New-CM7Schedule `
                -RecurInterval $testData.RecurInterval `
                -RecurCount $testData.RecurCount `
                -Start $testData.Start

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.CimClass.CimClassName | Should -Be 'SMS_ST_RecurInterval'
            $result.HourSpan | Should -Be 4
        }
    }

    Context "Create RecurInterval Schedule - Minute" {

        It "Should create a minute-interval recurring schedule token" {
            # Arrange
            $testData = $script:TestScheduleData.RecurInterval_Minute

            # Act
            $result = New-CM7Schedule `
                -RecurInterval $testData.RecurInterval `
                -RecurCount $testData.RecurCount `
                -Start $testData.Start

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.CimClass.CimClassName | Should -Be 'SMS_ST_RecurInterval'
            $result.MinuteSpan | Should -Be 30
        }
    }

    Context "Create RecurWeekly Schedule" {

        It "Should create a weekly recurring schedule token returning SMS_ST_RecurWeekly" {
            # Arrange
            $testData = $script:TestScheduleData.RecurWeekly

            # Act
            $result = New-CM7Schedule `
                -DayOfWeek $testData.DayOfWeek `
                -Start $testData.Start

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result | Should -BeOfType [Microsoft.Management.Infrastructure.CimInstance]
            $result.CimClass.CimClassName | Should -Be 'SMS_ST_RecurWeekly'
            $result.ScheduleString | Should -Not -BeNullOrEmpty
            $result.Day | Should -Be $script:DayOfWeekBitmask[$testData.DayOfWeek]
            $result.ForNumberOfWeeks | Should -Be 1
        }

        It "Should create a bi-weekly schedule with -RecurCount 2" {
            # Arrange
            $testData = $script:TestScheduleData.RecurWeeklyBiWeekly

            # Act
            $result = New-CM7Schedule `
                -DayOfWeek $testData.DayOfWeek `
                -RecurCount $testData.RecurCount `
                -Start $testData.Start

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.CimClass.CimClassName | Should -Be 'SMS_ST_RecurWeekly'
            $result.Day | Should -Be $script:DayOfWeekBitmask[$testData.DayOfWeek]
            $result.ForNumberOfWeeks | Should -Be 2
        }
    }

    Context "Create RecurMonthlyByWeekday Schedule" {

        It "Should create a monthly by weekday recurring schedule token" {
            # Arrange
            $testData = $script:TestScheduleData.RecurMonthlyByWeekday

            # Act
            $result = New-CM7Schedule `
                -DayOfWeek $testData.DayOfWeek `
                -WeekOrder $testData.WeekOrder `
                -Start $testData.Start

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result | Should -BeOfType [Microsoft.Management.Infrastructure.CimInstance]
            $result.CimClass.CimClassName | Should -Be 'SMS_ST_RecurMonthlyByWeekday'
            $result.ScheduleString | Should -Not -BeNullOrEmpty
            $result.Day | Should -Be $script:DayOfWeekBitmask[$testData.DayOfWeek]
            $result.WeekOrder | Should -Be $script:WeekOrderMap[$testData.WeekOrder]
            $result.ForNumberOfMonths | Should -Be 1
        }
    }

    Context "Create RecurMonthlyByDate Schedule" {

        It "Should create a monthly by date recurring schedule token" {
            # Arrange
            $testData = $script:TestScheduleData.RecurMonthlyByDate

            # Act
            $result = New-CM7Schedule `
                -DayOfMonth $testData.DayOfMonth `
                -Start $testData.Start

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result | Should -BeOfType [Microsoft.Management.Infrastructure.CimInstance]
            $result.CimClass.CimClassName | Should -Be 'SMS_ST_RecurMonthlyByDate'
            $result.ScheduleString | Should -Not -BeNullOrEmpty
            $result.MonthDay | Should -Be 15
            $result.ForNumberOfMonths | Should -Be 1
        }
    }

    Context "Create RecurMonthlyLastDayOfMonth Schedule" {

        It "Should create a monthly schedule for the last day of month using -LastDayOfMonth" {
            # Arrange
            $testData = $script:TestScheduleData.RecurMonthlyLastDayOfMonth

            # Act
            $result = New-CM7Schedule `
                -LastDayOfMonth `
                -Start $testData.Start

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.CimClass.CimClassName | Should -Be 'SMS_ST_RecurMonthlyByDate'
            $result.MonthDay | Should -Be 0
            $result.ForNumberOfMonths | Should -Be 1
        }
    }

    Context "UTC Time Support" {

        It "Should create a schedule with UTC time" {
            # Arrange
            $testData = $script:TestScheduleData.WithUTC

            # Act
            $result = New-CM7Schedule -Nonrecurring `
                -Start $testData.Start `
                -DurationInterval $testData.DurationInterval `
                -DurationCount $testData.DurationCount `
                -IsUtc

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.IsGMT | Should -Be $true
        }
    }

    Context "Duration with Recurrence" {

        It "Should create a recurring schedule with duration" {
            # Arrange
            $testData = $script:TestScheduleData.WithDuration

            # Act
            $result = New-CM7Schedule `
                -RecurInterval $testData.RecurInterval `
                -RecurCount $testData.RecurCount `
                -Start $testData.Start `
                -DurationInterval $testData.DurationInterval `
                -DurationCount $testData.DurationCount

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.CimClass.CimClassName | Should -Be 'SMS_ST_RecurInterval'
            $result.DaySpan | Should -Be 7
            $result.HourDuration | Should -Be 3
        }
    }

    Context "ScheduleString Switch Output" {

        It "Should return a string when -ScheduleString switch is used" {
            # Arrange
            $testData = $script:TestScheduleData.AsString

            # Act
            $result = New-CM7Schedule `
                -RecurInterval $testData.RecurInterval `
                -RecurCount $testData.RecurCount `
                -Start $testData.Start `
                -ScheduleString

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result | Should -BeOfType [string]
            $result | Should -Match '^[0-9A-Fa-f]+$'
        }

        It "Should return a CIM instance when -ScheduleString switch is NOT used" {
            # Arrange
            $testData = $script:TestScheduleData.AsString

            # Act
            $result = New-CM7Schedule `
                -RecurInterval $testData.RecurInterval `
                -RecurCount $testData.RecurCount `
                -Start $testData.Start

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result | Should -BeOfType [Microsoft.Management.Infrastructure.CimInstance]
            $result.ScheduleString | Should -Not -BeNullOrEmpty
        }
    }

    Context "Integration with New-CM7MaintenanceWindow" {

        It "Should create a schedule token usable with New-CM7MaintenanceWindow" {
            # Arrange
            $testData = $script:TestScheduleData.ForMaintenanceWindow

            # Act - Create the schedule token as string
            $schedule = New-CM7Schedule `
                -RecurInterval $testData.RecurInterval `
                -RecurCount $testData.RecurCount `
                -Start $testData.Start `
                -ScheduleString

            # Assert - Schedule token should be a valid hex string for New-CM7MaintenanceWindow
            $schedule | Should -Not -BeNullOrEmpty
            $schedule | Should -BeOfType [string]
            $schedule | Should -Match '^[0-9A-Fa-f]+$'
        }

        It "Should create a schedule CIM instance with ScheduleString NoteProperty" {
            # Arrange
            $testData = $script:TestScheduleData.ForMaintenanceWindow

            # Act
            $schedule = New-CM7Schedule `
                -RecurInterval $testData.RecurInterval `
                -RecurCount $testData.RecurCount `
                -Start $testData.Start

            # Assert
            $schedule.ScheduleString | Should -Not -BeNullOrEmpty
            $schedule.ScheduleString | Should -Match '^[0-9A-Fa-f]+$'
        }
    }

    Context "Output Object Properties" {

        It "Should return a CIM instance with correct class for NonRecurring" {
            # Arrange
            $testData = $script:TestScheduleData.NonRecurring

            # Act
            $result = New-CM7Schedule -Nonrecurring `
                -Start $testData.Start `
                -DurationInterval $testData.DurationInterval `
                -DurationCount $testData.DurationCount

            # Assert
            $result | Should -BeOfType [Microsoft.Management.Infrastructure.CimInstance]
            $result.CimClass.CimClassName | Should -Be 'SMS_ST_NonRecurring'
        }

        It "Should include ScheduleString NoteProperty" {
            # Arrange
            $testData = $script:TestScheduleData.NonRecurring

            # Act
            $result = New-CM7Schedule -Nonrecurring `
                -Start $testData.Start `
                -DurationInterval $testData.DurationInterval `
                -DurationCount $testData.DurationCount

            # Assert
            $result.ScheduleString | Should -Not -BeNullOrEmpty
            $result.ScheduleString | Should -Match '^[0-9A-Fa-f]+$'
        }

        It "Should include base CIM properties on all schedule types" {
            # Arrange
            $testData = $script:TestScheduleData.NonRecurring

            # Act
            $result = New-CM7Schedule -Nonrecurring `
                -Start $testData.Start `
                -DurationInterval $testData.DurationInterval `
                -DurationCount $testData.DurationCount

            # Assert - CIM instance properties
            $result.CimInstanceProperties['StartTime'] | Should -Not -BeNullOrEmpty
            $result.CimInstanceProperties['IsGMT'] | Should -Not -BeNullOrEmpty
            $result.CimInstanceProperties['DayDuration'] | Should -Not -BeNullOrEmpty
            $result.CimInstanceProperties['HourDuration'] | Should -Not -BeNullOrEmpty
            $result.CimInstanceProperties['MinuteDuration'] | Should -Not -BeNullOrEmpty
        }

        It "Should include RecurInterval-specific CIM properties for interval schedules" {
            # Arrange
            $testData = $script:TestScheduleData.RecurInterval_Daily

            # Act
            $result = New-CM7Schedule `
                -RecurInterval $testData.RecurInterval `
                -RecurCount $testData.RecurCount `
                -Start $testData.Start

            # Assert
            $result.CimInstanceProperties['DaySpan'] | Should -Not -BeNullOrEmpty
            $result.CimInstanceProperties['HourSpan'] | Should -Not -BeNullOrEmpty
            $result.CimInstanceProperties['MinuteSpan'] | Should -Not -BeNullOrEmpty
        }

        It "Should include RecurWeekly-specific CIM properties for weekly schedules" {
            # Arrange
            $testData = $script:TestScheduleData.RecurWeekly

            # Act
            $result = New-CM7Schedule `
                -DayOfWeek $testData.DayOfWeek `
                -Start $testData.Start

            # Assert
            $result.CimInstanceProperties['Day'] | Should -Not -BeNullOrEmpty
            $result.CimInstanceProperties['ForNumberOfWeeks'] | Should -Not -BeNullOrEmpty
        }

        It "Should include MonthlyByWeekday-specific CIM properties" {
            # Arrange
            $testData = $script:TestScheduleData.RecurMonthlyByWeekday

            # Act
            $result = New-CM7Schedule `
                -DayOfWeek $testData.DayOfWeek `
                -WeekOrder $testData.WeekOrder `
                -Start $testData.Start

            # Assert
            $result.CimInstanceProperties['Day'] | Should -Not -BeNullOrEmpty
            $result.CimInstanceProperties['WeekOrder'] | Should -Not -BeNullOrEmpty
            $result.CimInstanceProperties['ForNumberOfMonths'] | Should -Not -BeNullOrEmpty
        }

        It "Should include MonthlyByDate-specific CIM properties" {
            # Arrange
            $testData = $script:TestScheduleData.RecurMonthlyByDate

            # Act
            $result = New-CM7Schedule `
                -DayOfMonth $testData.DayOfMonth `
                -Start $testData.Start

            # Assert
            $result.CimInstanceProperties['MonthDay'] | Should -Not -BeNullOrEmpty
            $result.CimInstanceProperties['ForNumberOfMonths'] | Should -Not -BeNullOrEmpty
        }
    }

    Context "Error Handling" {

        It "Should fail when -End and -DurationInterval are both specified" {
            { New-CM7Schedule -Nonrecurring `
                -Start (Get-Date).AddDays(1) `
                -End (Get-Date).AddDays(2) `
                -DurationInterval Hours `
                -DurationCount 2 } | Should -Throw "*Cannot use -End*"
        }

        It "Should fail when -DurationInterval is specified without -DurationCount" {
            { New-CM7Schedule -Nonrecurring `
                -Start (Get-Date).AddDays(1) `
                -DurationInterval Hours } | Should -Throw "*-DurationInterval*-DurationCount*must be used together*"
        }

        It "Should fail when -End is earlier than -Start" {
            { New-CM7Schedule -Nonrecurring `
                -Start (Get-Date).AddDays(2) `
                -End (Get-Date).AddDays(1) } | Should -Throw "*-End value must be later*"
        }
    }

    Context "Default Values" {

        It "Should default to RecurrenceNone (NonRecurring) when no recurrence specified" {
            # Act
            $result = New-CM7Schedule -Start (Get-Date).AddDays(1)

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.CimClass.CimClassName | Should -Be 'SMS_ST_NonRecurring'
        }

        It "Should default Start to current date/time when not specified" {
            # Act
            $before = Get-Date
            $result = New-CM7Schedule -Nonrecurring -DurationInterval Hours -DurationCount 1
            $after = Get-Date

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.StartTime | Should -BeGreaterOrEqual $before.AddSeconds(-1)
            $result.StartTime | Should -BeLessOrEqual $after.AddSeconds(1)
        }

        It "Should default IsGMT to false" {
            # Act
            $result = New-CM7Schedule -Start (Get-Date).AddDays(1)

            # Assert
            $result.IsGMT | Should -Be $false
        }

        It "Should default RecurCount to 1 for weekly schedules" {
            # Act
            $result = New-CM7Schedule -DayOfWeek Monday -Start (Get-Date).AddDays(1)

            # Assert
            $result.ForNumberOfWeeks | Should -Be 1
        }

        It "Should default RecurCount to 1 for monthly by date schedules" {
            # Act
            $result = New-CM7Schedule -DayOfMonth 15 -Start (Get-Date).AddDays(1)

            # Assert
            $result.ForNumberOfMonths | Should -Be 1
        }

        It "Should default RecurCount to 1 for last day of month schedules" {
            # Act
            $result = New-CM7Schedule -LastDayOfMonth -Start (Get-Date).AddDays(1)

            # Assert
            $result.ForNumberOfMonths | Should -Be 1
        }
    }

    Context "Verbose Output" {

        It "Should produce verbose output when -Verbose is used" {
            # Arrange
            $testData = $script:TestScheduleData.RecurInterval_Daily

            # Act
            $verboseOutput = New-CM7Schedule `
                -RecurInterval $testData.RecurInterval `
                -RecurCount $testData.RecurCount `
                -Start $testData.Start `
                -Verbose 4>&1

            # Assert - verbose output should contain schedule creation messages
            $verboseMessages = $verboseOutput | Where-Object { $_ -is [System.Management.Automation.VerboseRecord] }
            $verboseMessages | Should -Not -BeNullOrEmpty
        }
    }
}
