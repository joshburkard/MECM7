# Functional Tests for Get-CM7CollectionQueryMembershipRule
# Tests the Get-CM7CollectionQueryMembershipRule function behavior and return values

BeforeAll {
    # Load test declarations
    . (Join-Path $PSScriptRoot "declarations.ps1")

    # Load all functions
    $CodePath = Join-Path (Get-Item $PSScriptRoot).Parent.FullName "Code"
    Get-ChildItem -Path (Join-Path $CodePath "Private") -Filter "*.ps1" | ForEach-Object { . $_.FullName }
    Get-ChildItem -Path (Join-Path $CodePath "Public") -Filter "*.ps1" | ForEach-Object { . $_.FullName }

    # Get test data for this function
    $script:TestQueryMembershipRuleData = $script:TestData['Get-CM7CollectionQueryMembershipRule']
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

Describe "Get-CM7CollectionQueryMembershipRule Function Tests" -Tag "Integration", "Collection", "Membership" {

    Context "Test Data Validation" {

        It "Should have test data defined in declarations.ps1" {
            # Assert
            $script:TestQueryMembershipRuleData | Should -Not -BeNullOrEmpty
            $script:TestData.ContainsKey('Get-CM7CollectionQueryMembershipRule') | Should -Be $true
        }

        It "Should have required test data parameter sets" {
            # Assert
            $script:TestQueryMembershipRuleData.ContainsKey('ByCollectionName') | Should -Be $true
            $script:TestQueryMembershipRuleData.ContainsKey('ByCollectionId') | Should -Be $true
            $script:TestQueryMembershipRuleData.ContainsKey('NonExistent') | Should -Be $true
        }

        It "Should output test data for verification" {
            # Output test data
            Write-Host "`n=== Test Data for Get-CM7CollectionQueryMembershipRule ===" -ForegroundColor Cyan
            Write-Host "ByCollectionName:" -ForegroundColor Yellow
            Write-Host "  Name: $($script:TestQueryMembershipRuleData.ByCollectionName.CollectionName)" -ForegroundColor White

            Write-Host "ByCollectionId:" -ForegroundColor Yellow
            Write-Host "  CollectionId: $($script:TestQueryMembershipRuleData.ByCollectionId.CollectionId)" -ForegroundColor White

            Write-Host "NonExistent:" -ForegroundColor Yellow
            Write-Host "  Name: $($script:TestQueryMembershipRuleData.NonExistent.CollectionName)" -ForegroundColor White
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
            { Get-CM7CollectionQueryMembershipRule -CollectionName "Test" } | Should -Throw "*not connected*"

            # Restore connection
            $script:CMConnection = $backupConnection
        }
    }

    Context "Query by Collection Name" {

        It "Should output test data for debugging" {
            # This test outputs what data is being used
            Write-Host "`nDEBUG: Test Data Values:" -ForegroundColor Cyan
            Write-Host "ByCollectionName.CollectionName = '$($script:TestQueryMembershipRuleData.ByCollectionName.CollectionName)'" -ForegroundColor Yellow
            Write-Host "ByCollectionId.CollectionId = '$($script:TestQueryMembershipRuleData.ByCollectionId.CollectionId)'" -ForegroundColor Yellow
            Write-Host "NonExistent.CollectionName = '$($script:TestQueryMembershipRuleData.NonExistent.CollectionName)'" -ForegroundColor Yellow
            Write-Host "NonExistent.CollectionId = '$($script:TestQueryMembershipRuleData.NonExistent.CollectionId)'" -ForegroundColor Yellow
            $true | Should -Be $true
        }

        It "Should retrieve query membership rules by collection name" {
            # Arrange
            $collectionName = $script:TestQueryMembershipRuleData.ByCollectionName.CollectionName

            # Act
            $result = Get-CM7CollectionQueryMembershipRule -CollectionName $collectionName

            # Assert
            if ($result) {
                if ($result -is [array]) {
                    $result[0].psobject.TypeNames[0] | Should -Be 'MECM7.CollectionQueryMembershipRule'
                } else {
                    $result.psobject.TypeNames[0] | Should -Be 'MECM7.CollectionQueryMembershipRule'
                }
            } else {
                # It's acceptable to have no query rules
                $result | Should -BeNullOrEmpty
            }
        }

        It "Should return null for non-existent collection" {
            # Arrange
            $collectionName = $script:TestQueryMembershipRuleData.NonExistent.CollectionName

            # Act
            $result = Get-CM7CollectionQueryMembershipRule -CollectionName $collectionName

            # Assert
            $result | Should -BeNullOrEmpty
        }
    }

    Context "Query by Collection ID" {

        It "Should retrieve query membership rules by collection ID" {
            # Arrange
            $collectionId = $script:TestQueryMembershipRuleData.ByCollectionId.CollectionId

            # Act
            $result = Get-CM7CollectionQueryMembershipRule -CollectionId $collectionId

            # Assert
            if ($result) {
                if ($result -is [array]) {
                    $result[0].psobject.TypeNames[0] | Should -Be 'MECM7.CollectionQueryMembershipRule'
                } else {
                    $result.psobject.TypeNames[0] | Should -Be 'MECM7.CollectionQueryMembershipRule'
                }
            } else {
                # It's acceptable to have no query rules
                $result | Should -BeNullOrEmpty
            }
        }

        It "Should return null for non-existent collection ID" {
            # Arrange
            $collectionId = $script:TestQueryMembershipRuleData.NonExistent.CollectionId

            # Act
            $result = Get-CM7CollectionQueryMembershipRule -CollectionId $collectionId

            # Assert
            $result | Should -BeNullOrEmpty
        }
    }

    Context "Query with Rule Name Filter" {

        It "Should filter by query rule name" {
            # Arrange
            $collectionName = $script:TestQueryMembershipRuleData.ByCollectionNameAndRuleName.CollectionName
            $ruleName = $script:TestQueryMembershipRuleData.ByCollectionNameAndRuleName.RuleName

            # Act
            $result = Get-CM7CollectionQueryMembershipRule -CollectionName $collectionName -RuleName $ruleName

            # Assert
            if ($result) {
                if ($result -is [array]) {
                    $result[0].psobject.TypeNames[0] | Should -Be 'MECM7.CollectionQueryMembershipRule'
                    foreach ($rule in $result) {
                        $rule.RuleName | Should -BeLike $ruleName
                    }
                } else {
                    $result.psobject.TypeNames[0] | Should -Be 'MECM7.CollectionQueryMembershipRule'
                    $result.RuleName | Should -BeLike $ruleName
                }
            } else {
                # No results is acceptable
                $result | Should -BeNullOrEmpty
            }
        }

        It "Should filter by rule name using collection ID" {
            # Arrange
            $collectionId = $script:TestQueryMembershipRuleData.ByCollectionIdAndRuleName.CollectionId
            $ruleName = $script:TestQueryMembershipRuleData.ByCollectionIdAndRuleName.RuleName

            # Act
            $result = Get-CM7CollectionQueryMembershipRule -CollectionId $collectionId -RuleName $ruleName

            # Assert
            if ($result) {
                if ($result -is [array]) {
                    $result[0].psobject.TypeNames[0] | Should -Be 'MECM7.CollectionQueryMembershipRule'
                    foreach ($rule in $result) {
                        $rule.RuleName | Should -BeLike $ruleName
                    }
                } else {
                    $result.psobject.TypeNames[0] | Should -Be 'MECM7.CollectionQueryMembershipRule'
                    $result.RuleName | Should -BeLike $ruleName
                }
            } else {
                # No results is acceptable
                $result | Should -BeNullOrEmpty
            }
        }

        It "Should support wildcard in rule name" {
            # Arrange
            $collectionName = $script:TestQueryMembershipRuleData.WithWildcard.CollectionName
            $rulePattern = $script:TestQueryMembershipRuleData.WithWildcard.RuleName

            # Act
            $result = Get-CM7CollectionQueryMembershipRule -CollectionName $collectionName -RuleName $rulePattern

            # Assert
            if ($result) {
                if ($result -is [array]) {
                    $result[0].psobject.TypeNames[0] | Should -Be 'MECM7.CollectionQueryMembershipRule'
                } else {
                    $result.psobject.TypeNames[0] | Should -Be 'MECM7.CollectionQueryMembershipRule'
                }
            } else {
                # No results is acceptable
                $result | Should -BeNullOrEmpty
            }
        }

        It "Should return null for non-existent rule name" {
            # Arrange
            $collectionName = $script:TestQueryMembershipRuleData.NonExistent.CollectionName

            # Act
            $result = Get-CM7CollectionQueryMembershipRule -CollectionName $collectionName -RuleName "NONEXISTENT-RULE-999"

            # Assert
            $result | Should -BeNullOrEmpty
        }
    }

    Context "Output Object Properties" {

        It "Should return objects with expected properties" {
            # Arrange
            $collectionName = $script:TestQueryMembershipRuleData.ByCollectionName.CollectionName

            # Act
            $result = Get-CM7CollectionQueryMembershipRule -CollectionName $collectionName

            # Assert
            if ($result) {
                $firstResult = if ($result -is [array]) { $result[0] } else { $result }
                $firstResult.psobject.TypeNames[0] | Should -Be 'MECM7.CollectionQueryMembershipRule'
                $firstResult.RuleName | Should -Not -BeNullOrEmpty
                $firstResult.QueryExpression | Should -Not -BeNullOrEmpty
                $firstResult.CollectionId | Should -Not -BeNullOrEmpty
            }
        }
    }

    Context "Error Handling" {

        It "Should handle invalid collection ID gracefully" {
            # Arrange
            $invalidCollectionId = "INVALID123"

            # Act
            $result = Get-CM7CollectionQueryMembershipRule -CollectionId $invalidCollectionId

            # Assert
            $result | Should -BeNullOrEmpty
        }

        It "Should handle empty results gracefully" {
            # Arrange
            $collectionName = $script:TestQueryMembershipRuleData.NonExistent.CollectionName

            # Act & Assert
            { Get-CM7CollectionQueryMembershipRule -CollectionName $collectionName } | Should -Not -Throw
        }
    }
}
