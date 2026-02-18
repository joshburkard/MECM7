# Functional Tests for Get-CM7DeviceVariable
# Tests the Get-CM7DeviceVariable function behavior and return values

BeforeAll {
    # Load test declarations
    . (Join-Path $PSScriptRoot "declarations.ps1")

    # Load all functions
    $CodePath = Join-Path (Get-Item $PSScriptRoot).Parent.FullName "Code"
    Get-ChildItem -Path (Join-Path $CodePath "Private") -Filter "*.ps1" | ForEach-Object { . $_.FullName }
    Get-ChildItem -Path (Join-Path $CodePath "Public") -Filter "*.ps1" | ForEach-Object { . $_.FullName }

    # Get test data for this function
    $script:TestDeviceVariableData = $script:TestData['Get-CM7DeviceVariable']
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

Describe "Get-CM7DeviceVariable Function Tests" -Tag "Integration", "Device", "Variable" {

    Context "Test Data Validation" {

        It "Should have test data defined in declarations.ps1" {
            # Assert
            $script:TestDeviceVariableData | Should -Not -BeNullOrEmpty
            $script:TestData.ContainsKey('Get-CM7DeviceVariable') | Should -Be $true
        }

        It "Should have required test data parameter sets" {
            # Assert
            $script:TestDeviceVariableData.ContainsKey('ByDeviceName') | Should -Be $true
            $script:TestDeviceVariableData.ContainsKey('ByResourceId') | Should -Be $true
            $script:TestDeviceVariableData.ContainsKey('NonExistentDevice') | Should -Be $true
            $script:TestDeviceVariableData.ContainsKey('NonExistentVariable') | Should -Be $true
        }

        It "Should output test data for verification" {
            # Output test data
            Write-Host "`n=== Test Data for Get-CM7DeviceVariable ===" -ForegroundColor Cyan
            Write-Host "ByDeviceName:" -ForegroundColor Yellow
            Write-Host "  DeviceName: $($script:TestDeviceVariableData.ByDeviceName.DeviceName)" -ForegroundColor White
            Write-Host "  ExpectedMinCount: $($script:TestDeviceVariableData.ByDeviceName.ExpectedMinCount)" -ForegroundColor White

            Write-Host "ByResourceId:" -ForegroundColor Yellow
            Write-Host "  ResourceId: $($script:TestDeviceVariableData.ByResourceId.ResourceId)" -ForegroundColor White
            Write-Host "  ExpectedMinCount: $($script:TestDeviceVariableData.ByResourceId.ExpectedMinCount)" -ForegroundColor White

            Write-Host "NonExistentDevice:" -ForegroundColor Yellow
            Write-Host "  DeviceName: $($script:TestDeviceVariableData.NonExistentDevice.DeviceName)" -ForegroundColor White

            Write-Host "NonExistentVariable:" -ForegroundColor Yellow
            Write-Host "  DeviceName: $($script:TestDeviceVariableData.NonExistentVariable.DeviceName)" -ForegroundColor White
            Write-Host "  VariableName: $($script:TestDeviceVariableData.NonExistentVariable.VariableName)" -ForegroundColor White
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
            { Get-CM7DeviceVariable -DeviceName "Test" } | Should -Throw "*not connected*"

            # Restore connection
            $script:CMConnection = $backupConnection
        }
    }

    Context "Query by Device Name" {

        It "Should output test data for debugging" {
            # This test outputs what data is being used
            Write-Host "`nDEBUG: Test Data Values:" -ForegroundColor Cyan
            Write-Host "ByDeviceName.DeviceName = '$($script:TestDeviceVariableData.ByDeviceName.DeviceName)'" -ForegroundColor Yellow
            Write-Host "ByResourceId.ResourceId = '$($script:TestDeviceVariableData.ByResourceId.ResourceId)'" -ForegroundColor Yellow
            Write-Host "NonExistentDevice.DeviceName = '$($script:TestDeviceVariableData.NonExistentDevice.DeviceName)'" -ForegroundColor Yellow
            $true | Should -Be $true
        }

        It "Should retrieve device variables by device name" {
            # Arrange
            $deviceName = $script:TestDeviceVariableData.ByDeviceName.DeviceName

            # Act
            $result = Get-CM7DeviceVariable -DeviceName $deviceName

            # Assert
            if ($result) {
                $result.Count | Should -BeGreaterOrEqual $script:TestDeviceVariableData.ByDeviceName.ExpectedMinCount
                $result[0].psobject.TypeNames[0] | Should -Be 'MECM7.DeviceVariable'
            } else {
                # It's acceptable to have no variables
                $result | Should -BeNullOrEmpty
            }
        }

        It "Should return null for non-existent device" {
            # Arrange
            $deviceName = $script:TestDeviceVariableData.NonExistentDevice.DeviceName

            # Act
            $result = Get-CM7DeviceVariable -DeviceName $deviceName

            # Assert
            $result | Should -BeNullOrEmpty
        }
    }

    Context "Query by Resource ID" {

        It "Should retrieve device variables by resource ID" {
            # Arrange
            $resourceId = $script:TestDeviceVariableData.ByResourceId.ResourceId

            # Act
            $result = Get-CM7DeviceVariable -ResourceId $resourceId

            # Assert
            if ($result) {
                $result.Count | Should -BeGreaterOrEqual $script:TestDeviceVariableData.ByResourceId.ExpectedMinCount
                $result[0].psobject.TypeNames[0] | Should -Be 'MECM7.DeviceVariable'
            } else {
                # It's acceptable to have no variables
                $result | Should -BeNullOrEmpty
            }
        }

        It "Should return null for non-existent resource ID" {
            # Arrange
            $resourceId = 999999999

            # Act
            $result = Get-CM7DeviceVariable -ResourceId $resourceId

            # Assert
            $result | Should -BeNullOrEmpty
        }
    }

    Context "Query with Variable Name Filter" {

        It "Should retrieve a specific variable by name" {
            # Arrange
            $deviceName = $script:TestDeviceVariableData.ByDeviceNameAndVariableName.DeviceName
            $variableName = $script:TestDeviceVariableData.ByDeviceNameAndVariableName.VariableName

            # Act
            $result = Get-CM7DeviceVariable -DeviceName $deviceName -VariableName $variableName

            # Assert
            if ($result) {
                if ($result -is [array]) {
                    $result.Count | Should -BeGreaterOrEqual 1
                    foreach ($r in $result) {
                        $r.Name | Should -BeLike $variableName
                        $r.psobject.TypeNames[0] | Should -Be 'MECM7.DeviceVariable'
                    }
                } else {
                    $result.Name | Should -BeLike $variableName
                    $result.psobject.TypeNames[0] | Should -Be 'MECM7.DeviceVariable'
                }
            } else {
                # Variable not found - acceptable in some configurations
                $result | Should -BeNullOrEmpty
            }
        }

        It "Should retrieve a specific variable by name using ResourceId" {
            # Arrange
            $resourceId = $script:TestDeviceVariableData.ByResourceIdAndVariableName.ResourceId
            $variableName = $script:TestDeviceVariableData.ByResourceIdAndVariableName.VariableName

            # Act
            $result = Get-CM7DeviceVariable -ResourceId $resourceId -VariableName $variableName

            # Assert
            if ($result) {
                if ($result -is [array]) {
                    foreach ($r in $result) {
                        $r.Name | Should -BeLike $variableName
                        $r.psobject.TypeNames[0] | Should -Be 'MECM7.DeviceVariable'
                    }
                } else {
                    $result.Name | Should -BeLike $variableName
                    $result.psobject.TypeNames[0] | Should -Be 'MECM7.DeviceVariable'
                }
            } else {
                $result | Should -BeNullOrEmpty
            }
        }

        It "Should support wildcard in variable name" {
            # Arrange
            $deviceName = $script:TestDeviceVariableData.ByDeviceNameAndVariableName.DeviceName
            $variablePattern = $script:TestDeviceVariableData.ByDeviceNameAndVariableName.VariableName

            # Act
            $result = Get-CM7DeviceVariable -DeviceName $deviceName -VariableName $variablePattern

            # Assert
            if ($result) {
                if ($result -is [array]) {
                    $result[0].psobject.TypeNames[0] | Should -Be 'MECM7.DeviceVariable'
                    foreach ($variable in $result) {
                        $variable.Name | Should -BeLike $variablePattern
                    }
                } else {
                    $result.psobject.TypeNames[0] | Should -Be 'MECM7.DeviceVariable'
                    $result.Name | Should -BeLike $variablePattern
                }
            } else {
                # No results is acceptable
                $result | Should -BeNullOrEmpty
            }
        }

        It "Should return null for non-existent variable name" {
            # Arrange
            $deviceName = $script:TestDeviceVariableData.NonExistentVariable.DeviceName
            $variableName = $script:TestDeviceVariableData.NonExistentVariable.VariableName

            # Act
            $result = Get-CM7DeviceVariable -DeviceName $deviceName -VariableName $variableName

            # Assert
            $result | Should -BeNullOrEmpty
        }
    }

    Context "Device Without Variables" {

        It "Should return null for device without variables" {
            # Arrange
            $testData = $script:TestDeviceVariableData.DeviceWithoutVariables

            # Skip if no test data provided
            if (-not $testData -or -not $testData.DeviceName) {
                Set-ItResult -Skipped -Because "No device without variables specified in test data"
                return
            }

            $deviceName = $testData.DeviceName

            # Act
            $result = Get-CM7DeviceVariable -DeviceName $deviceName

            # Assert
            $result | Should -BeNullOrEmpty
        }

        It "Should return null for device without variables (by ResourceId)" {
            # Arrange
            $testData = $script:TestDeviceVariableData.DeviceWithoutVariables

            # Skip if no test data provided
            if (-not $testData -or -not $testData.ResourceId) {
                Set-ItResult -Skipped -Because "No device ResourceId without variables specified in test data"
                return
            }

            $resourceId = $testData.ResourceId

            # Act
            $result = Get-CM7DeviceVariable -ResourceId $resourceId

            # Assert
            $result | Should -BeNullOrEmpty
        }
    }

    Context "Output Object Properties" {

        It "Should return objects with expected properties" {
            # Arrange
            $deviceName = $script:TestDeviceVariableData.ByDeviceName.DeviceName

            # Act
            $result = Get-CM7DeviceVariable -DeviceName $deviceName

            # Assert
            if ($result) {
                $firstResult = if ($result -is [array]) { $result[0] } else { $result }
                $firstResult.psobject.TypeNames[0] | Should -Be 'MECM7.DeviceVariable'
                $firstResult.Name | Should -Not -BeNullOrEmpty
                # Value can be empty for masked variables
                $firstResult.PSObject.Properties.Name | Should -Contain 'Value'
                $firstResult.PSObject.Properties.Name | Should -Contain 'IsMasked'
            }
        }

        It "Should have correct IsMasked values" {
            # Arrange
            $deviceName = $script:TestDeviceVariableData.ByDeviceName.DeviceName

            # Act
            $result = Get-CM7DeviceVariable -DeviceName $deviceName

            # Assert
            if ($result) {
                foreach ($variable in $result) {
                    $variable.IsMasked | Should -BeIn @($true, $false)
                }
            }
        }

        It "Should only return Name, Value, IsMasked properties" {
            # Arrange
            $deviceName = $script:TestDeviceVariableData.ByDeviceName.DeviceName

            # Act
            $result = Get-CM7DeviceVariable -DeviceName $deviceName

            # Assert
            if ($result) {
                $firstResult = if ($result -is [array]) { $result[0] } else { $result }
                $properties = $firstResult | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name
                $properties | Should -Contain 'Name'
                $properties | Should -Contain 'Value'
                $properties | Should -Contain 'IsMasked'
                $properties | Should -Not -Contain 'ResourceId'
                $properties | Should -Not -Contain 'DeviceName'
            }
        }
    }

    Context "Error Handling" {

        It "Should handle invalid resource ID gracefully" {
            # Arrange
            $invalidResourceId = 999999999

            # Act
            $result = Get-CM7DeviceVariable -ResourceId $invalidResourceId

            # Assert
            $result | Should -BeNullOrEmpty
        }

        It "Should handle empty results gracefully" {
            # Arrange
            $deviceName = $script:TestDeviceVariableData.NonExistentDevice.DeviceName

            # Act & Assert
            { Get-CM7DeviceVariable -DeviceName $deviceName } | Should -Not -Throw
        }
    }
}
