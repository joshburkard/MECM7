# Functional Tests for Add-CM7BoundaryToGroup
# Tests the Add-CM7BoundaryToGroup function behavior

BeforeAll {
    # Load test declarations
    . (Join-Path $PSScriptRoot "declarations.ps1")

    # Load all functions
    $CodePath = Join-Path (Get-Item $PSScriptRoot).Parent.FullName "Code"
    Get-ChildItem -Path (Join-Path $CodePath "Private") -Filter "*.ps1" | ForEach-Object { . $_.FullName }
    Get-ChildItem -Path (Join-Path $CodePath "Public")  -Filter "*.ps1" | ForEach-Object { . $_.FullName }

    # Get test data for this function
    $script:TestData_Add      = $script:TestData['Add-CM7BoundaryToGroup']
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
    $bgName = $script:TestData_Add.NewBoundaryGroup.Name
    $leftoverGroup = Get-CimInstance @cimParams -Query "SELECT * FROM SMS_BoundaryGroup WHERE Name = '$bgName'" -ErrorAction SilentlyContinue
    if ($leftoverGroup) {
        Write-Host "AfterAll safety-net: removing leftover boundary group '$bgName'" -ForegroundColor Yellow
        Remove-CimInstance -InputObject $leftoverGroup -ErrorAction SilentlyContinue
    }

    # Remove test boundary
    $bName = $script:TestData_Add.NewBoundary.Name
    $leftoverBoundary = Get-CimInstance @cimParams -Query "SELECT * FROM SMS_Boundary WHERE DisplayName = '$bName'" -ErrorAction SilentlyContinue
    if ($leftoverBoundary) {
        Write-Host "AfterAll safety-net: removing leftover boundary '$bName'" -ForegroundColor Yellow
        Remove-CimInstance -InputObject $leftoverBoundary -ErrorAction SilentlyContinue
    }
}

Describe "Add-CM7BoundaryToGroup Function Tests" -Tag "Integration", "Boundary", "BoundaryGroup", "Add" {

    # -------------------------------------------------------------------------
    # 1. Declarations validation
    # -------------------------------------------------------------------------
    Context "Test Data Validation" {

        It "Should have test data defined in declarations.ps1" {
            $script:TestData_Add | Should -Not -BeNullOrEmpty
            $script:TestData.ContainsKey('Add-CM7BoundaryToGroup') | Should -Be $true
        }

        It "Should have required test data sections" {
            $script:TestData_Add.ContainsKey('NewBoundary')        | Should -Be $true
            $script:TestData_Add.ContainsKey('NewBoundaryGroup')   | Should -Be $true
            $script:TestData_Add.ContainsKey('NonExistentBoundary')| Should -Be $true
            $script:TestData_Add.ContainsKey('NonExistentGroup')   | Should -Be $true
        }

        It "Should output test data for verification" {
            Write-Host "`n=== Test Data for Add-CM7BoundaryToGroup ===" -ForegroundColor Cyan
            Write-Host "NewBoundary.Name:           $($script:TestData_Add.NewBoundary.Name)" -ForegroundColor White
            Write-Host "NewBoundary.Value:          $($script:TestData_Add.NewBoundary.Value)" -ForegroundColor White
            Write-Host "NewBoundaryGroup.Name:      $($script:TestData_Add.NewBoundaryGroup.Name)" -ForegroundColor White
            Write-Host "NonExistentBoundary.Id:     $($script:TestData_Add.NonExistentBoundary.BoundaryId)" -ForegroundColor White
            Write-Host "NonExistentGroup.Id:        $($script:TestData_Add.NonExistentGroup.BoundaryGroupId)" -ForegroundColor White
            Write-Host "============================================`n" -ForegroundColor Cyan
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

            { Add-CM7BoundaryToGroup -BoundaryGroupName "Test" -BoundaryName "Test" } | Should -Throw "*not connected*"

            $script:CMConnection.CimSession = $backupCim
        }
    }

    # -------------------------------------------------------------------------
    # 3. Setup: create a boundary and a boundary group to work with
    # -------------------------------------------------------------------------
    Context "Setup: Create Test Boundary and Boundary Group" {

        It "Should create the test boundary via New-CM7Boundary" {
            $p = $script:TestData_Add.NewBoundary

            # Ensure clean state
            $existing = Get-CM7Boundary -Name $p.Name -ErrorAction SilentlyContinue
            if ($existing) { Remove-CM7Boundary -Name $p.Name -Force -ErrorAction SilentlyContinue }

            $script:CreatedBoundary = New-CM7Boundary -Name $p.Name -BoundaryType $p.BoundaryType -Value $p.Value -Force
            $script:CreatedBoundary           | Should -Not -BeNullOrEmpty
            $script:CreatedBoundary.BoundaryID| Should -BeGreaterThan 0
        }

        It "Should create the test boundary group via New-CM7BoundaryGroup" {
            $p = $script:TestData_Add.NewBoundaryGroup

            # Ensure clean state
            $existing = Get-CM7BoundaryGroup -Name $p.Name -ErrorAction SilentlyContinue
            if ($existing) { Remove-CM7BoundaryGroup -Name $p.Name -Force -ErrorAction SilentlyContinue }

            $script:CreatedBoundaryGroup = New-CM7BoundaryGroup -Name $p.Name -Force
            $script:CreatedBoundaryGroup        | Should -Not -BeNullOrEmpty
            $script:CreatedBoundaryGroup.GroupID| Should -BeGreaterThan 0
        }
    }

    # -------------------------------------------------------------------------
    # 4. Helper functions (used to check state in tests)
    # -------------------------------------------------------------------------
    BeforeAll {
        # Helper: checks if the test boundary is currently in the test group
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
    # 5. Add boundary to group — by IDs
    # -------------------------------------------------------------------------
    Context "Add Boundary to Group by BoundaryGroupId and BoundaryId" {

        BeforeEach {
            Remove-CM7BoundaryFromGroup -BoundaryGroupId $script:CreatedBoundaryGroup.GroupID -BoundaryId $script:CreatedBoundary.BoundaryID -Force -ErrorAction SilentlyContinue
        }

        It "Should add the boundary to the group using -BoundaryGroupId and -BoundaryId" {
            $bgId = $script:CreatedBoundaryGroup.GroupID
            $bId  = $script:CreatedBoundary.BoundaryID

            { Add-CM7BoundaryToGroup -BoundaryGroupId $bgId -BoundaryId $bId } | Should -Not -Throw

            Test-BoundaryInGroup | Should -Be $true
        }
    }

    # -------------------------------------------------------------------------
    # 6. Add boundary to group — by Names
    # -------------------------------------------------------------------------
    Context "Add Boundary to Group by BoundaryGroupName and BoundaryName" {

        BeforeEach {
            Remove-CM7BoundaryFromGroup -BoundaryGroupId $script:CreatedBoundaryGroup.GroupID -BoundaryId $script:CreatedBoundary.BoundaryID -Force -ErrorAction SilentlyContinue
        }

        It "Should add the boundary to the group using -BoundaryGroupName and -BoundaryName" {
            $bgName = $script:CreatedBoundaryGroup.Name
            $bName  = $script:CreatedBoundary.DisplayName

            { Add-CM7BoundaryToGroup -BoundaryGroupName $bgName -BoundaryName $bName } | Should -Not -Throw

            Test-BoundaryInGroup | Should -Be $true
        }
    }

    # -------------------------------------------------------------------------
    # 7. Add boundary to group — by InputObjects
    # -------------------------------------------------------------------------
    Context "Add Boundary to Group by BoundaryGroupInputObject and InputObject" {

        BeforeEach {
            Remove-CM7BoundaryFromGroup -BoundaryGroupId $script:CreatedBoundaryGroup.GroupID -BoundaryId $script:CreatedBoundary.BoundaryID -Force -ErrorAction SilentlyContinue
        }

        It "Should add the boundary to the group using -BoundaryGroupInputObject and -InputObject" {
            $groupObj    = Get-CM7BoundaryGroup -Name $script:CreatedBoundaryGroup.Name
            $boundaryObj = Get-CM7Boundary      -BoundaryId $script:CreatedBoundary.BoundaryID

            { Add-CM7BoundaryToGroup -BoundaryGroupInputObject $groupObj -InputObject $boundaryObj } | Should -Not -Throw

            Test-BoundaryInGroup | Should -Be $true
        }
    }

    # -------------------------------------------------------------------------
    # 8. Add boundary to group — mixed: BoundaryGroupName + BoundaryId
    # -------------------------------------------------------------------------
    Context "Add Boundary to Group by BoundaryGroupName and BoundaryId" {

        BeforeEach {
            Remove-CM7BoundaryFromGroup -BoundaryGroupId $script:CreatedBoundaryGroup.GroupID -BoundaryId $script:CreatedBoundary.BoundaryID -Force -ErrorAction SilentlyContinue
        }

        It "Should add the boundary to the group using -BoundaryGroupName and -BoundaryId" {
            $bgName = $script:CreatedBoundaryGroup.Name
            $bId    = $script:CreatedBoundary.BoundaryID

            { Add-CM7BoundaryToGroup -BoundaryGroupName $bgName -BoundaryId $bId } | Should -Not -Throw

            Test-BoundaryInGroup | Should -Be $true
        }
    }

    # -------------------------------------------------------------------------
    # 9. Add boundary to group — mixed: BoundaryGroupId + BoundaryName
    # -------------------------------------------------------------------------
    Context "Add Boundary to Group by BoundaryGroupId and BoundaryName" {

        BeforeEach {
            Remove-CM7BoundaryFromGroup -BoundaryGroupId $script:CreatedBoundaryGroup.GroupID -BoundaryId $script:CreatedBoundary.BoundaryID -Force -ErrorAction SilentlyContinue
        }

        It "Should add the boundary to the group using -BoundaryGroupId and -BoundaryName" {
            $bgId  = $script:CreatedBoundaryGroup.GroupID
            $bName = $script:CreatedBoundary.DisplayName

            { Add-CM7BoundaryToGroup -BoundaryGroupId $bgId -BoundaryName $bName } | Should -Not -Throw

            Test-BoundaryInGroup | Should -Be $true
        }
    }

    # -------------------------------------------------------------------------
    # 10. Pipeline: pipe boundary object, specify group by name
    # -------------------------------------------------------------------------
    Context "Add Boundary to Group via Pipeline (InputObject piped)" {

        BeforeEach {
            Remove-CM7BoundaryFromGroup -BoundaryGroupId $script:CreatedBoundaryGroup.GroupID -BoundaryId $script:CreatedBoundary.BoundaryID -Force -ErrorAction SilentlyContinue
        }

        It "Should add the boundary to the group when boundary is piped as InputObject" {
            $bgName = $script:CreatedBoundaryGroup.Name

            { Get-CM7Boundary -BoundaryId $script:CreatedBoundary.BoundaryID | Add-CM7BoundaryToGroup -BoundaryGroupName $bgName } | Should -Not -Throw

            Test-BoundaryInGroup | Should -Be $true
        }
    }

    # -------------------------------------------------------------------------
    # 11. WhatIf support
    # -------------------------------------------------------------------------
    Context "WhatIf Support" {

        BeforeEach {
            Remove-CM7BoundaryFromGroup -BoundaryGroupId $script:CreatedBoundaryGroup.GroupID -BoundaryId $script:CreatedBoundary.BoundaryID -Force -ErrorAction SilentlyContinue
        }

        It "Should not add the boundary to the group when -WhatIf is specified" {
            $bgName = $script:CreatedBoundaryGroup.Name
            $bId    = $script:CreatedBoundary.BoundaryID

            Add-CM7BoundaryToGroup -BoundaryGroupName $bgName -BoundaryId $bId -WhatIf

            Test-BoundaryInGroup | Should -Be $false
        }
    }

    # -------------------------------------------------------------------------
    # 12. Error handling — non-existent boundary
    # -------------------------------------------------------------------------
    Context "Error Handling: Non-Existent Boundary" {

        It "Should throw when boundary ID does not exist" {
            $bgId = $script:CreatedBoundaryGroup.GroupID
            $nonExistentBId = $script:TestData_Add.NonExistentBoundary.BoundaryId

            { Add-CM7BoundaryToGroup -BoundaryGroupId $bgId -BoundaryId $nonExistentBId } | Should -Throw
        }

        It "Should throw when boundary name does not exist" {
            $bgId  = $script:CreatedBoundaryGroup.GroupID
            $bName = $script:TestData_Add.NonExistentBoundary.Name

            { Add-CM7BoundaryToGroup -BoundaryGroupId $bgId -BoundaryName $bName } | Should -Throw
        }
    }

    # -------------------------------------------------------------------------
    # 13. Error handling — non-existent boundary group
    # -------------------------------------------------------------------------
    Context "Error Handling: Non-Existent Boundary Group" {

        It "Should throw when boundary group ID does not exist" {
            $bId    = $script:CreatedBoundary.BoundaryID
            $nonExistentBgId = $script:TestData_Add.NonExistentGroup.BoundaryGroupId

            { Add-CM7BoundaryToGroup -BoundaryGroupId $nonExistentBgId -BoundaryId $bId } | Should -Throw
        }

        It "Should throw when boundary group name does not exist" {
            $bId    = $script:CreatedBoundary.BoundaryID
            $bgName = $script:TestData_Add.NonExistentGroup.BoundaryGroupName

            { Add-CM7BoundaryToGroup -BoundaryGroupName $bgName -BoundaryId $bId } | Should -Throw
        }
    }

    # -------------------------------------------------------------------------
    # 14. Remove-CM7BoundaryFromGroup — parameter-set coverage
    # -------------------------------------------------------------------------
    Context "Remove-CM7BoundaryFromGroup: Connection Requirement" {

        It "Should throw if not connected to MECM" {
            $backupCim = $script:CMConnection.CimSession
            $script:CMConnection.CimSession = $null

            { Remove-CM7BoundaryFromGroup -BoundaryGroupName "Test" -BoundaryId 1 -Force } | Should -Throw "*not connected*"

            $script:CMConnection.CimSession = $backupCim
        }
    }

    Context "Remove-CM7BoundaryFromGroup: by BoundaryGroupId and BoundaryId" {

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

    Context "Remove-CM7BoundaryFromGroup: by BoundaryGroupName and BoundaryName" {

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

    Context "Remove-CM7BoundaryFromGroup: by BoundaryGroupInputObject and BoundaryInputObject" {

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

    Context "Remove-CM7BoundaryFromGroup: mixed BoundaryGroupName and BoundaryId" {

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

    Context "Remove-CM7BoundaryFromGroup: mixed BoundaryGroupId and BoundaryName" {

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

    Context "Remove-CM7BoundaryFromGroup: WhatIf Support" {

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

    Context "Remove-CM7BoundaryFromGroup: Error Handling — Non-Existent Boundary" {

        It "Should throw when boundary ID does not exist" {
            $bgId = $script:CreatedBoundaryGroup.GroupID
            $nonExistentId = $script:TestData_Add.NonExistentBoundary.BoundaryId

            { Remove-CM7BoundaryFromGroup -BoundaryGroupId $bgId -BoundaryId $nonExistentId -Force } | Should -Throw
        }

        It "Should throw when boundary name does not exist" {
            $bgId  = $script:CreatedBoundaryGroup.GroupID
            $bName = $script:TestData_Add.NonExistentBoundary.Name

            { Remove-CM7BoundaryFromGroup -BoundaryGroupId $bgId -BoundaryName $bName -Force } | Should -Throw
        }
    }

    Context "Remove-CM7BoundaryFromGroup: Error Handling — Non-Existent Boundary Group" {

        It "Should throw when boundary group ID does not exist" {
            $bId             = $script:CreatedBoundary.BoundaryID
            $nonExistentBgId = $script:TestData_Add.NonExistentGroup.BoundaryGroupId

            { Remove-CM7BoundaryFromGroup -BoundaryGroupId $nonExistentBgId -BoundaryId $bId -Force } | Should -Throw
        }

        It "Should throw when boundary group name does not exist" {
            $bId    = $script:CreatedBoundary.BoundaryID
            $bgName = $script:TestData_Add.NonExistentGroup.BoundaryGroupName

            { Remove-CM7BoundaryFromGroup -BoundaryGroupName $bgName -BoundaryId $bId -Force } | Should -Throw
        }
    }

    # -------------------------------------------------------------------------
    # 15. Cleanup: remove test boundary and boundary group
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
