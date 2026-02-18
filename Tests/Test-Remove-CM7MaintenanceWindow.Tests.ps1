# Functional Tests for Remove-CM7MaintenanceWindow
# Tests the Remove-CM7MaintenanceWindow function behavior and return values

BeforeAll {
    # Load test declarations
    . (Join-Path $PSScriptRoot "declarations.ps1")

    # Load all functions
    $CodePath = Join-Path (Get-Item $PSScriptRoot).Parent.FullName "Code"
    Get-ChildItem -Path (Join-Path $CodePath "Private") -Filter "*.ps1" | ForEach-Object { . $_.FullName }
    Get-ChildItem -Path (Join-Path $CodePath "Public") -Filter "*.ps1" | ForEach-Object { . $_.FullName }

    # Get test data for this function
    $script:TestRemoveMWData = $script:TestData['Remove-CM7MaintenanceWindow']
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

    # Helper function to create a test maintenance window for removal tests
    function script:New-TestMaintenanceWindow {
        param(
            [string]$CollectionName,
            [string]$CollectionId,
            [string]$Name
        )
        $params = @{
            Name            = $Name
            StartTime       = (Get-Date).AddDays(1).Date.AddHours(22)
            DurationMinutes = 60
            RecurrenceType  = 'None'
            ApplyTo         = 'Any'
            IsEnabled       = $true
            Force           = $true
        }
        if ($CollectionName) { $params.CollectionName = $CollectionName }
        if ($CollectionId) { $params.CollectionId = $CollectionId }
        New-CM7MaintenanceWindow @params
    }
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
        if ($script:TestRemoveMWData.ByCollectionName.CollectionName) {
            $cleanupCollections += $script:TestRemoveMWData.ByCollectionName.CollectionName
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

Describe "Remove-CM7MaintenanceWindow Function Tests" -Tag "Integration", "Collection", "MaintenanceWindow" {

    Context "Test Data Validation" {

        It "Should have test data defined in declarations.ps1" {
            $script:TestRemoveMWData | Should -Not -BeNullOrEmpty
            $script:TestData.ContainsKey('Remove-CM7MaintenanceWindow') | Should -Be $true
        }

        It "Should have required test data parameter sets" {
            $script:TestRemoveMWData.ContainsKey('ByCollectionName') | Should -Be $true
            $script:TestRemoveMWData.ContainsKey('ByCollectionID') | Should -Be $true
            $script:TestRemoveMWData.ContainsKey('NonExistentCollection') | Should -Be $true
            $script:TestRemoveMWData.ContainsKey('NonExistentMaintenanceWindow') | Should -Be $true
        }

        It "Should output test data for verification" {
            Write-Host "`n=== Test Data for Remove-CM7MaintenanceWindow ===" -ForegroundColor Cyan
            Write-Host "ByCollectionName:" -ForegroundColor Yellow
            Write-Host "  CollectionName: $($script:TestRemoveMWData.ByCollectionName.CollectionName)" -ForegroundColor White
            Write-Host "  MaintenanceWindowName: $($script:TestRemoveMWData.ByCollectionName.MaintenanceWindowName)" -ForegroundColor White

            Write-Host "ByCollectionID:" -ForegroundColor Yellow
            Write-Host "  CollectionID: $($script:TestRemoveMWData.ByCollectionID.CollectionID)" -ForegroundColor White
            Write-Host "  MaintenanceWindowName: $($script:TestRemoveMWData.ByCollectionID.MaintenanceWindowName)" -ForegroundColor White

            Write-Host "NonExistentCollection:" -ForegroundColor Yellow
            Write-Host "  CollectionName: $($script:TestRemoveMWData.NonExistentCollection.CollectionName)" -ForegroundColor White

            Write-Host "NonExistentMaintenanceWindow:" -ForegroundColor Yellow
            Write-Host "  CollectionName: $($script:TestRemoveMWData.NonExistentMaintenanceWindow.CollectionName)" -ForegroundColor White
            Write-Host "  MaintenanceWindowName: $($script:TestRemoveMWData.NonExistentMaintenanceWindow.MaintenanceWindowName)" -ForegroundColor White
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
            { Remove-CM7MaintenanceWindow -CollectionName "Test" -MaintenanceWindowName "Test" -Force } | Should -Throw "*not connected*"

            # Restore connection
            $script:CMConnection = $backupConnection
        }
    }

    Context "Parameter Validation" {

        It "Should fail when neither MaintenanceWindowName nor ServiceWindowID is provided" {
            # Act & Assert
            { Remove-CM7MaintenanceWindow -CollectionName "Test-Collection-Direct" -Force } | Should -Throw "*MaintenanceWindowName*ServiceWindowID*"
        }
    }

    Context "Remove Maintenance Window by Collection Name" {

        It "Should create a test maintenance window for removal" {
            # Arrange
            $testData = $script:TestRemoveMWData.ByCollectionName
            $mwName = "$($testData.MaintenanceWindowName)_$($script:TestTimestamp)"

            # Act - Create a maintenance window to remove
            $result = script:New-TestMaintenanceWindow -CollectionName $testData.CollectionName -Name $mwName

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.Name | Should -Be $mwName
            $script:CreatedMWByName = $result
        }

        It "Should remove the maintenance window by collection name" {
            # Arrange
            $testData = $script:TestRemoveMWData.ByCollectionName
            $mwName = "$($testData.MaintenanceWindowName)_$($script:TestTimestamp)"

            # Act
            $result = Remove-CM7MaintenanceWindow `
                -CollectionName $testData.CollectionName `
                -MaintenanceWindowName $mwName `
                -Force

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.Name | Should -Be $mwName
            $result.psobject.TypeNames[0] | Should -Be 'MECM7.RemovedMaintenanceWindow'
            $result.Status | Should -Be 'Removed'
            $result.CollectionID | Should -Not -BeNullOrEmpty
        }

        It "Should verify the maintenance window no longer exists after removal" {
            # Arrange
            $testData = $script:TestRemoveMWData.ByCollectionName
            $mwName = "$($testData.MaintenanceWindowName)_$($script:TestTimestamp)"

            # Act
            $result = Get-CM7MaintenanceWindow -CollectionName $testData.CollectionName -MaintenanceWindowName $mwName

            # Assert
            $result | Should -BeNullOrEmpty
        }
    }

    Context "Remove Maintenance Window by Collection ID" {

        It "Should create a test maintenance window for removal by Collection ID" {
            # Arrange
            $testData = $script:TestRemoveMWData.ByCollectionID
            $mwName = "$($testData.MaintenanceWindowName)_$($script:TestTimestamp)"

            # Act - Create a maintenance window to remove
            $result = script:New-TestMaintenanceWindow -CollectionId $testData.CollectionID -Name $mwName

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.Name | Should -Be $mwName
        }

        It "Should remove the maintenance window by collection ID" {
            # Arrange
            $testData = $script:TestRemoveMWData.ByCollectionID
            $mwName = "$($testData.MaintenanceWindowName)_$($script:TestTimestamp)"

            # Act
            $result = Remove-CM7MaintenanceWindow `
                -CollectionId $testData.CollectionID `
                -MaintenanceWindowName $mwName `
                -Force

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.Name | Should -Be $mwName
            $result.psobject.TypeNames[0] | Should -Be 'MECM7.RemovedMaintenanceWindow'
            $result.Status | Should -Be 'Removed'
            $result.CollectionID | Should -Be $testData.CollectionID
        }

        It "Should verify the maintenance window no longer exists after removal by collection ID" {
            # Arrange
            $testData = $script:TestRemoveMWData.ByCollectionID
            $mwName = "$($testData.MaintenanceWindowName)_$($script:TestTimestamp)"

            # Act
            $result = Get-CM7MaintenanceWindow -CollectionId $testData.CollectionID -MaintenanceWindowName $mwName

            # Assert
            $result | Should -BeNullOrEmpty
        }
    }

    Context "Remove Maintenance Window by ServiceWindowID" {

        It "Should create and then remove a maintenance window by ServiceWindowID" {
            # Arrange
            $testData = $script:TestRemoveMWData.ByServiceWindowID
            $mwName = "Test-RemoveMW-ByGUID_$($script:TestTimestamp)"

            # Create a maintenance window to get its ServiceWindowID
            $created = script:New-TestMaintenanceWindow -CollectionName $testData.CollectionName -Name $mwName

            if (-not $created -or -not $created.ServiceWindowID) {
                Set-ItResult -Skipped -Because "Could not create test maintenance window or ServiceWindowID not returned"
                return
            }

            $serviceWindowId = $created.ServiceWindowID

            # Act
            $result = Remove-CM7MaintenanceWindow `
                -CollectionName $testData.CollectionName `
                -ServiceWindowID $serviceWindowId `
                -Force

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.Name | Should -Be $mwName
            $result.ServiceWindowID | Should -Be $serviceWindowId
            $result.Status | Should -Be 'Removed'
        }
    }

    Context "Remove Maintenance Windows by Wildcard" {

        It "Should create multiple test maintenance windows for wildcard removal" {
            # Arrange
            $testData = $script:TestRemoveMWData.ByWildcard
            $baseName = "Test-RemoveMW-Wildcard_$($script:TestTimestamp)"

            # Create 3 maintenance windows with similar names
            for ($i = 1; $i -le 3; $i++) {
                $mwName = "${baseName}_MW${i}"
                $result = script:New-TestMaintenanceWindow -CollectionName $testData.CollectionName -Name $mwName
                $result | Should -Not -BeNullOrEmpty
            }
        }

        It "Should remove all maintenance windows matching a wildcard pattern" {
            # Arrange
            $testData = $script:TestRemoveMWData.ByWildcard
            $wildcardPattern = "Test-RemoveMW-Wildcard_$($script:TestTimestamp)*"

            # Act
            $results = Remove-CM7MaintenanceWindow `
                -CollectionName $testData.CollectionName `
                -MaintenanceWindowName $wildcardPattern `
                -Force

            # Assert
            $results | Should -Not -BeNullOrEmpty
            @($results).Count | Should -Be 3
            $results | ForEach-Object {
                $_.psobject.TypeNames[0] | Should -Be 'MECM7.RemovedMaintenanceWindow'
                $_.Status | Should -Be 'Removed'
            }
        }

        It "Should verify no matching maintenance windows remain after wildcard removal" {
            # Arrange
            $testData = $script:TestRemoveMWData.ByWildcard
            $wildcardPattern = "Test-RemoveMW-Wildcard_$($script:TestTimestamp)*"

            # Act
            $result = Get-CM7MaintenanceWindow -CollectionName $testData.CollectionName -MaintenanceWindowName $wildcardPattern

            # Assert
            $result | Should -BeNullOrEmpty
        }
    }

    Context "Output Object Properties" {

        It "Should return objects with all expected properties" {
            # Arrange - Create a maintenance window to remove and inspect output
            $testData = $script:TestRemoveMWData.ByCollectionName
            $mwName = "Test-RemoveMW-Props_$($script:TestTimestamp)"

            $created = script:New-TestMaintenanceWindow -CollectionName $testData.CollectionName -Name $mwName

            if (-not $created) {
                Set-ItResult -Skipped -Because "Could not create test maintenance window"
                return
            }

            # Act
            $result = Remove-CM7MaintenanceWindow `
                -CollectionName $testData.CollectionName `
                -MaintenanceWindowName $mwName `
                -Force

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.psobject.TypeNames[0] | Should -Be 'MECM7.RemovedMaintenanceWindow'
            $result.PSObject.Properties.Name | Should -Contain 'Name'
            $result.PSObject.Properties.Name | Should -Contain 'Description'
            $result.PSObject.Properties.Name | Should -Contain 'ServiceWindowID'
            $result.PSObject.Properties.Name | Should -Contain 'IsEnabled'
            $result.PSObject.Properties.Name | Should -Contain 'ServiceWindowType'
            $result.PSObject.Properties.Name | Should -Contain 'StartTime'
            $result.PSObject.Properties.Name | Should -Contain 'Duration'
            $result.PSObject.Properties.Name | Should -Contain 'RecurrenceType'
            $result.PSObject.Properties.Name | Should -Contain 'IsGMT'
            $result.PSObject.Properties.Name | Should -Contain 'ServiceWindowSchedules'
            $result.PSObject.Properties.Name | Should -Contain 'CollectionID'
            $result.PSObject.Properties.Name | Should -Contain 'Status'
            $result.Status | Should -Be 'Removed'
        }

        It "Should return a valid ServiceWindowID (GUID)" {
            # Arrange - Create and remove a maintenance window to check GUID
            $testData = $script:TestRemoveMWData.ByCollectionName
            $mwName = "Test-RemoveMW-GUID_$($script:TestTimestamp)"

            $created = script:New-TestMaintenanceWindow -CollectionName $testData.CollectionName -Name $mwName

            if (-not $created) {
                Set-ItResult -Skipped -Because "Could not create test maintenance window"
                return
            }

            # Act
            $result = Remove-CM7MaintenanceWindow `
                -CollectionName $testData.CollectionName `
                -MaintenanceWindowName $mwName `
                -Force

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.ServiceWindowID | Should -Not -BeNullOrEmpty
            { [guid]::Parse($result.ServiceWindowID) } | Should -Not -Throw
        }
    }

    Context "Error Handling" {

        It "Should fail for non-existent collection" {
            # Arrange
            $testData = $script:TestRemoveMWData.NonExistentCollection

            # Act & Assert
            {
                Remove-CM7MaintenanceWindow `
                    -CollectionName $testData.CollectionName `
                    -MaintenanceWindowName $testData.MaintenanceWindowName `
                    -Force
            } | Should -Throw "*not found*"
        }

        It "Should fail for non-existent collection ID" {
            # Act & Assert
            {
                Remove-CM7MaintenanceWindow `
                    -CollectionId "XXX99999" `
                    -MaintenanceWindowName "Test-RemoveMW_$($script:TestTimestamp)" `
                    -Force
            } | Should -Throw "*not found*"
        }

        It "Should warn for non-existent maintenance window name" {
            # Arrange
            $testData = $script:TestRemoveMWData.NonExistentMaintenanceWindow

            # Act - Should produce a warning, not an error
            $result = Remove-CM7MaintenanceWindow `
                -CollectionName $testData.CollectionName `
                -MaintenanceWindowName $testData.MaintenanceWindowName `
                -Force 3>&1

            # Assert - Result should be null or contain warnings, no objects
            $mwResult = $result | Where-Object { $_ -is [PSCustomObject] -and $_.psobject.TypeNames[0] -eq 'MECM7.RemovedMaintenanceWindow' }
            $mwResult | Should -BeNullOrEmpty
        }

        It "Should handle empty MaintenanceWindowName parameter" {
            # Act & Assert - should fail due to ValidateNotNullOrEmpty
            { Remove-CM7MaintenanceWindow -CollectionName "Test-Collection-Direct" -MaintenanceWindowName "" -Force } | Should -Throw
        }
    }

    Context "WhatIf Support" {

        It "Should support -WhatIf without making changes" {
            # Arrange - Create a maintenance window to test WhatIf
            $testData = $script:TestRemoveMWData.ByCollectionName
            $mwName = "Test-RemoveMW-WhatIf_$($script:TestTimestamp)"

            $created = script:New-TestMaintenanceWindow -CollectionName $testData.CollectionName -Name $mwName

            if (-not $created) {
                Set-ItResult -Skipped -Because "Could not create test maintenance window"
                return
            }

            # Act
            $result = Remove-CM7MaintenanceWindow `
                -CollectionName $testData.CollectionName `
                -MaintenanceWindowName $mwName `
                -WhatIf

            # Assert - result should be null because WhatIf doesn't execute
            $result | Should -BeNullOrEmpty

            # Verify the maintenance window was NOT removed
            $verifyResult = Get-CM7MaintenanceWindow -CollectionName $testData.CollectionName -MaintenanceWindowName $mwName
            $verifyResult | Should -Not -BeNullOrEmpty
            $verifyResult.Name | Should -Be $mwName
        }
    }

    Context "Remove with Combined Name and ServiceWindowID" {

        It "Should remove a maintenance window when both Name and ServiceWindowID match" {
            # Arrange
            $testData = $script:TestRemoveMWData.ByCollectionName
            $mwName = "Test-RemoveMW-Combined_$($script:TestTimestamp)"

            $created = script:New-TestMaintenanceWindow -CollectionName $testData.CollectionName -Name $mwName

            if (-not $created -or -not $created.ServiceWindowID) {
                Set-ItResult -Skipped -Because "Could not create test maintenance window or ServiceWindowID not returned"
                return
            }

            # Act
            $result = Remove-CM7MaintenanceWindow `
                -CollectionName $testData.CollectionName `
                -MaintenanceWindowName $mwName `
                -ServiceWindowID $created.ServiceWindowID `
                -Force

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.Name | Should -Be $mwName
            $result.ServiceWindowID | Should -Be $created.ServiceWindowID
            $result.Status | Should -Be 'Removed'
        }

        It "Should not remove when Name matches but ServiceWindowID does not" {
            # Arrange
            $testData = $script:TestRemoveMWData.ByCollectionName
            $mwName = "Test-RemoveMW-Mismatch_$($script:TestTimestamp)"

            $created = script:New-TestMaintenanceWindow -CollectionName $testData.CollectionName -Name $mwName

            if (-not $created) {
                Set-ItResult -Skipped -Because "Could not create test maintenance window"
                return
            }

            $fakeGuid = [guid]::NewGuid().ToString()

            # Act - Should produce a warning
            $result = Remove-CM7MaintenanceWindow `
                -CollectionName $testData.CollectionName `
                -MaintenanceWindowName $mwName `
                -ServiceWindowID $fakeGuid `
                -Force 3>&1

            # Assert - No removal should have occurred
            $mwResult = $result | Where-Object { $_ -is [PSCustomObject] -and $_.psobject.TypeNames[0] -eq 'MECM7.RemovedMaintenanceWindow' }
            $mwResult | Should -BeNullOrEmpty

            # Verify the MW still exists
            $verifyResult = Get-CM7MaintenanceWindow -CollectionName $testData.CollectionName -MaintenanceWindowName $mwName
            $verifyResult | Should -Not -BeNullOrEmpty
        }
    }
}
