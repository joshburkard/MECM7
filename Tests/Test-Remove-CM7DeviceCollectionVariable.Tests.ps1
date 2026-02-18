# Functional Tests for Remove-CM7DeviceCollectionVariable
# Tests the Remove-CM7DeviceCollectionVariable function behavior and return values

BeforeAll {
    # Load test declarations
    . (Join-Path $PSScriptRoot "declarations.ps1")

    # Load all functions
    $CodePath = Join-Path (Get-Item $PSScriptRoot).Parent.FullName "Code"
    Get-ChildItem -Path (Join-Path $CodePath "Private") -Filter "*.ps1" | ForEach-Object { . $_.FullName }
    Get-ChildItem -Path (Join-Path $CodePath "Public") -Filter "*.ps1" | ForEach-Object { . $_.FullName }

    # Get test data for this function
    $script:TestRemoveDCVarData = $script:TestData['Remove-CM7DeviceCollectionVariable']
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
    # Cleanup: Remove any leftover test variables created during this test run
    if ($script:CMConnection.CimSession -and $script:TestTimestamp) {
        $namespace = "root/SMS/site_$($script:CMConnection.SiteCode)"
        $cimParams = @{
            CimSession = $script:CMConnection.CimSession
            Namespace  = $namespace
        }

        # Try to clean up test variables from the test collection
        $cleanupCollections = @()
        if ($script:TestRemoveDCVarData.ByCollectionName.CollectionName) {
            $cleanupCollections += $script:TestRemoveDCVarData.ByCollectionName.CollectionName
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

Describe "Remove-CM7DeviceCollectionVariable Function Tests" -Tag "Integration", "Collection", "Variable" {

    Context "Test Data Validation" {

        It "Should have test data defined in declarations.ps1" {
            # Assert
            $script:TestRemoveDCVarData | Should -Not -BeNullOrEmpty
            $script:TestData.ContainsKey('Remove-CM7DeviceCollectionVariable') | Should -Be $true
        }

        It "Should have required test data parameter sets" {
            # Assert
            $script:TestRemoveDCVarData.ContainsKey('ByCollectionName') | Should -Be $true
            $script:TestRemoveDCVarData.ContainsKey('ByCollectionId') | Should -Be $true
            $script:TestRemoveDCVarData.ContainsKey('NonExistentCollection') | Should -Be $true
        }

        It "Should output test data for verification" {
            # Output test data
            Write-Host "`n=== Test Data for Remove-CM7DeviceCollectionVariable ===" -ForegroundColor Cyan
            Write-Host "ByCollectionName:" -ForegroundColor Yellow
            Write-Host "  CollectionName: $($script:TestRemoveDCVarData.ByCollectionName.CollectionName)" -ForegroundColor White
            Write-Host "  VariableName: $($script:TestRemoveDCVarData.ByCollectionName.VariableName)" -ForegroundColor White

            Write-Host "ByCollectionId:" -ForegroundColor Yellow
            Write-Host "  CollectionId: $($script:TestRemoveDCVarData.ByCollectionId.CollectionId)" -ForegroundColor White
            Write-Host "  VariableName: $($script:TestRemoveDCVarData.ByCollectionId.VariableName)" -ForegroundColor White

            Write-Host "ByWildcard:" -ForegroundColor Yellow
            Write-Host "  CollectionName: $($script:TestRemoveDCVarData.ByWildcard.CollectionName)" -ForegroundColor White
            Write-Host "  VariableNamePattern: $($script:TestRemoveDCVarData.ByWildcard.VariableNamePattern)" -ForegroundColor White

            Write-Host "NonExistentCollection:" -ForegroundColor Yellow
            Write-Host "  CollectionName: $($script:TestRemoveDCVarData.NonExistentCollection.CollectionName)" -ForegroundColor White

            Write-Host "NonExistentVariable:" -ForegroundColor Yellow
            Write-Host "  CollectionName: $($script:TestRemoveDCVarData.NonExistentVariable.CollectionName)" -ForegroundColor White
            Write-Host "  VariableName: $($script:TestRemoveDCVarData.NonExistentVariable.VariableName)" -ForegroundColor White
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
            { Remove-CM7DeviceCollectionVariable -CollectionName "Test" -VariableName "TestVar" -Force } | Should -Throw "*not connected*"

            # Restore connection
            $script:CMConnection = $backupConnection
        }
    }

    Context "Remove Variable by Collection Name" {

        It "Should create a test variable and then remove it by collection name" {
            # Arrange - Create a variable to remove
            $collectionName = $script:TestRemoveDCVarData.ByCollectionName.CollectionName
            $varName = "$($script:TestRemoveDCVarData.ByCollectionName.VariableName)_$($script:TestTimestamp)"
            $varValue = "RemoveTestValue"

            # Create the test variable first
            $createResult = New-CM7DeviceCollectionVariable -CollectionName $collectionName -VariableName $varName -Value $varValue -Force
            $createResult | Should -Not -BeNullOrEmpty
            $createResult.Name | Should -Be $varName

            # Verify it exists
            $verifyBefore = Get-CM7CollectionVariable -CollectionName $collectionName -VariableName $varName
            $verifyBefore | Should -Not -BeNullOrEmpty

            # Act - Remove the variable
            $result = Remove-CM7DeviceCollectionVariable -CollectionName $collectionName -VariableName $varName -Force

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.Name | Should -Be $varName
            $result.Status | Should -Be 'Removed'
            $result.CollectionId | Should -Not -BeNullOrEmpty
        }

        It "Should verify the variable no longer exists after removal" {
            # Arrange
            $collectionName = $script:TestRemoveDCVarData.ByCollectionName.CollectionName
            $varName = "$($script:TestRemoveDCVarData.ByCollectionName.VariableName)_$($script:TestTimestamp)"

            # Act
            $result = Get-CM7CollectionVariable -CollectionName $collectionName -VariableName $varName

            # Assert
            $result | Should -BeNullOrEmpty
        }
    }

    Context "Remove Variable by Collection ID" {

        It "Should create a test variable and then remove it by collection ID" {
            # Arrange - Create a variable to remove
            $collectionId = $script:TestRemoveDCVarData.ByCollectionId.CollectionId
            $varName = "$($script:TestRemoveDCVarData.ByCollectionId.VariableName)_$($script:TestTimestamp)"
            $varValue = "RemoveTestValueByID"

            # Create the test variable first
            $createResult = New-CM7DeviceCollectionVariable -CollectionId $collectionId -VariableName $varName -Value $varValue -Force
            $createResult | Should -Not -BeNullOrEmpty

            # Act - Remove the variable
            $result = Remove-CM7DeviceCollectionVariable -CollectionId $collectionId -VariableName $varName -Force

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.Name | Should -Be $varName
            $result.Status | Should -Be 'Removed'
            $result.CollectionId | Should -Be $collectionId
        }

        It "Should verify the variable no longer exists after removal by collection ID" {
            # Arrange
            $collectionId = $script:TestRemoveDCVarData.ByCollectionId.CollectionId
            $varName = "$($script:TestRemoveDCVarData.ByCollectionId.VariableName)_$($script:TestTimestamp)"

            # Act
            $result = Get-CM7CollectionVariable -CollectionId $collectionId -VariableName $varName

            # Assert
            $result | Should -BeNullOrEmpty
        }
    }

    Context "Remove Variable by Wildcard Pattern" {

        It "Should create multiple test variables and remove them by wildcard" {
            # Arrange - Create multiple variables matching a wildcard pattern
            $collectionName = $script:TestRemoveDCVarData.ByWildcard.CollectionName
            $basePattern = "TestDCVar_RemoveWC"
            $var1Name = "${basePattern}_A_$($script:TestTimestamp)"
            $var2Name = "${basePattern}_B_$($script:TestTimestamp)"

            # Create test variables
            New-CM7DeviceCollectionVariable -CollectionName $collectionName -VariableName $var1Name -Value "WildcardVal1" -Force | Should -Not -BeNullOrEmpty
            New-CM7DeviceCollectionVariable -CollectionName $collectionName -VariableName $var2Name -Value "WildcardVal2" -Force | Should -Not -BeNullOrEmpty

            # Verify they exist
            $verifyBefore = Get-CM7CollectionVariable -CollectionName $collectionName -VariableName "${basePattern}_*_$($script:TestTimestamp)"
            $verifyBefore | Should -Not -BeNullOrEmpty
            @($verifyBefore).Count | Should -BeGreaterOrEqual 2

            # Act - Remove by wildcard
            $result = Remove-CM7DeviceCollectionVariable -CollectionName $collectionName -VariableName "${basePattern}_*_$($script:TestTimestamp)" -Force

            # Assert
            $result | Should -Not -BeNullOrEmpty
            @($result).Count | Should -BeGreaterOrEqual 2
            $result | ForEach-Object { $_.Status | Should -Be 'Removed' }
        }

        It "Should verify wildcard-removed variables no longer exist" {
            # Arrange
            $collectionName = $script:TestRemoveDCVarData.ByWildcard.CollectionName
            $basePattern = "TestDCVar_RemoveWC"

            # Act
            $result = Get-CM7CollectionVariable -CollectionName $collectionName -VariableName "${basePattern}_*_$($script:TestTimestamp)"

            # Assert
            $result | Should -BeNullOrEmpty
        }
    }

    Context "Output Object Properties" {

        It "Should return objects with expected properties" {
            # Arrange - Create a variable to remove
            $collectionName = $script:TestRemoveDCVarData.ByCollectionName.CollectionName
            $varName = "TestDCVar_Props_$($script:TestTimestamp)"

            New-CM7DeviceCollectionVariable -CollectionName $collectionName -VariableName $varName -Value "PropsTestValue" -Force | Out-Null

            # Act
            $result = Remove-CM7DeviceCollectionVariable -CollectionName $collectionName -VariableName $varName -Force

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.psobject.TypeNames[0] | Should -Be 'MECM7.RemovedCollectionVariable'
            $result.PSObject.Properties.Name | Should -Contain 'Name'
            $result.PSObject.Properties.Name | Should -Contain 'Value'
            $result.PSObject.Properties.Name | Should -Contain 'IsMasked'
            $result.PSObject.Properties.Name | Should -Contain 'CollectionId'
            $result.PSObject.Properties.Name | Should -Contain 'Status'
            $result.Status | Should -Be 'Removed'
        }
    }

    Context "Error Handling" {

        It "Should fail for non-existent collection" {
            # Arrange
            $collectionName = $script:TestRemoveDCVarData.NonExistentCollection.CollectionName
            $varName = $script:TestRemoveDCVarData.NonExistentCollection.VariableName

            # Act & Assert
            { Remove-CM7DeviceCollectionVariable -CollectionName $collectionName -VariableName $varName -Force } | Should -Throw "*not found*"
        }

        It "Should warn for non-existent variable (not throw)" {
            # Arrange
            $collectionName = $script:TestRemoveDCVarData.NonExistentVariable.CollectionName
            $varName = $script:TestRemoveDCVarData.NonExistentVariable.VariableName

            # Act - Should produce a warning, not throw
            $result = Remove-CM7DeviceCollectionVariable -CollectionName $collectionName -VariableName $varName -Force -WarningVariable warningMsg 3>$null

            # Assert
            $result | Should -BeNullOrEmpty
        }

        It "Should fail for non-existent collection ID" {
            # Arrange
            $collectionId = "XXX99999"
            $varName = "TestVar_Invalid"

            # Act & Assert
            { Remove-CM7DeviceCollectionVariable -CollectionId $collectionId -VariableName $varName -Force } | Should -Throw "*not found*"
        }

        It "Should handle empty VariableName parameter" {
            # Act & Assert - should fail due to ValidateNotNullOrEmpty
            { Remove-CM7DeviceCollectionVariable -CollectionName "Test-Collection-Direct" -VariableName "" -Force } | Should -Throw
        }
    }

    Context "WhatIf Support" {

        It "Should support -WhatIf without making changes" {
            # Arrange - Create a variable to test WhatIf
            $collectionName = $script:TestRemoveDCVarData.ByCollectionName.CollectionName
            $varName = "TestDCVar_WhatIf_$($script:TestTimestamp)"

            New-CM7DeviceCollectionVariable -CollectionName $collectionName -VariableName $varName -Value "WhatIfValue" -Force | Out-Null

            # Act
            $result = Remove-CM7DeviceCollectionVariable -CollectionName $collectionName -VariableName $varName -WhatIf

            # Assert - result should be null because WhatIf doesn't execute
            $result | Should -BeNullOrEmpty

            # Verify the variable was NOT removed
            $verifyResult = Get-CM7CollectionVariable -CollectionName $collectionName -VariableName $varName
            $verifyResult | Should -Not -BeNullOrEmpty

            # Cleanup - Actually remove the test variable
            Remove-CM7DeviceCollectionVariable -CollectionName $collectionName -VariableName $varName -Force | Out-Null
        }
    }
}
