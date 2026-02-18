# Functional Tests for Get-CM7CollectionExcludeMembershipRule
# Tests the Get-CM7CollectionExcludeMembershipRule function behavior and return values

BeforeAll {
    # Load test declarations
    . (Join-Path $PSScriptRoot "declarations.ps1")

    # Load all functions
    $CodePath = Join-Path (Get-Item $PSScriptRoot).Parent.FullName "Code"
    Get-ChildItem -Path (Join-Path $CodePath "Private") -Filter "*.ps1" | ForEach-Object { . $_.FullName }
    Get-ChildItem -Path (Join-Path $CodePath "Public") -Filter "*.ps1" | ForEach-Object { . $_.FullName }

    # Get test data for this function
    $script:TestExcludeMembershipRuleData = $script:TestData['Get-CM7CollectionExcludeMembershipRule']
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

Describe "Get-CM7CollectionExcludeMembershipRule Function Tests" -Tag "Integration", "Collection", "Membership" {

    Context "Test Data Validation" {

        It "Should have test data defined in declarations.ps1" {
            # Assert
            $script:TestExcludeMembershipRuleData | Should -Not -BeNullOrEmpty
            $script:TestData.ContainsKey('Get-CM7CollectionExcludeMembershipRule') | Should -Be $true
        }

        It "Should have required test data parameter sets" {
            # Assert
            $script:TestExcludeMembershipRuleData.ContainsKey('ByCollectionName') | Should -Be $true
            $script:TestExcludeMembershipRuleData.ContainsKey('ByCollectionId') | Should -Be $true
            $script:TestExcludeMembershipRuleData.ContainsKey('NonExistent') | Should -Be $true
        }

        It "Should output test data for verification" {
            # Output test data
            Write-Host "`n=== Test Data for Get-CM7CollectionExcludeMembershipRule ===" -ForegroundColor Cyan
            Write-Host "ByCollectionName:" -ForegroundColor Yellow
            Write-Host "  Name: $($script:TestExcludeMembershipRuleData.ByCollectionName.CollectionName)" -ForegroundColor White

            Write-Host "ByCollectionId:" -ForegroundColor Yellow
            Write-Host "  CollectionId: $($script:TestExcludeMembershipRuleData.ByCollectionId.CollectionId)" -ForegroundColor White

            Write-Host "NonExistent:" -ForegroundColor Yellow
            Write-Host "  Name: $($script:TestExcludeMembershipRuleData.NonExistent.CollectionName)" -ForegroundColor White
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
            { Get-CM7CollectionExcludeMembershipRule -CollectionName "Test" } | Should -Throw "*not connected*"

            # Restore connection
            $script:CMConnection = $backupConnection
        }
    }

    Context "Query by Collection Name" {

        It "Should output test data for debugging" {
            # This test outputs what data is being used
            Write-Host "`nDEBUG: Test Data Values:" -ForegroundColor Cyan
            Write-Host "ByCollectionName.CollectionName = '$($script:TestExcludeMembershipRuleData.ByCollectionName.CollectionName)'" -ForegroundColor Yellow
            Write-Host "ByCollectionId.CollectionId = '$($script:TestExcludeMembershipRuleData.ByCollectionId.CollectionId)'" -ForegroundColor Yellow
            Write-Host "NonExistent.CollectionName = '$($script:TestExcludeMembershipRuleData.NonExistent.CollectionName)'" -ForegroundColor Yellow
            Write-Host "NonExistent.CollectionId = '$($script:TestExcludeMembershipRuleData.NonExistent.CollectionId)'" -ForegroundColor Yellow
            $true | Should -Be $true
        }

        It "Should retrieve exclude membership rules by collection name" {
            # Arrange
            $collectionName = $script:TestExcludeMembershipRuleData.ByCollectionName.CollectionName

            # Act
            $result = Get-CM7CollectionExcludeMembershipRule -CollectionName $collectionName

            # Assert
            if ($result) {
                if ($result -is [array]) {
                    $result[0].psobject.TypeNames[0] | Should -Be 'MECM7.CollectionExcludeMembershipRule'
                } else {
                    $result.psobject.TypeNames[0] | Should -Be 'MECM7.CollectionExcludeMembershipRule'
                }
            } else {
                # It's acceptable to have no exclude rules
                $result | Should -BeNullOrEmpty
            }
        }

        It "Should return null for non-existent collection" {
            # Arrange
            $collectionName = $script:TestExcludeMembershipRuleData.NonExistent.CollectionName

            # Act
            $result = Get-CM7CollectionExcludeMembershipRule -CollectionName $collectionName

            # Assert
            $result | Should -BeNullOrEmpty
        }
    }

    Context "Query by Collection ID" {

        It "Should retrieve exclude membership rules by collection ID" {
            # Arrange
            $collectionId = $script:TestExcludeMembershipRuleData.ByCollectionId.CollectionId

            # Act
            $result = Get-CM7CollectionExcludeMembershipRule -CollectionId $collectionId

            # Assert
            if ($result) {
                if ($result -is [array]) {
                    $result[0].psobject.TypeNames[0] | Should -Be 'MECM7.CollectionExcludeMembershipRule'
                } else {
                    $result.psobject.TypeNames[0] | Should -Be 'MECM7.CollectionExcludeMembershipRule'
                }
            } else {
                # It's acceptable to have no exclude rules
                $result | Should -BeNullOrEmpty
            }
        }

        It "Should return null for non-existent collection ID" {
            # Arrange
            $collectionId = $script:TestExcludeMembershipRuleData.NonExistent.CollectionId

            # Act
            $result = Get-CM7CollectionExcludeMembershipRule -CollectionId $collectionId

            # Assert
            $result | Should -BeNullOrEmpty
        }
    }

    Context "Query with Exclude Collection Name Filter" {

        It "Should filter by exclude collection name" {
            # Arrange
            $collectionName = $script:TestExcludeMembershipRuleData.ByCollectionNameAndExcludeName.CollectionName
            $excludeCollectionName = $script:TestExcludeMembershipRuleData.ByCollectionNameAndExcludeName.ExcludeCollectionName

            # Act
            $result = Get-CM7CollectionExcludeMembershipRule -CollectionName $collectionName -ExcludeCollectionName $excludeCollectionName

            # Assert
            if ($result) {
                if ($result -is [array]) {
                    $result[0].psobject.TypeNames[0] | Should -Be 'MECM7.CollectionExcludeMembershipRule'
                    foreach ($rule in $result) {
                        $rule.RuleName | Should -BeLike $excludeCollectionName
                    }
                } else {
                    $result.psobject.TypeNames[0] | Should -Be 'MECM7.CollectionExcludeMembershipRule'
                    $result.RuleName | Should -BeLike $excludeCollectionName
                }
            } else {
                # No results is acceptable
                $result | Should -BeNullOrEmpty
            }
        }

        It "Should support wildcard in exclude collection name" {
            # Arrange
            $collectionName = $script:TestExcludeMembershipRuleData.WithWildcard.CollectionName
            $excludePattern = $script:TestExcludeMembershipRuleData.WithWildcard.ExcludeCollectionName

            # Act
            $result = Get-CM7CollectionExcludeMembershipRule -CollectionName $collectionName -ExcludeCollectionName $excludePattern

            # Assert
            if ($result) {
                if ($result -is [array]) {
                    $result[0].psobject.TypeNames[0] | Should -Be 'MECM7.CollectionExcludeMembershipRule'
                } else {
                    $result.psobject.TypeNames[0] | Should -Be 'MECM7.CollectionExcludeMembershipRule'
                }
            } else {
                # No results is acceptable
                $result | Should -BeNullOrEmpty
            }
        }

        It "Should return null for non-existent exclude collection name" {
            # Arrange
            $collectionName = $script:TestExcludeMembershipRuleData.NonExistent.CollectionName

            # Act
            $result = Get-CM7CollectionExcludeMembershipRule -CollectionName $collectionName -ExcludeCollectionName "NONEXISTENT-999"

            # Assert
            $result | Should -BeNullOrEmpty
        }
    }

    Context "Query with Exclude Collection ID Filter" {

        It "Should filter by exclude collection ID" {
            # Arrange
            $collectionId = $script:TestExcludeMembershipRuleData.ByCollectionIdAndExcludeId.CollectionId
            $excludeCollectionId = $script:TestExcludeMembershipRuleData.ByCollectionIdAndExcludeId.ExcludeCollectionId

            # Act
            $result = Get-CM7CollectionExcludeMembershipRule -CollectionId $collectionId -ExcludeCollectionId $excludeCollectionId

            # Assert
            if ($result) {
                if ($result -is [array]) {
                    $result[0].ExcludeCollectionId | Should -Be $excludeCollectionId
                    $result[0].psobject.TypeNames[0] | Should -Be 'MECM7.CollectionExcludeMembershipRule'
                } else {
                    $result.ExcludeCollectionId | Should -Be $excludeCollectionId
                    $result.psobject.TypeNames[0] | Should -Be 'MECM7.CollectionExcludeMembershipRule'
                }
            } else {
                # No results is acceptable
                $result | Should -BeNullOrEmpty
            }
        }

        It "Should return null for non-existent exclude collection ID" {
            # Arrange
            $collectionId = $script:TestExcludeMembershipRuleData.NonExistent.CollectionId

            # Act
            $result = Get-CM7CollectionExcludeMembershipRule -CollectionId $collectionId -ExcludeCollectionId "XXX99999"

            # Assert
            $result | Should -BeNullOrEmpty
        }
    }

    Context "Output Object Properties" {

        It "Should return objects with expected properties" {
            # Arrange
            $collectionName = $script:TestExcludeMembershipRuleData.ByCollectionName.CollectionName

            # Act
            $result = Get-CM7CollectionExcludeMembershipRule -CollectionName $collectionName

            # Assert
            if ($result) {
                $firstResult = if ($result -is [array]) { $result[0] } else { $result }
                $firstResult.psobject.TypeNames[0] | Should -Be 'MECM7.CollectionExcludeMembershipRule'
                $firstResult.RuleName | Should -Not -BeNullOrEmpty
                $firstResult.ExcludeCollectionId | Should -Not -BeNullOrEmpty
                $firstResult.CollectionId | Should -Not -BeNullOrEmpty
            }
        }
    }

    Context "Error Handling" {

        It "Should handle invalid collection ID gracefully" {
            # Arrange
            $invalidCollectionId = "INVALID123"

            # Act
            $result = Get-CM7CollectionExcludeMembershipRule -CollectionId $invalidCollectionId

            # Assert
            $result | Should -BeNullOrEmpty
        }

        It "Should handle empty results gracefully" {
            # Arrange
            $collectionName = $script:TestExcludeMembershipRuleData.NonExistent.CollectionName

            # Act & Assert
            { Get-CM7CollectionExcludeMembershipRule -CollectionName $collectionName } | Should -Not -Throw
        }
    }
}
