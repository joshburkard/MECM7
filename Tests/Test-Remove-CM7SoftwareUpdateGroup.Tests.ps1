Describe 'Remove-CM7SoftwareUpdateGroup' {
    BeforeAll {
        # Load test declarations
        . (Join-Path $PSScriptRoot "declarations.ps1")

        # Load all functions
        $CodePath = Join-Path (Get-Item $PSScriptRoot).Parent.FullName "Code"
        Get-ChildItem -Path (Join-Path $CodePath "Private") -Filter "*.ps1" | ForEach-Object { . $_.FullName }
        Get-ChildItem -Path (Join-Path $CodePath "Public") -Filter "*.ps1" | ForEach-Object { . $_.FullName }

        # Track created package IDs for cleanup
        $script:CreatedPackageIds = @()

        # Get test data for this function
        $script:TestRemoveSUDPkgData = $script:TestData['Remove-CM7SoftwareUpdateGroup']
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

        # Create test software update group for removal tests
        $params = Get-TestData -FunctionName 'Remove-CM7SoftwareUpdateGroup' -ParameterSet 'ByName'
        New-CM7SoftwareUpdateGroup -Name $params.Name
        $params = Get-TestData -FunctionName 'Remove-CM7SoftwareUpdateGroup' -ParameterSet 'ById'
        New-CM7SoftwareUpdateGroup -Name $params.Name
    }

    Context "Test Data Validation" {

        It "Should have test data defined in declarations.ps1" {
            # Assert
            $script:TestRemoveSUDPkgData | Should -Not -BeNullOrEmpty
            $script:TestData.ContainsKey('Remove-CM7SoftwareUpdateGroup') | Should -Be $true
        }

        It "Should have required test data parameter sets" {
            # Assert
            $script:TestRemoveSUDPkgData.ContainsKey('ByName') | Should -Be $true
            $script:TestRemoveSUDPkgData.ContainsKey('ById') | Should -Be $true
            $script:TestRemoveSUDPkgData.ContainsKey('NonExistent') | Should -Be $true
        }

        It "Should output test data for verification" {
            # Output test data
            Write-Host "`n=== Test Data for Remove-CM7SoftwareUpdateGroup ===" -ForegroundColor Cyan
            Write-Host "TestDeployment:" -ForegroundColor Yellow
            Write-Host "  ByName: $($script:TestRemoveSUDPkgData.ByName.Name)" -ForegroundColor White
            Write-Host "  ById: $($script:TestRemoveSUDPkgData.ById.Id)" -ForegroundColor White
            Write-Host "  NonExistent: $($script:TestRemoveSUDPkgData.NonExistent.Name)" -ForegroundColor White

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
            { Remove-CM7SoftwareUpdateGroup -Name "NonExistentGroup" -Force } | Should -Throw "*not connected*"

            # Restore connection
            $script:CMConnection = $backupConnection
        }
    }

    Context "WhatIf Support" {
        It "Should support -WhatIf parameter" {
            $params = Get-TestData -FunctionName 'Remove-CM7SoftwareUpdateGroup' -ParameterSet 'ByName'
            { Remove-CM7SoftwareUpdateGroup @params -WhatIf } | Should -Not -Throw
        }
    }

    Context 'Remove by Name' {
        It 'Removes a software update group by name' {
            $testData = Get-TestData -FunctionName 'Remove-CM7SoftwareUpdateGroup' -ParameterSet 'ByName'
            $result = Remove-CM7SoftwareUpdateGroup -Name $testData.Name -Force -confirm:$false
            $result.Status | Should -Be 'Removed'
        }
    }

    Context 'Remove by CI_ID' {
        It 'Removes a software update group by CI_ID' {
            $testData = Get-TestData -FunctionName 'Remove-CM7SoftwareUpdateGroup' -ParameterSet 'ById'
            $testSUG = Get-CM7SoftwareUpdateGroup -Name $testData.Name
            $result = Remove-CM7SoftwareUpdateGroup -CI_ID $testSUG.CI_ID -Force -confirm:$false
            $result.Status | Should -Be 'Removed'
        }
    }

    Context 'Remove non-existent group' {
        It 'Throws error for non-existent group' {
            $testData = Get-TestData -FunctionName 'Remove-CM7SoftwareUpdateGroup' -ParameterSet 'NonExistent'
            { Remove-CM7SoftwareUpdateGroup -Name $testData.Name -Force 2>$null } | Should -Throw
        }
    }
}
