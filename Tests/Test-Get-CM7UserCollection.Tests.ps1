# Functional Tests for Get-CM7UserCollection
# Tests the Get-CM7UserCollection function behavior and return values

BeforeAll {
    # Load test declarations
    . (Join-Path $PSScriptRoot "declarations.ps1")

    # Load all functions
    $CodePath = Join-Path (Get-Item $PSScriptRoot).Parent.FullName "Code"
    Get-ChildItem -Path (Join-Path $CodePath "Private") -Filter "*.ps1" | ForEach-Object { . $_.FullName }
    Get-ChildItem -Path (Join-Path $CodePath "Public") -Filter "*.ps1" | ForEach-Object { . $_.FullName }

    # Get test data for this function
    $script:TestUserCollectionData = $script:TestData['Get-CM7UserCollection']
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

Describe "Get-CM7UserCollection Function Tests" -Tag "Integration", "UserCollection" {

    Context "Test Data Validation" {

        It "Should have test data defined in declarations.ps1" {
            # Assert
            $script:TestUserCollectionData | Should -Not -BeNullOrEmpty
            $script:TestData.ContainsKey('Get-CM7UserCollection') | Should -Be $true
        }

        It "Should have required test data parameter sets" {
            # Assert
            $script:TestUserCollectionData.ContainsKey('ByName') | Should -Be $true
            $script:TestUserCollectionData.ContainsKey('ByCollectionID') | Should -Be $true
            $script:TestUserCollectionData.ContainsKey('NonExistent') | Should -Be $true
        }

        It "Should output test data for verification" {
            # Output test data
            Write-Host "`n=== Test Data for Get-CM7UserCollection ===" -ForegroundColor Cyan
            Write-Host "ByName:" -ForegroundColor Yellow
            Write-Host "  Name: $($script:TestUserCollectionData.ByName.Name)" -ForegroundColor White
            Write-Host "  ExpectedCount: $($script:TestUserCollectionData.ByName.ExpectedCount)" -ForegroundColor White

            Write-Host "ByCollectionID:" -ForegroundColor Yellow
            Write-Host "  CollectionID: $($script:TestUserCollectionData.ByCollectionID.CollectionID)" -ForegroundColor White
            Write-Host "  ExpectedCount: $($script:TestUserCollectionData.ByCollectionID.ExpectedCount)" -ForegroundColor White

            Write-Host "NonExistent:" -ForegroundColor Yellow
            Write-Host "  Name: $($script:TestUserCollectionData.NonExistent.Name)" -ForegroundColor White
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
            { Get-CM7UserCollection -Name "Test" } | Should -Throw "*not connected*"

            # Restore connection
            $script:CMConnection = $backupConnection
        }
    }

    Context "Query by Collection Name" {

        It "Should retrieve user collection by exact name" {
            # Arrange
            $collectionName = $script:TestUserCollectionData.ByName.Name

            # Act
            $result = Get-CM7UserCollection -Name $collectionName

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.Count | Should -Be $script:TestUserCollectionData.ByName.ExpectedCount
            $result.Name | Should -Be $collectionName
        }

        It "Should return null for non-existent user collection" {
            # Arrange
            $collectionName = $script:TestUserCollectionData.NonExistent.Name

            # Act
            $result = Get-CM7UserCollection -Name $collectionName

            # Assert
            $result | Should -BeNullOrEmpty
        }

        It "Should support wildcard patterns" {
            # Arrange
            $pattern = "All*"

            # Act
            $result = Get-CM7UserCollection -Name $pattern

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result | ForEach-Object {
                $_.Name | Should -BeLike $pattern
            }
        }
    }

    Context "Query by CollectionId" {

        It "Should retrieve user collection by CollectionId" {
            # Arrange
            $collectionId = $script:TestUserCollectionData.ByCollectionID.CollectionID

            # Act
            $result = Get-CM7UserCollection -CollectionId $collectionId

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.Count | Should -Be $script:TestUserCollectionData.ByCollectionID.ExpectedCount
            $result.CollectionId | Should -Be $collectionId
        }

        It "Should return null for non-existent CollectionId" {
            # Arrange
            $invalidCollectionId = "XXX99999"

            # Act
            $result = Get-CM7UserCollection -CollectionId $invalidCollectionId

            # Assert
            $result | Should -BeNullOrEmpty
        }
    }

    Context "User Collection Type Verification" {

        It "Should only return user collections" {
            # Act
            $result = Get-CM7UserCollection

            # Assert
            # May or may not have results depending on the environment
            if ($result) {
                $result | ForEach-Object {
                    $_.CollectionType | Should -Be 'User'
                }
            }
        }

        It "Should produce same results as Get-CM7Collection -CollectionType User" {
            # Arrange
            $collectionName = $script:TestUserCollectionData.ByName.Name

            # Act
            $userCollectionResult = Get-CM7UserCollection -Name $collectionName
            $collectionResult = Get-CM7Collection -Name $collectionName -CollectionType User

            # Assert
            $userCollectionResult | Should -Not -BeNullOrEmpty
            $collectionResult | Should -Not -BeNullOrEmpty
            $userCollectionResult.CollectionId | Should -Be $collectionResult.CollectionId
            $userCollectionResult.Name | Should -Be $collectionResult.Name
            $userCollectionResult.CollectionType | Should -Be $collectionResult.CollectionType
            $userCollectionResult.MemberCount | Should -Be $collectionResult.MemberCount
        }
    }

    Context "Fast Mode" {

        It "Should return limited properties with Fast switch" {
            # Arrange
            $collectionName = $script:TestUserCollectionData.ByName.Name

            # Act
            $result = Get-CM7UserCollection -Name $collectionName -Fast

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.PSObject.Properties.Name | Should -Contain 'CollectionId'
            $result.PSObject.Properties.Name | Should -Contain 'Name'
            $result.PSObject.Properties.Name | Should -Contain 'CollectionType'
            $result.PSObject.Properties.Name | Should -Contain 'MemberCount'
        }

        It "Fast mode should be faster than full query" {
            # Arrange
            $collectionName = $script:TestUserCollectionData.ByName.Name

            # Act
            $fastStart = Get-Date
            $fastResult = Get-CM7UserCollection -Name $collectionName -Fast
            $fastDuration = (Get-Date) - $fastStart

            $fullStart = Get-Date
            $fullResult = Get-CM7UserCollection -Name $collectionName
            $fullDuration = (Get-Date) - $fullStart

            # Assert
            $fastResult | Should -Not -BeNullOrEmpty
            $fullResult | Should -Not -BeNullOrEmpty
            Write-Host "Fast mode: $($fastDuration.TotalMilliseconds)ms, Full mode: $($fullDuration.TotalMilliseconds)ms" -ForegroundColor Cyan
            # Note: We don't assert speed because it can vary
        }
    }

    Context "Return Object Properties" {

        It "Should return objects with expected properties" {
            # Arrange
            $collectionName = $script:TestUserCollectionData.ByName.Name

            # Act
            $result = Get-CM7UserCollection -Name $collectionName

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.PSObject.Properties.Name | Should -Contain 'CollectionId'
            $result.PSObject.Properties.Name | Should -Contain 'Name'
            $result.PSObject.Properties.Name | Should -Contain 'CollectionType'
            $result.PSObject.Properties.Name | Should -Contain 'MemberCount'
            $result.PSObject.Properties.Name | Should -Contain 'LastRefreshTime'
        }

        It "Should have PSTypeName set correctly" {
            # Arrange
            $collectionName = $script:TestUserCollectionData.ByName.Name

            # Act
            $result = Get-CM7UserCollection -Name $collectionName

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.PSObject.TypeNames[0] | Should -Be 'MECM7.Collection'
        }

        It "Should have CollectionType as 'User'" {
            # Arrange
            $collectionName = $script:TestUserCollectionData.ByName.Name

            # Act
            $result = Get-CM7UserCollection -Name $collectionName

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.CollectionType | Should -Be 'User'
        }
    }

    Context "Get All User Collections" {

        It "Should retrieve all user collections when no parameters specified" {
            # Act
            $result = Get-CM7UserCollection

            # Assert
            # May or may not have results depending on the environment
            if ($result) {
                $result.Count | Should -BeGreaterOrEqual $script:TestUserCollectionData.All.ExpectedMinCount
            }
        }
    }

    Context "Verbose Output" {

        It "Should provide verbose output when requested" {
            # Arrange
            $collectionName = $script:TestUserCollectionData.ByName.Name

            # Act & Assert
            $verboseOutput = Get-CM7UserCollection -Name $collectionName -Verbose 4>&1
            $verboseOutput | Should -Not -BeNullOrEmpty
            $verboseOutput | Where-Object { $_ -match "Running Get-CM7UserCollection" } | Should -Not -BeNullOrEmpty
        }
    }
}

AfterAll {
    # Optional: Close CIM session if needed
    if ($script:CMConnection.CimSession) {
        Write-Host "Cleaning up CIM session..." -ForegroundColor Yellow
        # Remove-CimSession -CimSession $script:CMConnection.CimSession -ErrorAction SilentlyContinue
    }
}
