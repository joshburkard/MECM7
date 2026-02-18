# Functional Tests for Add-CM7CollectionMembershipRule
# Tests the Add-CM7CollectionMembershipRule function behavior and return values
# Test collections are created dynamically in the default folder from declarations.ps1
# and removed after the test run

BeforeAll {
    # Load test declarations
    . (Join-Path $PSScriptRoot "declarations.ps1")

    # Load all functions
    $CodePath = Join-Path (Get-Item $PSScriptRoot).Parent.FullName "Code"
    Get-ChildItem -Path (Join-Path $CodePath "Private") -Filter "*.ps1" | ForEach-Object { . $_.FullName }
    Get-ChildItem -Path (Join-Path $CodePath "Public") -Filter "*.ps1" | ForEach-Object { . $_.FullName }

    # Get test data for this function
    $script:TestAddRuleData = $script:TestData['Add-CM7CollectionMembershipRule']
    $script:TestConnectData = $script:TestData['Connect-CM7']

    # Track created collections for cleanup
    $script:CreatedCollectionIds = @()

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

    # Default folder path for test collections
    $script:TestFolderPath = $DefaultPaths.DeviceCollection

    # Helper function to create a test collection for rule tests
    function New-TestCollectionForRules {
        param(
            [string]$NamePrefix = "Test-AddRule-Collection",
            [string]$LimitingCollectionId = "SMS00001"
        )
        $uniqueName = "$NamePrefix-$(Get-Date -Format 'yyyyMMdd_HHmmss_fff')-$([guid]::NewGuid().ToString().Substring(0, 8))"
        $newCollParams = @{
            Name                 = $uniqueName
            LimitingCollectionId = $LimitingCollectionId
        }
        if ($script:TestFolderPath) {
            $newCollParams.FolderPath = $script:TestFolderPath
        }
        $result = New-CM7Collection @newCollParams
        if ($result) {
            $script:CreatedCollectionIds += $result.CollectionId
            Write-Host "  Created test collection: $($result.Name) ($($result.CollectionId))" -ForegroundColor Gray
        }
        return $result
    }
}

Describe "Add-CM7CollectionMembershipRule Function Tests" -Tag "Integration", "Collection", "MembershipRule", "Add" {

    Context "Test Data Validation" {

        It "Should have test data defined in declarations.ps1" {
            # Assert
            $script:TestAddRuleData | Should -Not -BeNullOrEmpty
            $script:TestData.ContainsKey('Add-CM7CollectionMembershipRule') | Should -Be $true
        }

        It "Should have required test data parameter sets" {
            # Assert
            $script:TestAddRuleData.ContainsKey('DirectByCollectionNameAndResourceId') | Should -Be $true
            $script:TestAddRuleData.ContainsKey('QueryByCollectionName') | Should -Be $true
            $script:TestAddRuleData.ContainsKey('IncludeByCollectionName') | Should -Be $true
            $script:TestAddRuleData.ContainsKey('ExcludeByCollectionName') | Should -Be $true
        }

        It "Should output test data for verification" {
            # Output test data
            Write-Host "`n=== Test Data for Add-CM7CollectionMembershipRule ===" -ForegroundColor Cyan

            Write-Host "DirectByCollectionNameAndResourceId:" -ForegroundColor Yellow
            Write-Host "  CollectionName: $($script:TestAddRuleData.DirectByCollectionNameAndResourceId.CollectionName)" -ForegroundColor White
            Write-Host "  ResourceId: $($script:TestAddRuleData.DirectByCollectionNameAndResourceId.ResourceId)" -ForegroundColor White

            Write-Host "QueryByCollectionName:" -ForegroundColor Yellow
            Write-Host "  CollectionName: $($script:TestAddRuleData.QueryByCollectionName.CollectionName)" -ForegroundColor White
            Write-Host "  RuleName: $($script:TestAddRuleData.QueryByCollectionName.RuleName)" -ForegroundColor White

            Write-Host "IncludeByCollectionName:" -ForegroundColor Yellow
            Write-Host "  CollectionName: $($script:TestAddRuleData.IncludeByCollectionName.CollectionName)" -ForegroundColor White
            Write-Host "  IncludeCollectionName: $($script:TestAddRuleData.IncludeByCollectionName.IncludeCollectionName)" -ForegroundColor White

            Write-Host "ExcludeByCollectionName:" -ForegroundColor Yellow
            Write-Host "  CollectionName: $($script:TestAddRuleData.ExcludeByCollectionName.CollectionName)" -ForegroundColor White
            Write-Host "  ExcludeCollectionName: $($script:TestAddRuleData.ExcludeByCollectionName.ExcludeCollectionName)" -ForegroundColor White

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
            { Add-CM7CollectionMembershipRule -CollectionName "Test" -RuleType Direct -ResourceId 1 } | Should -Throw "*not connected*"

            # Restore connection
            $script:CMConnection = $backupConnection
        }
    }

    Context "Parameter Validation" {

        It "Should throw when ResourceId is missing for Direct rule" {
            { Add-CM7CollectionMembershipRule -CollectionName "Test" -RuleType Direct } | Should -Throw "*ResourceId*"
        }

        It "Should throw when RuleName is missing for Query rule" {
            { Add-CM7CollectionMembershipRule -CollectionName "Test" -RuleType Query -QueryExpression "select * from SMS_R_System" } | Should -Throw "*RuleName*"
        }

        It "Should throw when QueryExpression is missing for Query rule" {
            { Add-CM7CollectionMembershipRule -CollectionName "Test" -RuleType Query -RuleName "Test" } | Should -Throw "*QueryExpression*"
        }

        It "Should throw when neither IncludeCollectionId nor IncludeCollectionName is specified for Include rule" {
            { Add-CM7CollectionMembershipRule -CollectionName "Test" -RuleType Include } | Should -Throw "*IncludeCollection*"
        }

        It "Should throw when neither ExcludeCollectionId nor ExcludeCollectionName is specified for Exclude rule" {
            { Add-CM7CollectionMembershipRule -CollectionName "Test" -RuleType Exclude } | Should -Throw "*ExcludeCollection*"
        }
    }

    Context "Add Direct Membership Rule" {

        It "Should add a direct membership rule by collection name and ResourceId" {
            # Arrange - Create a test collection
            $testColl = New-TestCollectionForRules -NamePrefix "Test-AddRule-Direct"
            $testColl | Should -Not -BeNullOrEmpty

            $resourceId = $script:TestAddRuleData.DirectByCollectionNameAndResourceId.ResourceId

            # Act
            $result = Add-CM7CollectionMembershipRule -CollectionName $testColl.Name -RuleType Direct -ResourceId $resourceId

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.RuleType | Should -Be 'Direct'
            $result.ResourceId | Should -Be $resourceId
            $result.Status | Should -Be 'Added'
            $result.CollectionId | Should -Be $testColl.CollectionId
        }

        It "Should add a direct membership rule by collection ID" {
            # Arrange - Create a test collection
            $testColl = New-TestCollectionForRules -NamePrefix "Test-AddRule-DirectById"
            $testColl | Should -Not -BeNullOrEmpty

            $resourceId = $script:TestAddRuleData.DirectByCollectionNameAndResourceId.ResourceId

            # Act
            $result = Add-CM7CollectionMembershipRule -CollectionId $testColl.CollectionId -RuleType Direct -ResourceId $resourceId

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.RuleType | Should -Be 'Direct'
            $result.ResourceId | Should -Be $resourceId
            $result.Status | Should -Be 'Added'
        }

        It "Should add multiple direct membership rules with ResourceId array" {
            # Arrange - Create a test collection
            $testColl = New-TestCollectionForRules -NamePrefix "Test-AddRule-DirectMulti"
            $testColl | Should -Not -BeNullOrEmpty

            $resourceIds = $script:TestAddRuleData.DirectByCollectionNameAndResourceId.ResourceIdArray
            if (-not $resourceIds -or $resourceIds.Count -lt 2) {
                Set-ItResult -Skipped -Because "ResourceIdArray not defined with multiple IDs in test data"
                return
            }

            # Act
            $results = Add-CM7CollectionMembershipRule -CollectionName $testColl.Name -RuleType Direct -ResourceId $resourceIds

            # Assert
            $results | Should -Not -BeNullOrEmpty
            @($results).Count | Should -Be $resourceIds.Count
            $results | ForEach-Object {
                $_.RuleType | Should -Be 'Direct'
                $_.Status | Should -Be 'Added'
            }
        }
    }

    Context "Add Query Membership Rule" {

        It "Should add a query membership rule by collection name" {
            # Arrange - Create a test collection
            $testColl = New-TestCollectionForRules -NamePrefix "Test-AddRule-Query"
            $testColl | Should -Not -BeNullOrEmpty

            $queryData = $script:TestAddRuleData.QueryByCollectionName
            $uniqueRuleName = "$($queryData.RuleName)-$(Get-Date -Format 'yyyyMMdd_HHmmss')"

            # Act
            $result = Add-CM7CollectionMembershipRule -CollectionName $testColl.Name -RuleType Query -RuleName $uniqueRuleName -QueryExpression $queryData.QueryExpression

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.RuleType | Should -Be 'Query'
            $result.RuleName | Should -Be $uniqueRuleName
            $result.QueryExpression | Should -Be $queryData.QueryExpression
            $result.Status | Should -Be 'Added'
            $result.CollectionId | Should -Be $testColl.CollectionId
        }

        It "Should verify query rule is visible via Get-CM7CollectionQueryMembershipRule" {
            # Arrange - Create a test collection and add a query rule
            $testColl = New-TestCollectionForRules -NamePrefix "Test-AddRule-QueryVerify"
            $testColl | Should -Not -BeNullOrEmpty

            $queryData = $script:TestAddRuleData.QueryByCollectionName
            $uniqueRuleName = "Verify-Query-$(Get-Date -Format 'yyyyMMdd_HHmmss')"

            # Act - Add the rule
            $addResult = Add-CM7CollectionMembershipRule -CollectionName $testColl.Name -RuleType Query -RuleName $uniqueRuleName -QueryExpression $queryData.QueryExpression
            $addResult | Should -Not -BeNullOrEmpty

            # Verify - Read it back
            $rules = Get-CM7CollectionQueryMembershipRule -CollectionId $testColl.CollectionId
            $rules | Should -Not -BeNullOrEmpty
            $matchingRule = $rules | Where-Object { $_.RuleName -eq $uniqueRuleName }
            $matchingRule | Should -Not -BeNullOrEmpty
            # MECM expands short SELECT lists into full property lists, so use -Match on the WHERE clause
            $matchingRule.QueryExpression | Should -Match "SMS_R_System.Name like 'TEST-%'"
        }
    }

    Context "Add Include Membership Rule" {

        It "Should add an include membership rule by collection name and IncludeCollectionId" {
            # Arrange - Create a test collection
            $testColl = New-TestCollectionForRules -NamePrefix "Test-AddRule-Include"
            $testColl | Should -Not -BeNullOrEmpty

            $includeData = $script:TestAddRuleData.IncludeByCollectionName
            $includeCollectionId = $includeData.IncludeCollectionId

            # Act
            $result = Add-CM7CollectionMembershipRule -CollectionName $testColl.Name -RuleType Include -IncludeCollectionId $includeCollectionId

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.RuleType | Should -Be 'Include'
            $result.IncludeCollectionId | Should -Be $includeCollectionId
            $result.Status | Should -Be 'Added'
            $result.CollectionId | Should -Be $testColl.CollectionId
        }

        It "Should add an include membership rule by IncludeCollectionName" {
            # Arrange - Create a test collection
            $testColl = New-TestCollectionForRules -NamePrefix "Test-AddRule-InclByName"
            $testColl | Should -Not -BeNullOrEmpty

            $includeData = $script:TestAddRuleData.IncludeByCollectionName
            $includeCollectionName = $includeData.IncludeCollectionName

            # Act
            $result = Add-CM7CollectionMembershipRule -CollectionName $testColl.Name -RuleType Include -IncludeCollectionName $includeCollectionName

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.RuleType | Should -Be 'Include'
            $result.IncludeCollectionName | Should -Be $includeCollectionName
            $result.Status | Should -Be 'Added'
        }

        It "Should verify include rule is visible via Get-CM7CollectionIncludeMembershipRule" {
            # Arrange - Create a test collection and add an include rule
            $testColl = New-TestCollectionForRules -NamePrefix "Test-AddRule-InclVerify"
            $testColl | Should -Not -BeNullOrEmpty

            $includeData = $script:TestAddRuleData.IncludeByCollectionName
            $includeCollectionId = $includeData.IncludeCollectionId

            # Act - Add the rule
            $addResult = Add-CM7CollectionMembershipRule -CollectionName $testColl.Name -RuleType Include -IncludeCollectionId $includeCollectionId
            $addResult | Should -Not -BeNullOrEmpty

            # Verify - Read it back
            $rules = Get-CM7CollectionIncludeMembershipRule -CollectionId $testColl.CollectionId
            $rules | Should -Not -BeNullOrEmpty
            $matchingRule = $rules | Where-Object { $_.IncludeCollectionId -eq $includeCollectionId }
            $matchingRule | Should -Not -BeNullOrEmpty
        }
    }

    Context "Add Exclude Membership Rule" {

        It "Should add an exclude membership rule by collection name and ExcludeCollectionId" {
            # Arrange - Create a test collection
            $testColl = New-TestCollectionForRules -NamePrefix "Test-AddRule-Exclude"
            $testColl | Should -Not -BeNullOrEmpty

            $excludeData = $script:TestAddRuleData.ExcludeByCollectionName
            $excludeCollectionId = $excludeData.ExcludeCollectionId

            # Act
            $result = Add-CM7CollectionMembershipRule -CollectionName $testColl.Name -RuleType Exclude -ExcludeCollectionId $excludeCollectionId

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.RuleType | Should -Be 'Exclude'
            $result.ExcludeCollectionId | Should -Be $excludeCollectionId
            $result.Status | Should -Be 'Added'
            $result.CollectionId | Should -Be $testColl.CollectionId
        }

        It "Should add an exclude membership rule by ExcludeCollectionName" {
            # Arrange - Create a test collection
            $testColl = New-TestCollectionForRules -NamePrefix "Test-AddRule-ExclByName"
            $testColl | Should -Not -BeNullOrEmpty

            $excludeData = $script:TestAddRuleData.ExcludeByCollectionName
            $excludeCollectionName = $excludeData.ExcludeCollectionName

            # Act
            $result = Add-CM7CollectionMembershipRule -CollectionName $testColl.Name -RuleType Exclude -ExcludeCollectionName $excludeCollectionName

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.RuleType | Should -Be 'Exclude'
            $result.ExcludeCollectionName | Should -Be $excludeCollectionName
            $result.Status | Should -Be 'Added'
        }

        It "Should verify exclude rule is visible via Get-CM7CollectionExcludeMembershipRule" {
            # Arrange - Create a test collection and add an exclude rule
            $testColl = New-TestCollectionForRules -NamePrefix "Test-AddRule-ExclVerify"
            $testColl | Should -Not -BeNullOrEmpty

            $excludeData = $script:TestAddRuleData.ExcludeByCollectionName
            $excludeCollectionId = $excludeData.ExcludeCollectionId

            # Act - Add the rule
            $addResult = Add-CM7CollectionMembershipRule -CollectionName $testColl.Name -RuleType Exclude -ExcludeCollectionId $excludeCollectionId
            $addResult | Should -Not -BeNullOrEmpty

            # Verify - Read it back
            $rules = Get-CM7CollectionExcludeMembershipRule -CollectionId $testColl.CollectionId
            $rules | Should -Not -BeNullOrEmpty
            $matchingRule = $rules | Where-Object { $_.ExcludeCollectionId -eq $excludeCollectionId }
            $matchingRule | Should -Not -BeNullOrEmpty
        }
    }

    Context "Error Handling" {

        It "Should throw for non-existent collection name" {
            { Add-CM7CollectionMembershipRule -CollectionName "NonExistent-Collection-999" -RuleType Direct -ResourceId 1 } | Should -Throw "*not found*"
        }

        It "Should throw for non-existent collection ID" {
            { Add-CM7CollectionMembershipRule -CollectionId "XXX99999" -RuleType Direct -ResourceId 1 } | Should -Throw "*not found*"
        }

        It "Should throw for non-existent include collection ID" {
            # Arrange - Create a test collection
            $testColl = New-TestCollectionForRules -NamePrefix "Test-AddRule-ErrIncl"
            $testColl | Should -Not -BeNullOrEmpty

            # Act & Assert
            { Add-CM7CollectionMembershipRule -CollectionName $testColl.Name -RuleType Include -IncludeCollectionId "XXX99999" } | Should -Throw "*not found*"
        }

        It "Should throw for non-existent include collection name" {
            # Arrange
            $testColl = New-TestCollectionForRules -NamePrefix "Test-AddRule-ErrInclName"
            $testColl | Should -Not -BeNullOrEmpty

            # Act & Assert
            { Add-CM7CollectionMembershipRule -CollectionName $testColl.Name -RuleType Include -IncludeCollectionName "NonExistent-Collection-999" } | Should -Throw "*not found*"
        }

        It "Should throw for non-existent exclude collection ID" {
            # Arrange
            $testColl = New-TestCollectionForRules -NamePrefix "Test-AddRule-ErrExcl"
            $testColl | Should -Not -BeNullOrEmpty

            # Act & Assert
            { Add-CM7CollectionMembershipRule -CollectionName $testColl.Name -RuleType Exclude -ExcludeCollectionId "XXX99999" } | Should -Throw "*not found*"
        }

        It "Should throw for non-existent exclude collection name" {
            # Arrange
            $testColl = New-TestCollectionForRules -NamePrefix "Test-AddRule-ErrExclName"
            $testColl | Should -Not -BeNullOrEmpty

            # Act & Assert
            { Add-CM7CollectionMembershipRule -CollectionName $testColl.Name -RuleType Exclude -ExcludeCollectionName "NonExistent-Collection-999" } | Should -Throw "*not found*"
        }

        It "Should warn for non-existent resource ID in Direct rule" {
            # Arrange
            $testColl = New-TestCollectionForRules -NamePrefix "Test-AddRule-ErrDirect"
            $testColl | Should -Not -BeNullOrEmpty

            # Act - Should warn but not throw
            $result = Add-CM7CollectionMembershipRule -CollectionName $testColl.Name -RuleType Direct -ResourceId 99999999 -WarningAction SilentlyContinue

            # Assert - no result returned because resource was not found
            $result | Should -BeNullOrEmpty
        }
    }

    Context "WhatIf Support" {

        It "Should support -WhatIf for Direct rule" {
            # Arrange - Create a test collection
            $testColl = New-TestCollectionForRules -NamePrefix "Test-AddRule-WhatIfDirect"
            $testColl | Should -Not -BeNullOrEmpty

            $resourceId = $script:TestAddRuleData.DirectByCollectionNameAndResourceId.ResourceId

            # Act & Assert - should not throw, and should not actually add
            { Add-CM7CollectionMembershipRule -CollectionName $testColl.Name -RuleType Direct -ResourceId $resourceId -WhatIf } | Should -Not -Throw
        }

        It "Should support -WhatIf for Query rule" {
            # Arrange
            $testColl = New-TestCollectionForRules -NamePrefix "Test-AddRule-WhatIfQuery"
            $testColl | Should -Not -BeNullOrEmpty

            # Act & Assert
            { Add-CM7CollectionMembershipRule -CollectionName $testColl.Name -RuleType Query -RuleName "WhatIf-Test" -QueryExpression "select * from SMS_R_System" -WhatIf } | Should -Not -Throw
        }

        It "Should support -WhatIf for Include rule" {
            # Arrange
            $testColl = New-TestCollectionForRules -NamePrefix "Test-AddRule-WhatIfIncl"
            $testColl | Should -Not -BeNullOrEmpty

            $includeId = $script:TestAddRuleData.IncludeByCollectionName.IncludeCollectionId

            # Act & Assert
            { Add-CM7CollectionMembershipRule -CollectionName $testColl.Name -RuleType Include -IncludeCollectionId $includeId -WhatIf } | Should -Not -Throw
        }

        It "Should support -WhatIf for Exclude rule" {
            # Arrange
            $testColl = New-TestCollectionForRules -NamePrefix "Test-AddRule-WhatIfExcl"
            $testColl | Should -Not -BeNullOrEmpty

            $excludeId = $script:TestAddRuleData.ExcludeByCollectionName.ExcludeCollectionId

            # Act & Assert
            { Add-CM7CollectionMembershipRule -CollectionName $testColl.Name -RuleType Exclude -ExcludeCollectionId $excludeId -WhatIf } | Should -Not -Throw
        }
    }
}

AfterAll {
    # Clean up any test collections that were created
    if ($script:CreatedCollectionIds.Count -gt 0) {
        Write-Host "`n=== Cleaning up test collections ===" -ForegroundColor Cyan
        foreach ($collId in $script:CreatedCollectionIds) {
            try {
                Remove-CM7Collection -CollectionId $collId -Force -ErrorAction SilentlyContinue | Out-Null
                Write-Host "  Removed: $collId" -ForegroundColor Gray
            }
            catch {
                Write-Warning "  Failed to remove collection $collId : $_"
            }
        }
        Write-Host "=== Cleanup complete ===" -ForegroundColor Cyan
    }
}
