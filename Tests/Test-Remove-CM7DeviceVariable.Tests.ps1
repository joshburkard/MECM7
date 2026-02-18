# Functional Tests for Remove-CM7DeviceVariable
# Tests the Remove-CM7DeviceVariable function behavior and return values

BeforeAll {
    # Load test declarations
    . (Join-Path $PSScriptRoot "declarations.ps1")

    # Load all functions
    $CodePath = Join-Path (Get-Item $PSScriptRoot).Parent.FullName "Code"
    Get-ChildItem -Path (Join-Path $CodePath "Private") -Filter "*.ps1" | ForEach-Object { . $_.FullName }
    Get-ChildItem -Path (Join-Path $CodePath "Public") -Filter "*.ps1" | ForEach-Object { . $_.FullName }

    # Get test data for this function
    $script:TestRemoveDevVarData = $script:TestData['Remove-CM7DeviceVariable']
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

        # Try to clean up test variables from the test device
        $cleanupDevices = @()
        if ($script:TestRemoveDevVarData.ByDeviceName.DeviceName) {
            $cleanupDevices += $script:TestRemoveDevVarData.ByDeviceName.DeviceName
        }

        foreach ($devName in ($cleanupDevices | Select-Object -Unique)) {
            try {
                $dev = Get-CimInstance @cimParams -Query "SELECT ResourceID FROM SMS_R_System WHERE Name = '$devName'"
                if ($dev) {
                    $resId = if (@($dev).Count -gt 1) { $dev[0].ResourceID } else { $dev.ResourceID }
                    $settings = Get-CimInstance @cimParams -Query "SELECT * FROM SMS_MachineSettings WHERE ResourceID = $resId"
                    if ($settings) {
                        $fullSettings = $settings | Get-CimInstance
                        if ($fullSettings -and $fullSettings.MachineVariables) {
                            $cleaned = @($fullSettings.MachineVariables | Where-Object { $_.Name -notlike "*_$($script:TestTimestamp)" })
                            if ($cleaned.Count -ne @($fullSettings.MachineVariables).Count) {
                                $fullSettings.CimInstanceProperties['MachineVariables'].Value = [CimInstance[]]$cleaned
                                $fullSettings | Set-CimInstance
                                Write-Host "Cleaned up test variables from device '$devName'" -ForegroundColor Yellow
                            }
                        }
                    }
                }
            }
            catch {
                Write-Warning "Cleanup failed for device '$devName': $($_.Exception.Message)"
            }
        }
    }
}

Describe "Remove-CM7DeviceVariable Function Tests" -Tag "Integration", "Device", "Variable" {

    Context "Test Data Validation" {

        It "Should have test data defined in declarations.ps1" {
            # Assert
            $script:TestRemoveDevVarData | Should -Not -BeNullOrEmpty
            $script:TestData.ContainsKey('Remove-CM7DeviceVariable') | Should -Be $true
        }

        It "Should have required test data parameter sets" {
            # Assert
            $script:TestRemoveDevVarData.ContainsKey('ByDeviceName') | Should -Be $true
            $script:TestRemoveDevVarData.ContainsKey('ByResourceId') | Should -Be $true
            $script:TestRemoveDevVarData.ContainsKey('NonExistentDevice') | Should -Be $true
        }

        It "Should output test data for verification" {
            # Output test data
            Write-Host "`n=== Test Data for Remove-CM7DeviceVariable ===" -ForegroundColor Cyan
            Write-Host "ByDeviceName:" -ForegroundColor Yellow
            Write-Host "  DeviceName: $($script:TestRemoveDevVarData.ByDeviceName.DeviceName)" -ForegroundColor White
            Write-Host "  VariableName: $($script:TestRemoveDevVarData.ByDeviceName.VariableName)" -ForegroundColor White

            Write-Host "ByResourceId:" -ForegroundColor Yellow
            Write-Host "  ResourceId: $($script:TestRemoveDevVarData.ByResourceId.ResourceId)" -ForegroundColor White
            Write-Host "  VariableName: $($script:TestRemoveDevVarData.ByResourceId.VariableName)" -ForegroundColor White

            Write-Host "ByWildcard:" -ForegroundColor Yellow
            Write-Host "  DeviceName: $($script:TestRemoveDevVarData.ByWildcard.DeviceName)" -ForegroundColor White
            Write-Host "  VariableNamePattern: $($script:TestRemoveDevVarData.ByWildcard.VariableNamePattern)" -ForegroundColor White

            Write-Host "NonExistentDevice:" -ForegroundColor Yellow
            Write-Host "  DeviceName: $($script:TestRemoveDevVarData.NonExistentDevice.DeviceName)" -ForegroundColor White

            Write-Host "NonExistentVariable:" -ForegroundColor Yellow
            Write-Host "  DeviceName: $($script:TestRemoveDevVarData.NonExistentVariable.DeviceName)" -ForegroundColor White
            Write-Host "  VariableName: $($script:TestRemoveDevVarData.NonExistentVariable.VariableName)" -ForegroundColor White
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
            { Remove-CM7DeviceVariable -DeviceName "Test" -VariableName "TestVar" -Force } | Should -Throw "*not connected*"

            # Restore connection
            $script:CMConnection = $backupConnection
        }
    }

    Context "Remove Variable by Device Name" {

        It "Should create a test variable and then remove it by device name" {
            # Arrange - Create a variable to remove
            $deviceName = $script:TestRemoveDevVarData.ByDeviceName.DeviceName
            $varName = "$($script:TestRemoveDevVarData.ByDeviceName.VariableName)_$($script:TestTimestamp)"
            $varValue = "RemoveTestValue"

            # Create the test variable first
            $createResult = New-CM7DeviceVariable -DeviceName $deviceName -VariableName $varName -Value $varValue -Force
            $createResult | Should -Not -BeNullOrEmpty
            $createResult.Name | Should -Be $varName

            # Verify it exists
            $verifyBefore = Get-CM7DeviceVariable -DeviceName $deviceName -VariableName $varName
            $verifyBefore | Should -Not -BeNullOrEmpty

            # Act - Remove the variable
            $result = Remove-CM7DeviceVariable -DeviceName $deviceName -VariableName $varName -Force

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.Name | Should -Be $varName
            $result.Status | Should -Be 'Removed'
            $result.ResourceId | Should -Not -BeNullOrEmpty
        }

        It "Should verify the variable no longer exists after removal" {
            # Arrange
            $deviceName = $script:TestRemoveDevVarData.ByDeviceName.DeviceName
            $varName = "$($script:TestRemoveDevVarData.ByDeviceName.VariableName)_$($script:TestTimestamp)"

            # Act
            $result = Get-CM7DeviceVariable -DeviceName $deviceName -VariableName $varName

            # Assert
            $result | Should -BeNullOrEmpty
        }
    }

    Context "Remove Variable by Resource ID" {

        It "Should create a test variable and then remove it by resource ID" {
            # Arrange - Create a variable to remove
            $resourceId = $script:TestRemoveDevVarData.ByResourceId.ResourceId
            $varName = "$($script:TestRemoveDevVarData.ByResourceId.VariableName)_$($script:TestTimestamp)"
            $varValue = "RemoveTestValueByID"

            # Create the test variable first
            $createResult = New-CM7DeviceVariable -ResourceId $resourceId -VariableName $varName -Value $varValue -Force
            $createResult | Should -Not -BeNullOrEmpty

            # Act - Remove the variable
            $result = Remove-CM7DeviceVariable -ResourceId $resourceId -VariableName $varName -Force

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.Name | Should -Be $varName
            $result.Status | Should -Be 'Removed'
            $result.ResourceId | Should -Be $resourceId
        }

        It "Should verify the variable no longer exists after removal by resource ID" {
            # Arrange
            $resourceId = $script:TestRemoveDevVarData.ByResourceId.ResourceId
            $varName = "$($script:TestRemoveDevVarData.ByResourceId.VariableName)_$($script:TestTimestamp)"

            # Act
            $result = Get-CM7DeviceVariable -ResourceId $resourceId -VariableName $varName

            # Assert
            $result | Should -BeNullOrEmpty
        }
    }

    Context "Remove Variable by Wildcard Pattern" {

        It "Should create multiple test variables and remove them by wildcard" {
            # Arrange - Create multiple variables matching a wildcard pattern
            $deviceName = $script:TestRemoveDevVarData.ByWildcard.DeviceName
            $basePattern = "TestDevVar_RemoveWC"
            $var1Name = "${basePattern}_A_$($script:TestTimestamp)"
            $var2Name = "${basePattern}_B_$($script:TestTimestamp)"

            # Create test variables
            New-CM7DeviceVariable -DeviceName $deviceName -VariableName $var1Name -Value "WildcardVal1" -Force | Should -Not -BeNullOrEmpty
            New-CM7DeviceVariable -DeviceName $deviceName -VariableName $var2Name -Value "WildcardVal2" -Force | Should -Not -BeNullOrEmpty

            # Verify they exist
            $verifyBefore = Get-CM7DeviceVariable -DeviceName $deviceName -VariableName "${basePattern}_*_$($script:TestTimestamp)"
            $verifyBefore | Should -Not -BeNullOrEmpty
            @($verifyBefore).Count | Should -BeGreaterOrEqual 2

            # Act - Remove by wildcard
            $result = Remove-CM7DeviceVariable -DeviceName $deviceName -VariableName "${basePattern}_*_$($script:TestTimestamp)" -Force

            # Assert
            $result | Should -Not -BeNullOrEmpty
            @($result).Count | Should -BeGreaterOrEqual 2
            $result | ForEach-Object { $_.Status | Should -Be 'Removed' }
        }

        It "Should verify wildcard-removed variables no longer exist" {
            # Arrange
            $deviceName = $script:TestRemoveDevVarData.ByWildcard.DeviceName
            $basePattern = "TestDevVar_RemoveWC"

            # Act
            $result = Get-CM7DeviceVariable -DeviceName $deviceName -VariableName "${basePattern}_*_$($script:TestTimestamp)"

            # Assert
            $result | Should -BeNullOrEmpty
        }
    }

    Context "Output Object Properties" {

        It "Should return objects with expected properties" {
            # Arrange - Create a variable to remove
            $deviceName = $script:TestRemoveDevVarData.ByDeviceName.DeviceName
            $varName = "TestDevVar_Props_$($script:TestTimestamp)"

            New-CM7DeviceVariable -DeviceName $deviceName -VariableName $varName -Value "PropsTestValue" -Force | Out-Null

            # Act
            $result = Remove-CM7DeviceVariable -DeviceName $deviceName -VariableName $varName -Force

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.psobject.TypeNames[0] | Should -Be 'MECM7.RemovedDeviceVariable'
            $result.PSObject.Properties.Name | Should -Contain 'Name'
            $result.PSObject.Properties.Name | Should -Contain 'Value'
            $result.PSObject.Properties.Name | Should -Contain 'IsMasked'
            $result.PSObject.Properties.Name | Should -Contain 'ResourceId'
            $result.PSObject.Properties.Name | Should -Contain 'Status'
            $result.Status | Should -Be 'Removed'
        }
    }

    Context "Error Handling" {

        It "Should fail for non-existent device" {
            # Arrange
            $deviceName = $script:TestRemoveDevVarData.NonExistentDevice.DeviceName
            $varName = $script:TestRemoveDevVarData.NonExistentDevice.VariableName

            # Act & Assert
            { Remove-CM7DeviceVariable -DeviceName $deviceName -VariableName $varName -Force } | Should -Throw "*not found*"
        }

        It "Should warn for non-existent variable (not throw)" {
            # Arrange
            $deviceName = $script:TestRemoveDevVarData.NonExistentVariable.DeviceName
            $varName = $script:TestRemoveDevVarData.NonExistentVariable.VariableName

            # Act - Should produce a warning, not throw
            $result = Remove-CM7DeviceVariable -DeviceName $deviceName -VariableName $varName -Force -WarningVariable warningMsg 3>$null

            # Assert
            $result | Should -BeNullOrEmpty
        }

        It "Should fail for non-existent resource ID" {
            # Arrange
            $resourceId = 999999999
            $varName = "TestVar_Invalid"

            # Act & Assert
            { Remove-CM7DeviceVariable -ResourceId $resourceId -VariableName $varName -Force } | Should -Throw "*not found*"
        }

        It "Should handle empty VariableName parameter" {
            # Act & Assert - should fail due to ValidateNotNullOrEmpty
            { Remove-CM7DeviceVariable -DeviceName "Test-2016-1" -VariableName "" -Force } | Should -Throw
        }
    }

    Context "WhatIf Support" {

        It "Should support -WhatIf without making changes" {
            # Arrange - Create a variable to test WhatIf
            $deviceName = $script:TestRemoveDevVarData.ByDeviceName.DeviceName
            $varName = "TestDevVar_WhatIf_$($script:TestTimestamp)"

            New-CM7DeviceVariable -DeviceName $deviceName -VariableName $varName -Value "WhatIfValue" -Force | Out-Null

            # Act
            $result = Remove-CM7DeviceVariable -DeviceName $deviceName -VariableName $varName -WhatIf

            # Assert - result should be null because WhatIf doesn't execute
            $result | Should -BeNullOrEmpty

            # Verify the variable was NOT removed
            $verifyResult = Get-CM7DeviceVariable -DeviceName $deviceName -VariableName $varName
            $verifyResult | Should -Not -BeNullOrEmpty

            # Cleanup - Actually remove the test variable
            Remove-CM7DeviceVariable -DeviceName $deviceName -VariableName $varName -Force | Out-Null
        }
    }
}
