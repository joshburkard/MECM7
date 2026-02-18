# Functional Tests for New-CM7DeviceCollectionVariable
# Tests the New-CM7DeviceCollectionVariable function behavior and return values

BeforeAll {
    # Load test declarations
    . (Join-Path $PSScriptRoot "declarations.ps1")

    # Load all functions
    $CodePath = Join-Path (Get-Item $PSScriptRoot).Parent.FullName "Code"
    Get-ChildItem -Path (Join-Path $CodePath "Private") -Filter "*.ps1" | ForEach-Object { . $_.FullName }
    Get-ChildItem -Path (Join-Path $CodePath "Public") -Filter "*.ps1" | ForEach-Object { . $_.FullName }

    # Get test data for this function
    $script:TestNewCollVarData = $script:TestData['New-CM7DeviceCollectionVariable']
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

    # Generate unique timestamp suffix for test variable names to avoid collisions
    $script:TestTimestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
}

AfterAll {
    # Cleanup: Remove all test variables created during this test run
    if ($script:CMConnection.CimSession -and $script:TestTimestamp) {
        $namespace = "root/SMS/site_$($script:CMConnection.SiteCode)"
        $cimParams = @{
            CimSession = $script:CMConnection.CimSession
            Namespace  = $namespace
        }

        # Try to clean up test variables from the test collection
        $cleanupCollections = @()
        if ($script:TestNewCollVarData.ByCollectionName.CollectionName) {
            $cleanupCollections += $script:TestNewCollVarData.ByCollectionName.CollectionName
        }

        foreach ($collName in ($cleanupCollections | Select-Object -Unique)) {
            try {
                $coll = Get-CimInstance @cimParams -Query "SELECT CollectionID FROM SMS_Collection WHERE Name = '$collName'"
                if ($coll) {
                    $settings = Get-CimInstance @cimParams -Query "SELECT * FROM SMS_CollectionSettings WHERE CollectionID = '$($coll.CollectionID)'"
                    if ($settings) {
                        $fullSettings = $settings | Get-CimInstance
                        if ($fullSettings -and $fullSettings.CollectionVariables) {
                            $cleaned = @($fullSettings.CollectionVariables | Where-Object { $_.Name -notlike "*_$($script:TestTimestamp)" })
                            if ($cleaned.Count -ne @($fullSettings.CollectionVariables).Count) {
                                $fullSettings.CollectionVariables = [CimInstance[]]$cleaned
                                Set-CimInstance -InputObject $fullSettings @cimParams
                                Write-Host "Cleaned up test variables from collection '$collName'" -ForegroundColor Yellow
                            }
                        }
                    }
                }
            }
            catch {
                Write-Warning "Cleanup failed for collection '$collName': $($_.Exception.Message)"
            }
        }
    }
}

Describe "New-CM7DeviceCollectionVariable Function Tests" -Tag "Integration", "Collection", "Variable" {

    Context "Test Data Validation" {

        It "Should have test data defined in declarations.ps1" {
            # Assert
            $script:TestNewCollVarData | Should -Not -BeNullOrEmpty
            $script:TestData.ContainsKey('New-CM7DeviceCollectionVariable') | Should -Be $true
        }

        It "Should have required test data parameter sets" {
            # Assert
            $script:TestNewCollVarData.ContainsKey('ByCollectionName') | Should -Be $true
            $script:TestNewCollVarData.ContainsKey('ByCollectionId') | Should -Be $true
            $script:TestNewCollVarData.ContainsKey('NonExistentCollection') | Should -Be $true
        }

        It "Should output test data for verification" {
            # Output test data
            Write-Host "`n=== Test Data for New-CM7DeviceCollectionVariable ===" -ForegroundColor Cyan
            Write-Host "ByCollectionName:" -ForegroundColor Yellow
            Write-Host "  CollectionName: $($script:TestNewCollVarData.ByCollectionName.CollectionName)" -ForegroundColor White
            Write-Host "  VariableName: $($script:TestNewCollVarData.ByCollectionName.VariableName)" -ForegroundColor White
            Write-Host "  VariableValue: $($script:TestNewCollVarData.ByCollectionName.VariableValue)" -ForegroundColor White

            Write-Host "ByCollectionId:" -ForegroundColor Yellow
            Write-Host "  CollectionId: $($script:TestNewCollVarData.ByCollectionId.CollectionId)" -ForegroundColor White
            Write-Host "  VariableName: $($script:TestNewCollVarData.ByCollectionId.VariableName)" -ForegroundColor White
            Write-Host "  VariableValue: $($script:TestNewCollVarData.ByCollectionId.VariableValue)" -ForegroundColor White

            Write-Host "MaskedVariable:" -ForegroundColor Yellow
            Write-Host "  CollectionName: $($script:TestNewCollVarData.MaskedVariable.CollectionName)" -ForegroundColor White
            Write-Host "  VariableName: $($script:TestNewCollVarData.MaskedVariable.VariableName)" -ForegroundColor White
            Write-Host "  IsMasked: $($script:TestNewCollVarData.MaskedVariable.IsMasked)" -ForegroundColor White

            Write-Host "NonExistentCollection:" -ForegroundColor Yellow
            Write-Host "  CollectionName: $($script:TestNewCollVarData.NonExistentCollection.CollectionName)" -ForegroundColor White
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
            { New-CM7DeviceCollectionVariable -CollectionName "Test" -VariableName "TestVar" -Value "TestVal" -Force } | Should -Throw "*not connected*"

            # Restore connection
            $script:CMConnection = $backupConnection
        }
    }

    Context "Create Variable by Collection Name" {

        It "Should create a new collection variable by collection name" {
            # Arrange
            $collectionName = $script:TestNewCollVarData.ByCollectionName.CollectionName
            $varName = "$($script:TestNewCollVarData.ByCollectionName.VariableName)_$($script:TestTimestamp)"
            $varValue = $script:TestNewCollVarData.ByCollectionName.VariableValue

            # Act
            $result = New-CM7DeviceCollectionVariable -CollectionName $collectionName -VariableName $varName -Value $varValue -Force

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.Name | Should -Be $varName
            $result.Value | Should -Be $varValue
            $result.IsMasked | Should -Be $false
            $result.psobject.TypeNames[0] | Should -Be 'MECM7.CollectionVariable'
        }

        It "Should verify the variable exists after creation" {
            # Arrange
            $collectionName = $script:TestNewCollVarData.ByCollectionName.CollectionName
            $varName = "$($script:TestNewCollVarData.ByCollectionName.VariableName)_$($script:TestTimestamp)"

            # Act
            $result = Get-CM7CollectionVariable -CollectionName $collectionName -VariableName $varName

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.Name | Should -Be $varName
        }

        It "Should overwrite an existing variable with the same name" {
            # Arrange
            $collectionName = $script:TestNewCollVarData.ByCollectionName.CollectionName
            $varName = "$($script:TestNewCollVarData.ByCollectionName.VariableName)_$($script:TestTimestamp)"
            $newValue = "OverwrittenValue"

            # Act - should NOT throw, should overwrite
            $result = New-CM7DeviceCollectionVariable -CollectionName $collectionName -VariableName $varName -Value $newValue -Force

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.Name | Should -Be $varName
            $result.Value | Should -Be $newValue

            # Verify the value was actually overwritten
            $verify = Get-CM7CollectionVariable -CollectionName $collectionName -VariableName $varName
            $verify | Should -Not -BeNullOrEmpty
            $verify.Value | Should -Be $newValue
        }
    }

    Context "Create Variable by Collection ID" {

        It "Should create a new collection variable by collection ID" {
            # Arrange
            $collectionId = $script:TestNewCollVarData.ByCollectionId.CollectionId
            $varName = "$($script:TestNewCollVarData.ByCollectionId.VariableName)_$($script:TestTimestamp)"
            $varValue = $script:TestNewCollVarData.ByCollectionId.VariableValue

            # Act
            $result = New-CM7DeviceCollectionVariable -CollectionId $collectionId -VariableName $varName -Value $varValue -Force

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.Name | Should -Be $varName
            $result.Value | Should -Be $varValue
            $result.IsMasked | Should -Be $false
            $result.CollectionId | Should -Be $collectionId
        }

        It "Should verify the variable exists after creation by collection ID" {
            # Arrange
            $collectionId = $script:TestNewCollVarData.ByCollectionId.CollectionId
            $varName = "$($script:TestNewCollVarData.ByCollectionId.VariableName)_$($script:TestTimestamp)"

            # Act
            $result = Get-CM7CollectionVariable -CollectionId $collectionId -VariableName $varName

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.Name | Should -Be $varName
        }
    }

    Context "Create Masked Variable" {

        It "Should create a masked collection variable" {
            # Arrange
            $collectionName = $script:TestNewCollVarData.MaskedVariable.CollectionName
            $varName = "$($script:TestNewCollVarData.MaskedVariable.VariableName)_$($script:TestTimestamp)"
            $varValue = $script:TestNewCollVarData.MaskedVariable.VariableValue

            # Act
            $result = New-CM7DeviceCollectionVariable -CollectionName $collectionName -VariableName $varName -Value $varValue -IsMasked -Force

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.Name | Should -Be $varName
            $result.IsMasked | Should -Be $true
            $result.psobject.TypeNames[0] | Should -Be 'MECM7.CollectionVariable'
        }

        It "Should verify the masked variable exists and is marked as masked" {
            # Arrange
            $collectionName = $script:TestNewCollVarData.MaskedVariable.CollectionName
            $varName = "$($script:TestNewCollVarData.MaskedVariable.VariableName)_$($script:TestTimestamp)"

            # Act
            $result = Get-CM7CollectionVariable -CollectionName $collectionName -VariableName $varName

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.Name | Should -Be $varName
            $result.IsMasked | Should -Be $true
        }
    }

    Context "Create Variable with Special Characters" {

        It "Should create a variable with special characters in the value" {
            # Arrange
            $testData = $script:TestNewCollVarData.WithSpecialChars

            # Skip if no test data provided
            if (-not $testData -or -not $testData.CollectionName) {
                Set-ItResult -Skipped -Because "No special characters test data specified"
                return
            }

            $collectionName = $testData.CollectionName
            $varName = "$($testData.VariableName)_$($script:TestTimestamp)"
            $varValue = $testData.VariableValue

            # Act
            $result = New-CM7DeviceCollectionVariable -CollectionName $collectionName -VariableName $varName -Value $varValue -Force

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.Name | Should -Be $varName
            $result.Value | Should -Be $varValue
        }
    }

    Context "Create Variable with Empty Value" {

        It "Should create a variable with an empty value" {
            # Arrange
            $testData = $script:TestNewCollVarData.EmptyValue

            # Skip if no test data provided
            if (-not $testData -or -not $testData.CollectionName) {
                Set-ItResult -Skipped -Because "No empty value test data specified"
                return
            }

            $collectionName = $testData.CollectionName
            $varName = "$($testData.VariableName)_$($script:TestTimestamp)"

            # Act
            $result = New-CM7DeviceCollectionVariable -CollectionName $collectionName -VariableName $varName -Value "" -Force

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.Name | Should -Be $varName
            $result.Value | Should -Be ""
        }
    }

    Context "Output Object Properties" {

        It "Should return objects with expected properties" {
            # Arrange
            $collectionName = $script:TestNewCollVarData.ByCollectionName.CollectionName
            $varName = "$($script:TestNewCollVarData.ByCollectionName.VariableName)_$($script:TestTimestamp)"

            # Act - retrieve the variable we already created
            $result = Get-CM7CollectionVariable -CollectionName $collectionName -VariableName $varName

            # Assert
            if ($result) {
                $firstResult = if ($result -is [array]) { $result[0] } else { $result }
                $firstResult.psobject.TypeNames[0] | Should -Be 'MECM7.CollectionVariable'
                $firstResult.Name | Should -Not -BeNullOrEmpty
                $firstResult.PSObject.Properties.Name | Should -Contain 'Value'
                $firstResult.PSObject.Properties.Name | Should -Contain 'IsMasked'
            }
        }
    }

    Context "Error Handling" {

        It "Should fail for non-existent collection" {
            # Arrange
            $collectionName = $script:TestNewCollVarData.NonExistentCollection.CollectionName
            $varName = $script:TestNewCollVarData.NonExistentCollection.VariableName
            $varValue = $script:TestNewCollVarData.NonExistentCollection.VariableValue

            # Act & Assert
            { New-CM7DeviceCollectionVariable -CollectionName $collectionName -VariableName $varName -Value $varValue -Force } | Should -Throw "*not found*"
        }

        It "Should fail for invalid variable name with spaces" {
            # Arrange
            $testData = $script:TestNewCollVarData.InvalidVariableName

            # Skip if no test data provided
            if (-not $testData -or -not $testData.CollectionName) {
                Set-ItResult -Skipped -Because "No invalid variable name test data specified"
                return
            }

            $collectionName = $testData.CollectionName
            $varName = $testData.VariableName
            $varValue = $testData.VariableValue

            # Act & Assert - should fail due to ValidatePattern
            { New-CM7DeviceCollectionVariable -CollectionName $collectionName -VariableName $varName -Value $varValue -Force } | Should -Throw
        }

        It "Should fail for non-existent collection ID" {
            # Arrange
            $collectionId = "XXX99999"
            $varName = "TestVar_Invalid"
            $varValue = "ShouldFail"

            # Act & Assert
            { New-CM7DeviceCollectionVariable -CollectionId $collectionId -VariableName $varName -Value $varValue -Force } | Should -Throw "*not found*"
        }

        It "Should handle empty VariableName parameter" {
            # Act & Assert - should fail due to ValidateNotNullOrEmpty
            { New-CM7DeviceCollectionVariable -CollectionName "Test-Collection-Direct" -VariableName "" -Value "test" -Force } | Should -Throw
        }
    }

    Context "WhatIf Support" {

        It "Should support -WhatIf without making changes" {
            # Arrange
            $collectionName = $script:TestNewCollVarData.ByCollectionName.CollectionName
            $varName = "WhatIfTestVar_$($script:TestTimestamp)"
            $varValue = "WhatIfValue"

            # Act
            $result = New-CM7DeviceCollectionVariable -CollectionName $collectionName -VariableName $varName -Value $varValue -WhatIf

            # Assert - result should be null because WhatIf doesn't execute
            $result | Should -BeNullOrEmpty

            # Verify the variable was NOT created
            $verifyResult = Get-CM7CollectionVariable -CollectionName $collectionName -VariableName $varName
            $verifyResult | Should -BeNullOrEmpty
        }
    }
}
