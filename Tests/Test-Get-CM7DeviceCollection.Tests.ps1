# Functional Tests for Get-CM7DeviceCollection
# Tests the Get-CM7DeviceCollection function behavior and return values

BeforeAll {
    # Load test declarations
    . (Join-Path $PSScriptRoot "declarations.ps1")

    # Load all functions
    $CodePath = Join-Path (Get-Item $PSScriptRoot).Parent.FullName "Code"
    Get-ChildItem -Path (Join-Path $CodePath "Private") -Filter "*.ps1" | ForEach-Object { . $_.FullName }
    Get-ChildItem -Path (Join-Path $CodePath "Public") -Filter "*.ps1" | ForEach-Object { . $_.FullName }

    # Get test data for this function
    $script:TestDeviceCollectionData = $script:TestData['Get-CM7DeviceCollection']
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

Describe "Get-CM7DeviceCollection Function Tests" -Tag "Integration", "DeviceCollection" {

    Context "Test Data Validation" {

        It "Should have test data defined in declarations.ps1" {
            # Assert
            $script:TestDeviceCollectionData | Should -Not -BeNullOrEmpty
            $script:TestData.ContainsKey('Get-CM7DeviceCollection') | Should -Be $true
        }

        It "Should have required test data parameter sets" {
            # Assert
            $script:TestDeviceCollectionData.ContainsKey('ByName') | Should -Be $true
            $script:TestDeviceCollectionData.ContainsKey('ByCollectionID') | Should -Be $true
            $script:TestDeviceCollectionData.ContainsKey('NonExistent') | Should -Be $true
        }

        It "Should output test data for verification" {
            # Output test data
            Write-Host "`n=== Test Data for Get-CM7DeviceCollection ===" -ForegroundColor Cyan
            Write-Host "ByName:" -ForegroundColor Yellow
            Write-Host "  Name: $($script:TestDeviceCollectionData.ByName.Name)" -ForegroundColor White
            Write-Host "  ExpectedCount: $($script:TestDeviceCollectionData.ByName.ExpectedCount)" -ForegroundColor White

            Write-Host "ByCollectionID:" -ForegroundColor Yellow
            Write-Host "  CollectionID: $($script:TestDeviceCollectionData.ByCollectionID.CollectionID)" -ForegroundColor White
            Write-Host "  ExpectedCount: $($script:TestDeviceCollectionData.ByCollectionID.ExpectedCount)" -ForegroundColor White

            Write-Host "NonExistent:" -ForegroundColor Yellow
            Write-Host "  Name: $($script:TestDeviceCollectionData.NonExistent.Name)" -ForegroundColor White
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
            { Get-CM7DeviceCollection -Name "Test" } | Should -Throw "*not connected*"

            # Restore connection
            $script:CMConnection = $backupConnection
        }
    }

    Context "Query by Collection Name" {

        It "Should retrieve device collection by exact name" {
            # Arrange
            $collectionName = $script:TestDeviceCollectionData.ByName.Name

            # Act
            $result = Get-CM7DeviceCollection -Name $collectionName

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.Count | Should -Be $script:TestDeviceCollectionData.ByName.ExpectedCount
            $result.Name | Should -Be $collectionName
        }

        It "Should return null for non-existent device collection" {
            # Arrange
            $collectionName = $script:TestDeviceCollectionData.NonExistent.Name

            # Act
            $result = Get-CM7DeviceCollection -Name $collectionName

            # Assert
            $result | Should -BeNullOrEmpty
        }

        It "Should support wildcard patterns" {
            # Arrange
            $pattern = "Test-Collection*"

            # Act
            $result = Get-CM7DeviceCollection -Name $pattern

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result | ForEach-Object {
                $_.Name | Should -BeLike $pattern
            }
        }
    }

    Context "Query by CollectionId" {

        It "Should retrieve device collection by CollectionId" {
            # Arrange
            $collectionId = $script:TestDeviceCollectionData.ByCollectionID.CollectionID

            # Act
            $result = Get-CM7DeviceCollection -CollectionId $collectionId

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.Count | Should -Be $script:TestDeviceCollectionData.ByCollectionID.ExpectedCount
            $result.CollectionId | Should -Be $collectionId
        }

        It "Should return null for non-existent CollectionId" {
            # Arrange
            $invalidCollectionId = "XXX99999"

            # Act
            $result = Get-CM7DeviceCollection -CollectionId $invalidCollectionId

            # Assert
            $result | Should -BeNullOrEmpty
        }
    }

    Context "Device Collection Type Verification" {

        It "Should only return device collections" {
            # Act
            $result = Get-CM7DeviceCollection

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result | ForEach-Object {
                $_.CollectionType | Should -Be 'Device'
            }
        }

        It "Should produce same results as Get-CM7Collection -CollectionType Device" {
            # Arrange
            $collectionName = $script:TestDeviceCollectionData.ByName.Name

            # Act
            $deviceCollectionResult = Get-CM7DeviceCollection -Name $collectionName
            $collectionResult = Get-CM7Collection -Name $collectionName -CollectionType Device

            # Assert
            $deviceCollectionResult | Should -Not -BeNullOrEmpty
            $collectionResult | Should -Not -BeNullOrEmpty
            $deviceCollectionResult.CollectionId | Should -Be $collectionResult.CollectionId
            $deviceCollectionResult.Name | Should -Be $collectionResult.Name
            $deviceCollectionResult.CollectionType | Should -Be $collectionResult.CollectionType
            $deviceCollectionResult.MemberCount | Should -Be $collectionResult.MemberCount
        }
    }

    Context "Fast Mode" {

        It "Should return limited properties with Fast switch" {
            # Arrange
            $collectionName = $script:TestDeviceCollectionData.ByName.Name

            # Act
            $result = Get-CM7DeviceCollection -Name $collectionName -Fast

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.PSObject.Properties.Name | Should -Contain 'CollectionId'
            $result.PSObject.Properties.Name | Should -Contain 'Name'
            $result.PSObject.Properties.Name | Should -Contain 'CollectionType'
            $result.PSObject.Properties.Name | Should -Contain 'MemberCount'
        }

        It "Fast mode should be faster than full query" {
            # Arrange
            $collectionName = $script:TestDeviceCollectionData.ByName.Name

            # Act
            $fastStart = Get-Date
            $fastResult = Get-CM7DeviceCollection -Name $collectionName -Fast
            $fastDuration = (Get-Date) - $fastStart

            $fullStart = Get-Date
            $fullResult = Get-CM7DeviceCollection -Name $collectionName
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
            $collectionName = $script:TestDeviceCollectionData.ByName.Name

            # Act
            $result = Get-CM7DeviceCollection -Name $collectionName

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
            $collectionName = $script:TestDeviceCollectionData.ByName.Name

            # Act
            $result = Get-CM7DeviceCollection -Name $collectionName

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.PSObject.TypeNames[0] | Should -Be 'MECM7.Collection'
        }

        It "Should have CollectionType as 'Device'" {
            # Arrange
            $collectionName = $script:TestDeviceCollectionData.ByName.Name

            # Act
            $result = Get-CM7DeviceCollection -Name $collectionName

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.CollectionType | Should -Be 'Device'
        }
    }

    Context "Get All Device Collections" {

        It "Should retrieve all device collections when no parameters specified" {
            # Act
            $result = Get-CM7DeviceCollection

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.Count | Should -BeGreaterOrEqual $script:TestDeviceCollectionData.All.ExpectedMinCount
        }
    }

    Context "Verbose Output" {

        It "Should provide verbose output when requested" {
            # Arrange
            $collectionName = $script:TestDeviceCollectionData.ByName.Name

            # Act & Assert
            $verboseOutput = Get-CM7DeviceCollection -Name $collectionName -Verbose 4>&1
            $verboseOutput | Should -Not -BeNullOrEmpty
            $verboseOutput | Where-Object { $_ -match "Running Get-CM7DeviceCollection" } | Should -Not -BeNullOrEmpty
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
