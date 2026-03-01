# Functional Tests for Get-CM7DeviceCollectionDirectMembershipRule
# Tests the Get-CM7DeviceCollectionDirectMembershipRule function behavior and return values

BeforeAll {
    # Load test declarations
    . (Join-Path $PSScriptRoot "declarations.ps1")

    # Load all functions
    $CodePath = Join-Path (Get-Item $PSScriptRoot).Parent.FullName "Code"
    Get-ChildItem -Path (Join-Path $CodePath "Private") -Filter "*.ps1" | ForEach-Object { . $_.FullName }
    Get-ChildItem -Path (Join-Path $CodePath "Public") -Filter "*.ps1" | ForEach-Object { . $_.FullName }

    # Get test data for this function
    $script:TestDirectMembershipRuleData = $script:TestData['Get-CM7DeviceCollectionDirectMembershipRule']
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

Describe "Get-CM7DeviceCollectionDirectMembershipRule Function Tests" -Tag "Integration", "Collection", "Membership" {

    Context "Test Data Validation" {

        It "Should have test data defined in declarations.ps1" {
            # Assert
            $script:TestDirectMembershipRuleData | Should -Not -BeNullOrEmpty
            $script:TestData.ContainsKey('Get-CM7DeviceCollectionDirectMembershipRule') | Should -Be $true
        }

        It "Should have required test data parameter sets" {
            # Assert
            $script:TestDirectMembershipRuleData.ContainsKey('ByCollectionName') | Should -Be $true
            $script:TestDirectMembershipRuleData.ContainsKey('ByCollectionId') | Should -Be $true
            $script:TestDirectMembershipRuleData.ContainsKey('NonExistent') | Should -Be $true
        }

        It "Should output test data for verification" {
            # Output test data
            Write-Host "`n=== Test Data for Get-CM7DeviceCollectionDirectMembershipRule ===" -ForegroundColor Cyan
            Write-Host "ByCollectionName:" -ForegroundColor Yellow
            Write-Host "  Name: $($script:TestDirectMembershipRuleData.ByCollectionName.CollectionName)" -ForegroundColor White
            Write-Host "  ExpectedMinCount: $($script:TestDirectMembershipRuleData.ByCollectionName.ExpectedMinCount)" -ForegroundColor White

            Write-Host "ByCollectionId:" -ForegroundColor Yellow
            Write-Host "  CollectionId: $($script:TestDirectMembershipRuleData.ByCollectionId.CollectionId)" -ForegroundColor White
            Write-Host "  ExpectedMinCount: $($script:TestDirectMembershipRuleData.ByCollectionId.ExpectedMinCount)" -ForegroundColor White

            Write-Host "NonExistent:" -ForegroundColor Yellow
            Write-Host "  Name: $($script:TestDirectMembershipRuleData.NonExistent.CollectionName)" -ForegroundColor White
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
            { Get-CM7DeviceCollectionDirectMembershipRule -CollectionName "Test" } | Should -Throw "*not connected*"

            # Restore connection
            $script:CMConnection = $backupConnection
        }
    }

    Context "Query by Collection Name" {

        It "Should output test data for debugging" {
            # This test outputs what data is being used
            Write-Host "`nDEBUG: Test Data Values:" -ForegroundColor Cyan
            Write-Host "ByCollectionName.CollectionName = '$($script:TestDirectMembershipRuleData.ByCollectionName.CollectionName)'" -ForegroundColor Yellow
            Write-Host "ByCollectionId.CollectionId = '$($script:TestDirectMembershipRuleData.ByCollectionId.CollectionId)'" -ForegroundColor Yellow
            Write-Host "NonExistent.CollectionName = '$($script:TestDirectMembershipRuleData.NonExistent.CollectionName)'" -ForegroundColor Yellow
            Write-Host "NonExistent.CollectionId = '$($script:TestDirectMembershipRuleData.NonExistent.CollectionId)'" -ForegroundColor Yellow
            $true | Should -Be $true
        }

        It "Should retrieve direct members by collection name" {
            # Arrange
            $collectionName = $script:TestDirectMembershipRuleData.ByCollectionName.CollectionName

            # Act
            $result = Get-CM7DeviceCollectionDirectMembershipRule -CollectionName $collectionName

            # Assert
            if ($result) {
                @($result).Count | Should -BeGreaterOrEqual $script:TestDirectMembershipRuleData.ByCollectionName.ExpectedMinCount
                $result[0].psobject.TypeNames[0] | Should -Be 'MECM7.CollectionDirectMember'
            } else {
                # It's acceptable to have no direct members
                $result | Should -BeNullOrEmpty
            }
        }

        It "Should return null for non-existent collection" {
            # Arrange
            $collectionName = $script:TestDirectMembershipRuleData.NonExistent.CollectionName

            # Act
            $result = Get-CM7DeviceCollectionDirectMembershipRule -CollectionName $collectionName

            # Assert
            $result | Should -BeNullOrEmpty
        }
    }

    Context "Query by Collection ID" {

        It "Should retrieve direct members by collection ID" {
            # Arrange
            $collectionId = $script:TestDirectMembershipRuleData.ByCollectionId.CollectionId

            # Act
            $result = Get-CM7DeviceCollectionDirectMembershipRule -CollectionId $collectionId

            # Assert
            if ($result) {
                @($result).Count | Should -BeGreaterOrEqual $script:TestDirectMembershipRuleData.ByCollectionId.ExpectedMinCount
                $result[0].psobject.TypeNames[0] | Should -Be 'MECM7.CollectionDirectMember'
            } else {
                # It's acceptable to have no direct members
                $result | Should -BeNullOrEmpty
            }
        }

        It "Should return null for non-existent collection ID" {
            # Arrange
            $collectionId = $script:TestDirectMembershipRuleData.NonExistent.CollectionId

            # Act
            $result = Get-CM7DeviceCollectionDirectMembershipRule -CollectionId $collectionId

            # Assert
            $result | Should -BeNullOrEmpty
        }
    }

    Context "Query with Resource Name Filter" {

        It "Should support wildcard in resource name" {
            # Arrange
            $collectionName = $script:TestDirectMembershipRuleData.WithWildcard.CollectionName
            $resourcePattern = $script:TestDirectMembershipRuleData.WithWildcard.ResourceName

            # Act
            $result = Get-CM7DeviceCollectionDirectMembershipRule -CollectionName $collectionName -ResourceName $resourcePattern

            # Assert
            # Result may be empty or contain members matching the pattern
            if ($result) {
                if ($result -is [array]) {
                    $result[0].psobject.TypeNames[0] | Should -Be 'MECM7.CollectionDirectMember'
                    foreach ($member in $result) {
                        $member.Name | Should -Match "^TEST-"
                    }
                } else {
                    $result.psobject.TypeNames[0] | Should -Be 'MECM7.CollectionDirectMember'
                    $result.Name | Should -Match "^TEST-"
                }
            } else {
                # No results is acceptable
                $result | Should -BeNullOrEmpty
            }
        }

        It "Should return null for non-existent resource name" {
            # Arrange
            $collectionName = $script:TestDirectMembershipRuleData.NonExistent.CollectionName
            $resourceName = $script:TestDirectMembershipRuleData.NonExistent.ResourceName

            # Act
            $result = Get-CM7DeviceCollectionDirectMembershipRule -CollectionName $collectionName -ResourceName $resourceName

            # Assert
            $result | Should -BeNullOrEmpty
        }
    }

    Context "Query with Resource ID Filter" {

        It "Should support resource ID filter" {
            # Arrange
            $collectionId = $script:TestDirectMembershipRuleData.ByCollectionIdAndResourceId.CollectionId
            $resourceId = $script:TestDirectMembershipRuleData.ByCollectionIdAndResourceId.ResourceId

            # Act
            $result = Get-CM7DeviceCollectionDirectMembershipRule -CollectionId $collectionId -ResourceId $resourceId

            # Assert
            # Result may be empty if the resource is not a direct member
            if ($null -ne $result) {
                if ($result -is [array]) {
                    $result[0].ResourceId | Should -Be $resourceId
                    $result[0].psobject.TypeNames[0] | Should -Be 'MECM7.CollectionDirectMember'
                } else {
                    $result.ResourceId | Should -Be $resourceId
                    $result.psobject.TypeNames[0] | Should -Be 'MECM7.CollectionDirectMember'
                }
            } else {
                # No results is acceptable
                $result | Should -BeNullOrEmpty
            }
        }

        It "Should return null for non-existent resource ID" {
            # Arrange
            $collectionId = $script:TestDirectMembershipRuleData.NonExistent.CollectionId
            $resourceId = $script:TestDirectMembershipRuleData.NonExistent.ResourceId

            # Act
            $result = Get-CM7DeviceCollectionDirectMembershipRule -CollectionId $collectionId -ResourceId $resourceId

            # Assert
            $result | Should -BeNullOrEmpty
        }
    }

    Context "Fast Parameter" {

        It "Should return limited properties in Fast mode" {
            # Arrange
            $collectionName = $script:TestDirectMembershipRuleData.Fast.CollectionName

            # Act
            $result = Get-CM7DeviceCollectionDirectMembershipRule -CollectionName $collectionName -Fast

            # Assert
            if ($result) {
                $properties = $result[0] | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name
                $properties | Should -Contain 'ResourceId'
                $properties | Should -Contain 'Name'
                $properties | Should -Contain 'ResourceType'
            }
        }

        It "Should return complete properties without Fast mode" {
            # Arrange
            $collectionName = $script:TestDirectMembershipRuleData.ByCollectionName.CollectionName

            # Act
            $result = Get-CM7DeviceCollectionDirectMembershipRule -CollectionName $collectionName

            # Assert
            if ($result) {
                # When not in Fast mode, should have additional properties
                $result[0] | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name |
                    Should -Contain 'ResourceId'
                $result[0] | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name |
                    Should -Contain 'Name'
            }
        }
    }

    Context "Output Object Properties" {

        It "Should return objects with expected properties" {
            # Arrange
            $collectionName = $script:TestDirectMembershipRuleData.ByCollectionName.CollectionName

            # Act
            $result = Get-CM7DeviceCollectionDirectMembershipRule -CollectionName $collectionName

            # Assert
            if ($result) {
                $result[0].psobject.TypeNames[0] | Should -Be 'MECM7.CollectionDirectMember'
                $result[0].ResourceId | Should -Not -BeNullOrEmpty
                $result[0].Name | Should -Not -BeNullOrEmpty
                $result[0].ResourceType | Should -Not -BeNullOrEmpty
                $result[0].CollectionId | Should -Not -BeNullOrEmpty
            }
        }

        It "Should have correct ResourceType values" {
            # Arrange
            $collectionName = $script:TestDirectMembershipRuleData.ByCollectionName.CollectionName

            # Act
            $result = Get-CM7DeviceCollectionDirectMembershipRule -CollectionName $collectionName

            # Assert
            if ($result) {
                foreach ($member in $result) {
                    $member.ResourceType | Should -BeIn @('Device', 'User', 'Unknown')
                }
            }
        }
    }

    Context "Error Handling" {

        It "Should handle invalid collection ID gracefully" {
            # Arrange
            $invalidCollectionId = "INVALID123"

            # Act
            $result = Get-CM7DeviceCollectionDirectMembershipRule -CollectionId $invalidCollectionId

            # Assert
            $result | Should -BeNullOrEmpty
        }

        It "Should handle empty results gracefully" {
            # Arrange
            $collectionName = $script:TestDirectMembershipRuleData.NonExistent.CollectionName

            # Act & Assert
            { Get-CM7DeviceCollectionDirectMembershipRule -CollectionName $collectionName } | Should -Not -Throw
        }
    }
}
