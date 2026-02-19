# Functional Tests for Invoke-CM7ClientNotification
# Tests the Invoke-CM7ClientNotification function behavior and return values

BeforeAll {
    # Load test declarations
    . (Join-Path $PSScriptRoot "declarations.ps1")

    # Load all functions
    $CodePath = Join-Path (Get-Item $PSScriptRoot).Parent.FullName "Code"
    Get-ChildItem -Path (Join-Path $CodePath "Private") -Filter "*.ps1" | ForEach-Object { . $_.FullName }
    Get-ChildItem -Path (Join-Path $CodePath "Public") -Filter "*.ps1" | ForEach-Object { . $_.FullName }

    # Get test data for this function
    $script:TestNotificationData = $script:TestData['Invoke-CM7ClientNotification']
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

Describe "Invoke-CM7ClientNotification Function Tests" -Tag "Integration", "ClientNotification" {

    Context "Test Data Validation" {

        It "Should have test data defined in declarations.ps1" {
            # Assert
            $script:TestNotificationData | Should -Not -BeNullOrEmpty
            $script:TestData.ContainsKey('Invoke-CM7ClientNotification') | Should -Be $true
        }

        It "Should have required test data parameter sets" {
            # Assert
            $script:TestNotificationData.ContainsKey('ByDeviceName') | Should -Be $true
            $script:TestNotificationData.ContainsKey('ByResourceId') | Should -Be $true
            $script:TestNotificationData.ContainsKey('ByCollectionId') | Should -Be $true
            $script:TestNotificationData.ContainsKey('ByCollectionName') | Should -Be $true
        }

        It "Should output test data for verification" {
            # Output test data
            Write-Host "`n=== Test Data for Invoke-CM7ClientNotification ===" -ForegroundColor Cyan
            Write-Host "ByDeviceName:" -ForegroundColor Yellow
            Write-Host "  ActionType: $($script:TestNotificationData.ByDeviceName.ActionType)" -ForegroundColor White
            Write-Host "  DeviceName: $($script:TestNotificationData.ByDeviceName.DeviceName)" -ForegroundColor White

            Write-Host "ByResourceId:" -ForegroundColor Yellow
            Write-Host "  ActionType: $($script:TestNotificationData.ByResourceId.ActionType)" -ForegroundColor White
            Write-Host "  ResourceId: $($script:TestNotificationData.ByResourceId.ResourceId)" -ForegroundColor White

            Write-Host "ByCollectionId:" -ForegroundColor Yellow
            Write-Host "  ActionType: $($script:TestNotificationData.ByCollectionId.ActionType)" -ForegroundColor White
            Write-Host "  CollectionId: $($script:TestNotificationData.ByCollectionId.CollectionId)" -ForegroundColor White

            Write-Host "ByCollectionName:" -ForegroundColor Yellow
            Write-Host "  ActionType: $($script:TestNotificationData.ByCollectionName.ActionType)" -ForegroundColor White
            Write-Host "  CollectionName: $($script:TestNotificationData.ByCollectionName.CollectionName)" -ForegroundColor White
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
            { Invoke-CM7ClientNotification -ActionType ClientNotificationRequestMachinePolicyNow -DeviceName "test" } | Should -Throw "*not connected*"

            # Restore connection
            $script:CMConnection = $backupConnection
        }
    }

    Context "Parameter Validation" {

        It "Should require ActionType parameter" {
            $cmd = Get-Command Invoke-CM7ClientNotification
            $param = $cmd.Parameters['ActionType']
            $param | Should -Not -BeNullOrEmpty

            # ActionType should be mandatory in all parameter sets
            foreach ($ps in $cmd.ParameterSets) {
                $actionParam = $ps.Parameters | Where-Object { $_.Name -eq 'ActionType' }
                $actionParam.IsMandatory | Should -Be $true
            }
        }

        It "Should have ActionType as ValidateSet with all notification types" {
            $cmd = Get-Command Invoke-CM7ClientNotification
            $param = $cmd.Parameters['ActionType']
            $validateSet = $param.Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] }
            $validateSet | Should -Not -BeNullOrEmpty

            $expectedTypes = @(
                'ClientNotificationRequestMachinePolicyNow',
                'ClientNotificationRequestUsersPolicyNow',
                'ClientNotificationRequestDDRNow',
                'ClientNotificationRequestHWInvNow',
                'ClientNotificationRequestSWInvNow',
                'ClientNotificationAppDeplEvalNow',
                'ClientNotificationSUMDeplEvalNow',
                'ClientNotificationCheckComplianceNow',
                'ClientRequestSUPChangeNow',
                'ClientRequestDHAChangeNow',
                'ClientNotificationRebootMachine',
                'ClientNotificationWakeUpClientNow',
                'DiagnosticsEnableVerboseLogging',
                'DiagnosticsDisableVerboseLogging',
                'DiagnosticsCollectFiles',
                'EndpointProtectionFullScan',
                'EndpointProtectionQuickScan',
                'EndpointProtectionDownloadDefinition',
                'EndpointProtectionEvaluateSoftwareUpdate',
                'EndpointProtectionExcludeScanPaths',
                'EndpointProtectionAllowThreat',
                'EndpointProtectionRestoreQuarantinedItems',
                'EndpointProtectionRestoreWithDeps'
            )

            foreach ($type in $expectedTypes) {
                $validateSet.ValidValues | Should -Contain $type
            }
        }

        It "Should require a target (DeviceName, ResourceId, CollectionId, or CollectionName)" {
            $cmd = Get-Command Invoke-CM7ClientNotification
            $paramSets = $cmd.ParameterSets

            foreach ($ps in $paramSets) {
                $hasDevice = $ps.Parameters | Where-Object { $_.Name -eq 'DeviceName' -and $_.IsMandatory }
                $hasResource = $ps.Parameters | Where-Object { $_.Name -eq 'ResourceId' -and $_.IsMandatory }
                $hasCollectionId = $ps.Parameters | Where-Object { $_.Name -eq 'CollectionId' -and $_.IsMandatory }
                $hasCollectionName = $ps.Parameters | Where-Object { $_.Name -eq 'CollectionName' -and $_.IsMandatory }
                ($null -ne $hasDevice -or $null -ne $hasResource -or $null -ne $hasCollectionId -or $null -ne $hasCollectionName) | Should -Be $true
            }
        }

        It "Should support ShouldProcess (-WhatIf and -Confirm)" {
            $cmd = Get-Command Invoke-CM7ClientNotification
            $cmd.Parameters.ContainsKey('WhatIf') | Should -Be $true
            $cmd.Parameters.ContainsKey('Confirm') | Should -Be $true
        }

        It "Should have four parameter sets" {
            $cmd = Get-Command Invoke-CM7ClientNotification
            $cmd.ParameterSets.Count | Should -Be 4
        }

        It "Should reject invalid ActionType values" {
            { Invoke-CM7ClientNotification -ActionType "InvalidAction" -DeviceName "test" } | Should -Throw
        }
    }

    Context "Send Notification by Device Name" {

        It "Should send machine policy notification by device name" {
            # Arrange
            $actionType = $script:TestNotificationData.ByDeviceName.ActionType
            $deviceName = $script:TestNotificationData.ByDeviceName.DeviceName

            # Act
            $result = Invoke-CM7ClientNotification -ActionType $actionType -DeviceName $deviceName

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.OperationID | Should -BeGreaterThan 0
            $result.ActionType | Should -Be $actionType
            $result.ReturnValue | Should -Be 0
        }

        It "Should fail for non-existent device name" {
            # Act & Assert
            { Invoke-CM7ClientNotification -ActionType ClientNotificationRequestMachinePolicyNow -DeviceName "NONEXISTENT-DEVICE-999" -ErrorAction Stop } | Should -Throw "*Could not find device*"
        }
    }

    Context "Send Notification by Resource ID" {

        It "Should send notification by ResourceId" {
            # Arrange
            $actionType = $script:TestNotificationData.ByResourceId.ActionType
            $resourceId = $script:TestNotificationData.ByResourceId.ResourceId

            # Act
            $result = Invoke-CM7ClientNotification -ActionType $actionType -ResourceId $resourceId

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.OperationID | Should -BeGreaterThan 0
            $result.ActionType | Should -Be $actionType
            $result.ReturnValue | Should -Be 0
        }

        It "Should send notification to multiple ResourceIds" {
            # Arrange
            $actionType = $script:TestNotificationData.ByResourceId.ActionType
            $resourceIds = $script:TestNotificationData.ByResourceId.ResourceIdArray

            # Act
            if ($resourceIds -and $resourceIds.Count -gt 1) {
                $result = Invoke-CM7ClientNotification -ActionType $actionType -ResourceId $resourceIds

                # Assert
                $result | Should -Not -BeNullOrEmpty
                $result.OperationID | Should -BeGreaterThan 0
                $result.ReturnValue | Should -Be 0
            }
            else {
                Set-ItResult -Skipped -Because "Multiple ResourceIds not configured in test data"
            }
        }
    }

    Context "Send Notification by Collection ID" {

        It "Should send notification to a collection by CollectionId" {
            # Arrange
            $actionType = $script:TestNotificationData.ByCollectionId.ActionType
            $collectionId = $script:TestNotificationData.ByCollectionId.CollectionId

            # Act
            $result = Invoke-CM7ClientNotification -ActionType $actionType -CollectionId $collectionId

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.OperationID | Should -BeGreaterThan 0
            $result.ActionType | Should -Be $actionType
            $result.ReturnValue | Should -Be 0
        }
    }

    Context "Send Notification by Collection Name" {

        It "Should send notification to a collection by CollectionName" {
            # Arrange
            $actionType = $script:TestNotificationData.ByCollectionName.ActionType
            $collectionName = $script:TestNotificationData.ByCollectionName.CollectionName

            # Act
            $result = Invoke-CM7ClientNotification -ActionType $actionType -CollectionName $collectionName

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.OperationID | Should -BeGreaterThan 0
            $result.ActionType | Should -Be $actionType
            $result.ReturnValue | Should -Be 0
        }

        It "Should fail for non-existent collection name" {
            # Act & Assert
            { Invoke-CM7ClientNotification -ActionType ClientNotificationRequestMachinePolicyNow -CollectionName "NonExistent-Collection-999" -ErrorAction Stop } | Should -Throw "*Could not find collection*"
        }
    }

    Context "Different Action Types" {

        It "Should send hardware inventory notification" {
            # Arrange
            $deviceName = $script:TestNotificationData.ByDeviceName.DeviceName

            # Act
            $result = Invoke-CM7ClientNotification -ActionType ClientNotificationRequestHWInvNow -DeviceName $deviceName

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.OperationID | Should -BeGreaterThan 0
            $result.ActionType | Should -Be 'ClientNotificationRequestHWInvNow'
            $result.ReturnValue | Should -Be 0
        }

        It "Should send software inventory notification" {
            # Arrange
            $deviceName = $script:TestNotificationData.ByDeviceName.DeviceName

            # Act
            $result = Invoke-CM7ClientNotification -ActionType ClientNotificationRequestSWInvNow -DeviceName $deviceName

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.OperationID | Should -BeGreaterThan 0
            $result.ActionType | Should -Be 'ClientNotificationRequestSWInvNow'
            $result.ReturnValue | Should -Be 0
        }

        It "Should send software updates deployment evaluation notification" {
            # Arrange
            $deviceName = $script:TestNotificationData.ByDeviceName.DeviceName

            # Act
            $result = Invoke-CM7ClientNotification -ActionType ClientNotificationSUMDeplEvalNow -DeviceName $deviceName

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.OperationID | Should -BeGreaterThan 0
            $result.ActionType | Should -Be 'ClientNotificationSUMDeplEvalNow'
            $result.ReturnValue | Should -Be 0
        }

        It "Should send application deployment evaluation notification" {
            # Arrange
            $deviceName = $script:TestNotificationData.ByDeviceName.DeviceName

            # Act
            $result = Invoke-CM7ClientNotification -ActionType ClientNotificationAppDeplEvalNow -DeviceName $deviceName

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.OperationID | Should -BeGreaterThan 0
            $result.ActionType | Should -Be 'ClientNotificationAppDeplEvalNow'
            $result.ReturnValue | Should -Be 0
        }

        It "Should send DDR notification" {
            # Arrange
            $deviceName = $script:TestNotificationData.ByDeviceName.DeviceName

            # Act
            $result = Invoke-CM7ClientNotification -ActionType ClientNotificationRequestDDRNow -DeviceName $deviceName

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.OperationID | Should -BeGreaterThan 0
            $result.ActionType | Should -Be 'ClientNotificationRequestDDRNow'
            $result.ReturnValue | Should -Be 0
        }
    }

    Context "Return Object Properties" {

        It "Should return object with expected properties" {
            # Arrange
            $actionType = $script:TestNotificationData.ByDeviceName.ActionType
            $deviceName = $script:TestNotificationData.ByDeviceName.DeviceName

            # Act
            $result = Invoke-CM7ClientNotification -ActionType $actionType -DeviceName $deviceName

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.PSObject.Properties.Name | Should -Contain 'OperationID'
            $result.PSObject.Properties.Name | Should -Contain 'ActionType'
            $result.PSObject.Properties.Name | Should -Contain 'ReturnValue'
        }

        It "Should have PSTypeName set correctly" {
            # Arrange
            $actionType = $script:TestNotificationData.ByDeviceName.ActionType
            $deviceName = $script:TestNotificationData.ByDeviceName.DeviceName

            # Act
            $result = Invoke-CM7ClientNotification -ActionType $actionType -DeviceName $deviceName

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.PSObject.TypeNames[0] | Should -Be 'MECM7.ClientNotification'
        }
    }

    Context "WhatIf Support" {

        It "Should support -WhatIf without executing" {
            # Arrange
            $actionType = $script:TestNotificationData.ByDeviceName.ActionType
            $deviceName = $script:TestNotificationData.ByDeviceName.DeviceName

            # Act
            $result = Invoke-CM7ClientNotification -ActionType $actionType -DeviceName $deviceName -WhatIf

            # Assert - WhatIf should return no output
            $result | Should -BeNullOrEmpty
        }
    }

    Context "Verbose Output" {

        It "Should provide verbose output when requested" {
            # Arrange
            $actionType = $script:TestNotificationData.ByDeviceName.ActionType
            $deviceName = $script:TestNotificationData.ByDeviceName.DeviceName

            # Act & Assert
            $verboseOutput = Invoke-CM7ClientNotification -ActionType $actionType -DeviceName $deviceName -Verbose 4>&1
            $verboseOutput | Should -Not -BeNullOrEmpty
            $verboseOutput | Where-Object { $_ -match "Running Invoke-CM7ClientNotification" } | Should -Not -BeNullOrEmpty
            $verboseOutput | Where-Object { $_ -match "Client action type:" } | Should -Not -BeNullOrEmpty
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
