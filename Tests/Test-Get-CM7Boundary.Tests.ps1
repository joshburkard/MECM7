# Functional Tests for Get-CM7Boundary
# Tests the Get-CM7Boundary function behavior and return values

BeforeAll {
    # Load test declarations
    . (Join-Path $PSScriptRoot "declarations.ps1")

    # Load all functions
    $CodePath = Join-Path (Get-Item $PSScriptRoot).Parent.FullName "Code"
    Get-ChildItem -Path (Join-Path $CodePath "Private") -Filter "*.ps1" | ForEach-Object { . $_.FullName }
    Get-ChildItem -Path (Join-Path $CodePath "Public") -Filter "*.ps1" | ForEach-Object { . $_.FullName }

    # Get test data for this function
    $script:TestBoundaryData = $script:TestData['Get-CM7Boundary']
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

Describe "Get-CM7Boundary Function Tests" -Tag "Integration", "Boundary" {

    Context "Test Data Validation" {
        It "Should have test data defined in declarations.ps1" {
            $script:TestBoundaryData | Should -Not -BeNullOrEmpty
            $script:TestData.ContainsKey('Get-CM7Boundary') | Should -Be $true
        }
        It "Should have required test data parameter sets" {
            $script:TestBoundaryData.ContainsKey('ByName') | Should -Be $true
            $script:TestBoundaryData.ContainsKey('ByBoundaryId') | Should -Be $true
            $script:TestBoundaryData.ContainsKey('NonExistent') | Should -Be $true
            $script:TestBoundaryData.ContainsKey('All') | Should -Be $true
        }
    }

    Context "Get by Name" {
        It "Should return the TEST GINO boundary by name" {
            $data = $script:TestBoundaryData.ByName
            $result = Get-CM7Boundary -Name $data.Name
            $result | Should -Not -BeNullOrEmpty
            @($result | Where-Object { $_.DisplayName -eq $data.Name }).Count | Should -Be $data.ExpectedCount
        }
    }

    Context "Get by BoundaryId" {
        It "Should return the TEST GINO boundary by BoundaryId" {
            $data = $script:TestBoundaryData.ByBoundaryId
            $result = Get-CM7Boundary -BoundaryId $data.BoundaryId
            $result | Should -Not -BeNullOrEmpty
            @($result | Where-Object { $_.BoundaryID -eq $data.BoundaryId }).Count | Should -Be $data.ExpectedCount
        }
    }

    Context "Get all boundaries" {
        It "Should return at least one boundary" {
            $data = $script:TestBoundaryData.All
            $result = Get-CM7Boundary
            @($result).Count | Should -BeGreaterOrEqual $data.ExpectedMinCount
        }
    }

    Context "Get non-existent boundary" {
        It "Should return no results for a non-existent boundary name" {
            $data = $script:TestBoundaryData.NonExistent
            $result = Get-CM7Boundary -Name $data.Name
            $result | Should -BeNullOrEmpty
        }
        It "Should return no results for a non-existent boundary id" {
            $data = $script:TestBoundaryData.NonExistent
            $result = Get-CM7Boundary -BoundaryId $data.BoundaryId
            $result | Should -BeNullOrEmpty
        }
    }
}
