# Functional Tests for Remove-CM7Application
# Tests the Remove-CM7Application function behavior and return values

BeforeAll {
    # Load test declarations
    . (Join-Path $PSScriptRoot "declarations.ps1")

    # Load all functions
    $CodePath = Join-Path (Get-Item $PSScriptRoot).Parent.FullName "Code"
    Get-ChildItem -Path (Join-Path $CodePath "Private") -Filter "*.ps1" | ForEach-Object { . $_.FullName }
    Get-ChildItem -Path (Join-Path $CodePath "Public") -Filter "*.ps1" | ForEach-Object { . $_.FullName }

    # Get test data for this function
    $script:TestRemoveAppData = $script:TestData['Remove-CM7Application']
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

Describe "Remove-CM7Application Function Tests" -Tag "Integration", "Application", "Remove" {

    Context "Test Data Validation" {
        It "Should have test data defined in declarations.ps1" {
            $script:TestRemoveAppData | Should -Not -BeNullOrEmpty
            $script:TestData.ContainsKey('Remove-CM7Application') | Should -Be $true
        }
        It "Should have required test data parameter sets" {
            $script:TestRemoveAppData.ContainsKey('ByName') | Should -Be $true
            $script:TestRemoveAppData.ContainsKey('ByID') | Should -Be $true
            $script:TestRemoveAppData.ContainsKey('NonExistent') | Should -Be $true
        }
        It "Should output test data for verification" {
            Write-Host "`n=== Test Data for Remove-CM7Application ===" -ForegroundColor Cyan
            Write-Host "ByName:" -ForegroundColor Yellow
            Write-Host "  Name: $($script:TestRemoveAppData.ByName.Name)" -ForegroundColor White
            Write-Host "  ExpectedResult: $($script:TestRemoveAppData.ByName.ExpectedResult)" -ForegroundColor White
            Write-Host "ByID:" -ForegroundColor Yellow
            Write-Host "  ID: $($script:TestRemoveAppData.ByID.ID)" -ForegroundColor White
            Write-Host "  ExpectedResult: $($script:TestRemoveAppData.ByID.ExpectedResult)" -ForegroundColor White
            Write-Host "NonExistent:" -ForegroundColor Yellow
            Write-Host "  Name: $($script:TestRemoveAppData.NonExistent.Name)" -ForegroundColor White
            Write-Host "  ID: $($script:TestRemoveAppData.NonExistent.ID)" -ForegroundColor White
            Write-Host "  ExpectedResult: $($script:TestRemoveAppData.NonExistent.ExpectedResult)" -ForegroundColor White
            Write-Host "============================================================`n" -ForegroundColor Cyan
            $true | Should -Be $true
        }
    }

    Context "Connection Requirement" {
        It "Should fail if not connected to MECM" {
            $backupConnection = $script:CMConnection.Clone()
            $script:CMConnection.CimSession = $null
            { Remove-CM7Application -Name 'X' } | Should -Throw "*not connected*"
            $script:CMConnection = $backupConnection
        }
    }

    Context "Remove Application By Name" {
        It "Should create and then remove an application by name" {
            # Arrange
            $uniqueName = "PESTER_APP_Remove_$(Get-Date -Format 'yyyyMMddHHmmss')"
            $newApp = New-CM7Application -Name $uniqueName -Publisher 'TestPub' -SoftwareVersion '1.0'
            $newApp | Should -Not -BeNullOrEmpty
            $newApp.CI_ID | Should -BeGreaterThan 0
            # Act
            $result = Remove-CM7Application -Name $uniqueName -Force
            # Assert
            $result | Should -Be $true
            # Confirm removal
            $check = Get-CM7Application -Name $uniqueName -IsLatest
            $check | Should -BeNullOrEmpty
        }
    }

    Context "Remove Application By ID" {
        It "Should create and then remove an application by ID" {
            # Arrange
            $uniqueName = "PESTER_APP_RemoveID_$(Get-Date -Format 'yyyyMMddHHmmss')"
            $newApp = New-CM7Application -Name $uniqueName -Publisher 'TestPub' -SoftwareVersion '1.0'
            $newApp | Should -Not -BeNullOrEmpty
            $newApp.CI_ID | Should -BeGreaterThan 0
            # Act
            $result = Remove-CM7Application -ID $newApp.CI_ID -Force
            # Assert
            $result | Should -Be $true
            # Confirm removal
            $check = Get-CM7Application -ID $newApp.CI_ID -IsLatest
            $check | Should -BeNullOrEmpty
        }
    }

    Context "Remove Application by InputObject" {
        It "Should remove applications specified by input objects" {
            # Arrange
            $uniqueName1 = "PESTER_APP_InputObj1_$(Get-Date -Format 'yyyyMMddHHmmss')"
            $uniqueName2 = "PESTER_APP_InputObj2_$(Get-Date -Format 'yyyyMMddHHmmss')"
            $app1 = New-CM7Application -Name $uniqueName1 -Publisher 'TestPub' -SoftwareVersion '1.0'
            $app2 = New-CM7Application -Name $uniqueName2 -Publisher 'TestPub' -SoftwareVersion '1.0'
            $appsToRemove = @($app1, $app2)
            # Act
            # Note: This test assumes the ByInputObject parameter set is implemented in the function
            # $result = Remove-CM7Application -InputObject $appsToRemove -Force
            # Assert
            # $result | Should -Be $true
            # Confirm removal

            foreach ($app in $appsToRemove) {
                $app | Remove-CM7Application -Force | Out-Null
                $check = Get-CM7Application -ID $app.CI_ID -IsLatest
                $check | Should -BeNullOrEmpty
            }
        }
    }

    Context "Remove Non-Existent Application" {
        It "Should return false for non-existent application by name" {
            $result = Remove-CM7Application -Name $script:TestRemoveAppData.NonExistent.Name -Force
            $result | Should -Be $false
        }
        It "Should return false for non-existent application by ID" {
            $result = Remove-CM7Application -ID $script:TestRemoveAppData.NonExistent.ID -Force
            $result | Should -Be $false
        }
    }
}
