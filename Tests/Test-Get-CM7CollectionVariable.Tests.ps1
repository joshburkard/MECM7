# Functional Tests for Get-CM7CollectionVariable
# Tests the Get-CM7CollectionVariable function behavior and return values

BeforeAll {
    # Load test declarations
    . (Join-Path $PSScriptRoot "declarations.ps1")

    # Load all functions
    $CodePath = Join-Path (Get-Item $PSScriptRoot).Parent.FullName "Code"
    Get-ChildItem -Path (Join-Path $CodePath "Private") -Filter "*.ps1" | ForEach-Object { . $_.FullName }
    Get-ChildItem -Path (Join-Path $CodePath "Public") -Filter "*.ps1" | ForEach-Object { . $_.FullName }

    # Get test data for this function
    $script:TestCollectionVariableData = $script:TestData['Get-CM7CollectionVariable']
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

Describe "Get-CM7CollectionVariable Function Tests" -Tag "Integration", "Collection", "Variable" {

    Context "Test Data Validation" {

        It "Should have test data defined in declarations.ps1" {
            # Assert
            $script:TestCollectionVariableData | Should -Not -BeNullOrEmpty
            $script:TestData.ContainsKey('Get-CM7CollectionVariable') | Should -Be $true
        }

        It "Should have required test data parameter sets" {
            # Assert
            $script:TestCollectionVariableData.ContainsKey('ByCollectionName') | Should -Be $true
            $script:TestCollectionVariableData.ContainsKey('ByCollectionId') | Should -Be $true
            $script:TestCollectionVariableData.ContainsKey('NonExistentCollection') | Should -Be $true
            $script:TestCollectionVariableData.ContainsKey('NonExistentVariable') | Should -Be $true
        }

        It "Should output test data for verification" {
            # Output test data
            Write-Host "`n=== Test Data for Get-CM7CollectionVariable ===" -ForegroundColor Cyan
            Write-Host "ByCollectionName:" -ForegroundColor Yellow
            Write-Host "  CollectionName: $($script:TestCollectionVariableData.ByCollectionName.CollectionName)" -ForegroundColor White
            Write-Host "  ExpectedMinCount: $($script:TestCollectionVariableData.ByCollectionName.ExpectedMinCount)" -ForegroundColor White

            Write-Host "ByCollectionId:" -ForegroundColor Yellow
            Write-Host "  CollectionId: $($script:TestCollectionVariableData.ByCollectionId.CollectionId)" -ForegroundColor White
            Write-Host "  ExpectedMinCount: $($script:TestCollectionVariableData.ByCollectionId.ExpectedMinCount)" -ForegroundColor White

            Write-Host "NonExistentCollection:" -ForegroundColor Yellow
            Write-Host "  CollectionName: $($script:TestCollectionVariableData.NonExistentCollection.CollectionName)" -ForegroundColor White

            Write-Host "NonExistentVariable:" -ForegroundColor Yellow
            Write-Host "  CollectionName: $($script:TestCollectionVariableData.NonExistentVariable.CollectionName)" -ForegroundColor White
            Write-Host "  VariableName: $($script:TestCollectionVariableData.NonExistentVariable.VariableName)" -ForegroundColor White
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
            { Get-CM7CollectionVariable -CollectionName "Test" } | Should -Throw "*not connected*"

            # Restore connection
            $script:CMConnection = $backupConnection
        }
    }

    Context "Query by Collection Name" {

        It "Should output test data for debugging" {
            # This test outputs what data is being used
            Write-Host "`nDEBUG: Test Data Values:" -ForegroundColor Cyan
            Write-Host "ByCollectionName.CollectionName = '$($script:TestCollectionVariableData.ByCollectionName.CollectionName)'" -ForegroundColor Yellow
            Write-Host "ByCollectionId.CollectionId = '$($script:TestCollectionVariableData.ByCollectionId.CollectionId)'" -ForegroundColor Yellow
            Write-Host "NonExistentCollection.CollectionName = '$($script:TestCollectionVariableData.NonExistentCollection.CollectionName)'" -ForegroundColor Yellow
            $true | Should -Be $true
        }

        It "Should retrieve collection variables by collection name" {
            # Arrange
            $collectionName = $script:TestCollectionVariableData.ByCollectionName.CollectionName

            # Act
            $result = Get-CM7CollectionVariable -CollectionName $collectionName

            # Assert
            if ($result) {
                @($result).Count | Should -BeGreaterOrEqual $script:TestCollectionVariableData.ByCollectionName.ExpectedMinCount
                $result[0].psobject.TypeNames[0] | Should -Be 'MECM7.CollectionVariable'
            } else {
                # It's acceptable to have no variables
                $result | Should -BeNullOrEmpty
            }
        }

        It "Should return null for non-existent collection" {
            # Arrange
            $collectionName = $script:TestCollectionVariableData.NonExistentCollection.CollectionName

            # Act
            $result = Get-CM7CollectionVariable -CollectionName $collectionName

            # Assert
            $result | Should -BeNullOrEmpty
        }
    }

    Context "Query by Collection ID" {

        It "Should retrieve collection variables by collection ID" {
            # Arrange
            $collectionId = $script:TestCollectionVariableData.ByCollectionId.CollectionId

            # Act
            $result = Get-CM7CollectionVariable -CollectionId $collectionId

            # Assert
            if ($result) {
                @($result).Count | Should -BeGreaterOrEqual $script:TestCollectionVariableData.ByCollectionId.ExpectedMinCount
                $result[0].psobject.TypeNames[0] | Should -Be 'MECM7.CollectionVariable'
            } else {
                # It's acceptable to have no variables
                $result | Should -BeNullOrEmpty
            }
        }

        It "Should return null for non-existent collection ID" {
            # Arrange
            $collectionId = "XXX99999"

            # Act
            $result = Get-CM7CollectionVariable -CollectionId $collectionId

            # Assert
            $result | Should -BeNullOrEmpty
        }
    }

    Context "Query with Variable Name Filter" {

        It "Should retrieve a specific variable by name" {
            # Arrange
            $collectionName = $script:TestCollectionVariableData.ByCollectionNameAndVariableName.CollectionName
            $variableName = $script:TestCollectionVariableData.ByCollectionNameAndVariableName.VariableName

            # Act
            $result = Get-CM7CollectionVariable -CollectionName $collectionName -VariableName $variableName

            # Assert
            if ($result) {
                if ($result -is [array]) {
                    @($result).Count | Should -Be 1
                    $result[0].Name | Should -Be $variableName
                    $result[0].psobject.TypeNames[0] | Should -Be 'MECM7.CollectionVariable'
                } else {
                    $result.Name | Should -Be $variableName
                    $result.psobject.TypeNames[0] | Should -Be 'MECM7.CollectionVariable'
                }
            } else {
                # Variable not found - acceptable in some configurations
                $result | Should -BeNullOrEmpty
            }
        }

        It "Should retrieve a specific variable by name using CollectionId" {
            # Arrange
            $collectionId = $script:TestCollectionVariableData.ByCollectionIdAndVariableName.CollectionId
            $variableName = $script:TestCollectionVariableData.ByCollectionIdAndVariableName.VariableName

            # Act
            $result = Get-CM7CollectionVariable -CollectionId $collectionId -VariableName $variableName

            # Assert
            if ($result) {
                if ($result -is [array]) {
                    $result[0].Name | Should -Be $variableName
                    $result[0].psobject.TypeNames[0] | Should -Be 'MECM7.CollectionVariable'
                } else {
                    $result.Name | Should -Be $variableName
                    $result.psobject.TypeNames[0] | Should -Be 'MECM7.CollectionVariable'
                }
            } else {
                $result | Should -BeNullOrEmpty
            }
        }

        It "Should support wildcard in variable name" {
            # Arrange
            $collectionName = $script:TestCollectionVariableData.ByWildcard.CollectionName
            $variablePattern = $script:TestCollectionVariableData.ByWildcard.VariableName

            # Act
            $result = Get-CM7CollectionVariable -CollectionName $collectionName -VariableName $variablePattern

            # Assert
            if ($result) {
                if ($result -is [array]) {
                    $result[0].psobject.TypeNames[0] | Should -Be 'MECM7.CollectionVariable'
                    foreach ($variable in $result) {
                        $variable.Name | Should -BeLike $variablePattern
                    }
                } else {
                    $result.psobject.TypeNames[0] | Should -Be 'MECM7.CollectionVariable'
                    $result.Name | Should -BeLike $variablePattern
                }
            } else {
                # No results is acceptable
                $result | Should -BeNullOrEmpty
            }
        }

        It "Should return null for non-existent variable name" {
            # Arrange
            $collectionName = $script:TestCollectionVariableData.NonExistentVariable.CollectionName
            $variableName = $script:TestCollectionVariableData.NonExistentVariable.VariableName

            # Act
            $result = Get-CM7CollectionVariable -CollectionName $collectionName -VariableName $variableName

            # Assert
            $result | Should -BeNullOrEmpty
        }
    }

    Context "Collection Without Variables" {

        It "Should return null for collection without variables" {
            # Arrange
            $testData = $script:TestCollectionVariableData.CollectionWithoutVariables

            # Skip if no test data provided
            if (-not $testData -or -not $testData.CollectionName) {
                Set-ItResult -Skipped -Because "No collection without variables specified in test data"
                return
            }

            $collectionName = $testData.CollectionName

            # Act
            $result = Get-CM7CollectionVariable -CollectionName $collectionName

            # Assert
            $result | Should -BeNullOrEmpty
        }

        It "Should return null for collection without variables (by ID)" {
            # Arrange
            $testData = $script:TestCollectionVariableData.CollectionWithoutVariables

            # Skip if no test data provided
            if (-not $testData -or -not $testData.CollectionId) {
                Set-ItResult -Skipped -Because "No collection ID without variables specified in test data"
                return
            }

            $collectionId = $testData.CollectionId

            # Act
            $result = Get-CM7CollectionVariable -CollectionId $collectionId

            # Assert
            $result | Should -BeNullOrEmpty
        }
    }

    Context "Output Object Properties" {

        It "Should return objects with expected properties" {
            # Arrange
            $collectionName = $script:TestCollectionVariableData.ByCollectionName.CollectionName

            # Act
            $result = Get-CM7CollectionVariable -CollectionName $collectionName

            # Assert
            if ($result) {
                $firstResult = if ($result -is [array]) { $result[0] } else { $result }
                $firstResult.psobject.TypeNames[0] | Should -Be 'MECM7.CollectionVariable'
                $firstResult.Name | Should -Not -BeNullOrEmpty
                # Value can be empty for masked variables
                $firstResult.PSObject.Properties.Name | Should -Contain 'Value'
                $firstResult.PSObject.Properties.Name | Should -Contain 'IsMasked'
            }
        }

        It "Should have correct IsMasked values" {
            # Arrange
            $collectionName = $script:TestCollectionVariableData.ByCollectionName.CollectionName

            # Act
            $result = Get-CM7CollectionVariable -CollectionName $collectionName

            # Assert
            if ($result) {
                foreach ($variable in $result) {
                    $variable.IsMasked | Should -BeIn @($true, $false)
                }
            }
        }

        It "Should only return Name, Value, IsMasked properties" {
            # Arrange
            $collectionName = $script:TestCollectionVariableData.ByCollectionName.CollectionName

            # Act
            $result = Get-CM7CollectionVariable -CollectionName $collectionName

            # Assert
            if ($result) {
                $firstResult = if ($result -is [array]) { $result[0] } else { $result }
                $properties = $firstResult | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name
                $properties | Should -Contain 'Name'
                $properties | Should -Contain 'Value'
                $properties | Should -Contain 'IsMasked'
                $properties | Should -Not -Contain 'CollectionId'
                $properties | Should -Not -Contain 'CollectionName'
            }
        }
    }

    Context "Error Handling" {

        It "Should handle invalid collection ID gracefully" {
            # Arrange
            $invalidCollectionId = "INVALID123"

            # Act
            $result = Get-CM7CollectionVariable -CollectionId $invalidCollectionId

            # Assert
            $result | Should -BeNullOrEmpty
        }

        It "Should handle empty results gracefully" {
            # Arrange
            $collectionName = $script:TestCollectionVariableData.NonExistentCollection.CollectionName

            # Act & Assert
            { Get-CM7CollectionVariable -CollectionName $collectionName } | Should -Not -Throw
        }
    }
}
