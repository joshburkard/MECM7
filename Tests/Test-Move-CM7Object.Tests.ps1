# Functional Tests for Move-CM7Object
# Tests the Move-CM7Object function behavior and return values

BeforeAll {
    # Load test declarations
    . (Join-Path $PSScriptRoot "declarations.ps1")

    # Load all functions
    $CodePath = Join-Path (Get-Item $PSScriptRoot).Parent.FullName "Code"
    Get-ChildItem -Path (Join-Path $CodePath "Private") -Filter "*.ps1" | ForEach-Object { . $_.FullName }
    Get-ChildItem -Path (Join-Path $CodePath "Public") -Filter "*.ps1" | ForEach-Object { . $_.FullName }

    # Get test data for this function
    $script:TestMoveData = $script:TestData['Move-CM7Object']
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

Describe "Move-CM7Object Function Tests" -Tag "Integration", "Object", "Move" {

    Context "Test Data Validation" {

        It "Should have test data defined in declarations.ps1" {
            # Assert
            $script:TestMoveData | Should -Not -BeNullOrEmpty
            $script:TestData.ContainsKey('Move-CM7Object') | Should -Be $true
        }

        It "Should have required test data parameter sets" {
            # Assert
            $script:TestMoveData.ContainsKey('DeviceCollectionToFolder') | Should -Be $true
            $script:TestMoveData.ContainsKey('DeviceCollectionToRoot') | Should -Be $true
            $script:TestMoveData.ContainsKey('DeviceCollectionByFolderPath') | Should -Be $true
            $script:TestMoveData.ContainsKey('NonExistentObject') | Should -Be $true
            $script:TestMoveData.ContainsKey('NonExistentFolder') | Should -Be $true
            $script:TestMoveData.ContainsKey('NonExistentFolderPath') | Should -Be $true
        }

        It "Should output test data for verification" {
            # Output test data
            Write-Host "`n=== Test Data for Move-CM7Object ===" -ForegroundColor Cyan
            Write-Host "DeviceCollectionToFolder:" -ForegroundColor Yellow
            Write-Host "  ObjectId: $($script:TestMoveData.DeviceCollectionToFolder.ObjectId)" -ForegroundColor White
            Write-Host "  ObjectType: $($script:TestMoveData.DeviceCollectionToFolder.ObjectType)" -ForegroundColor White
            Write-Host "  FolderId: $($script:TestMoveData.DeviceCollectionToFolder.FolderId)" -ForegroundColor White

            Write-Host "DeviceCollectionToRoot:" -ForegroundColor Yellow
            Write-Host "  ObjectId: $($script:TestMoveData.DeviceCollectionToRoot.ObjectId)" -ForegroundColor White
            Write-Host "  FolderId: $($script:TestMoveData.DeviceCollectionToRoot.FolderId)" -ForegroundColor White

            Write-Host "DeviceCollectionByFolderPath:" -ForegroundColor Yellow
            Write-Host "  ObjectId: $($script:TestMoveData.DeviceCollectionByFolderPath.ObjectId)" -ForegroundColor White
            Write-Host "  FolderPath: $($script:TestMoveData.DeviceCollectionByFolderPath.FolderPath)" -ForegroundColor White

            Write-Host "NonExistentObject:" -ForegroundColor Yellow
            Write-Host "  ObjectId: $($script:TestMoveData.NonExistentObject.ObjectId)" -ForegroundColor White

            Write-Host "NonExistentFolder:" -ForegroundColor Yellow
            Write-Host "  FolderId: $($script:TestMoveData.NonExistentFolder.FolderId)" -ForegroundColor White

            Write-Host "NonExistentFolderPath:" -ForegroundColor Yellow
            Write-Host "  FolderPath: $($script:TestMoveData.NonExistentFolderPath.FolderPath)" -ForegroundColor White
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
            { Move-CM7Object -ObjectId "TEST001" -ObjectType DeviceCollection -FolderId 0 } | Should -Throw "*not connected*"

            # Restore connection
            $script:CMConnection = $backupConnection
        }
    }

    Context "Move by ObjectId" {

        It "Should move a device collection to a folder" {
            # Arrange
            $objectId = $script:TestMoveData.DeviceCollectionToFolder.ObjectId
            $objectType = $script:TestMoveData.DeviceCollectionToFolder.ObjectType
            $folderId = $script:TestMoveData.DeviceCollectionToFolder.FolderId

            # Act
            $result = Move-CM7Object -ObjectId $objectId -ObjectType $objectType -FolderId $folderId -Force

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.InstanceKey | Should -Be $objectId
            $result.TargetFolder | Should -Be $folderId
            $result.Success | Should -Be $true
        }

        It "Should move a device collection to the root folder" {
            # Arrange
            $objectId = $script:TestMoveData.DeviceCollectionToRoot.ObjectId
            $objectType = $script:TestMoveData.DeviceCollectionToRoot.ObjectType
            $folderId = $script:TestMoveData.DeviceCollectionToRoot.FolderId

            # Act
            $result = Move-CM7Object -ObjectId $objectId -ObjectType $objectType -FolderId $folderId -Force

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.InstanceKey | Should -Be $objectId
            $result.TargetFolder | Should -Be 0
            $result.Success | Should -Be $true
        }

        It "Should move multiple objects at once" {
            # Arrange
            $objectIds = $script:TestMoveData.MultipleObjects.ObjectIds
            $objectType = $script:TestMoveData.MultipleObjects.ObjectType
            $folderId = $script:TestMoveData.MultipleObjects.FolderId

            # Act
            $result = Move-CM7Object -ObjectId $objectIds -ObjectType $objectType -FolderId $folderId -Force

            # Assert
            $result | Should -Not -BeNullOrEmpty
            @($result).Count | Should -Be $objectIds.Count
        }
    }

    Context "Move by FolderPath" {

        It "Should move a device collection using FolderPath" {
            # Arrange
            $objectId = $script:TestMoveData.DeviceCollectionByFolderPath.ObjectId
            $folderPath = $script:TestMoveData.DeviceCollectionByFolderPath.FolderPath

            # Act
            $result = Move-CM7Object -ObjectId $objectId -FolderPath $folderPath -Force

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.InstanceKey | Should -Be $objectId
            $result.Success | Should -Be $true
        }

        It "Should move a device collection to root using FolderPath category only" {
            # Arrange
            $objectId = $script:TestMoveData.DeviceCollectionByFolderPathToRoot.ObjectId
            $folderPath = $script:TestMoveData.DeviceCollectionByFolderPathToRoot.FolderPath

            # Act
            $result = Move-CM7Object -ObjectId $objectId -FolderPath $folderPath -Force

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.InstanceKey | Should -Be $objectId
            $result.TargetFolder | Should -Be 0
            $result.Success | Should -Be $true
        }

        It "Should auto-detect ObjectType from FolderPath" {
            # Arrange
            $objectId = $script:TestMoveData.DeviceCollectionByFolderPath.ObjectId
            $folderPath = $script:TestMoveData.DeviceCollectionByFolderPath.FolderPath

            # Act
            $result = Move-CM7Object -ObjectId $objectId -FolderPath $folderPath -Force

            # Assert
            if ($result) {
                $result.ObjectType | Should -Be 5000  # DeviceCollection
            }
        }

        It "Should move multiple objects using FolderPath" {
            # Arrange - first move all objects to root so they are in a known state
            $objectIds = $script:TestMoveData.MultipleObjectsByFolderPath.ObjectIds
            $folderPath = $script:TestMoveData.MultipleObjectsByFolderPath.FolderPath
            foreach ($oid in $objectIds) {
                Move-CM7Object -ObjectId $oid -FolderPath ($folderPath -replace '\\[^\\]+$', '') -Force -ErrorAction SilentlyContinue | Out-Null
            }

            # Act
            $result = Move-CM7Object -ObjectId $objectIds -FolderPath $folderPath -Force

            # Assert
            $result | Should -Not -BeNullOrEmpty
            @($result).Count | Should -Be $objectIds.Count
        }

        It "Should resolve FolderPath with verbose output showing WQL queries" {
            # Arrange
            $objectId = $script:TestMoveData.DeviceCollectionByFolderPath.ObjectId
            $folderPath = $script:TestMoveData.DeviceCollectionByFolderPath.FolderPath

            # Act
            $verboseOutput = Move-CM7Object -ObjectId $objectId -FolderPath $folderPath -Force -Verbose 4>&1

            # Assert
            $verboseOutput | Should -Not -BeNullOrEmpty
            $verboseMessages = $verboseOutput | Where-Object { $_ -is [System.Management.Automation.VerboseRecord] }
            $resolveMessage = $verboseMessages | Where-Object { $_.Message -match "Resolving FolderPath" }
            $resolveMessage | Should -Not -BeNullOrEmpty
        }
    }

    Context "Error Handling" {

        It "Should throw for non-existent destination folder" {
            # Arrange
            $objectId = $script:TestMoveData.NonExistentFolder.ObjectId
            $objectType = $script:TestMoveData.NonExistentFolder.ObjectType
            $folderId = $script:TestMoveData.NonExistentFolder.FolderId

            # Act & Assert
            { Move-CM7Object -ObjectId $objectId -ObjectType $objectType -FolderId $folderId -Force } | Should -Throw "*not found*"
        }

        It "Should skip objects already in the target folder" {
            # Arrange - first move to root, then try moving there again
            $objectId = $script:TestMoveData.DeviceCollectionToRoot.ObjectId
            $objectType = $script:TestMoveData.DeviceCollectionToRoot.ObjectType

            # Move to root first
            Move-CM7Object -ObjectId $objectId -ObjectType $objectType -FolderId 0 -Force

            # Act - try to move to root again
            $result = Move-CM7Object -ObjectId $objectId -ObjectType $objectType -FolderId 0 -Force -Verbose 4>&1

            # Assert - should produce verbose output about skipping
            $verboseMessages = $result | Where-Object { $_ -is [System.Management.Automation.VerboseRecord] }
            $skipMessage = $verboseMessages | Where-Object { $_.Message -match "already in folder" }
            $skipMessage | Should -Not -BeNullOrEmpty
        }

        It "Should throw for non-existent FolderPath" {
            # Arrange
            $objectId = $script:TestMoveData.NonExistentFolderPath.ObjectId
            $folderPath = $script:TestMoveData.NonExistentFolderPath.FolderPath

            # Act & Assert
            { Move-CM7Object -ObjectId $objectId -FolderPath $folderPath -Force } | Should -Throw "*not found*"
        }

        It "Should throw for invalid category in FolderPath" {
            # Arrange
            $objectId = $script:TestMoveData.InvalidCategoryPath.ObjectId
            $folderPath = $script:TestMoveData.InvalidCategoryPath.FolderPath

            # Act & Assert
            { Move-CM7Object -ObjectId $objectId -FolderPath $folderPath -Force } | Should -Throw "*Invalid object type category*"
        }
    }

    Context "WhatIf Support" {

        It "Should support -WhatIf parameter" {
            # Arrange
            $objectId = $script:TestMoveData.DeviceCollectionToFolder.ObjectId
            $objectType = $script:TestMoveData.DeviceCollectionToFolder.ObjectType
            $folderId = $script:TestMoveData.DeviceCollectionToFolder.FolderId

            # Act & Assert - should not throw, and should not actually move
            { Move-CM7Object -ObjectId $objectId -ObjectType $objectType -FolderId $folderId -WhatIf } | Should -Not -Throw
        }
    }

    Context "Return Object Properties" {

        It "Should return objects with expected properties" {
            # Arrange
            $objectId = $script:TestMoveData.DeviceCollectionToRoot.ObjectId
            $objectType = $script:TestMoveData.DeviceCollectionToRoot.ObjectType

            # Act
            $result = Move-CM7Object -ObjectId $objectId -ObjectType $objectType -FolderId 0 -Force

            # Assert
            if ($result) {
                $result.PSObject.Properties.Name | Should -Contain 'InstanceKey'
                $result.PSObject.Properties.Name | Should -Contain 'ObjectType'
                $result.PSObject.Properties.Name | Should -Contain 'SourceFolder'
                $result.PSObject.Properties.Name | Should -Contain 'TargetFolder'
                $result.PSObject.Properties.Name | Should -Contain 'Success'
                $result.PSObject.Properties.Name | Should -Contain 'Message'
            }
        }

        It "Should have PSTypeName set correctly" {
            # Arrange
            $objectId = $script:TestMoveData.DeviceCollectionToFolder.ObjectId
            $objectType = $script:TestMoveData.DeviceCollectionToFolder.ObjectType
            $folderId = $script:TestMoveData.DeviceCollectionToFolder.FolderId

            # Act
            $result = Move-CM7Object -ObjectId $objectId -ObjectType $objectType -FolderId $folderId -Force

            # Assert
            if ($result) {
                $result.PSObject.TypeNames[0] | Should -Be 'MECM7.MoveResult'
            }
        }
    }

    Context "Verbose Output" {

        It "Should provide verbose output when requested" {
            # Arrange
            $objectId = $script:TestMoveData.DeviceCollectionToRoot.ObjectId
            $objectType = $script:TestMoveData.DeviceCollectionToRoot.ObjectType

            # Act & Assert
            $verboseOutput = Move-CM7Object -ObjectId $objectId -ObjectType $objectType -FolderId 0 -Force -Verbose 4>&1
            $verboseOutput | Should -Not -BeNullOrEmpty
            $verboseOutput | Where-Object { $_ -match "Running Move-CM7Object" } | Should -Not -BeNullOrEmpty
        }
    }
}

AfterAll {
    # Clean up: move all test collections back to the original folder
    if ($script:CMConnection.CimSession) {
        $restorePath = $script:TestMoveData.RestoreFolderPath
        $collectionIds = @($script:TestMoveData.DeviceCollectionToFolder.ObjectId, $script:TestMoveData.DeviceCollectionToRoot.ObjectId) + @($script:TestMoveData.MultipleObjects.ObjectIds) + @($script:TestMoveData.MultipleObjectsByFolderPath.ObjectIds) | Select-Object -Unique
        Write-Host "Test cleanup: Moving $($collectionIds.Count) collection(s) back to '$restorePath'" -ForegroundColor Yellow
        foreach ($id in $collectionIds) {
            Move-CM7Object -ObjectId $id -FolderPath $restorePath -Force -ErrorAction SilentlyContinue | Out-Null
        }
        Write-Host "Test cleanup: Done" -ForegroundColor Green
    }
}
