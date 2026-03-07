# Functional Tests for New-CM7BoundaryGroup
# Tests the New-CM7BoundaryGroup function behavior and return values

BeforeAll {
    # Load test declarations
    . (Join-Path $PSScriptRoot "declarations.ps1")

    # Load all functions
    $CodePath = Join-Path (Get-Item $PSScriptRoot).Parent.FullName "Code"
    Get-ChildItem -Path (Join-Path $CodePath "Private") -Filter "*.ps1" | ForEach-Object { . $_.FullName }
    Get-ChildItem -Path (Join-Path $CodePath "Public") -Filter "*.ps1" | ForEach-Object { . $_.FullName }

    # Get test data for this function
    $script:TestNewBoundaryGroupData = $script:TestData['New-CM7BoundaryGroup']
    $script:TestConnectData = $script:TestData['Connect-CM7']

    # Runtime state shared between contexts
    $script:TestGroupObj          = $null   # created 'Test' SMS_BoundaryGroup instance
    $script:SiteSystemServerNames = @()     # discovered site system server FQDNs

    # Establish connection for all tests
    $connectParams = @{
        SiteServer = $script:TestConnectData.Valid.SiteServer
        Credential = $script:TestConnectData.Valid.Credential
    }
    if ($script:TestConnectData.Valid.SkipCertificateCheck) { $connectParams.SkipCertificateCheck = $true }
    if ($script:TestConnectData.Valid.UseSsl)               { $connectParams.UseSsl = $true }
    Connect-CM7 @connectParams
}

AfterAll {
    # Safety net: remove any groups that were not cleaned up by the Cleanup contexts
    $namespace = "root/SMS/site_$($script:CMConnection.SiteCode)"
    $cimParams  = @{
        CimSession = $script:CMConnection.CimSession
        Namespace  = $namespace
    }

    foreach ($key in @('Simple', 'WithDescription', 'WithDefaultSiteCode')) {
        $gName = $script:TestNewBoundaryGroupData[$key].Name
        $leftover = Get-CimInstance @cimParams -Query "SELECT * FROM SMS_BoundaryGroup WHERE Name = '$gName'" -ErrorAction SilentlyContinue
        if ($leftover) {
            Write-Host "AfterAll safety-net: removing leftover boundary group '$gName'" -ForegroundColor Yellow
            Remove-CimInstance -InputObject $leftover -ErrorAction SilentlyContinue
        }
    }
}

Describe "New-CM7BoundaryGroup Function Tests" -Tag "Integration", "BoundaryGroup", "New" {

    # -------------------------------------------------------------------------
    # 1. Declarations validation
    # -------------------------------------------------------------------------
    Context "Test Data Validation" {
        It "Should have test data defined in declarations.ps1" {
            $script:TestNewBoundaryGroupData | Should -Not -BeNullOrEmpty
            $script:TestData.ContainsKey('New-CM7BoundaryGroup') | Should -Be $true
        }
        It "Should have required test data parameter sets" {
            $script:TestNewBoundaryGroupData.ContainsKey('Simple')             | Should -Be $true
            $script:TestNewBoundaryGroupData.ContainsKey('WithDescription')    | Should -Be $true
            $script:TestNewBoundaryGroupData.ContainsKey('WithDefaultSiteCode')| Should -Be $true
        }
    }

    # -------------------------------------------------------------------------
    # 2. Discover site system server names
    # -------------------------------------------------------------------------
    Context "Discover Site System Server Names" {
        It "Should retrieve available site system server names from SMS_SystemResourceList" {
            $namespace = "root/SMS/site_$($script:CMConnection.SiteCode)"
            $cimParams  = @{
                CimSession = $script:CMConnection.CimSession
                Namespace  = $namespace
            }

            # Query Distribution Points and Management Points — typical candidates for boundary group assignment
            $siteRoles = @('SMS Distribution Point', 'SMS Management Point')
            $servers = foreach ($role in $siteRoles) {
                Get-CimInstance @cimParams -Query "SELECT ServerName, RoleName FROM SMS_SystemResourceList WHERE RoleName = '$role'" -ErrorAction SilentlyContinue
            }

            # Deduplicate by ServerName
            $script:SiteSystemServerNames = $servers |
                Where-Object { $_.ServerName } |
                Select-Object -ExpandProperty ServerName -Unique

            Write-Host "Discovered $($script:SiteSystemServerNames.Count) site system server(s):" -ForegroundColor Cyan
            $script:SiteSystemServerNames | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }

            if ($script:SiteSystemServerNames.Count -eq 0) {
                Set-ItResult -Skipped -Because "No SMS Distribution Point / Management Point found in SMS_SystemResourceList"
            } else {
                $script:SiteSystemServerNames.Count | Should -BeGreaterThan 0
            }
        }
    }

    # -------------------------------------------------------------------------
    # 3. Create boundary group 'Test' with DefaultSiteCode and AddSiteSystemServerName
    # -------------------------------------------------------------------------
    Context "Create Boundary Group 'Test' with DefaultSiteCode and AddSiteSystemServerName" {
        It "Should create the boundary group using New-CM7BoundaryGroup with site system server(s)" {
            $params     = $script:TestNewBoundaryGroupData.Simple
            $siteCode   = $script:CMConnection.SiteCode

            $createParams = @{
                Name            = $params.Name
                DefaultSiteCode = $siteCode
                Force           = $true
            }
            if ($script:SiteSystemServerNames.Count -gt 0) {
                $createParams.AddSiteSystemServerName = $script:SiteSystemServerNames
            }

            $script:TestGroupObj = New-CM7BoundaryGroup @createParams
            $script:TestGroupObj            | Should -Not -BeNullOrEmpty
            $script:TestGroupObj.Name       | Should -Be $params.Name
            $script:TestGroupObj.GroupID    | Should -BeGreaterThan 0
            $script:TestGroupObj.DefaultSiteCode | Should -Be $siteCode
        }

        It "Should return an object with expected properties" {
            $result = Get-CM7BoundaryGroup -Name $script:TestNewBoundaryGroupData.Simple.Name
            $result | Should -Not -BeNullOrEmpty
            $result.PSObject.Properties.Name | Should -Contain 'GroupID'
            $result.PSObject.Properties.Name | Should -Contain 'Name'
        }

        It "Should have site system server(s) associated with the boundary group" {
            if ($script:SiteSystemServerNames.Count -eq 0) {
                Set-ItResult -Skipped -Because "No site system servers were discovered"
                return
            }

            $namespace = "root/SMS/site_$($script:CMConnection.SiteCode)"
            $cimParams  = @{
                CimSession = $script:CMConnection.CimSession
                Namespace  = $namespace
            }
            $groupId = $script:TestGroupObj.GroupID

            $associations = Get-CimInstance @cimParams -Query "SELECT * FROM SMS_BoundaryGroupSiteSystems WHERE GroupID = $groupId" -ErrorAction SilentlyContinue
            $associations | Should -Not -BeNullOrEmpty
            $associations.Count | Should -BeGreaterOrEqual $script:SiteSystemServerNames.Count
        }
    }

    # -------------------------------------------------------------------------
    # 4. Additional creation tests
    # -------------------------------------------------------------------------
    Context "Create Boundary Group With Description" {
        It "Should create a boundary group with description" {
            $params = $script:TestNewBoundaryGroupData.WithDescription
            $result = New-CM7BoundaryGroup -Name $params.Name -Description $params.Description -Force
            $result | Should -Not -BeNullOrEmpty
            $result.Name        | Should -Be $params.Name
            $result.Description | Should -Be $params.Description
        }
    }

    Context "Create Boundary Group With Default Site Code" {
        It "Should create a boundary group with a default site code" {
            $params = $script:TestNewBoundaryGroupData.WithDefaultSiteCode
            $result = New-CM7BoundaryGroup -Name $params.Name -DefaultSiteCode $params.DefaultSiteCode -Force
            $result | Should -Not -BeNullOrEmpty
            $result.Name            | Should -Be $params.Name
            $result.DefaultSiteCode | Should -Be $params.DefaultSiteCode
        }
    }

    Context "Duplicate Name Handling" {
        It "Should throw if boundary group name already exists" {
            $params = $script:TestNewBoundaryGroupData.Simple
            { New-CM7BoundaryGroup -Name $params.Name -Force } | Should -Throw
        }
    }

    Context "WhatIf Support" {
        It "Should not create a boundary group when -WhatIf is specified" {
            $whatIfName = "WhatIfTestGroup-$(Get-Date -Format 'yyyyMMddHHmmss')"
            New-CM7BoundaryGroup -Name $whatIfName -WhatIf
            $result = Get-CM7BoundaryGroup -Name $whatIfName -ErrorAction SilentlyContinue
            $result | Should -BeNullOrEmpty
        }
    }

    # -------------------------------------------------------------------------
    # 5. Cleanup — remove all created boundary groups
    # -------------------------------------------------------------------------
    Context "Cleanup: Remove Boundary Groups" {
        It "Should remove the 'Test' boundary group" {
            $namespace = "root/SMS/site_$($script:CMConnection.SiteCode)"
            $cimParams  = @{
                CimSession = $script:CMConnection.CimSession
                Namespace  = $namespace
            }
            $groupId  = $script:TestGroupObj.GroupID
            $instance = Get-CimInstance @cimParams -Query "SELECT * FROM SMS_BoundaryGroup WHERE GroupID = $groupId" -ErrorAction SilentlyContinue
            if ($instance) { Remove-CimInstance -InputObject $instance }

            $check = Get-CimInstance @cimParams -Query "SELECT GroupID FROM SMS_BoundaryGroup WHERE GroupID = $groupId" -ErrorAction SilentlyContinue
            $check | Should -BeNullOrEmpty
        }

        It "Should remove the 'WithDescription' boundary group" {
            $namespace = "root/SMS/site_$($script:CMConnection.SiteCode)"
            $cimParams  = @{
                CimSession = $script:CMConnection.CimSession
                Namespace  = $namespace
            }
            $gName    = $script:TestNewBoundaryGroupData.WithDescription.Name
            $instance = Get-CimInstance @cimParams -Query "SELECT * FROM SMS_BoundaryGroup WHERE Name = '$gName'" -ErrorAction SilentlyContinue
            if ($instance) { Remove-CimInstance -InputObject $instance }

            $check = Get-CimInstance @cimParams -Query "SELECT GroupID FROM SMS_BoundaryGroup WHERE Name = '$gName'" -ErrorAction SilentlyContinue
            $check | Should -BeNullOrEmpty
        }

        It "Should remove the 'WithDefaultSiteCode' boundary group" {
            $namespace = "root/SMS/site_$($script:CMConnection.SiteCode)"
            $cimParams  = @{
                CimSession = $script:CMConnection.CimSession
                Namespace  = $namespace
            }
            $gName    = $script:TestNewBoundaryGroupData.WithDefaultSiteCode.Name
            $instance = Get-CimInstance @cimParams -Query "SELECT * FROM SMS_BoundaryGroup WHERE Name = '$gName'" -ErrorAction SilentlyContinue
            if ($instance) { Remove-CimInstance -InputObject $instance }

            $check = Get-CimInstance @cimParams -Query "SELECT GroupID FROM SMS_BoundaryGroup WHERE Name = '$gName'" -ErrorAction SilentlyContinue
            $check | Should -BeNullOrEmpty
        }
    }
}
