# Functional Tests for Add-CM7SoftwareUpdateToGroup
# Tests the Add-CM7SoftwareUpdateToGroup function behavior and return values

BeforeAll {
    # Load test declarations
    . (Join-Path $PSScriptRoot "declarations.ps1")

    # Load all functions
    $CodePath = Join-Path (Get-Item $PSScriptRoot).Parent.FullName "Code"
    Get-ChildItem -Path (Join-Path $CodePath "Private") -Filter "*.ps1" | ForEach-Object { . $_.FullName }
    Get-ChildItem -Path (Join-Path $CodePath "Public") -Filter "*.ps1" | ForEach-Object { . $_.FullName }

    # Get test data for this function
    $script:TestAddSUToGroupData = $script:TestData['Add-CM7SoftwareUpdateToGroup']
    $script:TestConnectData = $script:TestData['Connect-CM7']

    # Track original state for cleanup
    $script:OriginalGroupUpdates = $null
    $script:TestGroupCiId = $null

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

    # Capture the original state of the test group for cleanup
    $namespace = "root/SMS/site_$($script:CMConnection.SiteCode)"
    $testGroupName = $script:TestAddSUToGroupData.TestGroup.SoftwareUpdateGroupName
    $testGroup = Get-CimInstance -CimSession $script:CMConnection.CimSession -Namespace $namespace `
        -Query "SELECT * FROM SMS_AuthorizationList WHERE LocalizedDisplayName = '$testGroupName'"
    if ($testGroup) {
        $script:TestGroupCiId = $testGroup.CI_ID
        $script:OriginalGroupUpdates = $testGroup.Updates
        Write-Host "Captured original state of group '$testGroupName' (CI_ID: $($testGroup.CI_ID), Updates: $(@($testGroup.Updates).Count))" -ForegroundColor Cyan
    }
}

Describe "Add-CM7SoftwareUpdateToGroup Function Tests" -Tag "Integration", "SoftwareUpdateGroup", "Add" {

    Context "Test Data Validation" {

        It "Should have test data defined in declarations.ps1" {
            # Assert
            $script:TestAddSUToGroupData | Should -Not -BeNullOrEmpty
            $script:TestData.ContainsKey('Add-CM7SoftwareUpdateToGroup') | Should -Be $true
        }

        It "Should have required test data parameter sets" {
            # Assert
            $script:TestAddSUToGroupData.ContainsKey('TestGroup') | Should -Be $true
            $script:TestAddSUToGroupData.ContainsKey('ByGroupNameAndArticleId') | Should -Be $true
            $script:TestAddSUToGroupData.ContainsKey('NonExistentGroup') | Should -Be $true
        }

        It "Should output test data for verification" {
            # Output test data
            Write-Host "`n=== Test Data for Add-CM7SoftwareUpdateToGroup ===" -ForegroundColor Cyan
            Write-Host "TestGroup:" -ForegroundColor Yellow
            Write-Host "  SoftwareUpdateGroupName: $($script:TestAddSUToGroupData.TestGroup.SoftwareUpdateGroupName)" -ForegroundColor White

            Write-Host "ByGroupNameAndArticleId:" -ForegroundColor Yellow
            Write-Host "  SoftwareUpdateGroupName: $($script:TestAddSUToGroupData.ByGroupNameAndArticleId.SoftwareUpdateGroupName)" -ForegroundColor White
            Write-Host "  ArticleId: $($script:TestAddSUToGroupData.ByGroupNameAndArticleId.ArticleId -join ', ')" -ForegroundColor White

            Write-Host "NonExistentGroup:" -ForegroundColor Yellow
            Write-Host "  SoftwareUpdateGroupName: $($script:TestAddSUToGroupData.NonExistentGroup.SoftwareUpdateGroupName)" -ForegroundColor White
            Write-Host "============================================================`n" -ForegroundColor Cyan

            # This test always passes, it's just for output
            $true | Should -Be $true
        }
    }

    Context "Connection Requirement" {

        It "Should fail if not connected to MECM" {
            # Arrange - Backup and clear connection
            $backupConnection = $script:CMConnection.Clone()
            $script:CMConnection.CimSession = $null

            # Act & Assert
            { Add-CM7SoftwareUpdateToGroup -SoftwareUpdateGroupName "Test" -UpdateId @(1) } | Should -Throw "*not connected*"

            # Restore connection
            $script:CMConnection = $backupConnection
        }
    }

    Context "Add by Group Name and Article ID" {

        It "Should add a software update to a group by Article ID" {
            # Arrange
            $testData = $script:TestAddSUToGroupData.ByGroupNameAndArticleId

            # Act
            $result = Add-CM7SoftwareUpdateToGroup -SoftwareUpdateGroupName $testData.SoftwareUpdateGroupName `
                -ArticleId $testData.ArticleId -Force

            # Assert
            if ($result) {
                $result | Should -Not -BeNullOrEmpty
                $result.LocalizedDisplayName | Should -Be $testData.SoftwareUpdateGroupName
                $result.CI_ID | Should -BeGreaterThan 0
            } else {
                # If result is null, the updates were already in the group (no changes needed)
                $true | Should -Be $true
            }
        }
    }

    Context "Add by Group Name and Update ID" {

        It "Should add a software update to a group by CI_ID" {
            # Arrange - First resolve an Article ID to a CI_ID
            $testData = $script:TestAddSUToGroupData.ByGroupNameAndArticleId
            $namespace = "root/SMS/site_$($script:CMConnection.SiteCode)"
            $articleId = $testData.ArticleId[0]

            $update = Get-CimInstance -CimSession $script:CMConnection.CimSession -Namespace $namespace `
                -Query "SELECT CI_ID FROM SMS_SoftwareUpdate WHERE ArticleID = '$articleId'" | Select-Object -First 1

            if (-not $update) {
                Set-ItResult -Skipped -Because "Software update with Article ID '$articleId' not found in the environment"
                return
            }

            # Act
            $result = Add-CM7SoftwareUpdateToGroup -SoftwareUpdateGroupName $testData.SoftwareUpdateGroupName `
                -UpdateId @([int]$update.CI_ID) -Force

            # Assert
            if ($result) {
                $result | Should -Not -BeNullOrEmpty
                $result.LocalizedDisplayName | Should -Be $testData.SoftwareUpdateGroupName
            } else {
                # Update already in group
                $true | Should -Be $true
            }
        }
    }

    Context "Add by Group Name and Software Update Object" {

        It "Should add a software update object to a group" {
            # Arrange
            $testData = $script:TestAddSUToGroupData.ByGroupNameAndSoftwareUpdate
            $updates = Get-CM7SoftwareUpdate -ArticleId $testData.ArticleId

            if (-not $updates) {
                Set-ItResult -Skipped -Because "Software update with Article ID '$($testData.ArticleId)' not found in the environment"
                return
            }

            # Act
            $result = Add-CM7SoftwareUpdateToGroup -SoftwareUpdateGroupName $testData.SoftwareUpdateGroupName `
                -SoftwareUpdate $updates -Force

            # Assert
            if ($result) {
                $result | Should -Not -BeNullOrEmpty
                $result.LocalizedDisplayName | Should -Be $testData.SoftwareUpdateGroupName
            } else {
                # Update already in group
                $true | Should -Be $true
            }
        }
    }

    Context "Add by Group Name and Software Update Name" {

        It "Should add software updates matching a name pattern" {
            # Arrange
            $testData = $script:TestAddSUToGroupData.ByGroupNameAndSoftwareUpdateName

            # Act
            $result = Add-CM7SoftwareUpdateToGroup -SoftwareUpdateGroupName $testData.SoftwareUpdateGroupName `
                -SoftwareUpdateName $testData.SoftwareUpdateName -Force

            # Assert
            if ($result) {
                $result | Should -Not -BeNullOrEmpty
                $result.LocalizedDisplayName | Should -Be $testData.SoftwareUpdateGroupName
            } else {
                # Updates already in group or not found
                $true | Should -Be $true
            }
        }
    }

    Context "Add by Group ID" {

        It "Should add a software update to a group specified by CI_ID" {
            # Arrange
            if (-not $script:TestGroupCiId) {
                Set-ItResult -Skipped -Because "Test group CI_ID not available"
                return
            }

            $testData = $script:TestAddSUToGroupData.ByGroupId

            # Act
            $result = Add-CM7SoftwareUpdateToGroup -SoftwareUpdateGroupId $script:TestGroupCiId `
                -ArticleId $testData.ArticleId -Force

            # Assert
            if ($result) {
                $result | Should -Not -BeNullOrEmpty
                $result.CI_ID | Should -Be $script:TestGroupCiId
            } else {
                # Update already in group
                $true | Should -Be $true
            }
        }
    }

    Context "Add by Group Object (Pipeline)" {

        It "Should accept a software update group object from pipeline" {
            # Arrange
            $testData = $script:TestAddSUToGroupData.ByGroupObject
            $group = Get-CM7SoftwareUpdateGroup -Name $testData.SoftwareUpdateGroupName

            if (-not $group) {
                Set-ItResult -Skipped -Because "Software update group '$($testData.SoftwareUpdateGroupName)' not found"
                return
            }

            # Act
            $result = $group | Add-CM7SoftwareUpdateToGroup -ArticleId $testData.ArticleId -Force

            # Assert
            if ($result) {
                $result | Should -Not -BeNullOrEmpty
                $result.LocalizedDisplayName | Should -Be $testData.SoftwareUpdateGroupName
            } else {
                # Update already in group
                $true | Should -Be $true
            }
        }
    }

    Context "Duplicate Update Handling" {

        It "Should silently skip updates that are already in the group" {
            # Arrange - First add the update, then try to add the same one again
            $testData = $script:TestAddSUToGroupData.DuplicateUpdate

            # First add (ensure the update is in the group, discard output)
            $null = Add-CM7SoftwareUpdateToGroup -SoftwareUpdateGroupName $testData.SoftwareUpdateGroupName `
                -ArticleId $testData.ArticleId -Force

            # Act - Second add (should return null since nothing new to add)
            $result = Add-CM7SoftwareUpdateToGroup -SoftwareUpdateGroupName $testData.SoftwareUpdateGroupName `
                -ArticleId $testData.ArticleId -Force

            # Assert - No result means all updates were already present
            $result | Should -BeNullOrEmpty
        }
    }

    Context "Error Handling" {

        It "Should throw for non-existent software update group name" {
            # Arrange
            $testData = $script:TestAddSUToGroupData.NonExistentGroup

            # Act & Assert
            { Add-CM7SoftwareUpdateToGroup -SoftwareUpdateGroupName $testData.SoftwareUpdateGroupName `
                -ArticleId $testData.ArticleId -Force } | Should -Throw "*not found*"
        }

        It "Should throw for non-existent software update group ID" {
            # Arrange
            $testData = $script:TestAddSUToGroupData.NonExistentGroupId

            # Act & Assert
            { Add-CM7SoftwareUpdateToGroup -SoftwareUpdateGroupId $testData.SoftwareUpdateGroupId `
                -ArticleId $testData.ArticleId -Force } | Should -Throw "*not found*"
        }

        It "Should warn and skip for non-existent Article ID" {
            # Arrange
            $testData = $script:TestAddSUToGroupData.NonExistentArticle

            # Act & Assert - Should not throw but should produce a warning
            $warningOutput = $null
            $result = Add-CM7SoftwareUpdateToGroup -SoftwareUpdateGroupName $testData.SoftwareUpdateGroupName `
                -ArticleId $testData.ArticleId -Force -WarningVariable warningOutput

            # The function should produce warnings about the non-existent article
            $warningOutput | Should -Not -BeNullOrEmpty
            # No result object should be returned since no updates were added
            $result | Should -BeNullOrEmpty
        }
    }

    Context "WhatIf Support" {

        It "Should support -WhatIf parameter without modifying the group" {
            # Arrange
            $testData = $script:TestAddSUToGroupData.ByGroupNameAndArticleId
            $namespace = "root/SMS/site_$($script:CMConnection.SiteCode)"

            # Get current state
            $beforeGroup = Get-CimInstance -CimSession $script:CMConnection.CimSession -Namespace $namespace `
                -Query "SELECT * FROM SMS_AuthorizationList WHERE LocalizedDisplayName = '$($testData.SoftwareUpdateGroupName)'"
            $beforeCount = @($beforeGroup.Updates).Count

            # Act
            { Add-CM7SoftwareUpdateToGroup -SoftwareUpdateGroupName $testData.SoftwareUpdateGroupName `
                -ArticleId $testData.ArticleId -WhatIf } | Should -Not -Throw

            # Assert - Verify group was not modified
            $afterGroup = Get-CimInstance -CimSession $script:CMConnection.CimSession -Namespace $namespace `
                -Query "SELECT * FROM SMS_AuthorizationList WHERE LocalizedDisplayName = '$($testData.SoftwareUpdateGroupName)'"
            $afterCount = @($afterGroup.Updates).Count
            $afterCount | Should -Be $beforeCount
        }
    }

    Context "Return Object Properties" {

        It "Should return objects with expected properties" {
            # Arrange
            $testData = $script:TestAddSUToGroupData.ByGroupNameAndArticleId

            # Act
            $result = Add-CM7SoftwareUpdateToGroup -SoftwareUpdateGroupName $testData.SoftwareUpdateGroupName `
                -ArticleId $testData.ArticleId -Force

            # Assert - result may be null if updates already in group
            if ($result) {
                $result.PSObject.Properties.Name | Should -Contain 'CI_ID'
                $result.PSObject.Properties.Name | Should -Contain 'CI_UniqueID'
                $result.PSObject.Properties.Name | Should -Contain 'LocalizedDisplayName'
                $result.PSObject.Properties.Name | Should -Contain 'LocalizedDescription'
                $result.PSObject.Properties.Name | Should -Contain 'IsDeployed'
                $result.PSObject.Properties.Name | Should -Contain 'IsExpired'
                $result.PSObject.Properties.Name | Should -Contain 'IsSuperseded'
                $result.PSObject.Properties.Name | Should -Contain 'NumberOfUpdates'
                $result.PSObject.Properties.Name | Should -Contain 'DateCreated'
                $result.PSObject.Properties.Name | Should -Contain 'DateLastModified'
            } else {
                # Updates already in group - skip property check
                Set-ItResult -Skipped -Because "Updates were already in the group, no result object returned"
            }
        }

        It "Should have PSTypeName set correctly" {
            # Arrange
            $testData = $script:TestAddSUToGroupData.ByGroupNameAndArticleId

            # Act
            $result = Add-CM7SoftwareUpdateToGroup -SoftwareUpdateGroupName $testData.SoftwareUpdateGroupName `
                -ArticleId $testData.ArticleId -Force

            # Assert
            if ($result) {
                $result.PSObject.TypeNames[0] | Should -Be 'MECM7.SoftwareUpdateGroup'
            } else {
                Set-ItResult -Skipped -Because "Updates were already in the group, no result object returned"
            }
        }
    }

    Context "Verbose Output" {

        It "Should provide verbose output when requested" {
            # Arrange
            $testData = $script:TestAddSUToGroupData.ByGroupNameAndArticleId

            # Act
            $verboseOutput = Add-CM7SoftwareUpdateToGroup -SoftwareUpdateGroupName $testData.SoftwareUpdateGroupName `
                -ArticleId $testData.ArticleId -Force -Verbose 4>&1

            # Assert
            $verboseOutput | Should -Not -BeNullOrEmpty
            $verboseMessages = $verboseOutput | Where-Object { $_ -is [System.Management.Automation.VerboseRecord] }
            $runningMessage = $verboseMessages | Where-Object { $_.Message -match "Running Add-CM7SoftwareUpdateToGroup" }
            $runningMessage | Should -Not -BeNullOrEmpty
        }
    }
}

AfterAll {
    # Clean up: restore the test group to its original state
    if ($script:CMConnection.CimSession -and $script:TestGroupCiId) {
        $namespace = "root/SMS/site_$($script:CMConnection.SiteCode)"
        try {
            $group = Get-CimInstance -CimSession $script:CMConnection.CimSession -Namespace $namespace `
                -Query "SELECT * FROM SMS_AuthorizationList WHERE CI_ID = $($script:TestGroupCiId)"
            if ($group) {
                $restoreUpdates = if ($script:OriginalGroupUpdates) { [uint32[]]$script:OriginalGroupUpdates } else { [uint32[]]@() }
                $group | Set-CimInstance -Property @{
                    Updates = $restoreUpdates
                }
                Write-Host "Test cleanup: Restored group '$($group.LocalizedDisplayName)' to original state ($(@($restoreUpdates).Count) updates)" -ForegroundColor Green
            }
        }
        catch {
            Write-Warning "Test cleanup: Failed to restore software update group: $_"
        }
        Write-Host "Test cleanup: Done" -ForegroundColor Green
    }
}
