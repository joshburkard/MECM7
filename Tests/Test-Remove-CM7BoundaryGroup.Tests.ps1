# Functional Tests for Remove-CM7BoundaryGroup
# Tests the Remove-CM7BoundaryGroup function behavior and return values

BeforeAll {
    # Load test declarations
    . (Join-Path $PSScriptRoot "declarations.ps1")

    # Load all functions
    $CodePath = Join-Path (Get-Item $PSScriptRoot).Parent.FullName "Code"
    Get-ChildItem -Path (Join-Path $CodePath "Private") -Filter "*.ps1" | ForEach-Object { . $_.FullName }
    Get-ChildItem -Path (Join-Path $CodePath "Public") -Filter "*.ps1" | ForEach-Object { . $_.FullName }

    # Get test data for this function
    $script:TestRemoveBoundaryGroupData = $script:TestData['Remove-CM7BoundaryGroup']
    $script:TestConnectData             = $script:TestData['Connect-CM7']

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
    # Safety net: remove any boundary groups that were not cleaned up by the test contexts
    $namespace = "root/SMS/site_$($script:CMConnection.SiteCode)"
    $cimParams  = @{
        CimSession = $script:CMConnection.CimSession
        Namespace  = $namespace
    }

    $testGroupNames = @(
        $script:TestRemoveBoundaryGroupData.NewGroups.Simple.Name,
        $script:TestRemoveBoundaryGroupData.NewGroups.WithDescription.Name
    )

    foreach ($gName in $testGroupNames) {
        if ($gName) {
            $leftover = Get-CimInstance @cimParams -Query "SELECT * FROM SMS_BoundaryGroup WHERE Name = '$gName'" -ErrorAction SilentlyContinue
            if ($leftover) {
                Write-Host "AfterAll safety-net: removing leftover boundary group '$gName'" -ForegroundColor Yellow
                Remove-CimInstance -InputObject $leftover -ErrorAction SilentlyContinue
            }
        }
    }
}

Describe "Remove-CM7BoundaryGroup Function Tests" -Tag "Integration", "BoundaryGroup", "Remove" {

    # -------------------------------------------------------------------------
    # 1. Declarations validation
    # -------------------------------------------------------------------------
    Context "Test Data Validation" {

        It "Should have test data defined in declarations.ps1" {
            $script:TestRemoveBoundaryGroupData | Should -Not -BeNullOrEmpty
            $script:TestData.ContainsKey('Remove-CM7BoundaryGroup') | Should -Be $true
        }

        It "Should have required test data parameter sets" {
            $script:TestRemoveBoundaryGroupData.ContainsKey('ByName')        | Should -Be $true
            $script:TestRemoveBoundaryGroupData.ContainsKey('ById')          | Should -Be $true
            $script:TestRemoveBoundaryGroupData.ContainsKey('ByInputObject') | Should -Be $true
            $script:TestRemoveBoundaryGroupData.ContainsKey('NewGroups')     | Should -Be $true
            $script:TestRemoveBoundaryGroupData.ContainsKey('NonExistent')   | Should -Be $true
        }

        It "Should output test data for verification" {
            Write-Host "`n=== Test Data for Remove-CM7BoundaryGroup ===" -ForegroundColor Cyan
            Write-Host "ByName.Name:                   $($script:TestRemoveBoundaryGroupData.ByName.Name)" -ForegroundColor White
            Write-Host "ByInputObject.Name:            $($script:TestRemoveBoundaryGroupData.ByInputObject.Name)" -ForegroundColor White
            Write-Host "NonExistent.Name:              $($script:TestRemoveBoundaryGroupData.NonExistent.Name)" -ForegroundColor White
            Write-Host "NewGroups.Simple.Name:         $($script:TestRemoveBoundaryGroupData.NewGroups.Simple.Name)" -ForegroundColor White
            Write-Host "NewGroups.WithDescription.Name:$($script:TestRemoveBoundaryGroupData.NewGroups.WithDescription.Name)" -ForegroundColor White
            Write-Host "=====================================================`n" -ForegroundColor Cyan
            $true | Should -Be $true
        }
    }

    # -------------------------------------------------------------------------
    # 2. Connection requirement
    # -------------------------------------------------------------------------
    Context "Connection Requirement" {

        It "Should fail if not connected to MECM" {
            $backupCim = $script:CMConnection.CimSession
            $script:CMConnection.CimSession = $null

            { Remove-CM7BoundaryGroup -Name "TestGroup" -Force } | Should -Throw "*not connected*"

            $script:CMConnection.CimSession = $backupCim
        }
    }

    # -------------------------------------------------------------------------
    # 3. Remove by Name
    # -------------------------------------------------------------------------
    Context "Remove Boundary Group By Name" {

        BeforeEach {
            # Create the "Test" boundary group so we can remove it
            $params = $script:TestRemoveBoundaryGroupData.NewGroups.Simple
            $existing = Get-CM7BoundaryGroup -Name $params.Name -ErrorAction SilentlyContinue
            if (-not $existing) {
                $script:CreatedSimpleGroup = New-CM7BoundaryGroup -Name $params.Name -Force
                Write-Host "Created boundary group '$($params.Name)' (GroupID: $($script:CreatedSimpleGroup.GroupID))" -ForegroundColor DarkGray
            }
        }

        It "Should remove boundary group 'Test' by -Name" {
            $params = $script:TestRemoveBoundaryGroupData.ByName

            { Remove-CM7BoundaryGroup -Name $params.Name -Force } | Should -Not -Throw

            # Verify removal
            $result = Get-CM7BoundaryGroup -Name $params.Name -ErrorAction SilentlyContinue
            $result | Should -BeNullOrEmpty
        }
    }

    # -------------------------------------------------------------------------
    # 4. Remove by Id
    # -------------------------------------------------------------------------
    Context "Remove Boundary Group By Id" {

        BeforeEach {
            # Create boundary group "Test" so we can remove it by GroupID
            $params = $script:TestRemoveBoundaryGroupData.NewGroups.Simple
            $existing = Get-CM7BoundaryGroup -Name $params.Name -ErrorAction SilentlyContinue
            if (-not $existing) {
                $script:CreatedGroupForId = New-CM7BoundaryGroup -Name $params.Name -Force
                Write-Host "Created boundary group '$($params.Name)' (GroupID: $($script:CreatedGroupForId.GroupID))" -ForegroundColor DarkGray
            } else {
                $script:CreatedGroupForId = $existing
            }
        }

        It "Should remove boundary group by -Id" {
            $groupId = [string]$script:CreatedGroupForId.GroupID
            $groupId | Should -Not -BeNullOrEmpty

            { Remove-CM7BoundaryGroup -Id $groupId -Force } | Should -Not -Throw

            # Verify removal
            $result = Get-CM7BoundaryGroup -Id $groupId -ErrorAction SilentlyContinue
            $result | Should -BeNullOrEmpty
        }

        It "Should emit a warning for a non-existent GroupID" {
            $data = $script:TestRemoveBoundaryGroupData.NonExistent
            $warnings = $null
            Remove-CM7BoundaryGroup -Id $data.GroupId -Force -WarningVariable warnings -ErrorAction SilentlyContinue
            $warnings | Should -Not -BeNullOrEmpty
        }
    }

    # -------------------------------------------------------------------------
    # 5. Remove by InputObject (pipeline)
    # -------------------------------------------------------------------------
    Context "Remove Boundary Group By InputObject (Pipeline)" {

        BeforeEach {
            # Create boundary group "TestWithDescription" for pipeline removal
            $params = $script:TestRemoveBoundaryGroupData.NewGroups.WithDescription
            $existing = Get-CM7BoundaryGroup -Name $params.Name -ErrorAction SilentlyContinue
            if (-not $existing) {
                $script:CreatedDescGroup = New-CM7BoundaryGroup -Name $params.Name -Description $params.Description -Force
                Write-Host "Created boundary group '$($params.Name)' (GroupID: $($script:CreatedDescGroup.GroupID))" -ForegroundColor DarkGray
            } else {
                $script:CreatedDescGroup = $existing
            }
        }

        It "Should remove boundary group via -InputObject" {
            $inputGroup = Get-CM7BoundaryGroup -Name $script:TestRemoveBoundaryGroupData.ByInputObject.Name
            $inputGroup | Should -Not -BeNullOrEmpty

            { Remove-CM7BoundaryGroup -InputObject $inputGroup -Force } | Should -Not -Throw

            # Verify removal
            $result = Get-CM7BoundaryGroup -Name $script:TestRemoveBoundaryGroupData.ByInputObject.Name -ErrorAction SilentlyContinue
            $result | Should -BeNullOrEmpty
        }

        It "Should remove boundary group via pipeline" {
            # Ensure the group exists before piping
            $params = $script:TestRemoveBoundaryGroupData.NewGroups.WithDescription
            $existing = Get-CM7BoundaryGroup -Name $params.Name -ErrorAction SilentlyContinue
            if (-not $existing) {
                New-CM7BoundaryGroup -Name $params.Name -Description $params.Description -Force | Out-Null
            }

            { Get-CM7BoundaryGroup -Name $params.Name | Remove-CM7BoundaryGroup -Force } | Should -Not -Throw

            # Verify removal
            $result = Get-CM7BoundaryGroup -Name $params.Name -ErrorAction SilentlyContinue
            $result | Should -BeNullOrEmpty
        }
    }

    # -------------------------------------------------------------------------
    # 6. WhatIf behaviour
    # -------------------------------------------------------------------------
    Context "WhatIf Behaviour" {

        BeforeEach {
            # Create boundary group "Test" to test WhatIf against
            $params = $script:TestRemoveBoundaryGroupData.NewGroups.Simple
            $existing = Get-CM7BoundaryGroup -Name $params.Name -ErrorAction SilentlyContinue
            if (-not $existing) {
                New-CM7BoundaryGroup -Name $params.Name -Force | Out-Null
                Write-Host "Created boundary group '$($params.Name)' for WhatIf test" -ForegroundColor DarkGray
            }
        }

        AfterEach {
            # Always clean up after WhatIf tests
            $params = $script:TestRemoveBoundaryGroupData.NewGroups.Simple
            $leftover = Get-CM7BoundaryGroup -Name $params.Name -ErrorAction SilentlyContinue
            if ($leftover) {
                Remove-CM7BoundaryGroup -Name $params.Name -Force -ErrorAction SilentlyContinue
            }
        }

        It "Should NOT remove boundary group when -WhatIf is specified" {
            $params = $script:TestRemoveBoundaryGroupData.NewGroups.Simple

            Remove-CM7BoundaryGroup -Name $params.Name -Force -WhatIf

            # Group should still exist
            $result = Get-CM7BoundaryGroup -Name $params.Name -ErrorAction SilentlyContinue
            $result | Should -Not -BeNullOrEmpty
        }
    }

    # -------------------------------------------------------------------------
    # 7. Non-existent boundary group
    # -------------------------------------------------------------------------
    Context "Non-Existent Boundary Group" {

        It "Should emit a warning and not throw for a non-existent name" {
            $data = $script:TestRemoveBoundaryGroupData.NonExistent
            $script:warnings = $null
            { Remove-CM7BoundaryGroup -Name $data.Name -Force -WarningVariable script:warnings } | Should -Not -Throw
            $script:warnings | Should -Not -BeNullOrEmpty
        }

        It "Should emit a warning for a non-existent GroupID" {
            $data = $script:TestRemoveBoundaryGroupData.NonExistent
            $warnings = $null
            Remove-CM7BoundaryGroup -Id $data.GroupId -Force -WarningVariable warnings -ErrorAction SilentlyContinue
            $warnings | Should -Not -BeNullOrEmpty
        }
    }

    # -------------------------------------------------------------------------
    # 8. Wildcard and DisableWildcardHandling
    # -------------------------------------------------------------------------
    Context "Wildcard Handling" {

        It "Should throw if both DisableWildcardHandling and ForceWildcardHandling are specified" {
            { Remove-CM7BoundaryGroup -Name "Test*" -DisableWildcardHandling -ForceWildcardHandling -Force } | Should -Throw
        }
    }
}
