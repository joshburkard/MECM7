# Functional Tests for New-CM7Boundary
# Tests the New-CM7Boundary function behavior and return values

BeforeAll {
    # Load test declarations
    . (Join-Path $PSScriptRoot "declarations.ps1")

    # Load all functions
    $CodePath = Join-Path (Get-Item $PSScriptRoot).Parent.FullName "Code"
    Get-ChildItem -Path (Join-Path $CodePath "Private") -Filter "*.ps1" | ForEach-Object { . $_.FullName }
    Get-ChildItem -Path (Join-Path $CodePath "Public") -Filter "*.ps1" | ForEach-Object { . $_.FullName }

    # Get test data for this function
    $script:TestNewBoundaryData = $script:TestData['New-CM7Boundary']
    $script:TestConnectData = $script:TestData['Connect-CM7']

    # Track created boundaries for cleanup
    $script:CreatedBoundaryIds = @()

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

Describe "New-CM7Boundary Function Tests" -Tag "Integration", "Boundary", "New" {

    Context "Test Data Validation" {
        It "Should have test data defined in declarations.ps1" {
            $script:TestNewBoundaryData | Should -Not -BeNullOrEmpty
            $script:TestData.ContainsKey('New-CM7Boundary') | Should -Be $true
        }
    }

    Context "Create IP Subnet Boundary" {
        It "Should create a new IP Subnet boundary" {
            $params = $script:TestNewBoundaryData.IPSubnet
            $result = New-CM7Boundary @params -Force
            $result | Should -Not -BeNullOrEmpty
            $result.BoundaryType | Should -Be 0
            $result.Value | Should -Be $params.Value
            $script:CreatedBoundaryIds += $result.BoundaryID
        }
    }

    Context "Create IP Range Boundary" {
        It "Should create a new IP Range boundary" {
            $params = $script:TestNewBoundaryData.IPRange
            $result = New-CM7Boundary @params -Force
            $result | Should -Not -BeNullOrEmpty
            $result.BoundaryType | Should -Be 3
            $result.Value | Should -Be $params.Value
            $script:CreatedBoundaryIds += $result.BoundaryID
        }
    }

    Context "Duplicate Name Handling" {
        It "Should throw if boundary name already exists" {
            $params = $script:TestNewBoundaryData.IPSubnet
            { New-CM7Boundary @params -Force } | Should -Throw
        }
    }
}
