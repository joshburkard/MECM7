# Functional Tests for Get-CM7ScriptExecutionStatus
# Tests the Get-CM7ScriptExecutionStatus function behavior and return values

BeforeAll {
    # Load test declarations
    . (Join-Path $PSScriptRoot "declarations.ps1")

    # Load all functions
    $CodePath = Join-Path (Get-Item $PSScriptRoot).Parent.FullName "Code"
    Get-ChildItem -Path (Join-Path $CodePath "Private") -Filter "*.ps1" | ForEach-Object { . $_.FullName }
    Get-ChildItem -Path (Join-Path $CodePath "Public") -Filter "*.ps1" | ForEach-Object { . $_.FullName }

    # Get test data for this function
    $script:TestStatusData = $script:TestData['Get-CM7ScriptExecutionStatus']
    $script:TestConnectData = $script:TestData['Connect-CM7']
    $script:TestInvokeData = $script:TestData['Invoke-CM7Script']

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

Describe "Get-CM7ScriptExecutionStatus Function Tests" -Tag "Integration", "Script" {

    Context "Test Data Validation" {

        It "Should have test data defined in declarations.ps1" {
            # Assert
            $script:TestStatusData | Should -Not -BeNullOrEmpty
            $script:TestData.ContainsKey('Get-CM7ScriptExecutionStatus') | Should -Be $true
        }

        It "Should have required test data parameter sets" {
            # Assert
            $script:TestStatusData.ContainsKey('ByClientOperationId') | Should -Be $true
            $script:TestStatusData.ContainsKey('NonExistent') | Should -Be $true
        }

        It "Should output test data for verification" {
            # Output test data
            Write-Host "`n=== Test Data for Get-CM7ScriptExecutionStatus ===" -ForegroundColor Cyan
            Write-Host "ByClientOperationId:" -ForegroundColor Yellow
            Write-Host "  ClientOperationId: $($script:TestStatusData.ByClientOperationId.ClientOperationId)" -ForegroundColor White

            if ($script:TestStatusData.ContainsKey('ByScriptGuidAndResourceId')) {
                Write-Host "ByScriptGuidAndResourceId:" -ForegroundColor Yellow
                Write-Host "  ScriptGuid: $($script:TestStatusData.ByScriptGuidAndResourceId.ScriptGuid)" -ForegroundColor White
                Write-Host "  TargetResourceId: $($script:TestStatusData.ByScriptGuidAndResourceId.TargetResourceId)" -ForegroundColor White
            }

            Write-Host "NonExistent:" -ForegroundColor Yellow
            Write-Host "  ClientOperationId: $($script:TestStatusData.NonExistent.ClientOperationId)" -ForegroundColor White
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
            { Get-CM7ScriptExecutionStatus -ClientOperationId 12345 } | Should -Throw "*not connected*"

            # Restore connection
            $script:CMConnection = $backupConnection
        }
    }

    Context "Parameter Validation" {

        It "Should have ClientOperationId as optional parameter" {
            $cmd = Get-Command Get-CM7ScriptExecutionStatus
            $param = $cmd.Parameters['ClientOperationId']
            $param | Should -Not -BeNullOrEmpty
            $param.ParameterType.Name | Should -Be 'Int32'
        }

        It "Should have ScriptName parameter" {
            $cmd = Get-Command Get-CM7ScriptExecutionStatus
            $param = $cmd.Parameters['ScriptName']
            $param | Should -Not -BeNullOrEmpty
            $param.ParameterType.Name | Should -Be 'String'
        }

        It "Should have CollectionName parameter" {
            $cmd = Get-Command Get-CM7ScriptExecutionStatus
            $param = $cmd.Parameters['CollectionName']
            $param | Should -Not -BeNullOrEmpty
            $param.ParameterType.Name | Should -Be 'String'
        }

        It "Should have CollectionId parameter" {
            $cmd = Get-Command Get-CM7ScriptExecutionStatus
            $param = $cmd.Parameters['CollectionId']
            $param | Should -Not -BeNullOrEmpty
            $param.ParameterType.Name | Should -Be 'String'
        }

        It "Should default to 'noFilter' parameter set" {
            $cmd = Get-Command Get-CM7ScriptExecutionStatus
            $cmd.DefaultParameterSet | Should -Be 'noFilter'
        }
    }

    Context "List Mode (no ClientOperationId)" {

        It "Should return a summary list when called without parameters" {
            # Act
            $result = Get-CM7ScriptExecutionStatus

            # Assert
            $result | Should -Not -BeNullOrEmpty
            # In list mode, results should be summary objects without detailed Results property
            $firstResult = @($result)[0]
            $firstResult.PSObject.Properties.Name | Should -Contain 'OperationID'
            $firstResult.PSObject.Properties.Name | Should -Contain 'ScriptName'
            $firstResult.PSObject.Properties.Name | Should -Contain 'ScriptGuid'
            $firstResult.PSObject.Properties.Name | Should -Contain 'CollectionID'
            $firstResult.PSObject.Properties.Name | Should -Contain 'CollectionName'
            $firstResult.PSObject.Properties.Name | Should -Contain 'LastUpdateTime'
        }

        It "Should return summary objects with PSTypeName 'MECM7.ScriptExecutionSummary'" {
            # Act
            $result = Get-CM7ScriptExecutionStatus

            # Assert
            if ($result) {
                $firstResult = @($result)[0]
                $firstResult.PSObject.TypeNames[0] | Should -Be 'MECM7.ScriptExecutionSummary'
            }
        }
    }

    Context "Get Status by ClientOperationId" {

        It "Should return detailed status for a known operation ID" {
            # Arrange
            $operationId = $script:TestStatusData.ByClientOperationId.ClientOperationId

            # Act
            $result = Get-CM7ScriptExecutionStatus -ClientOperationId $operationId

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.OperationID | Should -Be $operationId
            $result.ScriptName | Should -Not -BeNullOrEmpty
            $result.PSObject.Properties.Name | Should -Contain 'Results'
            $result.PSObject.Properties.Name | Should -Contain 'Status'
            $result.PSObject.Properties.Name | Should -Contain 'TotalClients'
            $result.PSObject.Properties.Name | Should -Contain 'CompletedClients'
        }

        It "Should return 'not found' status for non-existent operation ID" {
            # Arrange
            $operationId = $script:TestStatusData.NonExistent.ClientOperationId

            # Act
            $result = Get-CM7ScriptExecutionStatus -ClientOperationId $operationId

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.Status | Should -Be 'not found'
        }
    }

    Context "Invoke and Track End-to-End" {

        It "Should return status for a freshly invoked script" {
            # Arrange - invoke a script first
            $scriptName = $script:TestInvokeData.ByScriptNameAndDeviceName.ScriptName
            $deviceName = $script:TestInvokeData.ByScriptNameAndDeviceName.DeviceName
            $scriptParams = $script:TestInvokeData.ByScriptNameAndDeviceName.ScriptParameters

            $invokeParams = @{
                ScriptName = $scriptName
                DeviceName = $deviceName
            }
            if ($scriptParams -and $scriptParams.Count -gt 0) {
                $invokeParams.ScriptParameters = $scriptParams
            }

            $invocation = Invoke-CM7Script @invokeParams
            $invocation | Should -Not -BeNullOrEmpty
            $invocation.OperationID | Should -BeGreaterThan 0

            Write-Host "  Invoked script '$scriptName' on '$deviceName' with OperationID: $($invocation.OperationID)" -ForegroundColor Yellow

            # Act - get the execution status
            $result = Get-CM7ScriptExecutionStatus -ClientOperationId $invocation.OperationID

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.OperationID | Should -Be $invocation.OperationID
            $result.ScriptName | Should -Be $scriptName
            $result.Status | Should -Not -Be 'not found'
        }

        It "Should eventually show completed results when polling" {
            # Arrange - invoke a script
            $scriptName = $script:TestInvokeData.ByScriptNameAndDeviceName.ScriptName
            $deviceName = $script:TestInvokeData.ByScriptNameAndDeviceName.DeviceName
            $scriptParams = $script:TestInvokeData.ByScriptNameAndDeviceName.ScriptParameters

            $invokeParams = @{
                ScriptName = $scriptName
                DeviceName = $deviceName
            }
            if ($scriptParams -and $scriptParams.Count -gt 0) {
                $invokeParams.ScriptParameters = $scriptParams
            }

            $invocation = Invoke-CM7Script @invokeParams
            $invocation | Should -Not -BeNullOrEmpty

            Write-Host "  Polling for completion of OperationID: $($invocation.OperationID)" -ForegroundColor Yellow

            # Act - poll for completion
            $timeout = $script:TestTimeout
            $interval = $script:TestPollingInterval
            $elapsed = 0
            $result = $null

            while ($elapsed -lt $timeout) {
                $result = Get-CM7ScriptExecutionStatus -ClientOperationId $invocation.OperationID
                if ($result -and $result.CompletedClients -gt 0) {
                    Write-Host "  Script completed on $($result.CompletedClients)/$($result.TotalClients) clients after ${elapsed}s" -ForegroundColor Green
                    break
                }
                Start-Sleep -Seconds $interval
                $elapsed += $interval
                Write-Host "  Waiting... elapsed: ${elapsed}s" -ForegroundColor DarkGray
            }

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.CompletedClients | Should -BeGreaterThan 0
            $result.Results | Should -Not -BeNullOrEmpty
            $result.Results.Count | Should -BeGreaterThan 0
        }
    }

    Context "Filter by ScriptName" {

        It "Should filter results by script name" {
            # Arrange
            $scriptName = $script:TestInvokeData.ByScriptNameAndDeviceName.ScriptName

            # Act
            $result = Get-CM7ScriptExecutionStatus -ScriptName $scriptName

            # Assert
            $result | Should -Not -BeNullOrEmpty
            foreach ($r in @($result)) {
                $r.ScriptName | Should -Be $scriptName
            }
        }
    }

    Context "Return Object Properties" {

        It "Should return object with expected properties for detail mode" {
            # Arrange
            $operationId = $script:TestStatusData.ByClientOperationId.ClientOperationId

            # Act
            $result = Get-CM7ScriptExecutionStatus -ClientOperationId $operationId

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.PSObject.Properties.Name | Should -Contain 'OperationID'
            $result.PSObject.Properties.Name | Should -Contain 'ScriptName'
            $result.PSObject.Properties.Name | Should -Contain 'ScriptVersion'
            $result.PSObject.Properties.Name | Should -Contain 'ScriptGuid'
            $result.PSObject.Properties.Name | Should -Contain 'CollectionID'
            $result.PSObject.Properties.Name | Should -Contain 'CollectionName'
            $result.PSObject.Properties.Name | Should -Contain 'Results'
            $result.PSObject.Properties.Name | Should -Contain 'Status'
            $result.PSObject.Properties.Name | Should -Contain 'TotalClients'
            $result.PSObject.Properties.Name | Should -Contain 'CompletedClients'
            $result.PSObject.Properties.Name | Should -Contain 'FailedClients'
            $result.PSObject.Properties.Name | Should -Contain 'OfflineClients'
            $result.PSObject.Properties.Name | Should -Contain 'NotApplicableClients'
            $result.PSObject.Properties.Name | Should -Contain 'UnknownClients'
            $result.PSObject.Properties.Name | Should -Contain 'LastUpdateTime'
        }

        It "Should have PSTypeName set correctly for detail mode" {
            # Arrange
            $operationId = $script:TestStatusData.ByClientOperationId.ClientOperationId

            # Act
            $result = Get-CM7ScriptExecutionStatus -ClientOperationId $operationId

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.PSObject.TypeNames[0] | Should -Be 'MECM7.ScriptExecutionStatus'
        }

        It "Should include per-device result properties when results exist" {
            # Arrange
            $operationId = $script:TestStatusData.ByClientOperationId.ClientOperationId

            # Act
            $result = Get-CM7ScriptExecutionStatus -ClientOperationId $operationId

            # Assert
            if ($result -and $result.Results) {
                $deviceResult = $result.Results[0]
                $deviceResult.PSObject.Properties.Name | Should -Contain 'ResourceID'
                $deviceResult.PSObject.Properties.Name | Should -Contain 'DeviceName'
                $deviceResult.PSObject.Properties.Name | Should -Contain 'ScriptExecutionState'
                $deviceResult.PSObject.Properties.Name | Should -Contain 'ScriptExitCode'
                $deviceResult.PSObject.Properties.Name | Should -Contain 'ScriptOutput'
                $deviceResult.PSObject.Properties.Name | Should -Contain 'OutputObject'
            }
        }
    }

    Context "Verbose Output" {

        It "Should provide verbose output when requested" {
            # Arrange
            $operationId = $script:TestStatusData.ByClientOperationId.ClientOperationId

            # Act & Assert
            $verboseOutput = Get-CM7ScriptExecutionStatus -ClientOperationId $operationId -Verbose 4>&1
            $verboseOutput | Should -Not -BeNullOrEmpty
            $verboseOutput | Where-Object { $_ -match "Running Get-CM7ScriptExecutionStatus" } | Should -Not -BeNullOrEmpty
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
