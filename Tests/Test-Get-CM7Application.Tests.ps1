# Functional Tests for Get-CM7Application
# Tests the Get-CM7Application function behavior and return values

BeforeAll {
    # Load test declarations
    . (Join-Path $PSScriptRoot "declarations.ps1")

    # Load all functions
    $CodePath = Join-Path (Get-Item $PSScriptRoot).Parent.FullName "Code"
    Get-ChildItem -Path (Join-Path $CodePath "Private") -Filter "*.ps1" | ForEach-Object { . $_.FullName }
    Get-ChildItem -Path (Join-Path $CodePath "Public") -Filter "*.ps1" | ForEach-Object { . $_.FullName }

    $script:TestAppData = $script:TestData['Get-CM7Application']
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

Describe "Get-CM7Application Function Tests" -Tag "Integration", "Application" {
    Context "Test Data Validation" {
        It "Should have test data defined in declarations.ps1" {
            $script:TestAppData | Should -Not -BeNullOrEmpty
            $script:TestData.ContainsKey('Get-CM7Application') | Should -Be $true
        }
        It "Should have required test data parameter sets" {
            $script:TestAppData.ContainsKey('ByName') | Should -Be $true
            $script:TestAppData.ContainsKey('ByID') | Should -Be $true
            $script:TestAppData.ContainsKey('NonExistent') | Should -Be $true
        }
    }
    Context "Get-CM7Application ByName" {
        It "Should return the application by name" {
            $result = Get-CM7Application -Name $script:TestAppData.ByName.Name
            $result | Should -Not -BeNullOrEmpty
            ($result | Measure-Object).Count | Should -Be $script:TestAppData.ByName.ExpectedCount
            $result.LocalizedDisplayName | Should -Contain $script:TestAppData.ByName.Name
        }
    }
    Context "Get-CM7Application ByID" {
        It "Should return the application by ID" {
            $result = Get-CM7Application -ID $script:TestAppData.ByID.ID -IsLatest -ShowHidden
            $result | Should -Not -BeNullOrEmpty
            ($result | Measure-Object).Count | Should -Be $script:TestAppData.ByID.ExpectedCount
            $result.CI_ID | Should -Contain $script:TestAppData.ByID.ID
        }
    }
    Context "Get-CM7Application NonExistent" {
        It "Should return no results for non-existent application" {
            $result = Get-CM7Application -Name $script:TestAppData.NonExistent.Name
            $result | Should -BeNullOrEmpty
            $result = Get-CM7Application -ID $script:TestAppData.NonExistent.ID
            $result | Should -BeNullOrEmpty
        }
    }
    Context "Get-CM7Application All" {
        It "Should return at least one application" {
            $result = Get-CM7Application
            $result | Should -Not -BeNullOrEmpty
            @($result).Count | Should -BeGreaterOrEqual $script:TestAppData.All.ExpectedMinCount
        }
    }
    Context "Get-CM7Application All Fast" {
        It "Should return at least one application" {
            $result = Get-CM7Application -Fast
            $result | Should -Not -BeNullOrEmpty
            @($result).Count | Should -BeGreaterOrEqual $script:TestAppData.All.ExpectedMinCount
        }
    }
}
