# Functional Tests for Get-CM7MaintenanceWindow
# Tests the Get-CM7MaintenanceWindow function behavior and return values

BeforeAll {
    # Load test declarations
    . (Join-Path $PSScriptRoot "declarations.ps1")

    # Load all functions
    $CodePath = Join-Path (Get-Item $PSScriptRoot).Parent.FullName "Code"
    Get-ChildItem -Path (Join-Path $CodePath "Private") -Filter "*.ps1" | ForEach-Object { . $_.FullName }
    Get-ChildItem -Path (Join-Path $CodePath "Public") -Filter "*.ps1" | ForEach-Object { . $_.FullName }

    # Get test data for this function
    $script:TestMaintenanceWindowData = $script:TestData['Get-CM7MaintenanceWindow']
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
}

Describe "Get-CM7MaintenanceWindow Function Tests" -Tag "Integration", "Collection", "MaintenanceWindow" {

    Context "Test Data Validation" {

        It "Should have test data defined in declarations.ps1" {
            $script:TestMaintenanceWindowData | Should -Not -BeNullOrEmpty
            $script:TestData.ContainsKey('Get-CM7MaintenanceWindow') | Should -Be $true
        }

        It "Should have required test data parameter sets" {
            $script:TestMaintenanceWindowData.ContainsKey('ByCollectionName') | Should -Be $true
            $script:TestMaintenanceWindowData.ContainsKey('ByCollectionID') | Should -Be $true
            $script:TestMaintenanceWindowData.ContainsKey('NonExistent') | Should -Be $true
        }

        It "Should output test data for verification" {
            Write-Host "`n=== Test Data for Get-CM7MaintenanceWindow ===" -ForegroundColor Cyan
            Write-Host "ByCollectionName:" -ForegroundColor Yellow
            Write-Host "  CollectionName: $($script:TestMaintenanceWindowData.ByCollectionName.CollectionName)" -ForegroundColor White
            Write-Host "ByCollectionID:" -ForegroundColor Yellow
            Write-Host "  CollectionID: $($script:TestMaintenanceWindowData.ByCollectionID.CollectionID)" -ForegroundColor White
            Write-Host "NonExistent:" -ForegroundColor Yellow
            Write-Host "  CollectionName: $($script:TestMaintenanceWindowData.NonExistent.CollectionName)" -ForegroundColor White
            Write-Host "  CollectionID: $($script:TestMaintenanceWindowData.NonExistent.CollectionID)" -ForegroundColor White
            Write-Host "============================================================`n" -ForegroundColor Cyan
            $true | Should -Be $true
        }
    }

    Context "Connection Requirement" {

        It "Should fail if not connected to MECM" {
            $backupConnection = $script:CMConnection.Clone()
            $script:CMConnection.CimSession = $null
            { Get-CM7MaintenanceWindow -CollectionName "Test" } | Should -Throw "*not connected*"
            $script:CMConnection = $backupConnection
        }
    }

    Context "Query by Collection Name" {

        It "Should output test data for debugging" {
            Write-Host "`nDEBUG: Test Data Values:" -ForegroundColor Cyan
            Write-Host "ByCollectionName.CollectionName = '$($script:TestMaintenanceWindowData.ByCollectionName.CollectionName)'" -ForegroundColor Yellow
            Write-Host "ByCollectionID.CollectionID = '$($script:TestMaintenanceWindowData.ByCollectionID.CollectionID)'" -ForegroundColor Yellow
            Write-Host "NonExistent.CollectionName = '$($script:TestMaintenanceWindowData.NonExistent.CollectionName)'" -ForegroundColor Yellow
            $true | Should -Be $true
        }

        It "Should retrieve maintenance windows by collection name" {
            $collectionName = $script:TestMaintenanceWindowData.ByCollectionName.CollectionName
            $result = Get-CM7MaintenanceWindow -CollectionName $collectionName
            if ($result) {
                if ($result -is [array]) {
                    $result.Count | Should -BeGreaterOrEqual 1
                    $result[0].psobject.TypeNames[0] | Should -Be 'MECM7.MaintenanceWindow'
                } else {
                    $result.psobject.TypeNames[0] | Should -Be 'MECM7.MaintenanceWindow'
                }
            } else {
                # Collection may have no maintenance windows configured
                $result | Should -BeNullOrEmpty
            }
        }

        It "Should return null for non-existent collection" {
            $collectionName = $script:TestMaintenanceWindowData.NonExistent.CollectionName
            $result = Get-CM7MaintenanceWindow -CollectionName $collectionName
            $result | Should -BeNullOrEmpty
        }
    }

    Context "Query by Collection ID" {

        It "Should retrieve maintenance windows by collection ID" {
            $collectionId = $script:TestMaintenanceWindowData.ByCollectionID.CollectionID
            $result = Get-CM7MaintenanceWindow -CollectionId $collectionId
            if ($result) {
                if ($result -is [array]) {
                    $result.Count | Should -BeGreaterOrEqual 1
                    $result[0].psobject.TypeNames[0] | Should -Be 'MECM7.MaintenanceWindow'
                } else {
                    $result.psobject.TypeNames[0] | Should -Be 'MECM7.MaintenanceWindow'
                }
            } else {
                # Collection may have no maintenance windows configured
                $result | Should -BeNullOrEmpty
            }
        }

        It "Should return null for non-existent collection ID" {
            $collectionId = $script:TestMaintenanceWindowData.NonExistent.CollectionID
            $result = Get-CM7MaintenanceWindow -CollectionId $collectionId
            $result | Should -BeNullOrEmpty
        }
    }

    Context "Query with Maintenance Window Name Filter" {

        It "Should retrieve a specific maintenance window by name" {
            $collectionName = $script:TestMaintenanceWindowData.ByCollectionName.CollectionName
            # First get all maintenance windows to find a name to filter on
            $allWindows = Get-CM7MaintenanceWindow -CollectionName $collectionName
            if (-not $allWindows) {
                Set-ItResult -Skipped -Because "No maintenance windows configured on collection '$collectionName'"
                return
            }
            $targetName = if ($allWindows -is [array]) { $allWindows[0].Name } else { $allWindows.Name }
            $result = Get-CM7MaintenanceWindow -CollectionName $collectionName -MaintenanceWindowName $targetName
            if ($result) {
                if ($result -is [array]) {
                    $result.Count | Should -Be 1
                    $result[0].Name | Should -Be $targetName
                    $result[0].psobject.TypeNames[0] | Should -Be 'MECM7.MaintenanceWindow'
                } else {
                    $result.Name | Should -Be $targetName
                    $result.psobject.TypeNames[0] | Should -Be 'MECM7.MaintenanceWindow'
                }
            }
        }

        It "Should support wildcard in maintenance window name" {
            $collectionName = $script:TestMaintenanceWindowData.ByCollectionName.CollectionName
            # First get all maintenance windows to find a pattern to filter on
            $allWindows = Get-CM7MaintenanceWindow -CollectionName $collectionName
            if (-not $allWindows) {
                Set-ItResult -Skipped -Because "No maintenance windows configured on collection '$collectionName'"
                return
            }
            $firstName = if ($allWindows -is [array]) { $allWindows[0].Name } else { $allWindows.Name }
            # Use first 3 characters as wildcard pattern
            $pattern = "$($firstName.Substring(0, [Math]::Min(3, $firstName.Length)))*"
            $result = Get-CM7MaintenanceWindow -CollectionName $collectionName -MaintenanceWindowName $pattern
            if ($result) {
                if ($result -is [array]) {
                    $result[0].psobject.TypeNames[0] | Should -Be 'MECM7.MaintenanceWindow'
                    foreach ($window in $result) {
                        $window.Name | Should -BeLike $pattern
                    }
                } else {
                    $result.psobject.TypeNames[0] | Should -Be 'MECM7.MaintenanceWindow'
                    $result.Name | Should -BeLike $pattern
                }
            }
        }

        It "Should return null for non-existent maintenance window name" {
            $collectionName = $script:TestMaintenanceWindowData.ByCollectionName.CollectionName
            $result = Get-CM7MaintenanceWindow -CollectionName $collectionName -MaintenanceWindowName "NonExistentMaintenanceWindow999"
            $result | Should -BeNullOrEmpty
        }
    }

    Context "Output Object Properties" {

        It "Should return objects with expected properties" {
            $collectionName = $script:TestMaintenanceWindowData.ByCollectionName.CollectionName
            $result = Get-CM7MaintenanceWindow -CollectionName $collectionName
            if (-not $result) {
                Set-ItResult -Skipped -Because "No maintenance windows configured on collection '$collectionName'"
                return
            }
            $firstResult = if ($result -is [array]) { $result[0] } else { $result }
            $firstResult.psobject.TypeNames[0] | Should -Be 'MECM7.MaintenanceWindow'
            $firstResult.Name | Should -Not -BeNullOrEmpty
            $firstResult.PSObject.Properties.Name | Should -Contain 'Name'
            $firstResult.PSObject.Properties.Name | Should -Contain 'Description'
            $firstResult.PSObject.Properties.Name | Should -Contain 'ServiceWindowID'
            $firstResult.PSObject.Properties.Name | Should -Contain 'IsEnabled'
            $firstResult.PSObject.Properties.Name | Should -Contain 'ServiceWindowType'
            $firstResult.PSObject.Properties.Name | Should -Contain 'StartTime'
            $firstResult.PSObject.Properties.Name | Should -Contain 'Duration'
            $firstResult.PSObject.Properties.Name | Should -Contain 'RecurrenceType'
            $firstResult.PSObject.Properties.Name | Should -Contain 'IsGMT'
            $firstResult.PSObject.Properties.Name | Should -Contain 'CollectionID'
        }

        It "Should have correct IsEnabled values" {
            $collectionName = $script:TestMaintenanceWindowData.ByCollectionName.CollectionName
            $result = Get-CM7MaintenanceWindow -CollectionName $collectionName
            if (-not $result) {
                Set-ItResult -Skipped -Because "No maintenance windows configured on collection '$collectionName'"
                return
            }
            foreach ($window in $result) {
                $window.IsEnabled | Should -BeIn @($true, $false)
            }
        }

        It "Should have valid ServiceWindowType values" {
            $collectionName = $script:TestMaintenanceWindowData.ByCollectionName.CollectionName
            $result = Get-CM7MaintenanceWindow -CollectionName $collectionName
            if (-not $result) {
                Set-ItResult -Skipped -Because "No maintenance windows configured on collection '$collectionName'"
                return
            }
            $validTypes = @('General', 'SoftwareUpdatesOnly', 'TaskSequencesOnly')
            foreach ($window in $result) {
                $window.ServiceWindowType | Should -BeIn $validTypes
            }
        }

        It "Should have valid RecurrenceType values" {
            $collectionName = $script:TestMaintenanceWindowData.ByCollectionName.CollectionName
            $result = Get-CM7MaintenanceWindow -CollectionName $collectionName
            if (-not $result) {
                Set-ItResult -Skipped -Because "No maintenance windows configured on collection '$collectionName'"
                return
            }
            $validRecurrenceTypes = @('None', 'Daily', 'Weekly', 'MonthlyByWeekday', 'MonthlyByDate')
            foreach ($window in $result) {
                $window.RecurrenceType | Should -BeIn $validRecurrenceTypes
            }
        }

        It "Should include CollectionID in output" {
            $collectionId = $script:TestMaintenanceWindowData.ByCollectionID.CollectionID
            $result = Get-CM7MaintenanceWindow -CollectionId $collectionId
            if (-not $result) {
                Set-ItResult -Skipped -Because "No maintenance windows configured on collection '$collectionId'"
                return
            }
            $firstResult = if ($result -is [array]) { $result[0] } else { $result }
            $firstResult.CollectionID | Should -Be $collectionId
        }
    }

    Context "Error Handling" {

        It "Should handle invalid collection ID gracefully" {
            $invalidCollectionId = "INVALID123"
            $result = Get-CM7MaintenanceWindow -CollectionId $invalidCollectionId
            $result | Should -BeNullOrEmpty
        }

        It "Should handle empty results gracefully" {
            $collectionName = $script:TestMaintenanceWindowData.NonExistent.CollectionName
            { Get-CM7MaintenanceWindow -CollectionName $collectionName } | Should -Not -Throw
        }
    }
}
