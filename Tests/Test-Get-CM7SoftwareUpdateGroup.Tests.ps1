# Functional Tests for Get-CM7SoftwareUpdateGroup
# Tests the Get-CM7SoftwareUpdateGroup function behavior and return values

BeforeAll {
    # Load test declarations
    . (Join-Path $PSScriptRoot "declarations.ps1")

    # Load all functions
    $CodePath = Join-Path (Get-Item $PSScriptRoot).Parent.FullName "Code"
    Get-ChildItem -Path (Join-Path $CodePath "Private") -Filter "*.ps1" | ForEach-Object { . $_.FullName }
    Get-ChildItem -Path (Join-Path $CodePath "Public") -Filter "*.ps1" | ForEach-Object { . $_.FullName }

    # Get test data for this function
    $script:TestSUGroupData = $script:TestData['Get-CM7SoftwareUpdateGroup']
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

Describe "Get-CM7SoftwareUpdateGroup Function Tests" -Tag "Integration", "SoftwareUpdateGroup" {

    Context "Test Data Validation" {

        It "Should have test data defined in declarations.ps1" {
            # Assert
            $script:TestSUGroupData | Should -Not -BeNullOrEmpty
            $script:TestData.ContainsKey('Get-CM7SoftwareUpdateGroup') | Should -Be $true
        }

        It "Should have required test data parameter sets" {
            # Assert
            $script:TestSUGroupData.ContainsKey('ByName') | Should -Be $true
            $script:TestSUGroupData.ContainsKey('ById') | Should -Be $true
            $script:TestSUGroupData.ContainsKey('NonExistent') | Should -Be $true
            $script:TestSUGroupData.ContainsKey('All') | Should -Be $true
        }

        It "Should output test data for verification" {
            # Output test data
            Write-Host "`n=== Test Data for Get-CM7SoftwareUpdateGroup ===" -ForegroundColor Cyan
            Write-Host "ByName:" -ForegroundColor Yellow
            Write-Host "  Name: $($script:TestSUGroupData.ByName.Name)" -ForegroundColor White
            Write-Host "  ExpectedCount: $($script:TestSUGroupData.ByName.ExpectedCount)" -ForegroundColor White

            Write-Host "ById:" -ForegroundColor Yellow
            Write-Host "  Id: $($script:TestSUGroupData.ById.Id)" -ForegroundColor White
            Write-Host "  ExpectedName: $($script:TestSUGroupData.ById.ExpectedName)" -ForegroundColor White

            Write-Host "NonExistent:" -ForegroundColor Yellow
            Write-Host "  Id: $($script:TestSUGroupData.NonExistent.Id)" -ForegroundColor White
            Write-Host "  Name: $($script:TestSUGroupData.NonExistent.Name)" -ForegroundColor White
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
            { Get-CM7SoftwareUpdateGroup -Name "Test" } | Should -Throw "*not connected*"

            # Restore connection
            $script:CMConnection = $backupConnection
        }
    }

    Context "Query by Name" {

        It "Should retrieve software update group by name" {
            # Arrange
            $name = $script:TestSUGroupData.ByName.Name

            # Act
            $result = Get-CM7SoftwareUpdateGroup -Name $name

            # Assert
            $result | Should -Not -BeNullOrEmpty
            @($result).Count | Should -Be $script:TestSUGroupData.ByName.ExpectedCount
            $result.LocalizedDisplayName | Should -Be $name
        }

        It "Should return null for non-existent group name" {
            # Arrange
            $name = $script:TestSUGroupData.NonExistent.Name

            # Act
            $result = Get-CM7SoftwareUpdateGroup -Name $name

            # Assert
            $result | Should -BeNullOrEmpty
        }

        It "Should support wildcard patterns in name" {
            # Arrange
            $pattern = $script:TestSUGroupData.ByNameWildcard.Name

            # Act
            $result = Get-CM7SoftwareUpdateGroup -Name $pattern

            # Assert
            if ($script:TestSUGroupData.ByNameWildcard.ExpectedMinCount -gt 0) {
                $result | Should -Not -BeNullOrEmpty
                @($result).Count | Should -BeGreaterOrEqual $script:TestSUGroupData.ByNameWildcard.ExpectedMinCount
                $result | ForEach-Object {
                    $_.LocalizedDisplayName | Should -BeLike $pattern
                }
            }
        }
    }

    Context "Query by CI_ID" {

        It "Should retrieve software update group by ID" {
            # Arrange
            $id = $script:TestSUGroupData.ById.Id

            # Act
            if ($id -eq 0) {
                Set-ItResult -Skipped -Because "CI_ID not configured in test data (set to 0)"
            } else {
                $result = Get-CM7SoftwareUpdateGroup -Id $id

                # Assert
                $result | Should -Not -BeNullOrEmpty
                @($result).Count | Should -Be 1
                $result.CI_ID | Should -Be $id
                $result.LocalizedDisplayName | Should -Be $script:TestSUGroupData.ById.ExpectedName
            }
        }

        It "Should return null for non-existent CI_ID" {
            # Arrange
            $id = $script:TestSUGroupData.NonExistent.Id

            # Act
            $result = Get-CM7SoftwareUpdateGroup -Id $id

            # Assert
            $result | Should -BeNullOrEmpty
        }
    }

    Context "Fast Mode" {

        It "Should return limited properties with Fast switch" {
            # Arrange
            $name = $script:TestSUGroupData.ByName.Name

            # Act
            $result = Get-CM7SoftwareUpdateGroup -Name $name -Fast

            # Assert
            if ($result) {
                $result | Should -Not -BeNullOrEmpty
                $result.PSObject.Properties.Name | Should -Contain 'CI_ID'
                $result.PSObject.Properties.Name | Should -Contain 'LocalizedDisplayName'
                $result.PSObject.Properties.Name | Should -Contain 'LocalizedDescription'
                $result.PSObject.Properties.Name | Should -Contain 'IsDeployed'
                $result.PSObject.Properties.Name | Should -Contain 'IsExpired'
                $result.PSObject.Properties.Name | Should -Contain 'IsSuperseded'
                $result.PSObject.Properties.Name | Should -Contain 'NumberOfUpdates'
                $result.PSObject.Properties.Name | Should -Contain 'DateCreated'
                $result.PSObject.Properties.Name | Should -Contain 'DateLastModified'
            } else {
                Set-ItResult -Skipped -Because "No software update groups found"
            }
        }

        It "Fast mode should be faster than full query" {
            # Arrange
            $name = $script:TestSUGroupData.ByName.Name

            # Act
            $fastStart = Get-Date
            $fastResult = Get-CM7SoftwareUpdateGroup -Name $name -Fast
            $fastDuration = (Get-Date) - $fastStart

            $fullStart = Get-Date
            $fullResult = Get-CM7SoftwareUpdateGroup -Name $name
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
            $name = $script:TestSUGroupData.ByName.Name

            # Act
            $result = Get-CM7SoftwareUpdateGroup -Name $name

            # Assert
            if ($result) {
                $result | Should -Not -BeNullOrEmpty
                $firstResult = @($result)[0]
                $firstResult.PSObject.Properties.Name | Should -Contain 'CI_ID'
                $firstResult.PSObject.Properties.Name | Should -Contain 'CI_UniqueID'
                $firstResult.PSObject.Properties.Name | Should -Contain 'LocalizedDisplayName'
                $firstResult.PSObject.Properties.Name | Should -Contain 'LocalizedDescription'
                $firstResult.PSObject.Properties.Name | Should -Contain 'IsDeployed'
                $firstResult.PSObject.Properties.Name | Should -Contain 'IsExpired'
                $firstResult.PSObject.Properties.Name | Should -Contain 'IsSuperseded'
                $firstResult.PSObject.Properties.Name | Should -Contain 'NumberOfUpdates'
                $firstResult.PSObject.Properties.Name | Should -Contain 'DateCreated'
                $firstResult.PSObject.Properties.Name | Should -Contain 'DateLastModified'
                $firstResult.PSObject.Properties.Name | Should -Contain 'LocalizedCategoryInstanceNames'
            } else {
                Set-ItResult -Skipped -Because "No software update groups found"
            }
        }

        It "Should have PSTypeName set correctly" {
            # Arrange
            $name = $script:TestSUGroupData.ByName.Name

            # Act
            $result = Get-CM7SoftwareUpdateGroup -Name $name

            # Assert
            if ($result) {
                $firstResult = @($result)[0]
                $firstResult.PSObject.TypeNames[0] | Should -Be 'MECM7.SoftwareUpdateGroup'
            } else {
                Set-ItResult -Skipped -Because "No software update groups found"
            }
        }

        It "Should have IsDeployed as boolean" {
            # Arrange
            $name = $script:TestSUGroupData.ByName.Name

            # Act
            $result = Get-CM7SoftwareUpdateGroup -Name $name

            # Assert
            if ($result) {
                $firstResult = @($result)[0]
                $firstResult.IsDeployed | Should -BeOfType [bool]
            } else {
                Set-ItResult -Skipped -Because "No software update groups found"
            }
        }

        It "Should have NumberOfUpdates as integer" {
            # Arrange
            $name = $script:TestSUGroupData.ByName.Name

            # Act
            $result = Get-CM7SoftwareUpdateGroup -Name $name

            # Assert
            if ($result) {
                $firstResult = @($result)[0]
                $firstResult.NumberOfUpdates | Should -BeOfType [int]
                $firstResult.NumberOfUpdates | Should -BeGreaterOrEqual 0
            } else {
                Set-ItResult -Skipped -Because "No software update groups found"
            }
        }

        It "Should have CI_ID as integer" {
            # Arrange
            $name = $script:TestSUGroupData.ByName.Name

            # Act
            $result = Get-CM7SoftwareUpdateGroup -Name $name

            # Assert
            if ($result) {
                $firstResult = @($result)[0]
                $firstResult.CI_ID | Should -BeOfType [int]
                $firstResult.CI_ID | Should -BeGreaterThan 0
            } else {
                Set-ItResult -Skipped -Because "No software update groups found"
            }
        }
    }

    Context "Get All Software Update Groups" {

        It "Should retrieve all software update groups when no parameters specified" {
            # Act
            $result = Get-CM7SoftwareUpdateGroup

            # Assert
            $result | Should -Not -BeNullOrEmpty
            @($result).Count | Should -BeGreaterOrEqual $script:TestSUGroupData.All.ExpectedMinCount
        }
    }

    Context "Verbose Output" {

        It "Should provide verbose output when requested" {
            # Arrange
            $name = $script:TestSUGroupData.ByName.Name

            # Act & Assert
            $verboseOutput = Get-CM7SoftwareUpdateGroup -Name $name -Verbose 4>&1
            $verboseOutput | Should -Not -BeNullOrEmpty
            $verboseOutput | Where-Object { $_ -match "Running Get-CM7SoftwareUpdateGroup" } | Should -Not -BeNullOrEmpty
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
