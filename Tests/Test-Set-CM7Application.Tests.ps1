# Functional Tests for Set-CM7Application
# Tests the Set-CM7Application function behavior and return values

BeforeAll {
    # Load test declarations
    . (Join-Path $PSScriptRoot "declarations.ps1")

    # Load all functions
    $CodePath = Join-Path (Get-Item $PSScriptRoot).Parent.FullName "Code"
    Get-ChildItem -Path (Join-Path $CodePath "Private") -Filter "*.ps1" | ForEach-Object { . $_.FullName }
    Get-ChildItem -Path (Join-Path $CodePath "Public") -Filter "*.ps1" | ForEach-Object { . $_.FullName }

    # Get test data for this function
    $script:TestAppData = $script:TestData['Set-CM7Application']
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

Describe "Set-CM7Application Function Tests" -Tag "Integration", "Application" {

    Context "Test Data Validation" {
        It "Should have test data defined in declarations.ps1" {
            $script:TestAppData | Should -Not -BeNullOrEmpty
            $script:TestData.ContainsKey('Set-CM7Application') | Should -Be $true
        }
        It "Should have required test data parameter sets" {
            $script:TestAppData.ContainsKey('Valid') | Should -Be $true
            $script:TestAppData.ContainsKey('NonExistent') | Should -Be $true
        }
        It "Should output test data for verification" {
            Write-Host "`n=== Test Data for Set-CM7Application ===" -ForegroundColor Cyan
            Write-Host "Valid:" -ForegroundColor Yellow
            Write-Host "  Name: $($script:TestAppData.Valid.Name)" -ForegroundColor White
            Write-Host "  NewDescription: $($script:TestAppData.Valid.NewDescription)" -ForegroundColor White
            Write-Host "NonExistent:" -ForegroundColor Yellow
            Write-Host "  Name: $($script:TestAppData.NonExistent.Name)" -ForegroundColor White
            Write-Host "============================================================`n" -ForegroundColor Cyan
            $true | Should -Be $true
        }
    }

    Context "Connection Requirement" {
        It "Should fail if not connected to MECM" {
            $backupConnection = $script:CMConnection.Clone()
            $script:CMConnection.CimSession = $null
            { Set-CM7Application -Name "Test" -Description "desc" } | Should -Throw "*not connected*"
            $script:CMConnection = $backupConnection
        }
    }

    Context "Set and Validate Application Properties" {
        It "Should create, modify, and remove an application" {
            $params = $script:TestAppData.Valid
            # Create application
            $created = New-CM7Application -Name $params.Name -Publisher $params.Publisher -SoftwareVersion $params.SoftwareVersion -Description $params.Description -Owner $params.Owner -SupportContact $params.SupportContact -SupportUrl $params.SupportUrl -InfoUrl $params.InfoUrl -PrivacyUrl $params.PrivacyUrl -IsEnabled $params.IsEnabled -IsHidden $params.IsHidden -AutoInstall $params.AutoInstall
            $created | Should -Not -BeNullOrEmpty
            $created.LocalizedDisplayName | Should -Be $params.Name
            # Modify application
            $modified = Set-CM7Application -Name $params.Name -Description $params.NewDescription
            $modified | Should -Not -BeNullOrEmpty
            # Validate change
            $fetched = Get-CM7Application -Name $params.Name
            $fetched.LocalizedDescription | Should -Be $params.NewDescription
            # Remove application
            $removed = Remove-CM7Application -Name $params.Name -Force
            $removed | Should -Be $true
        }
        It "Should throw for non-existent application" {
            $params = $script:TestAppData.NonExistent
            { Set-CM7Application -Name $params.Name -Description "desc" } | Should -Throw
        }
    }
}
