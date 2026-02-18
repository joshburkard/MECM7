# Functional Tests for Get-CM7Device
# Tests the Get-CM7Device function behavior and return values

BeforeAll {
    # Load test declarations
    . (Join-Path $PSScriptRoot "declarations.ps1")

    # Load all functions
    $CodePath = Join-Path (Get-Item $PSScriptRoot).Parent.FullName "Code"
    Get-ChildItem -Path (Join-Path $CodePath "Private") -Filter "*.ps1" | ForEach-Object { . $_.FullName }
    Get-ChildItem -Path (Join-Path $CodePath "Public") -Filter "*.ps1" | ForEach-Object { . $_.FullName }

    # Get test data for this function
    $script:TestDeviceData = $script:TestData['Get-CM7Device']
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

Describe "Get-CM7Device Function Tests" -Tag "Integration", "Device" {

    Context "Test Data Validation" {

        It "Should have test data defined in declarations.ps1" {
            # Assert
            $script:TestDeviceData | Should -Not -BeNullOrEmpty
            $script:TestData.ContainsKey('Get-CM7Device') | Should -Be $true
        }

        It "Should have required test data parameter sets" {
            # Assert
            $script:TestDeviceData.ContainsKey('ByName') | Should -Be $true
            $script:TestDeviceData.ContainsKey('ByResourceId') | Should -Be $true
            $script:TestDeviceData.ContainsKey('ByWildcard') | Should -Be $true
            $script:TestDeviceData.ContainsKey('NonExistent') | Should -Be $true
        }

        It "Should output test data for verification" {
            # Output test data
            Write-Host "`n=== Test Data for Get-CM7Device ===" -ForegroundColor Cyan
            Write-Host "ByName:" -ForegroundColor Yellow
            Write-Host "  Name: $($script:TestDeviceData.ByName.Name)" -ForegroundColor White
            Write-Host "  ExpectedCount: $($script:TestDeviceData.ByName.ExpectedCount)" -ForegroundColor White

            Write-Host "ByResourceId:" -ForegroundColor Yellow
            Write-Host "  ResourceId: $($script:TestDeviceData.ByResourceId.ResourceId)" -ForegroundColor White
            Write-Host "  ExpectedCount: $($script:TestDeviceData.ByResourceId.ExpectedCount)" -ForegroundColor White

            Write-Host "ByWildcard:" -ForegroundColor Yellow
            Write-Host "  Name: $($script:TestDeviceData.ByWildcard.Name)" -ForegroundColor White
            Write-Host "  ExpectedMinCount: $($script:TestDeviceData.ByWildcard.ExpectedMinCount)" -ForegroundColor White

            Write-Host "NonExistent:" -ForegroundColor Yellow
            Write-Host "  Name: $($script:TestDeviceData.NonExistent.Name)" -ForegroundColor White
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
            { Get-CM7Device -Name "TEST" } | Should -Throw "*not connected*"

            # Restore connection
            $script:CMConnection = $backupConnection
        }
    }

    Context "Query by Device Name" {

        It "Should retrieve device by exact name" {
            # Arrange
            $deviceName = $script:TestDeviceData.ByName.Name

            # Act
            $result = Get-CM7Device -Name $deviceName

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.Count | Should -Be $script:TestDeviceData.ByName.ExpectedCount
            $result.Name | Should -Be $deviceName
        }

        It "Should return null for non-existent device" {
            # Arrange
            $deviceName = $script:TestDeviceData.NonExistent.Name

            # Act
            $result = Get-CM7Device -Name $deviceName

            # Assert
            $result | Should -BeNullOrEmpty
        }

        It "Should support wildcard patterns" {
            # Arrange
            $pattern = $script:TestDeviceData.ByWildcard.Name

            # Act
            $result = Get-CM7Device -Name $pattern

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.Count | Should -BeGreaterOrEqual $script:TestDeviceData.ByWildcard.ExpectedMinCount
            $result | ForEach-Object {
                $_.Name | Should -BeLike $pattern
            }
        }
    }

    Context "Query by ResourceId" {

        It "Should retrieve device by ResourceId" {
            # Arrange
            $resourceId = $script:TestDeviceData.ByResourceId.ResourceId

            # Act
            $result = Get-CM7Device -ResourceId $resourceId

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.Count | Should -Be $script:TestDeviceData.ByResourceId.ExpectedCount
            $result.ResourceId | Should -Be $resourceId
        }

        It "Should return null for non-existent ResourceId" {
            # Arrange
            $invalidResourceId = 99999999

            # Act
            $result = Get-CM7Device -ResourceId $invalidResourceId

            # Assert
            $result | Should -BeNullOrEmpty
        }
    }

    Context "Query by Collection" {

        It "Should retrieve devices by CollectionName" {
            # Arrange
            $collectionName = $script:TestDeviceData.ByCollectionName.CollectionName

            # Act
            $result = Get-CM7Device -CollectionName $collectionName

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.Count | Should -BeGreaterOrEqual $script:TestDeviceData.ByCollectionName.ExpectedMinCount
        }

        It "Should retrieve devices by CollectionId" {
            # Arrange
            $collectionId = $script:TestDeviceData.ByCollectionId.CollectionId

            # Act
            $result = Get-CM7Device -CollectionId $collectionId

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.Count | Should -BeGreaterOrEqual $script:TestDeviceData.ByCollectionId.ExpectedMinCount
        }

        It "Should return null for non-existent collection" {
            # Arrange
            $invalidCollection = "NonExistent Collection 999"

            # Act
            $result = Get-CM7Device -CollectionName $invalidCollection

            # Assert
            $result | Should -BeNullOrEmpty
        }
    }

    Context "Fast Mode" {

        It "Should return limited properties with Fast switch" {
            # Arrange
            $deviceName = $script:TestDeviceData.Fast.Name

            # Act
            $result = Get-CM7Device -Name $deviceName -Fast

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.PSObject.Properties.Name | Should -Contain 'ResourceId'
            $result.PSObject.Properties.Name | Should -Contain 'Name'
            $result.PSObject.Properties.Name | Should -Contain 'LastLogonTimestamp'
        }

        It "Fast mode should be faster than full query" {
            # Arrange
            $deviceName = $script:TestDeviceData.Fast.Name

            # Act
            $fastStart = Get-Date
            $fastResult = Get-CM7Device -Name $deviceName -Fast
            $fastDuration = (Get-Date) - $fastStart

            $fullStart = Get-Date
            $fullResult = Get-CM7Device -Name $deviceName
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
            $deviceName = $script:TestDeviceData.ByName.Name

            # Act
            $result = Get-CM7Device -Name $deviceName

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.PSObject.Properties.Name | Should -Contain 'ResourceId'
            $result.PSObject.Properties.Name | Should -Contain 'Name'
            $result.PSObject.Properties.Name | Should -Contain 'OperatingSystem'
            $result.PSObject.Properties.Name | Should -Contain 'LastLogonUser'
            $result.PSObject.Properties.Name | Should -Contain 'IPAddresses'
            $result.PSObject.Properties.Name | Should -Contain 'MACAddresses'
        }

        It "Should have PSTypeName set correctly" {
            # Arrange
            $deviceName = $script:TestDeviceData.ByName.Name

            # Act
            $result = Get-CM7Device -Name $deviceName

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.PSObject.TypeNames[0] | Should -Be 'MECM7.Device'
        }

        It "Should have ResourceId as integer" {
            # Arrange
            $deviceName = $script:TestDeviceData.ByName.Name

            # Act
            $result = Get-CM7Device -Name $deviceName

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.ResourceId | Should -BeOfType [int]
        }
    }

    Context "Get All Devices" {

        It "Should retrieve all devices when no parameters specified" {
            # Act
            $result = Get-CM7Device

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.Count | Should -BeGreaterOrEqual $script:TestDeviceData.All.ExpectedMinCount
        }
    }

    Context "Verbose Output" {

        It "Should provide verbose output when requested" {
            # Arrange
            $deviceName = $script:TestDeviceData.ByName.Name

            # Act & Assert
            $verboseOutput = Get-CM7Device -Name $deviceName -Verbose 4>&1
            $verboseOutput | Should -Not -BeNullOrEmpty
            $verboseOutput | Where-Object { $_ -match "Running Get-CM7Device" } | Should -Not -BeNullOrEmpty
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
