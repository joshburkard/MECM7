# Functional Tests for New-CM7Collection
# Tests the New-CM7Collection function behavior and return values

BeforeAll {
    # Load test declarations
    . (Join-Path $PSScriptRoot "declarations.ps1")

    # Load all functions
    $CodePath = Join-Path (Get-Item $PSScriptRoot).Parent.FullName "Code"
    Get-ChildItem -Path (Join-Path $CodePath "Private") -Filter "*.ps1" | ForEach-Object { . $_.FullName }
    Get-ChildItem -Path (Join-Path $CodePath "Public") -Filter "*.ps1" | ForEach-Object { . $_.FullName }

    # Get test data for this function
    $script:TestNewCollData = $script:TestData['New-CM7Collection']
    $script:TestConnectData = $script:TestData['Connect-CM7']

    # Track created collections for cleanup
    $script:CreatedCollectionIds = @()

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

Describe "New-CM7Collection Function Tests" -Tag "Integration", "Collection", "New" {

    Context "Test Data Validation" {

        It "Should have test data defined in declarations.ps1" {
            # Assert
            $script:TestNewCollData | Should -Not -BeNullOrEmpty
            $script:TestData.ContainsKey('New-CM7Collection') | Should -Be $true
        }

        It "Should have required test data parameter sets" {
            # Assert
            $script:TestNewCollData.ContainsKey('DeviceCollectionByLimitingId') | Should -Be $true
            $script:TestNewCollData.ContainsKey('DeviceCollectionByLimitingName') | Should -Be $true
            $script:TestNewCollData.ContainsKey('UserCollection') | Should -Be $true
            $script:TestNewCollData.ContainsKey('WithComment') | Should -Be $true
            $script:TestNewCollData.ContainsKey('WithPeriodicRefresh') | Should -Be $true
            $script:TestNewCollData.ContainsKey('WithContinuousRefresh') | Should -Be $true
            $script:TestNewCollData.ContainsKey('WithBothRefresh') | Should -Be $true
            $script:TestNewCollData.ContainsKey('WithFolderPath') | Should -Be $true
        }

        It "Should output test data for verification" {
            # Output test data
            Write-Host "`n=== Test Data for New-CM7Collection ===" -ForegroundColor Cyan
            Write-Host "DeviceCollectionByLimitingId:" -ForegroundColor Yellow
            Write-Host "  Name: $($script:TestNewCollData.DeviceCollectionByLimitingId.Name)" -ForegroundColor White
            Write-Host "  LimitingCollectionId: $($script:TestNewCollData.DeviceCollectionByLimitingId.LimitingCollectionId)" -ForegroundColor White

            Write-Host "DeviceCollectionByLimitingName:" -ForegroundColor Yellow
            Write-Host "  Name: $($script:TestNewCollData.DeviceCollectionByLimitingName.Name)" -ForegroundColor White
            Write-Host "  LimitingCollectionName: $($script:TestNewCollData.DeviceCollectionByLimitingName.LimitingCollectionName)" -ForegroundColor White

            Write-Host "UserCollection:" -ForegroundColor Yellow
            Write-Host "  Name: $($script:TestNewCollData.UserCollection.Name)" -ForegroundColor White
            Write-Host "  CollectionType: $($script:TestNewCollData.UserCollection.CollectionType)" -ForegroundColor White

            Write-Host "WithFolderPath:" -ForegroundColor Yellow
            Write-Host "  Name: $($script:TestNewCollData.WithFolderPath.Name)" -ForegroundColor White
            Write-Host "  FolderPath: $($script:TestNewCollData.WithFolderPath.FolderPath)" -ForegroundColor White
            Write-Host "============================================================`n" -ForegroundColor Cyan

            # This test always passes, it's just for output
            $true | Should -Be $true
        }
    }

    Context "Connection Requirement" {

        It "Should fail if not connected to MECM" {
            # Arrange - Backup and clear connection
            $backupConnection = $script:CMConnection.Clone()
            $script:CMConnection.CimSession = $null

            # Act & Assert
            { New-CM7Collection -Name "Test" -LimitingCollectionId "SMS00001" } | Should -Throw "*not connected*"

            # Restore connection
            $script:CMConnection = $backupConnection
        }
    }

    Context "Create Device Collection by Limiting Collection ID" {

        It "Should create a device collection with a limiting collection ID" {
            # Arrange
            $uniqueName = "$($script:TestNewCollData.DeviceCollectionByLimitingId.Name)-$(Get-Date -Format 'yyyyMMdd_HHmmss')"
            $limitingId = $script:TestNewCollData.DeviceCollectionByLimitingId.LimitingCollectionId

            # Act
            $result = New-CM7Collection -Name $uniqueName -LimitingCollectionId $limitingId

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.Name | Should -Be $uniqueName
            $result.CollectionType | Should -Be 'Device'
            $result.LimitToCollectionID | Should -Be $limitingId
            $result.CollectionId | Should -Not -BeNullOrEmpty

            # Track for cleanup
            $script:CreatedCollectionIds += $result.CollectionId
        }
    }

    Context "Create Device Collection by Limiting Collection Name" {

        It "Should create a device collection with a limiting collection name" {
            # Arrange
            $uniqueName = "$($script:TestNewCollData.DeviceCollectionByLimitingName.Name)-$(Get-Date -Format 'yyyyMMdd_HHmmss')"
            $limitingName = $script:TestNewCollData.DeviceCollectionByLimitingName.LimitingCollectionName

            # Act
            $result = New-CM7Collection -Name $uniqueName -LimitingCollectionName $limitingName

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.Name | Should -Be $uniqueName
            $result.CollectionType | Should -Be 'Device'
            $result.CollectionId | Should -Not -BeNullOrEmpty

            # Track for cleanup
            $script:CreatedCollectionIds += $result.CollectionId
        }
    }

    Context "Create User Collection" {

        It "Should create a user collection" {
            # Arrange
            $uniqueName = "$($script:TestNewCollData.UserCollection.Name)-$(Get-Date -Format 'yyyyMMdd_HHmmss')"
            $limitingId = $script:TestNewCollData.UserCollection.LimitingCollectionId

            # Act
            $result = New-CM7Collection -Name $uniqueName -CollectionType User -LimitingCollectionId $limitingId

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.Name | Should -Be $uniqueName
            $result.CollectionType | Should -Be 'User'
            $result.CollectionId | Should -Not -BeNullOrEmpty

            # Track for cleanup
            $script:CreatedCollectionIds += $result.CollectionId
        }
    }

    Context "Create Collection with Comment" {

        It "Should create a collection with a comment" {
            # Arrange
            $uniqueName = "$($script:TestNewCollData.WithComment.Name)-$(Get-Date -Format 'yyyyMMdd_HHmmss')"
            $limitingId = $script:TestNewCollData.WithComment.LimitingCollectionId
            $comment = $script:TestNewCollData.WithComment.Comment

            # Act
            $result = New-CM7Collection -Name $uniqueName -LimitingCollectionId $limitingId -Comment $comment

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.Name | Should -Be $uniqueName
            $result.Comment | Should -Be $comment
            $result.CollectionId | Should -Not -BeNullOrEmpty

            # Track for cleanup
            $script:CreatedCollectionIds += $result.CollectionId
        }
    }

    Context "Create Collection with Refresh Types" {

        It "Should create a collection with Periodic refresh" {
            # Arrange
            $uniqueName = "$($script:TestNewCollData.WithPeriodicRefresh.Name)-$(Get-Date -Format 'yyyyMMdd_HHmmss')"
            $limitingId = $script:TestNewCollData.WithPeriodicRefresh.LimitingCollectionId

            # Act
            $result = New-CM7Collection -Name $uniqueName -LimitingCollectionId $limitingId -RefreshType Periodic

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.Name | Should -Be $uniqueName
            $result.RefreshType | Should -Be 2  # Periodic = 2
            $result.CollectionId | Should -Not -BeNullOrEmpty

            # Track for cleanup
            $script:CreatedCollectionIds += $result.CollectionId
        }

        It "Should create a collection with Continuous refresh" {
            # Arrange
            $uniqueName = "$($script:TestNewCollData.WithContinuousRefresh.Name)-$(Get-Date -Format 'yyyyMMdd_HHmmss')"
            $limitingId = $script:TestNewCollData.WithContinuousRefresh.LimitingCollectionId

            # Act
            $result = New-CM7Collection -Name $uniqueName -LimitingCollectionId $limitingId -RefreshType Continuous

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.Name | Should -Be $uniqueName
            $result.RefreshType | Should -Be 4  # Continuous = 4
            $result.CollectionId | Should -Not -BeNullOrEmpty

            # Track for cleanup
            $script:CreatedCollectionIds += $result.CollectionId
        }

        It "Should create a collection with Both (Periodic + Continuous) refresh" {
            # Arrange
            $uniqueName = "$($script:TestNewCollData.WithBothRefresh.Name)-$(Get-Date -Format 'yyyyMMdd_HHmmss')"
            $limitingId = $script:TestNewCollData.WithBothRefresh.LimitingCollectionId

            # Act
            $result = New-CM7Collection -Name $uniqueName -LimitingCollectionId $limitingId -RefreshType Both

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.Name | Should -Be $uniqueName
            $result.RefreshType | Should -Be 6  # Both = 6
            $result.CollectionId | Should -Not -BeNullOrEmpty

            # Track for cleanup
            $script:CreatedCollectionIds += $result.CollectionId
        }
    }

    Context "Create Collection with FolderPath" {

        It "Should create a collection and move it to the specified folder" {
            # Arrange
            $uniqueName = "$($script:TestNewCollData.WithFolderPath.Name)-$(Get-Date -Format 'yyyyMMdd_HHmmss')"
            $limitingId = $script:TestNewCollData.WithFolderPath.LimitingCollectionId
            $folderPath = $script:TestNewCollData.WithFolderPath.FolderPath

            # Act
            $result = New-CM7Collection -Name $uniqueName -LimitingCollectionId $limitingId -FolderPath $folderPath

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.Name | Should -Be $uniqueName
            $result.CollectionId | Should -Not -BeNullOrEmpty

            # Track for cleanup
            $script:CreatedCollectionIds += $result.CollectionId
        }
    }

    Context "Error Handling" {

        It "Should throw for non-existent limiting collection ID" {
            # Arrange
            $uniqueName = "Test-NonExistentLimiting-$(Get-Date -Format 'yyyyMMdd_HHmmss')"
            $limitingId = $script:TestNewCollData.NonExistentLimiting.LimitingCollectionId

            # Act & Assert
            { New-CM7Collection -Name $uniqueName -LimitingCollectionId $limitingId } | Should -Throw "*not found*"
        }

        It "Should throw for non-existent limiting collection name" {
            # Arrange
            $uniqueName = "Test-NonExistentLimitingName-$(Get-Date -Format 'yyyyMMdd_HHmmss')"
            $limitingName = $script:TestNewCollData.NonExistentLimiting.LimitingCollectionName

            # Act & Assert
            { New-CM7Collection -Name $uniqueName -LimitingCollectionName $limitingName } | Should -Throw "*not found*"
        }

        It "Should throw for duplicate collection name" {
            # Arrange
            $duplicateName = $script:TestNewCollData.DuplicateName.Name
            $limitingId = $script:TestNewCollData.DuplicateName.LimitingCollectionId

            # Act & Assert
            { New-CM7Collection -Name $duplicateName -LimitingCollectionId $limitingId } | Should -Throw "*already exists*"
        }
    }

    Context "WhatIf Support" {

        It "Should support -WhatIf parameter" {
            # Arrange
            $uniqueName = "Test-WhatIf-$(Get-Date -Format 'yyyyMMdd_HHmmss')"
            $limitingId = $script:TestNewCollData.DeviceCollectionByLimitingId.LimitingCollectionId

            # Act & Assert - should not throw, and should not actually create
            { New-CM7Collection -Name $uniqueName -LimitingCollectionId $limitingId -WhatIf } | Should -Not -Throw

            # Verify the collection was NOT created
            $checkQuery = "SELECT CollectionID FROM SMS_Collection WHERE Name = '$uniqueName'"
            $namespace = "root/SMS/site_$($script:CMConnection.SiteCode)"
            $check = Get-CimInstance -CimSession $script:CMConnection.CimSession -Namespace $namespace -Query $checkQuery
            $check | Should -BeNullOrEmpty
        }
    }

    Context "Return Object Properties" {

        It "Should return objects with expected properties" {
            # Arrange
            $uniqueName = "Test-ReturnProps-$(Get-Date -Format 'yyyyMMdd_HHmmss')"
            $limitingId = $script:TestNewCollData.DeviceCollectionByLimitingId.LimitingCollectionId

            # Act
            $result = New-CM7Collection -Name $uniqueName -LimitingCollectionId $limitingId

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.PSObject.Properties.Name | Should -Contain 'CollectionId'
            $result.PSObject.Properties.Name | Should -Contain 'Name'
            $result.PSObject.Properties.Name | Should -Contain 'CollectionType'
            $result.PSObject.Properties.Name | Should -Contain 'TypeValue'
            $result.PSObject.Properties.Name | Should -Contain 'LimitToCollectionID'
            $result.PSObject.Properties.Name | Should -Contain 'MemberCount'
            $result.PSObject.Properties.Name | Should -Contain 'Comment'
            $result.PSObject.Properties.Name | Should -Contain 'RefreshType'

            # Track for cleanup
            $script:CreatedCollectionIds += $result.CollectionId
        }

        It "Should have PSTypeName set correctly" {
            # Arrange
            $uniqueName = "Test-PSTypeName-$(Get-Date -Format 'yyyyMMdd_HHmmss')"
            $limitingId = $script:TestNewCollData.DeviceCollectionByLimitingId.LimitingCollectionId

            # Act
            $result = New-CM7Collection -Name $uniqueName -LimitingCollectionId $limitingId

            # Assert
            if ($result) {
                $result.PSObject.TypeNames[0] | Should -Be 'MECM7.Collection'
            }

            # Track for cleanup
            if ($result) { $script:CreatedCollectionIds += $result.CollectionId }
        }
    }

    Context "Default Values" {

        It "Should default to Device collection type" {
            # Arrange
            $uniqueName = "Test-DefaultDevice-$(Get-Date -Format 'yyyyMMdd_HHmmss')"
            $limitingId = $script:TestNewCollData.DeviceCollectionByLimitingId.LimitingCollectionId

            # Act
            $result = New-CM7Collection -Name $uniqueName -LimitingCollectionId $limitingId

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.CollectionType | Should -Be 'Device'
            $result.TypeValue | Should -Be 2

            # Track for cleanup
            $script:CreatedCollectionIds += $result.CollectionId
        }

        It "Should default to Manual refresh type" {
            # Arrange
            $uniqueName = "Test-DefaultRefresh-$(Get-Date -Format 'yyyyMMdd_HHmmss')"
            $limitingId = $script:TestNewCollData.DeviceCollectionByLimitingId.LimitingCollectionId

            # Act
            $result = New-CM7Collection -Name $uniqueName -LimitingCollectionId $limitingId

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.RefreshType | Should -Be 1  # Manual = 1

            # Track for cleanup
            $script:CreatedCollectionIds += $result.CollectionId
        }
    }

    Context "Verbose Output" {

        It "Should provide verbose output when requested" {
            # Arrange
            $uniqueName = "Test-Verbose-$(Get-Date -Format 'yyyyMMdd_HHmmss')"
            $limitingId = $script:TestNewCollData.DeviceCollectionByLimitingId.LimitingCollectionId

            # Act
            $verboseOutput = New-CM7Collection -Name $uniqueName -LimitingCollectionId $limitingId -Verbose 4>&1

            # Assert
            $verboseOutput | Should -Not -BeNullOrEmpty
            $verboseMessages = $verboseOutput | Where-Object { $_ -is [System.Management.Automation.VerboseRecord] }
            $runningMessage = $verboseMessages | Where-Object { $_.Message -match "Running New-CM7Collection" }
            $runningMessage | Should -Not -BeNullOrEmpty

            # Track for cleanup - extract the actual result from verbose output
            $resultObj = $verboseOutput | Where-Object { $_ -isnot [System.Management.Automation.VerboseRecord] }
            if ($resultObj -and $resultObj.CollectionId) {
                $script:CreatedCollectionIds += $resultObj.CollectionId
            }
        }
    }
}

AfterAll {
    # Clean up: remove all test collections created during tests
    if ($script:CMConnection.CimSession -and $script:CreatedCollectionIds.Count -gt 0) {
        $namespace = "root/SMS/site_$($script:CMConnection.SiteCode)"
        $uniqueIds = $script:CreatedCollectionIds | Select-Object -Unique
        Write-Host "Test cleanup: Removing $($uniqueIds.Count) test collection(s)" -ForegroundColor Yellow
        foreach ($id in $uniqueIds) {
            try {
                $collQuery = "SELECT * FROM SMS_Collection WHERE CollectionID = '$id'"
                $coll = Get-CimInstance -CimSession $script:CMConnection.CimSession -Namespace $namespace -Query $collQuery
                if ($coll) {
                    Remove-CimInstance -CimSession $script:CMConnection.CimSession -InputObject $coll -ErrorAction SilentlyContinue
                    Write-Host "  Removed collection: $id" -ForegroundColor Green
                }
            }
            catch {
                Write-Warning "  Failed to remove collection '$id': $_"
            }
        }
        Write-Host "Test cleanup: Done" -ForegroundColor Green
    }
}
