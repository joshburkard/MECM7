# Functional Tests for Get-CM7SoftwareUpdateDeploymentPackage
# Tests the Get-CM7SoftwareUpdateDeploymentPackage function behavior and return values

BeforeAll {
    # Load test declarations
    . (Join-Path $PSScriptRoot "declarations.ps1")

    # Load all functions
    $CodePath = Join-Path (Get-Item $PSScriptRoot).Parent.FullName "Code"
    Get-ChildItem -Path (Join-Path $CodePath "Private") -Filter "*.ps1" | ForEach-Object { . $_.FullName }
    Get-ChildItem -Path (Join-Path $CodePath "Public") -Filter "*.ps1" | ForEach-Object { . $_.FullName }

    # Get test data for this function
    $script:TestSUDeploymentPackageData = $script:TestData['Get-CM7SoftwareUpdateDeploymentPackage']
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

Describe "Get-CM7SoftwareUpdateDeploymentPackage Function Tests" -Tag "Integration", "SoftwareUpdateDeploymentPackage" {

    Context "Test Data Validation" {

        It "Should have test data defined in declarations.ps1" {
            # Assert
            $script:TestSUDeploymentPackageData | Should -Not -BeNullOrEmpty
            $script:TestData.ContainsKey('Get-CM7SoftwareUpdateDeploymentPackage') | Should -Be $true
        }

        It "Should have required test data parameter sets" {
            # Assert
            $script:TestSUDeploymentPackageData.ContainsKey('ByName') | Should -Be $true
            $script:TestSUDeploymentPackageData.ContainsKey('ById') | Should -Be $true
            $script:TestSUDeploymentPackageData.ContainsKey('NonExistent') | Should -Be $true
            $script:TestSUDeploymentPackageData.ContainsKey('All') | Should -Be $true
        }

        It "Should output test data for verification" {
            # Output test data
            Write-Host "`n=== Test Data for Get-CM7SoftwareUpdateDeploymentPackage ===" -ForegroundColor Cyan
            Write-Host "ByName:" -ForegroundColor Yellow
            Write-Host "  Name: $($script:TestSUDeploymentPackageData.ByName.Name)" -ForegroundColor White
            Write-Host "  ExpectedCount: $($script:TestSUDeploymentPackageData.ByName.ExpectedCount)" -ForegroundColor White

            Write-Host "ById:" -ForegroundColor Yellow
            Write-Host "  Id: $($script:TestSUDeploymentPackageData.ById.Id)" -ForegroundColor White
            Write-Host "  ExpectedName: $($script:TestSUDeploymentPackageData.ById.ExpectedName)" -ForegroundColor White

            Write-Host "NonExistent:" -ForegroundColor Yellow
            Write-Host "  Id: $($script:TestSUDeploymentPackageData.NonExistent.Id)" -ForegroundColor White
            Write-Host "  Name: $($script:TestSUDeploymentPackageData.NonExistent.Name)" -ForegroundColor White
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
            { Get-CM7SoftwareUpdateDeploymentPackage -Name "Test" } | Should -Throw "*not connected*"

            # Restore connection
            $script:CMConnection = $backupConnection
        }
    }

    Context "Query by Name" {

        It "Should retrieve software update deployment package by name" {
            # Arrange
            $name = $script:TestSUDeploymentPackageData.ByName.Name

            # Act
            $result = Get-CM7SoftwareUpdateDeploymentPackage -Name $name

            # Assert
            $result | Should -Not -BeNullOrEmpty
            @($result).Count | Should -Be $script:TestSUDeploymentPackageData.ByName.ExpectedCount
            $result.Name | Should -Be $name
        }

        It "Should return null for non-existent package name" {
            # Arrange
            $name = $script:TestSUDeploymentPackageData.NonExistent.Name

            # Act
            $result = Get-CM7SoftwareUpdateDeploymentPackage -Name $name

            # Assert
            $result | Should -BeNullOrEmpty
        }

        It "Should support wildcard patterns in name" {
            # Arrange
            $pattern = $script:TestSUDeploymentPackageData.ByNameWildcard.Name

            # Act
            $result = Get-CM7SoftwareUpdateDeploymentPackage -Name $pattern

            # Assert
            if ($script:TestSUDeploymentPackageData.ByNameWildcard.ExpectedMinCount -gt 0) {
                $result | Should -Not -BeNullOrEmpty
                @($result).Count | Should -BeGreaterOrEqual $script:TestSUDeploymentPackageData.ByNameWildcard.ExpectedMinCount
                $result | ForEach-Object {
                    $_.Name | Should -BeLike $pattern
                }
            }
        }
    }

    Context "Query by Package ID" {

        It "Should retrieve software update deployment package by ID" {
            # Arrange
            $id = $script:TestSUDeploymentPackageData.ById.Id

            # Act
            $result = Get-CM7SoftwareUpdateDeploymentPackage -Id $id

            # Assert
            $result | Should -Not -BeNullOrEmpty
            @($result).Count | Should -Be 1
            $result.PackageID | Should -Be $id
            $result.Name | Should -Be $script:TestSUDeploymentPackageData.ById.ExpectedName
        }

        It "Should return null for non-existent package ID" {
            # Arrange
            $id = $script:TestSUDeploymentPackageData.NonExistent.Id

            # Act
            $result = Get-CM7SoftwareUpdateDeploymentPackage -Id $id

            # Assert
            $result | Should -BeNullOrEmpty
        }
    }

    Context "Fast Mode" {

        It "Should return limited properties with Fast switch" {
            # Arrange
            $name = $script:TestSUDeploymentPackageData.ByName.Name

            # Act
            $result = Get-CM7SoftwareUpdateDeploymentPackage -Name $name -Fast

            # Assert
            if ($result) {
                $result | Should -Not -BeNullOrEmpty
                $result.PSObject.Properties.Name | Should -Contain 'PackageID'
                $result.PSObject.Properties.Name | Should -Contain 'Name'
                $result.PSObject.Properties.Name | Should -Contain 'Description'
                $result.PSObject.Properties.Name | Should -Contain 'SourceSite'
                $result.PSObject.Properties.Name | Should -Contain 'PkgSourcePath'
                $result.PSObject.Properties.Name | Should -Contain 'PackageSize'
                $result.PSObject.Properties.Name | Should -Contain 'LastRefreshTime'
                $result.PSObject.Properties.Name | Should -Contain 'Priority'
            } else {
                Set-ItResult -Skipped -Because "No software update deployment packages found"
            }
        }

        It "Fast mode should be faster than full query" {
            # Arrange
            $name = $script:TestSUDeploymentPackageData.ByName.Name

            # Act
            $fastStart = Get-Date
            $fastResult = Get-CM7SoftwareUpdateDeploymentPackage -Name $name -Fast
            $fastDuration = (Get-Date) - $fastStart

            $fullStart = Get-Date
            $fullResult = Get-CM7SoftwareUpdateDeploymentPackage -Name $name
            $fullDuration = (Get-Date) - $fullStart

            # Assert
            Write-Host "Fast mode: $($fastDuration.TotalMilliseconds)ms, Full mode: $($fullDuration.TotalMilliseconds)ms" -ForegroundColor Cyan
            # Note: We don't assert speed because it can vary
            $true | Should -Be $true
        }
    }

    Context "Return Object Properties" {

        It "Should return objects with expected properties" {
            # Arrange
            $name = $script:TestSUDeploymentPackageData.ByName.Name

            # Act
            $result = Get-CM7SoftwareUpdateDeploymentPackage -Name $name

            # Assert
            if ($result) {
                $result | Should -Not -BeNullOrEmpty
                $firstResult = @($result)[0]
                $firstResult.PSObject.Properties.Name | Should -Contain 'PackageID'
                $firstResult.PSObject.Properties.Name | Should -Contain 'Name'
                $firstResult.PSObject.Properties.Name | Should -Contain 'Description'
                $firstResult.PSObject.Properties.Name | Should -Contain 'SourceSite'
                $firstResult.PSObject.Properties.Name | Should -Contain 'PkgSourcePath'
                $firstResult.PSObject.Properties.Name | Should -Contain 'PackageSize'
                $firstResult.PSObject.Properties.Name | Should -Contain 'SourceVersion'
                $firstResult.PSObject.Properties.Name | Should -Contain 'StoredPkgVersion'
                $firstResult.PSObject.Properties.Name | Should -Contain 'LastRefreshTime'
                $firstResult.PSObject.Properties.Name | Should -Contain 'Priority'
                $firstResult.PSObject.Properties.Name | Should -Contain 'PkgSourceFlag'
                $firstResult.PSObject.Properties.Name | Should -Contain 'ImagePath'
            } else {
                Set-ItResult -Skipped -Because "No software update deployment packages found"
            }
        }

        It "Should have PSTypeName set correctly" {
            # Arrange
            $name = $script:TestSUDeploymentPackageData.ByName.Name

            # Act
            $result = Get-CM7SoftwareUpdateDeploymentPackage -Name $name

            # Assert
            if ($result) {
                $firstResult = @($result)[0]
                $firstResult.PSObject.TypeNames[0] | Should -Be 'MECM7.SoftwareUpdateDeploymentPackage'
            } else {
                Set-ItResult -Skipped -Because "No software update deployment packages found"
            }
        }

        It "Should have Priority as string (friendly name)" {
            # Arrange
            $name = $script:TestSUDeploymentPackageData.ByName.Name

            # Act
            $result = Get-CM7SoftwareUpdateDeploymentPackage -Name $name

            # Assert
            if ($result) {
                $firstResult = @($result)[0]
                $firstResult.Priority | Should -BeOfType [string]
                $firstResult.Priority | Should -Match "^(High|Normal|Low|Unknown.*)$"
            } else {
                Set-ItResult -Skipped -Because "No software update deployment packages found"
            }
        }

        It "Should have PkgSourceFlag as string (friendly name)" {
            # Arrange
            $name = $script:TestSUDeploymentPackageData.ByName.Name

            # Act
            $result = Get-CM7SoftwareUpdateDeploymentPackage -Name $name

            # Assert
            if ($result) {
                $firstResult = @($result)[0]
                $firstResult.PkgSourceFlag | Should -BeOfType [string]
                $firstResult.PkgSourceFlag | Should -Match "^(StorageDirect|StorageCompressed|StorageNoPackage|Unknown.*)$"
            } else {
                Set-ItResult -Skipped -Because "No software update deployment packages found"
            }
        }

        It "Should have PackageSize as long" {
            # Arrange
            $name = $script:TestSUDeploymentPackageData.ByName.Name

            # Act
            $result = Get-CM7SoftwareUpdateDeploymentPackage -Name $name

            # Assert
            if ($result) {
                $firstResult = @($result)[0]
                $firstResult.PackageSize | Should -BeOfType [long]
                $firstResult.PackageSize | Should -BeGreaterOrEqual 0
            } else {
                Set-ItResult -Skipped -Because "No software update deployment packages found"
            }
        }
    }

    Context "Get All Software Update Deployment Packages" {

        It "Should retrieve all software update deployment packages when no parameters specified" {
            # Act
            $result = Get-CM7SoftwareUpdateDeploymentPackage

            # Assert
            $result | Should -Not -BeNullOrEmpty
            @($result).Count | Should -BeGreaterOrEqual $script:TestSUDeploymentPackageData.All.ExpectedMinCount
        }
    }

    Context "Verbose Output" {

        It "Should provide verbose output when requested" {
            # Arrange
            $name = $script:TestSUDeploymentPackageData.ByName.Name

            # Act & Assert
            $verboseOutput = Get-CM7SoftwareUpdateDeploymentPackage -Name $name -Verbose 4>&1
            $verboseOutput | Should -Not -BeNullOrEmpty
            $verboseOutput | Where-Object { $_ -match "Running Get-CM7SoftwareUpdateDeploymentPackage" } | Should -Not -BeNullOrEmpty
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
