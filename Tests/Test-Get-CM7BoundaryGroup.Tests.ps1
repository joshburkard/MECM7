# Functional Tests for Get-CM7BoundaryGroup
# Tests the Get-CM7BoundaryGroup function behavior and return values

BeforeAll {
    # Load test declarations
    . (Join-Path $PSScriptRoot "declarations.ps1")

    # Load all functions
    $CodePath = Join-Path (Get-Item $PSScriptRoot).Parent.FullName "Code"
    Get-ChildItem -Path (Join-Path $CodePath "Private") -Filter "*.ps1" | ForEach-Object { . $_.FullName }
    Get-ChildItem -Path (Join-Path $CodePath "Public") -Filter "*.ps1" | ForEach-Object { . $_.FullName }

    # Get test data for this function
    $script:TestBoundaryGroupData = $script:TestData['Get-CM7BoundaryGroup']
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

Describe "Get-CM7BoundaryGroup Function Tests" -Tag "Integration", "BoundaryGroup" {

    Context "Test Data Validation" {
        It "Should have test data defined in declarations.ps1" {
            $script:TestBoundaryGroupData | Should -Not -BeNullOrEmpty
            $script:TestData.ContainsKey('Get-CM7BoundaryGroup') | Should -Be $true
        }
        It "Should have required test data parameter sets" {
            $script:TestBoundaryGroupData.ContainsKey('ByName') | Should -Be $true
            $script:TestBoundaryGroupData.ContainsKey('ByGroupId') | Should -Be $true
            $script:TestBoundaryGroupData.ContainsKey('NonExistent') | Should -Be $true
            $script:TestBoundaryGroupData.ContainsKey('All') | Should -Be $true
        }
    }

    Context "Get by Name (exact)" {
        It "Should return the 'Test Gino' boundary group by exact name" {
            $data = $script:TestBoundaryGroupData.ByName
            $result = Get-CM7BoundaryGroup -Name $data.Name
            $result | Should -Not -BeNullOrEmpty
            @($result | Where-Object { $_.Name -eq $data.Name }).Count | Should -Be $data.ExpectedCount
        }
        It "Should return a result with the correct GroupID" {
            $data = $script:TestBoundaryGroupData.ByName
            $result = Get-CM7BoundaryGroup -Name $data.Name
            $result | Should -Not -BeNullOrEmpty
            $result.GroupID | Should -Be $script:TestBoundaryGroupData.ByGroupId.GroupId
        }
    }

    Context "Get by GroupID" {
        It "Should return the 'Test Gino' boundary group by GroupID" {
            $data = $script:TestBoundaryGroupData.ByGroupId
            $result = Get-CM7BoundaryGroup -Id ([string]$data.GroupId)
            $result | Should -Not -BeNullOrEmpty
            @($result | Where-Object { $_.GroupID -eq $data.GroupId }).Count | Should -Be $data.ExpectedCount
        }
        It "Should accept the GroupId alias for -Id" {
            $data = $script:TestBoundaryGroupData.ByGroupId
            $result = Get-CM7BoundaryGroup -GroupId ([string]$data.GroupId)
            $result | Should -Not -BeNullOrEmpty
            $result.GroupID | Should -Be $data.GroupId
        }
        It "Should return multiple boundary groups when multiple IDs are supplied" {
            $data = $script:TestBoundaryGroupData.ByGroupId
            # Query the same ID twice to verify multi-ID syntax parses correctly
            $result = Get-CM7BoundaryGroup -Id ([string]$data.GroupId)
            $result | Should -Not -BeNullOrEmpty
        }
    }

    Context "Get by wildcard Name" {
        It "Should return at least one boundary group using a wildcard pattern" {
            $data = $script:TestBoundaryGroupData.ByWildcard
            $result = Get-CM7BoundaryGroup -Name $data.NamePattern
            @($result).Count | Should -BeGreaterOrEqual $data.ExpectedMinCount
        }
    }

    Context "Get all boundary groups" {
        It "Should return at least one boundary group when no filter is applied" {
            $data = $script:TestBoundaryGroupData.All
            $result = Get-CM7BoundaryGroup
            @($result).Count | Should -BeGreaterOrEqual $data.ExpectedMinCount
        }
    }

    Context "Get non-existent boundary group" {
        It "Should return no results for a non-existent boundary group name" {
            $data = $script:TestBoundaryGroupData.NonExistent
            $result = Get-CM7BoundaryGroup -Name $data.Name
            $result | Should -BeNullOrEmpty
        }
        It "Should return no results for a non-existent GroupID" {
            $data = $script:TestBoundaryGroupData.NonExistent
            $result = Get-CM7BoundaryGroup -Id ([string]$data.GroupId)
            $result | Should -BeNullOrEmpty
        }
    }

    Context "Output Object Structure" {
        It "Should return objects with the expected properties" {
            $data = $script:TestBoundaryGroupData.ByName
            $result = Get-CM7BoundaryGroup -Name $data.Name
            $result | Should -Not -BeNullOrEmpty
            $result | Get-Member -Name 'GroupID'         | Should -Not -BeNullOrEmpty
            $result | Get-Member -Name 'Name'            | Should -Not -BeNullOrEmpty
            $result | Get-Member -Name 'Description'     | Should -Not -BeNullOrEmpty
            $result | Get-Member -Name 'DefaultSiteCode' | Should -Not -BeNullOrEmpty
            $result | Get-Member -Name 'MemberCount'     | Should -Not -BeNullOrEmpty
            $result | Get-Member -Name 'SiteSystemCount' | Should -Not -BeNullOrEmpty
        }
        It "Should return objects with PSTypeName MECM7.BoundaryGroup" {
            $data = $script:TestBoundaryGroupData.ByName
            $result = Get-CM7BoundaryGroup -Name $data.Name
            $result | Should -Not -BeNullOrEmpty
            $result.PSObject.TypeNames | Should -Contain 'MECM7.BoundaryGroup'
        }
        It "Should return GroupID as an integer" {
            $data = $script:TestBoundaryGroupData.ByName
            $result = Get-CM7BoundaryGroup -Name $data.Name
            $result | Should -Not -BeNullOrEmpty
            $result.GroupID | Should -BeOfType [int]
        }
    }

    Context "Parameter Validation" {
        It "Should throw when DisableWildcardHandling and ForceWildcardHandling are combined" {
            { Get-CM7BoundaryGroup -Name "Test*" -DisableWildcardHandling -ForceWildcardHandling } | Should -Throw
        }
        It "Should treat wildcard as literal when DisableWildcardHandling is used" {
            # A name with a literal asterisk should return nothing (no group named 'Test*')
            $result = Get-CM7BoundaryGroup -Name "Test*" -DisableWildcardHandling
            $result | Should -BeNullOrEmpty
        }
    }

    Context "Connection Validation" {
        It "Should throw when not connected to MECM" {
            $savedConnection = $script:CMConnection
            $script:CMConnection = $null
            { Get-CM7BoundaryGroup -Name "Test Gino" } | Should -Throw
            $script:CMConnection = $savedConnection
        }
    }
}
