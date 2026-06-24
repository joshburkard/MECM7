# Functional Tests for Set-CM7BoundaryGroup
# Tests the Set-CM7BoundaryGroup function behavior and return values
# Flow:
#   1. Create a boundary group "Test" via New-CM7BoundaryGroup
#   2. Exercise all parameter sets and options of Set-CM7BoundaryGroup
#   3. Remove the boundary group via Remove-CM7BoundaryGroup

BeforeAll {
    # Load test declarations
    . (Join-Path $PSScriptRoot "declarations.ps1")

    # Load all functions
    $CodePath = Join-Path (Get-Item $PSScriptRoot).Parent.FullName "Code"
    Get-ChildItem -Path (Join-Path $CodePath "Private") -Filter "*.ps1" | ForEach-Object { . $_.FullName }
    Get-ChildItem -Path (Join-Path $CodePath "Public") -Filter "*.ps1" | ForEach-Object { . $_.FullName }

    # Get test data for this function
    $script:TestSetBoundaryGroupData = $script:TestData['Set-CM7BoundaryGroup']
    $script:TestConnectData          = $script:TestData['Connect-CM7']

    # Runtime state shared between contexts
    $script:TestGroupObj = $null   # created SMS_BoundaryGroup instance

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
    # Safety net: remove any test groups left over if tests failed mid-way
    $namespace = "root/SMS/site_$($script:CMConnection.SiteCode)"
    $cimParams  = @{
        CimSession = $script:CMConnection.CimSession
        Namespace  = $namespace
    }

    # All names that may have been created or renamed during tests
    $namesToClean = @(
        $script:TestSetBoundaryGroupData.Create.Name,
        $script:TestSetBoundaryGroupData.Rename.NewName
    )

    foreach ($n in $namesToClean | Where-Object { $_ }) {
        $safeName = $n -replace "'", "''"
        $leftover = Get-CimInstance @cimParams -Query "SELECT * FROM SMS_BoundaryGroup WHERE Name = '$safeName'" -ErrorAction SilentlyContinue
        if ($leftover) {
            Write-Host "AfterAll safety-net: removing leftover boundary group '$n'" -ForegroundColor Yellow
            Remove-CimInstance -InputObject $leftover -ErrorAction SilentlyContinue
        }
    }
}

Describe "Set-CM7BoundaryGroup Function Tests" -Tag "Integration", "BoundaryGroup", "Set" {

    # -------------------------------------------------------------------------
    # 1. Declarations validation
    # -------------------------------------------------------------------------
    Context "Test Data Validation" {
        It "Should have test data defined in declarations.ps1" {
            $script:TestSetBoundaryGroupData | Should -Not -BeNullOrEmpty
            $script:TestData.ContainsKey('Set-CM7BoundaryGroup') | Should -Be $true
        }
        It "Should have required test data parameter sets" {
            $script:TestSetBoundaryGroupData.ContainsKey('Create')      | Should -Be $true
            $script:TestSetBoundaryGroupData.ContainsKey('Rename')      | Should -Be $true
            $script:TestSetBoundaryGroupData.ContainsKey('Description') | Should -Be $true
            $script:TestSetBoundaryGroupData.ContainsKey('SiteCode')    | Should -Be $true
            $script:TestSetBoundaryGroupData.ContainsKey('Options')     | Should -Be $true
            $script:TestSetBoundaryGroupData.ContainsKey('NonExistent') | Should -Be $true
        }
    }

    # -------------------------------------------------------------------------
    # 2. Setup: create a boundary group to work with
    # -------------------------------------------------------------------------
    Context "Setup: Create Boundary Group for Set Tests" {
        It "Should create a test boundary group named '$($script:TestSetBoundaryGroupData.Create.Name)'" {
            $params = $script:TestSetBoundaryGroupData.Create
            $script:TestGroupObj = New-CM7BoundaryGroup -Name $params.Name -Force
            $script:TestGroupObj         | Should -Not -BeNullOrEmpty
            $script:TestGroupObj.Name    | Should -Be $params.Name
            $script:TestGroupObj.GroupID | Should -BeGreaterThan 0
        }
    }

    # -------------------------------------------------------------------------
    # 3. Set by Name
    # -------------------------------------------------------------------------
    Context "Set by Name - Update Description" {
        It "Should update the description when using -Name parameter set" {
            $params     = $script:TestSetBoundaryGroupData.Description
            $groupName  = $script:TestSetBoundaryGroupData.Create.Name

            Set-CM7BoundaryGroup -Name $groupName -Description $params.Value

            $result = Get-CM7BoundaryGroup -Name $groupName
            $result             | Should -Not -BeNullOrEmpty
            $result.Description | Should -Be $params.Value
        }
    }

    # -------------------------------------------------------------------------
    # 4. Set by Id
    # -------------------------------------------------------------------------
    Context "Set by Id - Update DefaultSiteCode" {
        It "Should update the DefaultSiteCode when using -Id parameter set" {
            $params  = $script:TestSetBoundaryGroupData.SiteCode
            $groupId = [string]$script:TestGroupObj.GroupID

            Set-CM7BoundaryGroup -Id $groupId -DefaultSiteCode $params.Value

            $result = Get-CM7BoundaryGroup -Id $groupId
            $result                 | Should -Not -BeNullOrEmpty
            $result.DefaultSiteCode | Should -Be $params.Value
        }

        It "Should clear DefaultSiteCode when set to empty string" {
            $groupId = [string]$script:TestGroupObj.GroupID
            Set-CM7BoundaryGroup -Id $groupId -DefaultSiteCode ""

            $result = Get-CM7BoundaryGroup -Id $groupId
            $result | Should -Not -BeNullOrEmpty
            # DefaultSiteCode should be null or empty after clearing
            [string]::IsNullOrEmpty($result.DefaultSiteCode) | Should -Be $true
        }
    }

    # -------------------------------------------------------------------------
    # 5. Set via InputObject (pipeline)
    # -------------------------------------------------------------------------
    Context "Set by InputObject (pipeline)" {
        It "Should update description when piped via InputObject" {
            $groupName  = $script:TestSetBoundaryGroupData.Create.Name
            $newDesc    = "Pipeline-updated description"

            Get-CM7BoundaryGroup -Name $groupName | Set-CM7BoundaryGroup -Description $newDesc

            $result = Get-CM7BoundaryGroup -Name $groupName
            $result             | Should -Not -BeNullOrEmpty
            $result.Description | Should -Be $newDesc
        }
    }

    # -------------------------------------------------------------------------
    # 6. Options: peer download flags
    # -------------------------------------------------------------------------
    Context "Options - Peer Download Flags" {
        It "Should enable AllowPeerDownload" {
            $groupName = $script:TestSetBoundaryGroupData.Create.Name
            $groupId   = [string]$script:TestGroupObj.GroupID

            Set-CM7BoundaryGroup -Name $groupName -AllowPeerDownload $true

            $result = Get-CM7BoundaryGroup -Id $groupId
            $result | Should -Not -BeNullOrEmpty
            # Bit 0x0002 = AllowPeerDownload
            ($result.AllowPeerDownload) | Should -Be $true
        }

        It "Should enable SubnetPeerDownloadOnly" {
            $groupName = $script:TestSetBoundaryGroupData.Create.Name
            $groupId   = [string]$script:TestGroupObj.GroupID

            Set-CM7BoundaryGroup -Name $groupName -SubnetPeerDownloadOnly $true

            $result = Get-CM7BoundaryGroup -Id $groupId
            $result | Should -Not -BeNullOrEmpty
            # Bit 0x0004 = SubnetPeerDownloadOnly
            ($result.SubnetPeerDownloadOnly) | Should -Be $true
        }

        It "Should enable PreferDPOverPeer" {
            $groupName = $script:TestSetBoundaryGroupData.Create.Name
            $groupId   = [string]$script:TestGroupObj.GroupID

            Set-CM7BoundaryGroup -Name $groupName -PreferDPOverPeer $true

            $result = Get-CM7BoundaryGroup -Id $groupId
            $result | Should -Not -BeNullOrEmpty
            # Bit 0x0008 = PreferDPOverPeer
            ($result.PreferDPOverPeer) | Should -Be $true
        }

        It "Should enable PreferCloudDPOverDP" {
            $groupName = $script:TestSetBoundaryGroupData.Create.Name
            $groupId   = [string]$script:TestGroupObj.GroupID

            Set-CM7BoundaryGroup -Name $groupName -PreferCloudDPOverDP $true

            $result = Get-CM7BoundaryGroup -Id $groupId
            $result | Should -Not -BeNullOrEmpty
            # Bit 0x0010 = PreferCloudDPOverDP
            ($result.PreferCloudDPOverDP) | Should -Be $true
        }

        It "Should disable AllowPeerDownload and clear all related flags at once" {
            $groupName = $script:TestSetBoundaryGroupData.Create.Name
            $groupId   = [string]$script:TestGroupObj.GroupID

            Set-CM7BoundaryGroup -Name $groupName `
                -AllowPeerDownload $false `
                -SubnetPeerDownloadOnly $false `
                -PreferDPOverPeer $false `
                -PreferCloudDPOverDP $false

            $result = Get-CM7BoundaryGroup -Id $groupId
            $result | Should -Not -BeNullOrEmpty
            ($result.Flags -band 0x001E) | Should -Be 0
        }
    }

    # -------------------------------------------------------------------------
    # 7. Site system server management
    # -------------------------------------------------------------------------
    Context "Site System Server Management" {
        It "Should discover site system servers from SMS_SystemResourceList" {
            $namespace = "root/SMS/site_$($script:CMConnection.SiteCode)"
            $cimParams  = @{
                CimSession = $script:CMConnection.CimSession
                Namespace  = $namespace
            }
            $siteRoles = @('SMS Distribution Point', 'SMS Management Point')
            $servers = foreach ($role in $siteRoles) {
                Get-CimInstance @cimParams -Query "SELECT ServerName FROM SMS_SystemResourceList WHERE RoleName = '$role'" -ErrorAction SilentlyContinue
            }
            $script:SiteSystemServerNames = @($servers | Select-Object -ExpandProperty ServerName -Unique | Where-Object { $_ })
            Write-Host "Discovered $($script:SiteSystemServerNames.Count) site system server(s)." -ForegroundColor Cyan
            # Not failing if none found — boundary group can exist without site systems
            $true | Should -Be $true
        }

        It "Should add site system server(s) via -AddSiteSystemServerName" {
            if ($script:SiteSystemServerNames.Count -eq 0) {
                Set-ItResult -Skipped -Because "No site system servers were discovered in this environment"
                return
            }

            $groupName = $script:TestSetBoundaryGroupData.Create.Name
            $groupId   = [string]$script:TestGroupObj.GroupID

            Set-CM7BoundaryGroup -Name $groupName -AddSiteSystemServerName $script:SiteSystemServerNames[0]

            $namespace = "root/SMS/site_$($script:CMConnection.SiteCode)"
            $cimParams  = @{
                CimSession = $script:CMConnection.CimSession
                Namespace  = $namespace
            }
            $associations = Get-CimInstance @cimParams -Query "SELECT * FROM SMS_BoundaryGroupSiteSystems WHERE GroupID = $groupId" -ErrorAction SilentlyContinue
            $associations | Should -Not -BeNullOrEmpty
        }

        It "Should clear all site system servers via -ClearSiteSystemServer" {
            if ($script:SiteSystemServerNames.Count -eq 0) {
                Set-ItResult -Skipped -Because "No site system servers were discovered in this environment"
                return
            }

            $groupName = $script:TestSetBoundaryGroupData.Create.Name
            $groupId   = [string]$script:TestGroupObj.GroupID

            Set-CM7BoundaryGroup -Name $groupName -ClearSiteSystemServer

            $namespace = "root/SMS/site_$($script:CMConnection.SiteCode)"
            $cimParams  = @{
                CimSession = $script:CMConnection.CimSession
                Namespace  = $namespace
            }
            $associations = Get-CimInstance @cimParams -Query "SELECT * FROM SMS_BoundaryGroupSiteSystems WHERE GroupID = $groupId" -ErrorAction SilentlyContinue
            @($associations).Count | Should -Be 0
        }
    }

    # -------------------------------------------------------------------------
    # 8. PassThru
    # -------------------------------------------------------------------------
    Context "PassThru" {
        It "Should return the updated boundary group object when -PassThru is used" {
            $groupName  = $script:TestSetBoundaryGroupData.Create.Name
            $newDesc    = "PassThru test description"

            $result = Set-CM7BoundaryGroup -Name $groupName -Description $newDesc -PassThru
            $result             | Should -Not -BeNullOrEmpty
            $result.GroupID     | Should -Be $script:TestGroupObj.GroupID
            $result.Description | Should -Be $newDesc
        }

        It "Should not produce output when -PassThru is not specified" {
            $groupName = $script:TestSetBoundaryGroupData.Create.Name
            $output    = Set-CM7BoundaryGroup -Name $groupName -Description "No passthru"
            $output    | Should -BeNullOrEmpty
        }
    }

    # -------------------------------------------------------------------------
    # 9. WhatIf support
    # -------------------------------------------------------------------------
    Context "WhatIf Support" {
        It "Should not modify the boundary group when -WhatIf is specified" {
            $groupName       = $script:TestSetBoundaryGroupData.Create.Name
            $before          = Get-CM7BoundaryGroup -Name $groupName
            $distinctDesc    = "WhatIf-should-not-be-applied-$([Guid]::NewGuid().ToString('N'))"

            Set-CM7BoundaryGroup -Name $groupName -Description $distinctDesc -WhatIf

            $after = Get-CM7BoundaryGroup -Name $groupName
            $after.Description | Should -Not -Be $distinctDesc
            $after.Description | Should -Be $before.Description
        }
    }

    # -------------------------------------------------------------------------
    # 10. Rename (NewName) - done last before cleanup to keep the name stable
    # -------------------------------------------------------------------------
    Context "Rename Boundary Group (NewName)" {
        It "Should rename the boundary group" {
            $createName  = $script:TestSetBoundaryGroupData.Create.Name
            $renameData  = $script:TestSetBoundaryGroupData.Rename
            $groupId     = [string]$script:TestGroupObj.GroupID

            Set-CM7BoundaryGroup -Name $createName -NewName $renameData.NewName

            $result = Get-CM7BoundaryGroup -Id $groupId
            $result      | Should -Not -BeNullOrEmpty
            $result.Name | Should -Be $renameData.NewName
        }

        It "Should not be findable under the old name after rename" {
            $createName = $script:TestSetBoundaryGroupData.Create.Name
            $result     = Get-CM7BoundaryGroup -Name $createName
            $result     | Should -BeNullOrEmpty
        }
    }

    # -------------------------------------------------------------------------
    # 11. Error handling
    # -------------------------------------------------------------------------
    Context "Error Handling" {
        It "Should throw when the boundary group does not exist (ByName)" {
            $params = $script:TestSetBoundaryGroupData.NonExistent
            { Set-CM7BoundaryGroup -Name $params.Name -Description "Should fail" } | Should -Throw
        }

        It "Should throw when the boundary group does not exist (ById)" {
            $params = $script:TestSetBoundaryGroupData.NonExistent
            { Set-CM7BoundaryGroup -Id $params.GroupId -Description "Should fail" } | Should -Throw
        }
    }

    # -------------------------------------------------------------------------
    # 12. Cleanup: remove the test boundary group
    # -------------------------------------------------------------------------
    Context "Cleanup: Remove Test Boundary Group" {
        It "Should remove the renamed boundary group" {
            $renameData = $script:TestSetBoundaryGroupData.Rename
            $groupId    = [string]$script:TestGroupObj.GroupID

            Remove-CM7BoundaryGroup -Id $groupId -Force

            $result = Get-CM7BoundaryGroup -Id $groupId
            $result | Should -BeNullOrEmpty
        }
    }
}
