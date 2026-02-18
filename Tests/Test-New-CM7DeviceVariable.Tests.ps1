# Functional Tests for New-CM7DeviceVariable
# Tests the New-CM7DeviceVariable function behavior and return values

BeforeAll {
    # Load test declarations
    . (Join-Path $PSScriptRoot "declarations.ps1")

    # Load all functions
    $CodePath = Join-Path (Get-Item $PSScriptRoot).Parent.FullName "Code"
    Get-ChildItem -Path (Join-Path $CodePath "Private") -Filter "*.ps1" | ForEach-Object { . $_.FullName }
    Get-ChildItem -Path (Join-Path $CodePath "Public") -Filter "*.ps1" | ForEach-Object { . $_.FullName }

    # Get test data for this function
    $script:TestNewDevVarData = $script:TestData['New-CM7DeviceVariable']
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

        # Try to clean up test variables from the test device
        $cleanupDevices = @()
        if ($script:TestNewDevVarData.ByDeviceName.DeviceName) {
            $cleanupDevices += $script:TestNewDevVarData.ByDeviceName.DeviceName
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

Describe "New-CM7DeviceVariable Function Tests" -Tag "Integration", "Device", "Variable" {

    Context "Test Data Validation" {

        It "Should have test data defined in declarations.ps1" {
            # Assert
            $script:TestNewDevVarData | Should -Not -BeNullOrEmpty
            $script:TestData.ContainsKey('New-CM7DeviceVariable') | Should -Be $true
        }

        It "Should have required test data parameter sets" {
            # Assert
            $script:TestNewDevVarData.ContainsKey('ByDeviceName') | Should -Be $true
            $script:TestNewDevVarData.ContainsKey('ByResourceId') | Should -Be $true
            $script:TestNewDevVarData.ContainsKey('NonExistentDevice') | Should -Be $true
        }

        It "Should output test data for verification" {
            # Output test data
            Write-Host "`n=== Test Data for New-CM7DeviceVariable ===" -ForegroundColor Cyan
            Write-Host "ByDeviceName:" -ForegroundColor Yellow
            Write-Host "  DeviceName: $($script:TestNewDevVarData.ByDeviceName.DeviceName)" -ForegroundColor White
            Write-Host "  VariableName: $($script:TestNewDevVarData.ByDeviceName.VariableName)" -ForegroundColor White
            Write-Host "  VariableValue: $($script:TestNewDevVarData.ByDeviceName.VariableValue)" -ForegroundColor White

            Write-Host "ByResourceId:" -ForegroundColor Yellow
            Write-Host "  ResourceId: $($script:TestNewDevVarData.ByResourceId.ResourceId)" -ForegroundColor White
            Write-Host "  VariableName: $($script:TestNewDevVarData.ByResourceId.VariableName)" -ForegroundColor White
            Write-Host "  VariableValue: $($script:TestNewDevVarData.ByResourceId.VariableValue)" -ForegroundColor White

            Write-Host "MaskedVariable:" -ForegroundColor Yellow
            Write-Host "  DeviceName: $($script:TestNewDevVarData.MaskedVariable.DeviceName)" -ForegroundColor White
            Write-Host "  VariableName: $($script:TestNewDevVarData.MaskedVariable.VariableName)" -ForegroundColor White
            Write-Host "  IsMasked: $($script:TestNewDevVarData.MaskedVariable.IsMasked)" -ForegroundColor White

            Write-Host "NonExistentDevice:" -ForegroundColor Yellow
            Write-Host "  DeviceName: $($script:TestNewDevVarData.NonExistentDevice.DeviceName)" -ForegroundColor White
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
            { New-CM7DeviceVariable -DeviceName "Test" -VariableName "TestVar" -Value "TestVal" -Force } | Should -Throw "*not connected*"

            # Restore connection
            $script:CMConnection = $backupConnection
        }
    }

    Context "Create Variable by Device Name" {

        It "Should create a new device variable by device name" {
            # Arrange
            $deviceName = $script:TestNewDevVarData.ByDeviceName.DeviceName
            $varName = "$($script:TestNewDevVarData.ByDeviceName.VariableName)_$($script:TestTimestamp)"
            $varValue = $script:TestNewDevVarData.ByDeviceName.VariableValue

            # Act
            $result = New-CM7DeviceVariable -DeviceName $deviceName -VariableName $varName -Value $varValue -Force

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.Name | Should -Be $varName
            $result.Value | Should -Be $varValue
            $result.IsMasked | Should -Be $false
            $result.psobject.TypeNames[0] | Should -Be 'MECM7.DeviceVariable'
        }

        It "Should verify the variable exists after creation" {
            # Arrange
            $deviceName = $script:TestNewDevVarData.ByDeviceName.DeviceName
            $varName = "$($script:TestNewDevVarData.ByDeviceName.VariableName)_$($script:TestTimestamp)"

            # Act
            $result = Get-CM7DeviceVariable -DeviceName $deviceName -VariableName $varName

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.Name | Should -Be $varName
        }

        It "Should overwrite an existing variable with the same name" {
            # Arrange
            $deviceName = $script:TestNewDevVarData.ByDeviceName.DeviceName
            $varName = "$($script:TestNewDevVarData.ByDeviceName.VariableName)_$($script:TestTimestamp)"
            $newValue = "OverwrittenValue"

            # Act - should NOT throw, should overwrite
            $result = New-CM7DeviceVariable -DeviceName $deviceName -VariableName $varName -Value $newValue -Force

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.Name | Should -Be $varName
            $result.Value | Should -Be $newValue

            # Verify the value was actually overwritten
            $verify = Get-CM7DeviceVariable -DeviceName $deviceName -VariableName $varName
            $verify | Should -Not -BeNullOrEmpty
            $verify.Value | Should -Be $newValue
        }
    }

    Context "Create Variable by Resource ID" {

        It "Should create a new device variable by resource ID" {
            # Arrange
            $resourceId = $script:TestNewDevVarData.ByResourceId.ResourceId
            $varName = "$($script:TestNewDevVarData.ByResourceId.VariableName)_$($script:TestTimestamp)"
            $varValue = $script:TestNewDevVarData.ByResourceId.VariableValue

            # Act
            $result = New-CM7DeviceVariable -ResourceId $resourceId -VariableName $varName -Value $varValue -Force

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.Name | Should -Be $varName
            $result.Value | Should -Be $varValue
            $result.IsMasked | Should -Be $false
            $result.ResourceId | Should -Be $resourceId
        }

        It "Should verify the variable exists after creation by resource ID" {
            # Arrange
            $resourceId = $script:TestNewDevVarData.ByResourceId.ResourceId
            $varName = "$($script:TestNewDevVarData.ByResourceId.VariableName)_$($script:TestTimestamp)"

            # Act
            $result = Get-CM7DeviceVariable -ResourceId $resourceId -VariableName $varName

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.Name | Should -Be $varName
        }
    }

    Context "Create Masked Variable" {

        It "Should create a masked device variable" {
            # Arrange
            $deviceName = $script:TestNewDevVarData.MaskedVariable.DeviceName
            $varName = "$($script:TestNewDevVarData.MaskedVariable.VariableName)_$($script:TestTimestamp)"
            $varValue = $script:TestNewDevVarData.MaskedVariable.VariableValue

            # Act
            $result = New-CM7DeviceVariable -DeviceName $deviceName -VariableName $varName -Value $varValue -IsMasked -Force

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.Name | Should -Be $varName
            $result.IsMasked | Should -Be $true
            $result.psobject.TypeNames[0] | Should -Be 'MECM7.DeviceVariable'
        }

        It "Should verify the masked variable exists and is marked as masked" {
            # Arrange
            $deviceName = $script:TestNewDevVarData.MaskedVariable.DeviceName
            $varName = "$($script:TestNewDevVarData.MaskedVariable.VariableName)_$($script:TestTimestamp)"

            # Act
            $result = Get-CM7DeviceVariable -DeviceName $deviceName -VariableName $varName

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.Name | Should -Be $varName
            $result.IsMasked | Should -Be $true
        }
    }

    Context "Create Variable with Special Characters" {

        It "Should create a variable with special characters in the value" {
            # Arrange
            $testData = $script:TestNewDevVarData.WithSpecialChars

            # Skip if no test data provided
            if (-not $testData -or -not $testData.DeviceName) {
                Set-ItResult -Skipped -Because "No special characters test data specified"
                return
            }

            $deviceName = $testData.DeviceName
            $varName = "$($testData.VariableName)_$($script:TestTimestamp)"
            $varValue = $testData.VariableValue

            # Act
            $result = New-CM7DeviceVariable -DeviceName $deviceName -VariableName $varName -Value $varValue -Force

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.Name | Should -Be $varName
            $result.Value | Should -Be $varValue
        }
    }

    Context "Create Variable with Empty Value" {

        It "Should create a variable with an empty value" {
            # Arrange
            $testData = $script:TestNewDevVarData.EmptyValue

            # Skip if no test data provided
            if (-not $testData -or -not $testData.DeviceName) {
                Set-ItResult -Skipped -Because "No empty value test data specified"
                return
            }

            $deviceName = $testData.DeviceName
            $varName = "$($testData.VariableName)_$($script:TestTimestamp)"

            # Act
            $result = New-CM7DeviceVariable -DeviceName $deviceName -VariableName $varName -Value "" -Force

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.Name | Should -Be $varName
            $result.Value | Should -Be ""
        }
    }

    Context "Output Object Properties" {

        It "Should return objects with expected properties" {
            # Arrange
            $deviceName = $script:TestNewDevVarData.ByDeviceName.DeviceName
            $varName = "$($script:TestNewDevVarData.ByDeviceName.VariableName)_$($script:TestTimestamp)"

            # Act - retrieve the variable we already created
            $result = Get-CM7DeviceVariable -DeviceName $deviceName -VariableName $varName

            # Assert
            if ($result) {
                $firstResult = if ($result -is [array]) { $result[0] } else { $result }
                $firstResult.psobject.TypeNames[0] | Should -Be 'MECM7.DeviceVariable'
                $firstResult.Name | Should -Not -BeNullOrEmpty
                $firstResult.PSObject.Properties.Name | Should -Contain 'Value'
                $firstResult.PSObject.Properties.Name | Should -Contain 'IsMasked'
            }
        }
    }

    Context "Error Handling" {

        It "Should fail for non-existent device" {
            # Arrange
            $deviceName = $script:TestNewDevVarData.NonExistentDevice.DeviceName
            $varName = $script:TestNewDevVarData.NonExistentDevice.VariableName
            $varValue = $script:TestNewDevVarData.NonExistentDevice.VariableValue

            # Act & Assert
            { New-CM7DeviceVariable -DeviceName $deviceName -VariableName $varName -Value $varValue -Force } | Should -Throw "*not found*"
        }

        It "Should fail for invalid variable name with spaces" {
            # Arrange
            $testData = $script:TestNewDevVarData.InvalidVariableName

            # Skip if no test data provided
            if (-not $testData -or -not $testData.DeviceName) {
                Set-ItResult -Skipped -Because "No invalid variable name test data specified"
                return
            }

            $deviceName = $testData.DeviceName
            $varName = $testData.VariableName
            $varValue = $testData.VariableValue

            # Act & Assert - should fail due to ValidatePattern
            { New-CM7DeviceVariable -DeviceName $deviceName -VariableName $varName -Value $varValue -Force } | Should -Throw
        }

        It "Should fail for non-existent resource ID" {
            # Arrange
            $resourceId = 999999999
            $varName = "TestVar_Invalid"
            $varValue = "ShouldFail"

            # Act & Assert
            { New-CM7DeviceVariable -ResourceId $resourceId -VariableName $varName -Value $varValue -Force } | Should -Throw "*not found*"
        }

        It "Should handle empty VariableName parameter" {
            # Act & Assert - should fail due to ValidateNotNullOrEmpty
            { New-CM7DeviceVariable -DeviceName "Test-2016-1" -VariableName "" -Value "test" -Force } | Should -Throw
        }
    }

    Context "WhatIf Support" {

        It "Should support -WhatIf without making changes" {
            # Arrange
            $deviceName = $script:TestNewDevVarData.ByDeviceName.DeviceName
            $varName = "WhatIfTestVar_$($script:TestTimestamp)"
            $varValue = "WhatIfValue"

            # Act
            $result = New-CM7DeviceVariable -DeviceName $deviceName -VariableName $varName -Value $varValue -WhatIf

            # Assert - result should be null because WhatIf doesn't execute
            $result | Should -BeNullOrEmpty

            # Verify the variable was NOT created
            $verifyResult = Get-CM7DeviceVariable -DeviceName $deviceName -VariableName $varName
            $verifyResult | Should -BeNullOrEmpty
        }
    }
}
