# Functional Tests for Remove-CM7BoundaryFromGroup
# Tests the Remove-CM7BoundaryFromGroup function behavior

BeforeAll {
    # Load test declarations
    . (Join-Path $PSScriptRoot "declarations.ps1")

    # Load all functions
    $CodePath = Join-Path (Get-Item $PSScriptRoot).Parent.FullName "Code"
    Get-ChildItem -Path (Join-Path $CodePath "Private") -Filter "*.ps1" | ForEach-Object { . $_.FullName }
    Get-ChildItem -Path (Join-Path $CodePath "Public")  -Filter "*.ps1" | ForEach-Object { . $_.FullName }

    # Get test data for this function
    $script:TestData_Remove   = $script:TestData['Remove-CM7BoundaryFromGroup']
    $script:TestConnectData   = $script:TestData['Connect-CM7']

    # Runtime state shared between contexts
    $script:CreatedBoundary      = $null   # SMS_Boundary created for tests
    $script:CreatedBoundaryGroup = $null   # SMS_BoundaryGroup created for tests

    # Establish connection for all tests
    $connectParams = @{
        SiteServer = $script:TestConnectData.Valid.SiteServer
        Credential = $script:TestConnectData.Valid.Credential
    }
    if ($script:TestConnectData.Valid.SkipCertificateCheck) { $connectParams.SkipCertificateCheck = $true }
    if ($script:TestConnectData.Valid.UseSsl)               { $connectParams.UseSsl               = $true }
    Connect-CM7 @connectParams
}

AfterAll {
    # Safety net: remove any leftover test objects
    $namespace = "root/SMS/site_$($script:CMConnection.SiteCode)"
    $cimParams  = @{
        CimSession = $script:CMConnection.CimSession
        Namespace  = $namespace
    }

    # Remove test boundary group
    $bgName = $script:TestData_Remove.NewBoundaryGroup.Name
    $leftoverGroup = Get-CimInstance @cimParams -Query "SELECT * FROM SMS_BoundaryGroup WHERE Name = '$bgName'" -ErrorAction SilentlyContinue
    if ($leftoverGroup) {
        Write-Host "AfterAll safety-net: removing leftover boundary group '$bgName'" -ForegroundColor Yellow
        Remove-CimInstance -InputObject $leftoverGroup -ErrorAction SilentlyContinue
    }

    # Remove test boundary
    $bName = $script:TestData_Remove.NewBoundary.Name
    $leftoverBoundary = Get-CimInstance @cimParams -Query "SELECT * FROM SMS_Boundary WHERE DisplayName = '$bName'" -ErrorAction SilentlyContinue
    if ($leftoverBoundary) {
        Write-Host "AfterAll safety-net: removing leftover boundary '$bName'" -ForegroundColor Yellow
        Remove-CimInstance -InputObject $leftoverBoundary -ErrorAction SilentlyContinue
    }
}

Describe "Remove-CM7BoundaryFromGroup Function Tests" -Tag "Integration", "Boundary", "BoundaryGroup", "Remove" {

    # -------------------------------------------------------------------------
    # 1. Declarations validation
    # -------------------------------------------------------------------------
    Context "Test Data Validation" {

        It "Should have test data defined in declarations.ps1" {
            $script:TestData_Remove | Should -Not -BeNullOrEmpty
            $script:TestData.ContainsKey('Remove-CM7BoundaryFromGroup') | Should -Be $true
        }

        It "Should have required test data sections" {
            $script:TestData_Remove.ContainsKey('NewBoundary')        | Should -Be $true
            $script:TestData_Remove.ContainsKey('NewBoundaryGroup')   | Should -Be $true
            $script:TestData_Remove.ContainsKey('NonExistentBoundary')| Should -Be $true
            $script:TestData_Remove.ContainsKey('NonExistentGroup')   | Should -Be $true
        }

        It "Should output test data for verification" {
            Write-Host "`n=== Test Data for Remove-CM7BoundaryFromGroup ===" -ForegroundColor Cyan
            Write-Host "NewBoundary.Name:           $($script:TestData_Remove.NewBoundary.Name)" -ForegroundColor White
            Write-Host "NewBoundary.Value:          $($script:TestData_Remove.NewBoundary.Value)" -ForegroundColor White
            Write-Host "NewBoundaryGroup.Name:      $($script:TestData_Remove.NewBoundaryGroup.Name)" -ForegroundColor White
            Write-Host "NonExistentBoundary.Id:     $($script:TestData_Remove.NonExistentBoundary.BoundaryId)" -ForegroundColor White
            Write-Host "NonExistentGroup.Id:        $($script:TestData_Remove.NonExistentGroup.BoundaryGroupId)" -ForegroundColor White
            Write-Host "================================================`n" -ForegroundColor Cyan
            $true | Should -Be $true
        }
    }

    # -------------------------------------------------------------------------
    # 2. Connection requirement
    # -------------------------------------------------------------------------
    Context "Connection Requirement" {

        It "Should throw if not connected to MECM" {
            $backupCim = $script:CMConnection.CimSession
            $script:CMConnection.CimSession = $null

            { Remove-CM7BoundaryFromGroup -BoundaryGroupName "Test" -BoundaryId 1 -Force } | Should -Throw "*not connected*"

            $script:CMConnection.CimSession = $backupCim
        }
    }

    # -------------------------------------------------------------------------
    # 3. Setup: create a boundary and a boundary group, then add boundary to group
    # -------------------------------------------------------------------------
    Context "Setup: Create Test Boundary and Boundary Group" {

        It "Should create the test boundary via New-CM7Boundary" {
            $p = $script:TestData_Remove.NewBoundary

            # Ensure clean state
            $existing = Get-CM7Boundary -Name $p.Name -ErrorAction SilentlyContinue
            if ($existing) { Remove-CM7Boundary -Name $p.Name -Force -ErrorAction SilentlyContinue }

            $script:CreatedBoundary = New-CM7Boundary -Name $p.Name -BoundaryType $p.BoundaryType -Value $p.Value -Force
            $script:CreatedBoundary            | Should -Not -BeNullOrEmpty
            $script:CreatedBoundary.BoundaryID | Should -BeGreaterThan 0
        }

        It "Should create the test boundary group via New-CM7BoundaryGroup" {
            $p = $script:TestData_Remove.NewBoundaryGroup

            # Ensure clean state
            $existing = Get-CM7BoundaryGroup -Name $p.Name -ErrorAction SilentlyContinue
            if ($existing) { Remove-CM7BoundaryGroup -Name $p.Name -Force -ErrorAction SilentlyContinue }

            $script:CreatedBoundaryGroup = New-CM7BoundaryGroup -Name $p.Name -Force
            $script:CreatedBoundaryGroup         | Should -Not -BeNullOrEmpty
            $script:CreatedBoundaryGroup.GroupID | Should -BeGreaterThan 0
        }
    }

    # -------------------------------------------------------------------------
    # 4. Helper function (used to check membership state in tests)
    # -------------------------------------------------------------------------
    BeforeAll {
        function Test-BoundaryInGroup {
            $namespace = "root/SMS/site_$($script:CMConnection.SiteCode)"
            $cimParams  = @{
                CimSession = $script:CMConnection.CimSession
                Namespace  = $namespace
            }
            $boundaryId = $script:CreatedBoundary.BoundaryID
            $groupId    = $script:CreatedBoundaryGroup.GroupID
            $member = Get-CimInstance @cimParams -Query "SELECT BoundaryID FROM SMS_BoundaryGroupMembers WHERE GroupID = $groupId AND BoundaryID = $boundaryId" -ErrorAction SilentlyContinue
            return ($null -ne $member)
        }
    }

    # -------------------------------------------------------------------------
    # 5. Remove by BoundaryGroupId and BoundaryId
    # -------------------------------------------------------------------------
    Context "Remove by BoundaryGroupId and BoundaryId" {

        BeforeEach {
            Add-CM7BoundaryToGroup -BoundaryGroupId $script:CreatedBoundaryGroup.GroupID -BoundaryId $script:CreatedBoundary.BoundaryID -ErrorAction SilentlyContinue
        }

        It "Should remove the boundary using -BoundaryGroupId and -BoundaryId" {
            $bgId = $script:CreatedBoundaryGroup.GroupID
            $bId  = $script:CreatedBoundary.BoundaryID

            { Remove-CM7BoundaryFromGroup -BoundaryGroupId $bgId -BoundaryId $bId -Force } | Should -Not -Throw

            Test-BoundaryInGroup | Should -Be $false
        }
    }

    # -------------------------------------------------------------------------
    # 6. Remove by BoundaryGroupName and BoundaryName
    # -------------------------------------------------------------------------
    Context "Remove by BoundaryGroupName and BoundaryName" {

        BeforeEach {
            Add-CM7BoundaryToGroup -BoundaryGroupId $script:CreatedBoundaryGroup.GroupID -BoundaryId $script:CreatedBoundary.BoundaryID -ErrorAction SilentlyContinue
        }

        It "Should remove the boundary using -BoundaryGroupName and -BoundaryName" {
            $bgName = $script:CreatedBoundaryGroup.Name
            $bName  = $script:CreatedBoundary.DisplayName

            { Remove-CM7BoundaryFromGroup -BoundaryGroupName $bgName -BoundaryName $bName -Force } | Should -Not -Throw

            Test-BoundaryInGroup | Should -Be $false
        }
    }

    # -------------------------------------------------------------------------
    # 7. Remove by BoundaryGroupInputObject and BoundaryInputObject
    # -------------------------------------------------------------------------
    Context "Remove by BoundaryGroupInputObject and BoundaryInputObject" {

        BeforeEach {
            Add-CM7BoundaryToGroup -BoundaryGroupId $script:CreatedBoundaryGroup.GroupID -BoundaryId $script:CreatedBoundary.BoundaryID -ErrorAction SilentlyContinue
        }

        It "Should remove the boundary using -BoundaryGroupInputObject and -BoundaryInputObject" {
            $groupObj    = Get-CM7BoundaryGroup -Name $script:CreatedBoundaryGroup.Name
            $boundaryObj = Get-CM7Boundary -BoundaryId $script:CreatedBoundary.BoundaryID

            { Remove-CM7BoundaryFromGroup -BoundaryGroupInputObject $groupObj -BoundaryInputObject $boundaryObj -Force } | Should -Not -Throw

            Test-BoundaryInGroup | Should -Be $false
        }
    }

    # -------------------------------------------------------------------------
    # 8. Remove by BoundaryGroupName and BoundaryId (mixed)
    # -------------------------------------------------------------------------
    Context "Remove by BoundaryGroupName and BoundaryId" {

        BeforeEach {
            Add-CM7BoundaryToGroup -BoundaryGroupId $script:CreatedBoundaryGroup.GroupID -BoundaryId $script:CreatedBoundary.BoundaryID -ErrorAction SilentlyContinue
        }

        It "Should remove the boundary using -BoundaryGroupName and -BoundaryId" {
            $bgName = $script:CreatedBoundaryGroup.Name
            $bId    = $script:CreatedBoundary.BoundaryID

            { Remove-CM7BoundaryFromGroup -BoundaryGroupName $bgName -BoundaryId $bId -Force } | Should -Not -Throw

            Test-BoundaryInGroup | Should -Be $false
        }
    }

    # -------------------------------------------------------------------------
    # 9. Remove by BoundaryGroupId and BoundaryName (mixed)
    # -------------------------------------------------------------------------
    Context "Remove by BoundaryGroupId and BoundaryName" {

        BeforeEach {
            Add-CM7BoundaryToGroup -BoundaryGroupId $script:CreatedBoundaryGroup.GroupID -BoundaryId $script:CreatedBoundary.BoundaryID -ErrorAction SilentlyContinue
        }

        It "Should remove the boundary using -BoundaryGroupId and -BoundaryName" {
            $bgId  = $script:CreatedBoundaryGroup.GroupID
            $bName = $script:CreatedBoundary.DisplayName

            { Remove-CM7BoundaryFromGroup -BoundaryGroupId $bgId -BoundaryName $bName -Force } | Should -Not -Throw

            Test-BoundaryInGroup | Should -Be $false
        }
    }

    # -------------------------------------------------------------------------
    # 10. Remove by BoundaryGroupInputObject and BoundaryId (mixed)
    # -------------------------------------------------------------------------
    Context "Remove by BoundaryGroupInputObject and BoundaryId" {

        BeforeEach {
            Add-CM7BoundaryToGroup -BoundaryGroupId $script:CreatedBoundaryGroup.GroupID -BoundaryId $script:CreatedBoundary.BoundaryID -ErrorAction SilentlyContinue
        }

        It "Should remove the boundary using -BoundaryGroupInputObject and -BoundaryId" {
            $groupObj = Get-CM7BoundaryGroup -Name $script:CreatedBoundaryGroup.Name
            $bId      = $script:CreatedBoundary.BoundaryID

            { Remove-CM7BoundaryFromGroup -BoundaryGroupInputObject $groupObj -BoundaryId $bId -Force } | Should -Not -Throw

            Test-BoundaryInGroup | Should -Be $false
        }
    }

    # -------------------------------------------------------------------------
    # 11. Remove by BoundaryGroupInputObject and BoundaryName (mixed)
    # -------------------------------------------------------------------------
    Context "Remove by BoundaryGroupInputObject and BoundaryName" {

        BeforeEach {
            Add-CM7BoundaryToGroup -BoundaryGroupId $script:CreatedBoundaryGroup.GroupID -BoundaryId $script:CreatedBoundary.BoundaryID -ErrorAction SilentlyContinue
        }

        It "Should remove the boundary using -BoundaryGroupInputObject and -BoundaryName" {
            $groupObj = Get-CM7BoundaryGroup -Name $script:CreatedBoundaryGroup.Name
            $bName    = $script:CreatedBoundary.DisplayName

            { Remove-CM7BoundaryFromGroup -BoundaryGroupInputObject $groupObj -BoundaryName $bName -Force } | Should -Not -Throw

            Test-BoundaryInGroup | Should -Be $false
        }
    }

    # -------------------------------------------------------------------------
    # 12. Remove by BoundaryGroupId and BoundaryInputObject (mixed)
    # -------------------------------------------------------------------------
    Context "Remove by BoundaryGroupId and BoundaryInputObject" {

        BeforeEach {
            Add-CM7BoundaryToGroup -BoundaryGroupId $script:CreatedBoundaryGroup.GroupID -BoundaryId $script:CreatedBoundary.BoundaryID -ErrorAction SilentlyContinue
        }

        It "Should remove the boundary using -BoundaryGroupId and -BoundaryInputObject" {
            $bgId        = $script:CreatedBoundaryGroup.GroupID
            $boundaryObj = Get-CM7Boundary -BoundaryId $script:CreatedBoundary.BoundaryID

            { Remove-CM7BoundaryFromGroup -BoundaryGroupId $bgId -BoundaryInputObject $boundaryObj -Force } | Should -Not -Throw

            Test-BoundaryInGroup | Should -Be $false
        }
    }

    # -------------------------------------------------------------------------
    # 13. Remove by BoundaryGroupName and BoundaryInputObject (mixed)
    # -------------------------------------------------------------------------
    Context "Remove by BoundaryGroupName and BoundaryInputObject" {

        BeforeEach {
            Add-CM7BoundaryToGroup -BoundaryGroupId $script:CreatedBoundaryGroup.GroupID -BoundaryId $script:CreatedBoundary.BoundaryID -ErrorAction SilentlyContinue
        }

        It "Should remove the boundary using -BoundaryGroupName and -BoundaryInputObject" {
            $bgName      = $script:CreatedBoundaryGroup.Name
            $boundaryObj = Get-CM7Boundary -BoundaryId $script:CreatedBoundary.BoundaryID

            { Remove-CM7BoundaryFromGroup -BoundaryGroupName $bgName -BoundaryInputObject $boundaryObj -Force } | Should -Not -Throw

            Test-BoundaryInGroup | Should -Be $false
        }
    }

    # -------------------------------------------------------------------------
    # 14. WhatIf support
    # -------------------------------------------------------------------------
    Context "WhatIf Support" {

        BeforeEach {
            Add-CM7BoundaryToGroup -BoundaryGroupId $script:CreatedBoundaryGroup.GroupID -BoundaryId $script:CreatedBoundary.BoundaryID -ErrorAction SilentlyContinue
        }

        It "Should not remove the boundary when -WhatIf is specified" {
            $bgId = $script:CreatedBoundaryGroup.GroupID
            $bId  = $script:CreatedBoundary.BoundaryID

            Remove-CM7BoundaryFromGroup -BoundaryGroupId $bgId -BoundaryId $bId -WhatIf

            Test-BoundaryInGroup | Should -Be $true
        }

        AfterEach {
            Remove-CM7BoundaryFromGroup -BoundaryGroupId $script:CreatedBoundaryGroup.GroupID -BoundaryId $script:CreatedBoundary.BoundaryID -Force -ErrorAction SilentlyContinue
        }
    }

    # -------------------------------------------------------------------------
    # 15. Error handling — non-existent boundary
    # -------------------------------------------------------------------------
    Context "Error Handling: Non-Existent Boundary" {

        It "Should throw when boundary ID does not exist" {
            $bgId          = $script:CreatedBoundaryGroup.GroupID
            $nonExistentId = $script:TestData_Remove.NonExistentBoundary.BoundaryId

            { Remove-CM7BoundaryFromGroup -BoundaryGroupId $bgId -BoundaryId $nonExistentId -Force } | Should -Throw
        }

        It "Should throw when boundary name does not exist" {
            $bgId  = $script:CreatedBoundaryGroup.GroupID
            $bName = $script:TestData_Remove.NonExistentBoundary.Name

            { Remove-CM7BoundaryFromGroup -BoundaryGroupId $bgId -BoundaryName $bName -Force } | Should -Throw
        }
    }

    # -------------------------------------------------------------------------
    # 16. Error handling — non-existent boundary group
    # -------------------------------------------------------------------------
    Context "Error Handling: Non-Existent Boundary Group" {

        It "Should throw when boundary group ID does not exist" {
            $bId             = $script:CreatedBoundary.BoundaryID
            $nonExistentBgId = $script:TestData_Remove.NonExistentGroup.BoundaryGroupId

            { Remove-CM7BoundaryFromGroup -BoundaryGroupId $nonExistentBgId -BoundaryId $bId -Force } | Should -Throw
        }

        It "Should throw when boundary group name does not exist" {
            $bId    = $script:CreatedBoundary.BoundaryID
            $bgName = $script:TestData_Remove.NonExistentGroup.BoundaryGroupName

            { Remove-CM7BoundaryFromGroup -BoundaryGroupName $bgName -BoundaryId $bId -Force } | Should -Throw
        }
    }

    # -------------------------------------------------------------------------
    # 17. Cleanup: remove test boundary and boundary group
    # -------------------------------------------------------------------------
    Context "Cleanup: Remove Test Boundary and Boundary Group" {

        It "Should remove the test boundary group via Remove-CM7BoundaryGroup" {
            { Remove-CM7BoundaryGroup -Id ([string]$script:CreatedBoundaryGroup.GroupID) -Force } | Should -Not -Throw

            $check = Get-CM7BoundaryGroup -Id ([string]$script:CreatedBoundaryGroup.GroupID) -ErrorAction SilentlyContinue
            $check | Should -BeNullOrEmpty
        }

        It "Should remove the test boundary via Remove-CM7Boundary" {
            { Remove-CM7Boundary -BoundaryId $script:CreatedBoundary.BoundaryID -Force } | Should -Not -Throw

            $check = Get-CM7Boundary -BoundaryId $script:CreatedBoundary.BoundaryID -ErrorAction SilentlyContinue
            $check | Should -BeNullOrEmpty
        }
    }
}
