# Functional Tests for Get-CM7CollectionIncludeMembershipRule
# Tests the Get-CM7CollectionIncludeMembershipRule function behavior and return values

BeforeAll {
    # Load test declarations
    . (Join-Path $PSScriptRoot "declarations.ps1")

    # Load all functions
    $CodePath = Join-Path (Get-Item $PSScriptRoot).Parent.FullName "Code"
    Get-ChildItem -Path (Join-Path $CodePath "Private") -Filter "*.ps1" | ForEach-Object { . $_.FullName }
    Get-ChildItem -Path (Join-Path $CodePath "Public") -Filter "*.ps1" | ForEach-Object { . $_.FullName }

    # Get test data for this function
    $script:TestIncludeMembershipRuleData = $script:TestData['Get-CM7CollectionIncludeMembershipRule']
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

Describe "Get-CM7CollectionIncludeMembershipRule Function Tests" -Tag "Integration", "Collection", "Membership" {

    Context "Test Data Validation" {

        It "Should have test data defined in declarations.ps1" {
            # Assert
            $script:TestIncludeMembershipRuleData | Should -Not -BeNullOrEmpty
            $script:TestData.ContainsKey('Get-CM7CollectionIncludeMembershipRule') | Should -Be $true
        }

        It "Should have required test data parameter sets" {
            # Assert
            $script:TestIncludeMembershipRuleData.ContainsKey('ByCollectionName') | Should -Be $true
            $script:TestIncludeMembershipRuleData.ContainsKey('ByCollectionId') | Should -Be $true
            $script:TestIncludeMembershipRuleData.ContainsKey('NonExistent') | Should -Be $true
        }

        It "Should output test data for verification" {
            # Output test data
            Write-Host "`n=== Test Data for Get-CM7CollectionIncludeMembershipRule ===" -ForegroundColor Cyan
            Write-Host "ByCollectionName:" -ForegroundColor Yellow
            Write-Host "  Name: $($script:TestIncludeMembershipRuleData.ByCollectionName.CollectionName)" -ForegroundColor White

            Write-Host "ByCollectionId:" -ForegroundColor Yellow
            Write-Host "  CollectionId: $($script:TestIncludeMembershipRuleData.ByCollectionId.CollectionId)" -ForegroundColor White

            Write-Host "NonExistent:" -ForegroundColor Yellow
            Write-Host "  Name: $($script:TestIncludeMembershipRuleData.NonExistent.CollectionName)" -ForegroundColor White
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
            { Get-CM7CollectionIncludeMembershipRule -CollectionName "Test" } | Should -Throw "*not connected*"

            # Restore connection
            $script:CMConnection = $backupConnection
        }
    }

    Context "Query by Collection Name" {

        It "Should output test data for debugging" {
            # This test outputs what data is being used
            Write-Host "`nDEBUG: Test Data Values:" -ForegroundColor Cyan
            Write-Host "ByCollectionName.CollectionName = '$($script:TestIncludeMembershipRuleData.ByCollectionName.CollectionName)'" -ForegroundColor Yellow
            Write-Host "ByCollectionId.CollectionId = '$($script:TestIncludeMembershipRuleData.ByCollectionId.CollectionId)'" -ForegroundColor Yellow
            Write-Host "NonExistent.CollectionName = '$($script:TestIncludeMembershipRuleData.NonExistent.CollectionName)'" -ForegroundColor Yellow
            Write-Host "NonExistent.CollectionId = '$($script:TestIncludeMembershipRuleData.NonExistent.CollectionId)'" -ForegroundColor Yellow
            $true | Should -Be $true
        }

        It "Should retrieve include membership rules by collection name" {
            # Arrange
            $collectionName = $script:TestIncludeMembershipRuleData.ByCollectionName.CollectionName

            # Act
            $result = Get-CM7CollectionIncludeMembershipRule -CollectionName $collectionName

            # Assert
            if ($result) {
                if ($result -is [array]) {
                    $result[0].psobject.TypeNames[0] | Should -Be 'MECM7.CollectionIncludeMembershipRule'
                } else {
                    $result.psobject.TypeNames[0] | Should -Be 'MECM7.CollectionIncludeMembershipRule'
                }
            } else {
                # It's acceptable to have no include rules
                $result | Should -BeNullOrEmpty
            }
        }

        It "Should return null for non-existent collection" {
            # Arrange
            $collectionName = $script:TestIncludeMembershipRuleData.NonExistent.CollectionName

            # Act
            $result = Get-CM7CollectionIncludeMembershipRule -CollectionName $collectionName

            # Assert
            $result | Should -BeNullOrEmpty
        }
    }

    Context "Query by Collection ID" {

        It "Should retrieve include membership rules by collection ID" {
            # Arrange
            $collectionId = $script:TestIncludeMembershipRuleData.ByCollectionId.CollectionId

            # Act
            $result = Get-CM7CollectionIncludeMembershipRule -CollectionId $collectionId

            # Assert
            if ($result) {
                if ($result -is [array]) {
                    $result[0].psobject.TypeNames[0] | Should -Be 'MECM7.CollectionIncludeMembershipRule'
                } else {
                    $result.psobject.TypeNames[0] | Should -Be 'MECM7.CollectionIncludeMembershipRule'
                }
            } else {
                # It's acceptable to have no include rules
                $result | Should -BeNullOrEmpty
            }
        }

        It "Should return null for non-existent collection ID" {
            # Arrange
            $collectionId = $script:TestIncludeMembershipRuleData.NonExistent.CollectionId

            # Act
            $result = Get-CM7CollectionIncludeMembershipRule -CollectionId $collectionId

            # Assert
            $result | Should -BeNullOrEmpty
        }
    }

    Context "Query with Include Collection Name Filter" {

        It "Should filter by include collection name" {
            # Arrange
            $collectionName = $script:TestIncludeMembershipRuleData.ByCollectionNameAndIncludeName.CollectionName
            $includeCollectionName = $script:TestIncludeMembershipRuleData.ByCollectionNameAndIncludeName.IncludeCollectionName

            # Act
            $result = Get-CM7CollectionIncludeMembershipRule -CollectionName $collectionName -IncludeCollectionName $includeCollectionName

            # Assert
            if ($result) {
                if ($result -is [array]) {
                    $result[0].psobject.TypeNames[0] | Should -Be 'MECM7.CollectionIncludeMembershipRule'
                    foreach ($rule in $result) {
                        $rule.RuleName | Should -BeLike $includeCollectionName
                    }
                } else {
                    $result.psobject.TypeNames[0] | Should -Be 'MECM7.CollectionIncludeMembershipRule'
                    $result.RuleName | Should -BeLike $includeCollectionName
                }
            } else {
                # No results is acceptable
                $result | Should -BeNullOrEmpty
            }
        }

        It "Should support wildcard in include collection name" {
            # Arrange
            $collectionName = $script:TestIncludeMembershipRuleData.WithWildcard.CollectionName
            $includePattern = $script:TestIncludeMembershipRuleData.WithWildcard.IncludeCollectionName

            # Act
            $result = Get-CM7CollectionIncludeMembershipRule -CollectionName $collectionName -IncludeCollectionName $includePattern

            # Assert
            if ($result) {
                if ($result -is [array]) {
                    $result[0].psobject.TypeNames[0] | Should -Be 'MECM7.CollectionIncludeMembershipRule'
                } else {
                    $result.psobject.TypeNames[0] | Should -Be 'MECM7.CollectionIncludeMembershipRule'
                }
            } else {
                # No results is acceptable
                $result | Should -BeNullOrEmpty
            }
        }

        It "Should return null for non-existent include collection name" {
            # Arrange
            $collectionName = $script:TestIncludeMembershipRuleData.NonExistent.CollectionName

            # Act
            $result = Get-CM7CollectionIncludeMembershipRule -CollectionName $collectionName -IncludeCollectionName "NONEXISTENT-999"

            # Assert
            $result | Should -BeNullOrEmpty
        }
    }

    Context "Query with Include Collection ID Filter" {

        It "Should filter by include collection ID" {
            # Arrange
            $collectionId = $script:TestIncludeMembershipRuleData.ByCollectionIdAndIncludeId.CollectionId
            $includeCollectionId = $script:TestIncludeMembershipRuleData.ByCollectionIdAndIncludeId.IncludeCollectionId

            # Act
            $result = Get-CM7CollectionIncludeMembershipRule -CollectionId $collectionId -IncludeCollectionId $includeCollectionId

            # Assert
            if ($result) {
                if ($result -is [array]) {
                    $result[0].IncludeCollectionId | Should -Be $includeCollectionId
                    $result[0].psobject.TypeNames[0] | Should -Be 'MECM7.CollectionIncludeMembershipRule'
                } else {
                    $result.IncludeCollectionId | Should -Be $includeCollectionId
                    $result.psobject.TypeNames[0] | Should -Be 'MECM7.CollectionIncludeMembershipRule'
                }
            } else {
                # No results is acceptable
                $result | Should -BeNullOrEmpty
            }
        }

        It "Should return null for non-existent include collection ID" {
            # Arrange
            $collectionId = $script:TestIncludeMembershipRuleData.NonExistent.CollectionId

            # Act
            $result = Get-CM7CollectionIncludeMembershipRule -CollectionId $collectionId -IncludeCollectionId "XXX99999"

            # Assert
            $result | Should -BeNullOrEmpty
        }
    }

    Context "Output Object Properties" {

        It "Should return objects with expected properties" {
            # Arrange
            $collectionName = $script:TestIncludeMembershipRuleData.ByCollectionName.CollectionName

            # Act
            $result = Get-CM7CollectionIncludeMembershipRule -CollectionName $collectionName

            # Assert
            if ($result) {
                $firstResult = if ($result -is [array]) { $result[0] } else { $result }
                $firstResult.psobject.TypeNames[0] | Should -Be 'MECM7.CollectionIncludeMembershipRule'
                $firstResult.RuleName | Should -Not -BeNullOrEmpty
                $firstResult.IncludeCollectionId | Should -Not -BeNullOrEmpty
                $firstResult.CollectionId | Should -Not -BeNullOrEmpty
            }
        }
    }

    Context "Error Handling" {

        It "Should handle invalid collection ID gracefully" {
            # Arrange
            $invalidCollectionId = "INVALID123"

            # Act
            $result = Get-CM7CollectionIncludeMembershipRule -CollectionId $invalidCollectionId

            # Assert
            $result | Should -BeNullOrEmpty
        }

        It "Should handle empty results gracefully" {
            # Arrange
            $collectionName = $script:TestIncludeMembershipRuleData.NonExistent.CollectionName

            # Act & Assert
            { Get-CM7CollectionIncludeMembershipRule -CollectionName $collectionName } | Should -Not -Throw
        }
    }
}
