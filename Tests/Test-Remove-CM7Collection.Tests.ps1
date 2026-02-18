# Functional Tests for Remove-CM7Collection
# Tests the Remove-CM7Collection function behavior and return values
# Test collections are created dynamically in the default folder from declarations.ps1
# and removed during the test run itself

BeforeAll {
    # Load test declarations
    . (Join-Path $PSScriptRoot "declarations.ps1")

    # Load all functions
    $CodePath = Join-Path (Get-Item $PSScriptRoot).Parent.FullName "Code"
    Get-ChildItem -Path (Join-Path $CodePath "Private") -Filter "*.ps1" | ForEach-Object { . $_.FullName }
    Get-ChildItem -Path (Join-Path $CodePath "Public") -Filter "*.ps1" | ForEach-Object { . $_.FullName }

    # Get test data for this function
    $script:TestRemoveCollData = $script:TestData['Remove-CM7Collection']
    $script:TestConnectData = $script:TestData['Connect-CM7']

    # Track created collections for cleanup (in case tests fail before removing them)
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

    # Helper function to create a test collection for removal tests
    function New-TestCollectionForRemoval {
        param(
            [string]$NamePrefix = "Test-Remove-Collection",
            [string]$LimitingCollectionId = "SMS00001"
        )
        $uniqueName = "$NamePrefix-$(Get-Date -Format 'yyyyMMdd_HHmmss_fff')-$([guid]::NewGuid().ToString().Substring(0, 8))"
        $newCollParams = @{
            Name                 = $uniqueName
            LimitingCollectionId = $LimitingCollectionId
        }
        # Use folder path from test data if available
        $folderPath = $script:TestRemoveCollData.FolderPath
        if ($folderPath) {
            $newCollParams.FolderPath = $folderPath
        }
        $result = New-CM7Collection @newCollParams
        if ($result) {
            $script:CreatedCollectionIds += $result.CollectionId
            Write-Host "  Created test collection: $($result.Name) ($($result.CollectionId))" -ForegroundColor Gray
        }
        return $result
    }
}

Describe "Remove-CM7Collection Function Tests" -Tag "Integration", "Collection", "Remove" {

    Context "Test Data Validation" {

        It "Should have test data defined in declarations.ps1" {
            # Assert
            $script:TestRemoveCollData | Should -Not -BeNullOrEmpty
            $script:TestData.ContainsKey('Remove-CM7Collection') | Should -Be $true
        }

        It "Should have required test data parameter sets" {
            # Assert
            $script:TestRemoveCollData.ContainsKey('ByName') | Should -Be $true
            $script:TestRemoveCollData.ContainsKey('ById') | Should -Be $true
            $script:TestRemoveCollData.ContainsKey('Protected') | Should -Be $true
        }

        It "Should output test data for verification" {
            # Output test data
            Write-Host "`n=== Test Data for Remove-CM7Collection ===" -ForegroundColor Cyan
            Write-Host "ByName:" -ForegroundColor Yellow
            Write-Host "  CollectionNamePattern: $($script:TestRemoveCollData.ByName.CollectionNamePattern)" -ForegroundColor White

            Write-Host "Protected:" -ForegroundColor Yellow
            Write-Host "  ProtectedCollections: $($script:TestRemoveCollData.Protected.ProtectedCollections -join ', ')" -ForegroundColor White

            if ($script:TestRemoveCollData.FolderPath) {
                Write-Host "FolderPath: $($script:TestRemoveCollData.FolderPath)" -ForegroundColor Yellow
            }
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
            { Remove-CM7Collection -Name "Test" } | Should -Throw "*not connected*"

            # Restore connection
            $script:CMConnection = $backupConnection
        }
    }

    Context "Remove Collection by Name" {

        It "Should create and then remove a collection by name" {
            # Arrange - Create a test collection first
            $testColl = New-TestCollectionForRemoval -NamePrefix "Test-Remove-ByName"
            $testColl | Should -Not -BeNullOrEmpty
            $collName = $testColl.Name

            # Act - Remove by name
            $result = Remove-CM7Collection -Name $collName -Force

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.Name | Should -Be $collName
            $result.CollectionId | Should -Be $testColl.CollectionId
            $result.Status | Should -Be 'Removed'

            # Verify collection is actually gone
            $namespace = "root/SMS/site_$($script:CMConnection.SiteCode)"
            $check = Get-CimInstance -CimSession $script:CMConnection.CimSession -Namespace $namespace -Query "SELECT CollectionID FROM SMS_Collection WHERE CollectionID = '$($testColl.CollectionId)'"
            $check | Should -BeNullOrEmpty

            # Remove from cleanup tracking since we already removed it
            $script:CreatedCollectionIds = $script:CreatedCollectionIds | Where-Object { $_ -ne $testColl.CollectionId }
        }
    }

    Context "Remove Collection by ID" {

        It "Should create and then remove a collection by CollectionId" {
            # Arrange - Create a test collection first
            $testColl = New-TestCollectionForRemoval -NamePrefix "Test-Remove-ById"
            $testColl | Should -Not -BeNullOrEmpty

            # Act - Remove by ID
            $result = Remove-CM7Collection -CollectionId $testColl.CollectionId -Force

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.CollectionId | Should -Be $testColl.CollectionId
            $result.Status | Should -Be 'Removed'

            # Verify collection is actually gone
            $namespace = "root/SMS/site_$($script:CMConnection.SiteCode)"
            $check = Get-CimInstance -CimSession $script:CMConnection.CimSession -Namespace $namespace -Query "SELECT CollectionID FROM SMS_Collection WHERE CollectionID = '$($testColl.CollectionId)'"
            $check | Should -BeNullOrEmpty

            # Remove from cleanup tracking
            $script:CreatedCollectionIds = $script:CreatedCollectionIds | Where-Object { $_ -ne $testColl.CollectionId }
        }
    }

    Context "Remove Collection by InputObject" {

        It "Should remove a collection using InputObject from Get-CM7Collection" {
            # Arrange - Create a test collection first
            $testColl = New-TestCollectionForRemoval -NamePrefix "Test-Remove-InputObj"
            $testColl | Should -Not -BeNullOrEmpty

            # Get the collection object via Get-CM7Collection
            $collObj = Get-CM7Collection -CollectionId $testColl.CollectionId
            $collObj | Should -Not -BeNullOrEmpty

            # Act - Remove by InputObject
            $result = Remove-CM7Collection -InputObject $collObj -Force

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.CollectionId | Should -Be $testColl.CollectionId
            $result.Status | Should -Be 'Removed'

            # Remove from cleanup tracking
            $script:CreatedCollectionIds = $script:CreatedCollectionIds | Where-Object { $_ -ne $testColl.CollectionId }
        }

        It "Should remove a collection via pipeline" {
            # Arrange - Create a test collection first
            $testColl = New-TestCollectionForRemoval -NamePrefix "Test-Remove-Pipeline"
            $testColl | Should -Not -BeNullOrEmpty

            # Act - Remove via pipeline
            $result = Get-CM7Collection -CollectionId $testColl.CollectionId | Remove-CM7Collection -Force

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.CollectionId | Should -Be $testColl.CollectionId
            $result.Status | Should -Be 'Removed'

            # Remove from cleanup tracking
            $script:CreatedCollectionIds = $script:CreatedCollectionIds | Where-Object { $_ -ne $testColl.CollectionId }
        }
    }

    Context "Protected Collections" {

        It "Should throw when trying to remove a built-in protected collection" {
            # Arrange
            $protectedIds = $script:TestRemoveCollData.Protected.ProtectedCollections

            foreach ($protectedId in $protectedIds) {
                # Act & Assert - Should throw for each protected collection
                { Remove-CM7Collection -CollectionId $protectedId -Force } | Should -Throw "*protected*"
            }
        }
    }

    Context "Error Handling" {

        It "Should throw for non-existent collection name" {
            # Act & Assert
            { Remove-CM7Collection -Name "NonExistent-Collection-ZZZZZ-99999" -Force } | Should -Throw "*not found*"
        }

        It "Should throw for non-existent collection ID" {
            # Act & Assert
            { Remove-CM7Collection -CollectionId "XXX99999" -Force } | Should -Throw "*not found*"
        }

        It "Should throw when InputObject has no CollectionId property" {
            # Arrange
            $badObj = [PSCustomObject]@{ Name = "Test"; SomeOtherProperty = "Value" }

            # Act & Assert
            { Remove-CM7Collection -InputObject $badObj -Force } | Should -Throw "*CollectionId*"
        }
    }

    Context "WhatIf Support" {

        It "Should support -WhatIf parameter without actually removing" {
            # Arrange - Create a test collection
            $testColl = New-TestCollectionForRemoval -NamePrefix "Test-Remove-WhatIf"
            $testColl | Should -Not -BeNullOrEmpty

            # Act - WhatIf should not remove
            { Remove-CM7Collection -Name $testColl.Name -WhatIf } | Should -Not -Throw

            # Assert - Collection should still exist
            $namespace = "root/SMS/site_$($script:CMConnection.SiteCode)"
            $check = Get-CimInstance -CimSession $script:CMConnection.CimSession -Namespace $namespace -Query "SELECT CollectionID FROM SMS_Collection WHERE CollectionID = '$($testColl.CollectionId)'"
            $check | Should -Not -BeNullOrEmpty

            # Clean up - actually remove it
            Remove-CM7Collection -CollectionId $testColl.CollectionId -Force
            $script:CreatedCollectionIds = $script:CreatedCollectionIds | Where-Object { $_ -ne $testColl.CollectionId }
        }
    }

    Context "Return Object Properties" {

        It "Should return objects with expected properties" {
            # Arrange - Create a test collection
            $testColl = New-TestCollectionForRemoval -NamePrefix "Test-Remove-Props"
            $testColl | Should -Not -BeNullOrEmpty

            # Act
            $result = Remove-CM7Collection -CollectionId $testColl.CollectionId -Force

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.PSObject.Properties.Name | Should -Contain 'CollectionId'
            $result.PSObject.Properties.Name | Should -Contain 'Name'
            $result.PSObject.Properties.Name | Should -Contain 'CollectionType'
            $result.PSObject.Properties.Name | Should -Contain 'MemberCount'
            $result.PSObject.Properties.Name | Should -Contain 'Status'
            $result.Status | Should -Be 'Removed'
            $result.CollectionType | Should -BeIn @('Device', 'User')

            # Remove from cleanup tracking
            $script:CreatedCollectionIds = $script:CreatedCollectionIds | Where-Object { $_ -ne $testColl.CollectionId }
        }
    }

    Context "Verbose Output" {

        It "Should provide verbose output when requested" {
            # Arrange - Create a test collection
            $testColl = New-TestCollectionForRemoval -NamePrefix "Test-Remove-Verbose"
            $testColl | Should -Not -BeNullOrEmpty

            # Act
            $verboseOutput = Remove-CM7Collection -CollectionId $testColl.CollectionId -Force -Verbose 4>&1

            # Assert
            $verboseOutput | Should -Not -BeNullOrEmpty
            $verboseMessages = $verboseOutput | Where-Object { $_ -is [System.Management.Automation.VerboseRecord] }
            $runningMessage = $verboseMessages | Where-Object { $_.Message -match "Running Remove-CM7Collection" }
            $runningMessage | Should -Not -BeNullOrEmpty

            # Remove from cleanup tracking
            $script:CreatedCollectionIds = $script:CreatedCollectionIds | Where-Object { $_ -ne $testColl.CollectionId }
        }
    }
}

AfterAll {
    # Clean up: remove any remaining test collections that weren't cleaned up during tests
    if ($script:CMConnection.CimSession -and $script:CreatedCollectionIds.Count -gt 0) {
        $namespace = "root/SMS/site_$($script:CMConnection.SiteCode)"
        $uniqueIds = $script:CreatedCollectionIds | Select-Object -Unique
        Write-Host "Test cleanup: Removing $($uniqueIds.Count) remaining test collection(s)" -ForegroundColor Yellow
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
