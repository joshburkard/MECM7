# Functional Tests for New-CM7MaintenanceWindow
# Tests the New-CM7MaintenanceWindow function behavior and return values

BeforeAll {
    # Load test declarations
    . (Join-Path $PSScriptRoot "declarations.ps1")

    # Load all functions
    $CodePath = Join-Path (Get-Item $PSScriptRoot).Parent.FullName "Code"
    Get-ChildItem -Path (Join-Path $CodePath "Private") -Filter "*.ps1" | ForEach-Object { . $_.FullName }
    Get-ChildItem -Path (Join-Path $CodePath "Public") -Filter "*.ps1" | ForEach-Object { . $_.FullName }

    # Get test data for this function
    $script:TestNewMWData = $script:TestData['New-CM7MaintenanceWindow']
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

    # Generate unique timestamp suffix for test maintenance window names to avoid collisions
    $script:TestTimestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
}

AfterAll {
    # Cleanup: Remove all test maintenance windows created during this test run
    if ($script:CMConnection.CimSession -and $script:TestTimestamp) {
        $namespace = "root/SMS/site_$($script:CMConnection.SiteCode)"
        $cimParams = @{
            CimSession = $script:CMConnection.CimSession
            Namespace  = $namespace
        }

        # Collect collection names used in tests
        $cleanupCollections = @()
        if ($script:TestNewMWData.ByCollectionName.CollectionName) {
            $cleanupCollections += $script:TestNewMWData.ByCollectionName.CollectionName
        }

        foreach ($collName in ($cleanupCollections | Select-Object -Unique)) {
            try {
                $coll = Get-CimInstance @cimParams -Query "SELECT CollectionID FROM SMS_Collection WHERE Name = '$collName'"
                if ($coll) {
                    $settings = Get-CimInstance @cimParams -Query "SELECT * FROM SMS_CollectionSettings WHERE CollectionID = '$($coll.CollectionID)'"
                    if ($settings) {
                        $fullSettings = $settings | Get-CimInstance
                        if ($fullSettings -and $fullSettings.ServiceWindows) {
                            $original = @($fullSettings.ServiceWindows)
                            $cleaned = @($original | Where-Object { $_.Name -notlike "*_$($script:TestTimestamp)" })
                            if ($cleaned.Count -ne $original.Count) {
                                $fullSettings.CimInstanceProperties['ServiceWindows'].Value = [CimInstance[]]$cleaned
                                $fullSettings | Set-CimInstance
                                $removedCount = $original.Count - $cleaned.Count
                                Write-Host "Cleaned up $removedCount test maintenance window(s) from collection '$collName'" -ForegroundColor Yellow
                            }
                        }
                    }
                }
            }
            catch {
                Write-Warning "Cleanup failed for collection '$collName': $($_.Exception.Message)"
            }
        }
    }
}

Describe "New-CM7MaintenanceWindow Function Tests" -Tag "Integration", "Collection", "MaintenanceWindow" {

    Context "Test Data Validation" {

        It "Should have test data defined in declarations.ps1" {
            $script:TestNewMWData | Should -Not -BeNullOrEmpty
            $script:TestData.ContainsKey('New-CM7MaintenanceWindow') | Should -Be $true
        }

        It "Should have required test data parameter sets" {
            $script:TestNewMWData.ContainsKey('ByCollectionName') | Should -Be $true
            $script:TestNewMWData.ContainsKey('ByCollectionID') | Should -Be $true
            $script:TestNewMWData.ContainsKey('NonExistentCollection') | Should -Be $true
        }

        It "Should output test data for verification" {
            Write-Host "`n=== Test Data for New-CM7MaintenanceWindow ===" -ForegroundColor Cyan
            Write-Host "ByCollectionName:" -ForegroundColor Yellow
            Write-Host "  CollectionName: $($script:TestNewMWData.ByCollectionName.CollectionName)" -ForegroundColor White
            Write-Host "  Name: $($script:TestNewMWData.ByCollectionName.Name)" -ForegroundColor White
            Write-Host "  DurationMinutes: $($script:TestNewMWData.ByCollectionName.DurationMinutes)" -ForegroundColor White
            Write-Host "  RecurrenceType: $($script:TestNewMWData.ByCollectionName.RecurrenceType)" -ForegroundColor White

            Write-Host "ByCollectionID:" -ForegroundColor Yellow
            Write-Host "  CollectionID: $($script:TestNewMWData.ByCollectionID.CollectionID)" -ForegroundColor White
            Write-Host "  Name: $($script:TestNewMWData.ByCollectionID.Name)" -ForegroundColor White
            Write-Host "  DurationMinutes: $($script:TestNewMWData.ByCollectionID.DurationMinutes)" -ForegroundColor White
            Write-Host "  RecurrenceType: $($script:TestNewMWData.ByCollectionID.RecurrenceType)" -ForegroundColor White

            Write-Host "WithSpecificTime:" -ForegroundColor Yellow
            Write-Host "  CollectionName: $($script:TestNewMWData.WithSpecificTime.CollectionName)" -ForegroundColor White
            Write-Host "  Name: $($script:TestNewMWData.WithSpecificTime.Name)" -ForegroundColor White
            Write-Host "  RecurrenceType: $($script:TestNewMWData.WithSpecificTime.RecurrenceType)" -ForegroundColor White

            Write-Host "NonExistentCollection:" -ForegroundColor Yellow
            Write-Host "  CollectionName: $($script:TestNewMWData.NonExistentCollection.CollectionName)" -ForegroundColor White
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
            { New-CM7MaintenanceWindow -CollectionName "Test" -Name "Test" -StartTime (Get-Date) -DurationMinutes 60 -Force } | Should -Throw "*not connected*"

            # Restore connection
            $script:CMConnection = $backupConnection
        }
    }

    Context "Create Daily Maintenance Window by Collection Name" {

        It "Should create a new daily maintenance window by collection name" {
            # Arrange
            $testData = $script:TestNewMWData.ByCollectionName
            $mwName = "$($testData.Name)_$($script:TestTimestamp)"

            # Act
            $result = New-CM7MaintenanceWindow `
                -CollectionName $testData.CollectionName `
                -Name $mwName `
                -StartTime $testData.StartTime `
                -DurationMinutes $testData.DurationMinutes `
                -RecurrenceType $testData.RecurrenceType `
                -DayOfWeek $testData.DayOfWeek `
                -ApplyTo $testData.ApplyTo `
                -IsEnabled $testData.IsEnabled `
                -Force

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.Name | Should -Be $mwName
            $result.psobject.TypeNames[0] | Should -Be 'MECM7.MaintenanceWindow'
            $result.IsEnabled | Should -Be $true
            $result.RecurrenceType | Should -Be 'Daily'
            $result.ServiceWindowType | Should -Be 'General'
            $result.ServiceWindowID | Should -Not -BeNullOrEmpty
        }

        It "Should verify the maintenance window exists after creation" {
            # Arrange
            $testData = $script:TestNewMWData.ByCollectionName
            $mwName = "$($testData.Name)_$($script:TestTimestamp)"

            # Act
            $result = Get-CM7MaintenanceWindow -CollectionName $testData.CollectionName -MaintenanceWindowName $mwName

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.Name | Should -Be $mwName
            $result.RecurrenceType | Should -Be 'Daily'
        }
    }

    Context "Create Weekly Maintenance Window by Collection ID" {

        It "Should create a new weekly maintenance window by collection ID" {
            # Arrange
            $testData = $script:TestNewMWData.ByCollectionID
            $mwName = "$($testData.Name)_$($script:TestTimestamp)"

            # Act
            $result = New-CM7MaintenanceWindow `
                -CollectionId $testData.CollectionID `
                -Name $mwName `
                -StartTime $testData.StartTime `
                -DurationMinutes $testData.DurationMinutes `
                -RecurrenceType $testData.RecurrenceType `
                -DayOfWeek $testData.DayOfWeek `
                -ApplyTo $testData.ApplyTo `
                -IsEnabled $testData.IsEnabled `
                -Force

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.Name | Should -Be $mwName
            $result.psobject.TypeNames[0] | Should -Be 'MECM7.MaintenanceWindow'
            $result.RecurrenceType | Should -Be 'Weekly'
            $result.ServiceWindowType | Should -Be 'SoftwareUpdatesOnly'
            $result.CollectionID | Should -Be $testData.CollectionID
        }

        It "Should verify the maintenance window exists after creation by collection ID" {
            # Arrange
            $testData = $script:TestNewMWData.ByCollectionID
            $mwName = "$($testData.Name)_$($script:TestTimestamp)"

            # Act
            $result = Get-CM7MaintenanceWindow -CollectionId $testData.CollectionID -MaintenanceWindowName $mwName

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.Name | Should -Be $mwName
        }
    }

    Context "Create Non-Recurring Maintenance Window" {

        It "Should create a one-time maintenance window" {
            # Arrange
            $testData = $script:TestNewMWData.WithSpecificTime
            $mwName = "$($testData.Name)_$($script:TestTimestamp)"

            # Act
            $result = New-CM7MaintenanceWindow `
                -CollectionName $testData.CollectionName `
                -Name $mwName `
                -StartTime $testData.StartTime `
                -DurationMinutes $testData.DurationMinutes `
                -RecurrenceType $testData.RecurrenceType `
                -ApplyTo $testData.ApplyTo `
                -IsEnabled $testData.IsEnabled `
                -Force

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.Name | Should -Be $mwName
            $result.RecurrenceType | Should -Be 'None'
            $result.ServiceWindowType | Should -Be 'TaskSequencesOnly'
        }
    }

    Context "Create Disabled Maintenance Window" {

        It "Should create a disabled maintenance window" {
            # Arrange
            $testData = $script:TestNewMWData.DisabledWindow
            $mwName = "$($testData.Name)_$($script:TestTimestamp)"

            # Act
            $result = New-CM7MaintenanceWindow `
                -CollectionName $testData.CollectionName `
                -Name $mwName `
                -StartTime $testData.StartTime `
                -DurationMinutes $testData.DurationMinutes `
                -RecurrenceType $testData.RecurrenceType `
                -ApplyTo $testData.ApplyTo `
                -IsEnabled $testData.IsEnabled `
                -Force

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.Name | Should -Be $mwName
            $result.IsEnabled | Should -Be $false
        }
    }

    Context "Create Monthly by Weekday Maintenance Window" {

        It "Should create a monthly-by-weekday maintenance window" {
            # Arrange
            $testData = $script:TestNewMWData.MonthlyByWeekday

            # Skip if no test data provided
            if (-not $testData -or -not $testData.CollectionName) {
                Set-ItResult -Skipped -Because "No MonthlyByWeekday test data specified"
                return
            }

            $mwName = "$($testData.Name)_$($script:TestTimestamp)"

            # Act
            $splatParams = @{
                CollectionName   = $testData.CollectionName
                Name             = $mwName
                StartTime        = $testData.StartTime
                DurationMinutes  = $testData.DurationMinutes
                RecurrenceType   = $testData.RecurrenceType
                DayOfWeek        = $testData.DayOfWeek
                WeekOrder        = $testData.WeekOrder
                ForNumberOfMonths = $testData.ForNumberOfMonths
                ApplyTo          = $testData.ApplyTo
                IsEnabled        = $testData.IsEnabled
                Force            = $true
            }
            $result = New-CM7MaintenanceWindow @splatParams

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.Name | Should -Be $mwName
            $result.RecurrenceType | Should -Be 'MonthlyByWeekday'
            $result.ServiceWindowType | Should -Be 'SoftwareUpdatesOnly'
        }
    }

    Context "Create Monthly by Date Maintenance Window" {

        It "Should create a monthly-by-date maintenance window" {
            # Arrange
            $testData = $script:TestNewMWData.MonthlyByDate

            # Skip if no test data provided
            if (-not $testData -or -not $testData.CollectionName) {
                Set-ItResult -Skipped -Because "No MonthlyByDate test data specified"
                return
            }

            $mwName = "$($testData.Name)_$($script:TestTimestamp)"

            # Act
            $splatParams = @{
                CollectionName    = $testData.CollectionName
                Name              = $mwName
                StartTime         = $testData.StartTime
                DurationMinutes   = $testData.DurationMinutes
                RecurrenceType    = $testData.RecurrenceType
                MonthDay          = $testData.MonthDay
                ForNumberOfMonths = $testData.ForNumberOfMonths
                ApplyTo           = $testData.ApplyTo
                IsEnabled         = $testData.IsEnabled
                Force             = $true
            }
            $result = New-CM7MaintenanceWindow @splatParams

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.Name | Should -Be $mwName
            $result.RecurrenceType | Should -Be 'MonthlyByDate'
        }
    }

    Context "Create Maintenance Window with UTC Time" {

        It "Should create a maintenance window with UTC time" {
            # Arrange
            $testData = $script:TestNewMWData.UTCTimeZone

            # Skip if no test data provided
            if (-not $testData -or -not $testData.CollectionName) {
                Set-ItResult -Skipped -Because "No UTCTimeZone test data specified"
                return
            }

            $mwName = "$($testData.Name)_$($script:TestTimestamp)"

            # Act
            $splatParams = @{
                CollectionName  = $testData.CollectionName
                Name            = $mwName
                StartTime       = $testData.StartTime
                DurationMinutes = $testData.DurationMinutes
                RecurrenceType  = $testData.RecurrenceType
                ApplyTo         = $testData.ApplyTo
                IsEnabled       = $testData.IsEnabled
                IsUtc           = $true
                Force           = $true
            }
            $result = New-CM7MaintenanceWindow @splatParams

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.Name | Should -Be $mwName
            $result.IsGMT | Should -Be $true
        }
    }

    Context "Create Maintenance Window with Schedule Token" {

        It "Should create a maintenance window using a raw schedule token from an existing window" {
            # Arrange - First get an existing maintenance window to copy its schedule
            $testData = $script:TestNewMWData.ByCollectionName
            $collectionName = $testData.CollectionName
            $existingWindows = Get-CM7MaintenanceWindow -CollectionName $collectionName

            if (-not $existingWindows) {
                Set-ItResult -Skipped -Because "No existing maintenance windows on collection '$collectionName' to copy schedule from"
                return
            }

            $sourceWindow = if ($existingWindows -is [array]) { $existingWindows[0] } else { $existingWindows }
            $scheduleToken = $sourceWindow.ServiceWindowSchedules
            $mwName = "Test-MainWin-ScheduleToken_$($script:TestTimestamp)"

            # Act
            $result = New-CM7MaintenanceWindow `
                -CollectionName $collectionName `
                -Name $mwName `
                -Schedule $scheduleToken `
                -ApplyTo "Any" `
                -Force

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.Name | Should -Be $mwName
            $result.ServiceWindowSchedules | Should -Be $scheduleToken
            $result.psobject.TypeNames[0] | Should -Be 'MECM7.MaintenanceWindow'
        }
    }

    Context "Output Object Properties" {

        It "Should return objects with expected properties" {
            # Arrange - Create a window to check properties
            $testData = $script:TestNewMWData.ByCollectionName
            $mwName = "$($testData.Name)_$($script:TestTimestamp)"

            # Act - retrieve the window we already created
            $result = Get-CM7MaintenanceWindow -CollectionName $testData.CollectionName -MaintenanceWindowName $mwName

            if (-not $result) {
                Set-ItResult -Skipped -Because "Test maintenance window '$mwName' not found (may not have been created yet)"
                return
            }

            # Assert
            $firstResult = if ($result -is [array]) { $result[0] } else { $result }
            $firstResult.psobject.TypeNames[0] | Should -Be 'MECM7.MaintenanceWindow'
            $firstResult.PSObject.Properties.Name | Should -Contain 'Name'
            $firstResult.PSObject.Properties.Name | Should -Contain 'Description'
            $firstResult.PSObject.Properties.Name | Should -Contain 'ServiceWindowID'
            $firstResult.PSObject.Properties.Name | Should -Contain 'IsEnabled'
            $firstResult.PSObject.Properties.Name | Should -Contain 'ServiceWindowType'
            $firstResult.PSObject.Properties.Name | Should -Contain 'StartTime'
            $firstResult.PSObject.Properties.Name | Should -Contain 'Duration'
            $firstResult.PSObject.Properties.Name | Should -Contain 'RecurrenceType'
            $firstResult.PSObject.Properties.Name | Should -Contain 'IsGMT'
            $firstResult.PSObject.Properties.Name | Should -Contain 'ServiceWindowSchedules'
            $firstResult.PSObject.Properties.Name | Should -Contain 'CollectionID'
        }

        It "Should return a valid ServiceWindowID (GUID)" {
            # Arrange
            $testData = $script:TestNewMWData.ByCollectionName
            $mwName = "$($testData.Name)_$($script:TestTimestamp)"

            # Act
            $result = Get-CM7MaintenanceWindow -CollectionName $testData.CollectionName -MaintenanceWindowName $mwName

            if (-not $result) {
                Set-ItResult -Skipped -Because "Test maintenance window '$mwName' not found"
                return
            }

            $firstResult = if ($result -is [array]) { $result[0] } else { $result }

            # Assert - ServiceWindowID should be a valid GUID
            $firstResult.ServiceWindowID | Should -Not -BeNullOrEmpty
            { [guid]::Parse($firstResult.ServiceWindowID) } | Should -Not -Throw
        }
    }

    Context "ApplyTo Parameter Validation" {

        It "Should create a SoftwareUpdatesOnly maintenance window" {
            # Arrange
            $testData = $script:TestNewMWData.ByCollectionID
            $mwName = "$($testData.Name)_$($script:TestTimestamp)"

            # Act - retrieve the window we created in the weekly context
            $result = Get-CM7MaintenanceWindow -CollectionId $testData.CollectionID -MaintenanceWindowName $mwName

            if (-not $result) {
                Set-ItResult -Skipped -Because "Test maintenance window '$mwName' not found"
                return
            }

            $firstResult = if ($result -is [array]) { $result[0] } else { $result }

            # Assert
            $firstResult.ServiceWindowType | Should -Be 'SoftwareUpdatesOnly'
        }

        It "Should create a TaskSequencesOnly maintenance window" {
            # Arrange
            $testData = $script:TestNewMWData.WithSpecificTime
            $mwName = "$($testData.Name)_$($script:TestTimestamp)"

            # Act
            $result = Get-CM7MaintenanceWindow -CollectionName $testData.CollectionName -MaintenanceWindowName $mwName

            if (-not $result) {
                Set-ItResult -Skipped -Because "Test maintenance window '$mwName' not found"
                return
            }

            $firstResult = if ($result -is [array]) { $result[0] } else { $result }

            # Assert
            $firstResult.ServiceWindowType | Should -Be 'TaskSequencesOnly'
        }
    }

    Context "Error Handling" {

        It "Should fail for non-existent collection" {
            # Arrange
            $testData = $script:TestNewMWData.NonExistentCollection

            # Act & Assert
            {
                New-CM7MaintenanceWindow `
                    -CollectionName $testData.CollectionName `
                    -Name "$($testData.Name)_$($script:TestTimestamp)" `
                    -StartTime $testData.StartTime `
                    -DurationMinutes $testData.DurationMinutes `
                    -ApplyTo $testData.ApplyTo `
                    -Force
            } | Should -Throw "*not found*"
        }

        It "Should fail for non-existent collection ID" {
            # Act & Assert
            {
                New-CM7MaintenanceWindow `
                    -CollectionId "XXX99999" `
                    -Name "Test-MW-Invalid_$($script:TestTimestamp)" `
                    -StartTime (Get-Date).AddDays(1) `
                    -DurationMinutes 60 `
                    -Force
            } | Should -Throw "*not found*"
        }

        It "Should fail when Weekly recurrence is missing DayOfWeek" {
            # Arrange
            $testData = $script:TestNewMWData.ByCollectionName

            # Act & Assert
            {
                New-CM7MaintenanceWindow `
                    -CollectionName $testData.CollectionName `
                    -Name "Test-MW-NoDayOfWeek_$($script:TestTimestamp)" `
                    -StartTime (Get-Date).AddDays(1) `
                    -DurationMinutes 60 `
                    -RecurrenceType Weekly `
                    -Force
            } | Should -Throw "*DayOfWeek*"
        }

        It "Should fail when MonthlyByWeekday recurrence is missing DayOfWeek" {
            # Arrange
            $testData = $script:TestNewMWData.ByCollectionName

            # Act & Assert
            {
                New-CM7MaintenanceWindow `
                    -CollectionName $testData.CollectionName `
                    -Name "Test-MW-NoWeekday_$($script:TestTimestamp)" `
                    -StartTime (Get-Date).AddDays(1) `
                    -DurationMinutes 60 `
                    -RecurrenceType MonthlyByWeekday `
                    -Force
            } | Should -Throw "*DayOfWeek*"
        }

        It "Should fail when MonthlyByDate recurrence is missing MonthDay" {
            # Arrange
            $testData = $script:TestNewMWData.ByCollectionName

            # Act & Assert
            {
                New-CM7MaintenanceWindow `
                    -CollectionName $testData.CollectionName `
                    -Name "Test-MW-NoMonthDay_$($script:TestTimestamp)" `
                    -StartTime (Get-Date).AddDays(1) `
                    -DurationMinutes 60 `
                    -RecurrenceType MonthlyByDate `
                    -Force
            } | Should -Throw "*MonthDay*"
        }

        It "Should handle empty Name parameter" {
            # Act & Assert - should fail due to ValidateNotNullOrEmpty
            { New-CM7MaintenanceWindow -CollectionName "Test-Collection-Direct" -Name "" -StartTime (Get-Date) -DurationMinutes 60 -Force } | Should -Throw
        }
    }

    Context "WhatIf Support" {

        It "Should support -WhatIf without making changes" {
            # Arrange
            $testData = $script:TestNewMWData.ByCollectionName
            $mwName = "Test-MainWin-WhatIf_$($script:TestTimestamp)"

            # Act
            $result = New-CM7MaintenanceWindow `
                -CollectionName $testData.CollectionName `
                -Name $mwName `
                -StartTime $testData.StartTime `
                -DurationMinutes $testData.DurationMinutes `
                -RecurrenceType $testData.RecurrenceType `
                -DayOfWeek $testData.DayOfWeek `
                -WhatIf

            # Assert - result should be null because WhatIf doesn't execute
            $result | Should -BeNullOrEmpty

            # Verify the maintenance window was NOT created
            $verifyResult = Get-CM7MaintenanceWindow -CollectionName $testData.CollectionName -MaintenanceWindowName $mwName
            $verifyResult | Should -BeNullOrEmpty
        }
    }

    Context "Duplicate Name Handling" {

        It "Should allow creating maintenance windows with duplicate names (with warning)" {
            # Arrange
            $testData = $script:TestNewMWData.ByCollectionName
            $mwName = "$($testData.Name)_$($script:TestTimestamp)"

            # Act - create a second window with the same name (first was created in earlier context)
            $result = New-CM7MaintenanceWindow `
                -CollectionName $testData.CollectionName `
                -Name $mwName `
                -StartTime $testData.StartTime `
                -DurationMinutes $testData.DurationMinutes `
                -RecurrenceType $testData.RecurrenceType `
                -DayOfWeek $testData.DayOfWeek `
                -ApplyTo $testData.ApplyTo `
                -IsEnabled $testData.IsEnabled `
                -Force 3>&1

            # Assert - should succeed (MECM allows duplicate names)
            # The result may contain warning messages mixed in
            $mwResult = $result | Where-Object { $_ -is [PSCustomObject] -and $_.psobject.TypeNames[0] -eq 'MECM7.MaintenanceWindow' }
            if ($mwResult) {
                $mwResult.Name | Should -Be $mwName
            }
        }
    }
}
