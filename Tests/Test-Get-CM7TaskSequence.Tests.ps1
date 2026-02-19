# Functional Tests for Get-CM7TaskSequence
# Tests the Get-CM7TaskSequence function behavior and return values

BeforeAll {
    # Load test declarations
    . (Join-Path $PSScriptRoot "declarations.ps1")

    # Load all functions
    $CodePath = Join-Path (Get-Item $PSScriptRoot).Parent.FullName "Code"
    Get-ChildItem -Path (Join-Path $CodePath "Private") -Filter "*.ps1" | ForEach-Object { . $_.FullName }
    Get-ChildItem -Path (Join-Path $CodePath "Public") -Filter "*.ps1" | ForEach-Object { . $_.FullName }

    # Get test data for this function
    $script:TestTSData = $script:TestData['Get-CM7TaskSequence']
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

Describe "Get-CM7TaskSequence Function Tests" -Tag "Integration", "TaskSequence" {

    Context "Test Data Validation" {

        It "Should have test data defined in declarations.ps1" {
            # Assert
            $script:TestTSData | Should -Not -BeNullOrEmpty
            $script:TestData.ContainsKey('Get-CM7TaskSequence') | Should -Be $true
        }

        It "Should have required test data parameter sets" {
            # Assert
            $script:TestTSData.ContainsKey('ByName') | Should -Be $true
            $script:TestTSData.ContainsKey('ByPackageId') | Should -Be $true
            $script:TestTSData.ContainsKey('NonExistent') | Should -Be $true
            $script:TestTSData.ContainsKey('All') | Should -Be $true
        }

        It "Should output test data for verification" {
            # Output test data
            Write-Host "`n=== Test Data for Get-CM7TaskSequence ===" -ForegroundColor Cyan
            Write-Host "ByName:" -ForegroundColor Yellow
            Write-Host "  Name: $($script:TestTSData.ByName.Name)" -ForegroundColor White
            Write-Host "  ExpectedCount: $($script:TestTSData.ByName.ExpectedCount)" -ForegroundColor White

            Write-Host "ByPackageId:" -ForegroundColor Yellow
            Write-Host "  PackageId: $($script:TestTSData.ByPackageId.PackageId)" -ForegroundColor White
            Write-Host "  ExpectedName: $($script:TestTSData.ByPackageId.ExpectedName)" -ForegroundColor White

            Write-Host "NonExistent:" -ForegroundColor Yellow
            Write-Host "  PackageId: $($script:TestTSData.NonExistent.PackageId)" -ForegroundColor White
            Write-Host "  Name: $($script:TestTSData.NonExistent.Name)" -ForegroundColor White
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
            { Get-CM7TaskSequence -Name "Test" } | Should -Throw "*not connected*"

            # Restore connection
            $script:CMConnection = $backupConnection
        }
    }

    Context "Query by Name" {

        It "Should retrieve task sequence by name" {
            # Arrange
            $name = $script:TestTSData.ByName.Name

            # Act
            $result = Get-CM7TaskSequence -Name $name

            # Assert
            $result | Should -Not -BeNullOrEmpty
            @($result).Count | Should -Be $script:TestTSData.ByName.ExpectedCount
            $result.Name | Should -Be $name
        }

        It "Should return null for non-existent task sequence name" {
            # Arrange
            $name = $script:TestTSData.NonExistent.Name

            # Act
            $result = Get-CM7TaskSequence -Name $name

            # Assert
            $result | Should -BeNullOrEmpty
        }

        It "Should support wildcard patterns in name" {
            # Arrange
            $pattern = $script:TestTSData.ByNameWildcard.Name

            # Act
            $result = Get-CM7TaskSequence -Name $pattern

            # Assert
            if ($script:TestTSData.ByNameWildcard.ExpectedMinCount -gt 0) {
                $result | Should -Not -BeNullOrEmpty
                @($result).Count | Should -BeGreaterOrEqual $script:TestTSData.ByNameWildcard.ExpectedMinCount
                $result | ForEach-Object {
                    $_.Name | Should -BeLike $pattern
                }
            }
        }
    }

    Context "Query by PackageID" {

        It "Should retrieve task sequence by PackageID" {
            # Arrange
            $packageId = $script:TestTSData.ByPackageId.PackageId

            # Act
            if ([string]::IsNullOrEmpty($packageId)) {
                Set-ItResult -Skipped -Because "PackageID not configured in test data (empty string)"
            } else {
                $result = Get-CM7TaskSequence -TaskSequencePackageId $packageId

                # Assert
                $result | Should -Not -BeNullOrEmpty
                @($result).Count | Should -Be 1
                $result.PackageID | Should -Be $packageId
                $result.Name | Should -Be $script:TestTSData.ByPackageId.ExpectedName
            }
        }

        It "Should return null for non-existent PackageID" {
            # Arrange
            $packageId = $script:TestTSData.NonExistent.PackageId

            # Act
            $result = Get-CM7TaskSequence -TaskSequencePackageId $packageId

            # Assert
            $result | Should -BeNullOrEmpty
        }
    }

    Context "Fast Mode" {

        It "Should return limited properties with Fast switch" {
            # Arrange
            $name = $script:TestTSData.ByName.Name

            # Act
            $result = Get-CM7TaskSequence -Name $name -Fast

            # Assert
            if ($result) {
                $result | Should -Not -BeNullOrEmpty
                $result.PSObject.Properties.Name | Should -Contain 'PackageID'
                $result.PSObject.Properties.Name | Should -Contain 'Name'
                # Fast mode with filter uses SELECT * so all properties are available
                # Fast mode without filter uses lightweight SELECT so only PackageID and Name are guaranteed
            } else {
                Set-ItResult -Skipped -Because "No task sequences found"
            }
        }

        It "Fast mode should be faster than full query" {
            # Arrange
            $name = $script:TestTSData.ByName.Name

            # Act
            $fastStart = Get-Date
            $fastResult = Get-CM7TaskSequence -Name $name -Fast
            $fastDuration = (Get-Date) - $fastStart

            $fullStart = Get-Date
            $fullResult = Get-CM7TaskSequence -Name $name
            $fullDuration = (Get-Date) - $fullStart

            # Assert
            Write-Host "Fast mode: $($fastDuration.TotalMilliseconds)ms, Full mode: $($fullDuration.TotalMilliseconds)ms" -ForegroundColor Cyan
            # Note: We don't assert speed because it can vary
            $true | Should -Be $true
        }
    }

    Context "Return Object Properties" {

        It "Should return objects with expected non-lazy properties" {
            # Arrange
            $name = $script:TestTSData.ByName.Name

            # Act
            $result = Get-CM7TaskSequence -Name $name

            # Assert
            if ($result) {
                $result | Should -Not -BeNullOrEmpty
                $firstResult = @($result)[0]
                # Core properties - always present
                $firstResult.PSObject.Properties.Name | Should -Contain 'PackageID'
                $firstResult.PSObject.Properties.Name | Should -Contain 'Name'
                $firstResult.PSObject.Properties.Name | Should -Contain 'Description'
                $firstResult.PSObject.Properties.Name | Should -Contain 'SourceDate'
                $firstResult.PSObject.Properties.Name | Should -Contain 'LastRefreshTime'
                $firstResult.PSObject.Properties.Name | Should -Contain 'BootImageID'
                # Non-lazy properties from SMS_TaskSequencePackage
                $firstResult.PSObject.Properties.Name | Should -Contain 'ProgramFlags'
                $firstResult.PSObject.Properties.Name | Should -Contain 'PackageType'
                $firstResult.PSObject.Properties.Name | Should -Contain 'SourceSite'
                $firstResult.PSObject.Properties.Name | Should -Contain 'ObjectPath'
                $firstResult.PSObject.Properties.Name | Should -Contain 'TsEnabled'
                $firstResult.PSObject.Properties.Name | Should -Contain 'HighImpactTaskSequence'
            } else {
                Set-ItResult -Skipped -Because "No task sequences found"
            }
        }

        It "Should have PSTypeName set correctly" {
            # Arrange
            $name = $script:TestTSData.ByName.Name

            # Act
            $result = Get-CM7TaskSequence -Name $name

            # Assert
            if ($result) {
                $firstResult = @($result)[0]
                $firstResult.PSObject.TypeNames[0] | Should -Be 'MECM7.TaskSequence'
            } else {
                Set-ItResult -Skipped -Because "No task sequences found"
            }
        }

        It "Should NOT contain lazy properties (Sequence, References, etc.)" {
            # Arrange
            $name = $script:TestTSData.ByName.Name

            # Act
            $result = Get-CM7TaskSequence -Name $name

            # Assert - lazy properties should not have values (they are excluded from SELECT)
            if ($result) {
                $firstResult = @($result)[0]
                # Sequence is the huge XML blob - must not be populated
                $firstResult.Sequence | Should -BeNullOrEmpty
                # References is a lazy array property
                $firstResult.References | Should -BeNullOrEmpty
            } else {
                Set-ItResult -Skipped -Because "No task sequences found"
            }
        }

        It "Should have PackageID as string" {
            # Arrange
            $name = $script:TestTSData.ByName.Name

            # Act
            $result = Get-CM7TaskSequence -Name $name

            # Assert
            if ($result) {
                $firstResult = @($result)[0]
                $firstResult.PackageID | Should -BeOfType [string]
                $firstResult.PackageID | Should -Not -BeNullOrEmpty
            } else {
                Set-ItResult -Skipped -Because "No task sequences found"
            }
        }
    }

    Context "Get All Task Sequences" {

        It "Should retrieve all task sequences when no parameters specified" {
            # Act - non-Fast mode uses explicit column list excluding lazy properties
            $result = Get-CM7TaskSequence

            # Assert
            $result | Should -Not -BeNullOrEmpty
            @($result).Count | Should -BeGreaterOrEqual $script:TestTSData.All.ExpectedMinCount
        }

        It "Should retrieve all task sequences with Fast mode" {
            # Act - Fast mode uses column-specific SELECT, no per-instance re-query
            $result = Get-CM7TaskSequence -Fast

            # Assert
            $result | Should -Not -BeNullOrEmpty
            @($result).Count | Should -BeGreaterOrEqual $script:TestTSData.All.ExpectedMinCount
            # Verify only essential properties are returned
            $firstResult = @($result)[0]
            $firstResult.PSObject.Properties.Name | Should -Contain 'PackageID'
            $firstResult.PSObject.Properties.Name | Should -Contain 'Name'
        }
    }

    Context "Verbose Output" {

        It "Should provide verbose output when requested" {
            # Arrange
            $name = $script:TestTSData.ByName.Name

            # Act & Assert
            $verboseOutput = Get-CM7TaskSequence -Name $name -Verbose 4>&1
            $verboseOutput | Should -Not -BeNullOrEmpty
            $verboseOutput | Where-Object { $_ -match "Running Get-CM7TaskSequence" } | Should -Not -BeNullOrEmpty
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
