# Functional Tests for Invoke-CM7Script
# Tests the Invoke-CM7Script function behavior and return values

BeforeAll {
    # Load test declarations
    . (Join-Path $PSScriptRoot "declarations.ps1")

    # Load all functions
    $CodePath = Join-Path (Get-Item $PSScriptRoot).Parent.FullName "Code"
    Get-ChildItem -Path (Join-Path $CodePath "Private") -Filter "*.ps1" | ForEach-Object { . $_.FullName }
    Get-ChildItem -Path (Join-Path $CodePath "Public") -Filter "*.ps1" | ForEach-Object { . $_.FullName }

    # Get test data for this function
    $script:TestInvokeData = $script:TestData['Invoke-CM7Script']
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

Describe "Invoke-CM7Script Function Tests" -Tag "Integration", "Script" {

    Context "Test Data Validation" {

        It "Should have test data defined in declarations.ps1" {
            # Assert
            $script:TestInvokeData | Should -Not -BeNullOrEmpty
            $script:TestData.ContainsKey('Invoke-CM7Script') | Should -Be $true
        }

        It "Should have required test data parameter sets" {
            # Assert
            $script:TestInvokeData.ContainsKey('ByScriptNameAndDeviceName') | Should -Be $true
            $script:TestInvokeData.ContainsKey('ByScriptGuidAndResourceId') | Should -Be $true
            $script:TestInvokeData.ContainsKey('ByScriptNameAndCollectionId') | Should -Be $true
        }

        It "Should output test data for verification" {
            # Output test data
            Write-Host "`n=== Test Data for Invoke-CM7Script ===" -ForegroundColor Cyan
            Write-Host "ByScriptNameAndDeviceName:" -ForegroundColor Yellow
            Write-Host "  ScriptName: $($script:TestInvokeData.ByScriptNameAndDeviceName.ScriptName)" -ForegroundColor White
            Write-Host "  DeviceName: $($script:TestInvokeData.ByScriptNameAndDeviceName.DeviceName)" -ForegroundColor White
            Write-Host "  ScriptParameters: $($script:TestInvokeData.ByScriptNameAndDeviceName.ScriptParameters | ConvertTo-Json -Compress)" -ForegroundColor White

            Write-Host "ByScriptGuidAndResourceId:" -ForegroundColor Yellow
            Write-Host "  ScriptGuid: $($script:TestInvokeData.ByScriptGuidAndResourceId.ScriptGuid)" -ForegroundColor White
            Write-Host "  ResourceId: $($script:TestInvokeData.ByScriptGuidAndResourceId.ResourceId)" -ForegroundColor White

            Write-Host "ByScriptNameAndCollectionId:" -ForegroundColor Yellow
            Write-Host "  ScriptName: $($script:TestInvokeData.ByScriptNameAndCollectionId.ScriptName)" -ForegroundColor White
            Write-Host "  CollectionId: $($script:TestInvokeData.ByScriptNameAndCollectionId.CollectionId)" -ForegroundColor White
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
            { Invoke-CM7Script -ScriptName "test" -DeviceName "test" } | Should -Throw "*not connected*"

            # Restore connection
            $script:CMConnection = $backupConnection
        }
    }

    Context "Parameter Validation" {

        It "Should require ScriptName or ScriptGuid" {
            # Assert - both ScriptName and ScriptGuid are in mandatory parameter sets
            $cmd = Get-Command Invoke-CM7Script
            $paramSets = $cmd.ParameterSets

            # All parameter sets should have either ScriptName or ScriptGuid as mandatory
            foreach ($ps in $paramSets) {
                $hasScriptName = $ps.Parameters | Where-Object { $_.Name -eq 'ScriptName' -and $_.IsMandatory }
                $hasScriptGuid = $ps.Parameters | Where-Object { $_.Name -eq 'ScriptGuid' -and $_.IsMandatory }
                ($null -ne $hasScriptName -or $null -ne $hasScriptGuid) | Should -Be $true
            }
        }

        It "Should require a target (DeviceName, ResourceId, or CollectionId)" {
            # Assert - each parameter set should have exactly one target parameter as mandatory
            $cmd = Get-Command Invoke-CM7Script
            $paramSets = $cmd.ParameterSets

            foreach ($ps in $paramSets) {
                $hasDevice = $ps.Parameters | Where-Object { $_.Name -eq 'DeviceName' -and $_.IsMandatory }
                $hasResource = $ps.Parameters | Where-Object { $_.Name -eq 'ResourceId' -and $_.IsMandatory }
                $hasCollection = $ps.Parameters | Where-Object { $_.Name -eq 'CollectionId' -and $_.IsMandatory }
                ($null -ne $hasDevice -or $null -ne $hasResource -or $null -ne $hasCollection) | Should -Be $true
            }
        }

        It "Should have ScriptParameters as optional hashtable parameter" {
            $cmd = Get-Command Invoke-CM7Script
            $param = $cmd.Parameters['ScriptParameters']
            $param | Should -Not -BeNullOrEmpty
            $param.ParameterType.Name | Should -Be 'Hashtable'
        }
    }

    Context "Invoke by Script Name and Device Name" {

        It "Should invoke script by name on a device by name" {
            # Arrange
            $scriptName = $script:TestInvokeData.ByScriptNameAndDeviceName.ScriptName
            $deviceName = $script:TestInvokeData.ByScriptNameAndDeviceName.DeviceName
            $scriptParams = $script:TestInvokeData.ByScriptNameAndDeviceName.ScriptParameters

            # Act
            $invokeParams = @{
                ScriptName       = $scriptName
                DeviceName       = $deviceName
            }
            if ($scriptParams -and $scriptParams.Count -gt 0) {
                $invokeParams.ScriptParameters = $scriptParams
            }
            $result = Invoke-CM7Script @invokeParams

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.OperationID | Should -BeGreaterThan 0
            $result.ScriptName | Should -Be $scriptName
            $result.ReturnValue | Should -Be 0
        }

        It "Should fail for non-existent script name" {
            # Act & Assert
            { Invoke-CM7Script -ScriptName "NonExistent-Script-999" -DeviceName "TEST" -ErrorAction Stop } | Should -Throw "*Could not find script*"
        }

        It "Should fail for non-existent device name" {
            # Arrange
            $scriptName = $script:TestInvokeData.ByScriptNameAndDeviceName.ScriptName

            # Act & Assert
            { Invoke-CM7Script -ScriptName $scriptName -DeviceName "NONEXISTENT-DEVICE-999" -ErrorAction Stop } | Should -Throw "*Could not find device*"
        }
    }

    Context "Invoke by Script GUID and Resource ID" {

        It "Should invoke script by GUID on a device by ResourceId" {
            # Arrange
            $scriptGuid = $script:TestInvokeData.ByScriptGuidAndResourceId.ScriptGuid
            $resourceId = $script:TestInvokeData.ByScriptGuidAndResourceId.ResourceId
            $scriptParams = $script:TestInvokeData.ByScriptGuidAndResourceId.ScriptParameters

            # Act
            $invokeParams = @{
                ScriptGuid  = $scriptGuid
                ResourceId  = $resourceId
            }
            if ($scriptParams -and $scriptParams.Count -gt 0) {
                $invokeParams.ScriptParameters = $scriptParams
            }
            $result = Invoke-CM7Script @invokeParams

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.OperationID | Should -BeGreaterThan 0
            $result.ScriptGuid | Should -Be $scriptGuid
            $result.ReturnValue | Should -Be 0
        }

        It "Should fail for non-existent script GUID" {
            # Act & Assert
            { Invoke-CM7Script -ScriptGuid "00000000-0000-0000-0000-000000000000" -ResourceId 16777220 -ErrorAction Stop } | Should -Throw "*Could not find script*"
        }
    }

    Context "Invoke by Script Name and Collection ID" {

        It "Should invoke script on a collection" {
            # Arrange
            $scriptName = $script:TestInvokeData.ByScriptNameAndCollectionId.ScriptName
            $collectionId = $script:TestInvokeData.ByScriptNameAndCollectionId.CollectionId
            $scriptParams = $script:TestInvokeData.ByScriptNameAndCollectionId.ScriptParameters

            # Act
            $invokeParams = @{
                ScriptName   = $scriptName
                CollectionId = $collectionId
            }
            if ($scriptParams -and $scriptParams.Count -gt 0) {
                $invokeParams.ScriptParameters = $scriptParams
            }
            $result = Invoke-CM7Script @invokeParams

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.OperationID | Should -BeGreaterThan 0
            $result.ScriptName | Should -Be $scriptName
            $result.ReturnValue | Should -Be 0
        }
    }

    Context "Return Object Properties" {

        It "Should return object with expected properties" {
            # Arrange
            $scriptName = $script:TestInvokeData.ByScriptNameAndDeviceName.ScriptName
            $deviceName = $script:TestInvokeData.ByScriptNameAndDeviceName.DeviceName
            $scriptParams = $script:TestInvokeData.ByScriptNameAndDeviceName.ScriptParameters

            # Act
            $invokeParams = @{
                ScriptName = $scriptName
                DeviceName = $deviceName
            }
            if ($scriptParams -and $scriptParams.Count -gt 0) {
                $invokeParams.ScriptParameters = $scriptParams
            }
            $result = Invoke-CM7Script @invokeParams

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.PSObject.Properties.Name | Should -Contain 'OperationID'
            $result.PSObject.Properties.Name | Should -Contain 'ScriptName'
            $result.PSObject.Properties.Name | Should -Contain 'ScriptGuid'
            $result.PSObject.Properties.Name | Should -Contain 'ReturnValue'
        }

        It "Should have PSTypeName set correctly" {
            # Arrange
            $scriptName = $script:TestInvokeData.ByScriptNameAndDeviceName.ScriptName
            $deviceName = $script:TestInvokeData.ByScriptNameAndDeviceName.DeviceName

            # Act
            $result = Invoke-CM7Script -ScriptName $scriptName -DeviceName $deviceName

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.PSObject.TypeNames[0] | Should -Be 'MECM7.ScriptInvocation'
        }
    }

    Context "Verbose Output" {

        It "Should provide verbose output when requested" {
            # Arrange
            $scriptName = $script:TestInvokeData.ByScriptNameAndDeviceName.ScriptName
            $deviceName = $script:TestInvokeData.ByScriptNameAndDeviceName.DeviceName

            # Act & Assert
            $verboseOutput = Invoke-CM7Script -ScriptName $scriptName -DeviceName $deviceName -Verbose 4>&1
            $verboseOutput | Should -Not -BeNullOrEmpty
            $verboseOutput | Where-Object { $_ -match "Running Invoke-CM7Script" } | Should -Not -BeNullOrEmpty
        }
    }
}

AfterAll {
    # Optional: Close CIM session if needed
    if ($script:CMConnection.CimSession) {
        Write-Host "Cleaning up CIM session..." -ForegroundColor Yellow
        # Remove-CimSession -CimSession $script:CMConnection.CimSession -ErrorAction SilentlyContinue
    }
}
