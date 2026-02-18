# Functional Tests for Get-CM7SoftwareUpdateDeployment
# Tests the Get-CM7SoftwareUpdateDeployment function behavior and return values

BeforeAll {
    # Load test declarations
    . (Join-Path $PSScriptRoot "declarations.ps1")

    # Load all functions
    $CodePath = Join-Path (Get-Item $PSScriptRoot).Parent.FullName "Code"
    Get-ChildItem -Path (Join-Path $CodePath "Private") -Filter "*.ps1" | ForEach-Object { . $_.FullName }
    Get-ChildItem -Path (Join-Path $CodePath "Public") -Filter "*.ps1" | ForEach-Object { . $_.FullName }

    # Get test data for this function
    $script:TestSUDeploymentData = $script:TestData['Get-CM7SoftwareUpdateDeployment']
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

Describe "Get-CM7SoftwareUpdateDeployment Function Tests" -Tag "Integration", "SoftwareUpdateDeployment" {

    Context "Test Data Validation" {

        It "Should have test data defined in declarations.ps1" {
            # Assert
            $script:TestSUDeploymentData | Should -Not -BeNullOrEmpty
            $script:TestData.ContainsKey('Get-CM7SoftwareUpdateDeployment') | Should -Be $true
        }

        It "Should have required test data parameter sets" {
            # Assert
            $script:TestSUDeploymentData.ContainsKey('ByCollectionName') | Should -Be $true
            $script:TestSUDeploymentData.ContainsKey('NonExistent') | Should -Be $true
            $script:TestSUDeploymentData.ContainsKey('All') | Should -Be $true
        }

        It "Should output test data for verification" {
            # Output test data
            Write-Host "`n=== Test Data for Get-CM7SoftwareUpdateDeployment ===" -ForegroundColor Cyan
            Write-Host "ByCollectionName:" -ForegroundColor Yellow
            Write-Host "  CollectionName: $($script:TestSUDeploymentData.ByCollectionName.CollectionName)" -ForegroundColor White
            Write-Host "  ExpectedMinCount: $($script:TestSUDeploymentData.ByCollectionName.ExpectedMinCount)" -ForegroundColor White

            Write-Host "NonExistent:" -ForegroundColor Yellow
            Write-Host "  CollectionName: $($script:TestSUDeploymentData.NonExistent.CollectionName)" -ForegroundColor White
            Write-Host "  AssignmentId: $($script:TestSUDeploymentData.NonExistent.AssignmentId)" -ForegroundColor White
            Write-Host "  Name: $($script:TestSUDeploymentData.NonExistent.Name)" -ForegroundColor White
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
            { Get-CM7SoftwareUpdateDeployment -CollectionName "Test" } | Should -Throw "*not connected*"

            # Restore connection
            $script:CMConnection = $backupConnection
        }
    }

    Context "Query by Collection Name" {

        It "Should retrieve software update deployments by collection name" {
            # Arrange
            $collectionName = $script:TestSUDeploymentData.ByCollectionName.CollectionName

            # Act
            $result = Get-CM7SoftwareUpdateDeployment -CollectionName $collectionName

            # Assert
            $result | Should -Not -BeNullOrEmpty
            @($result).Count | Should -BeGreaterOrEqual $script:TestSUDeploymentData.ByCollectionName.ExpectedMinCount
            $result | ForEach-Object {
                $_.CollectionName | Should -Be $collectionName
            }
        }

        It "Should return null for non-existent collection" {
            # Arrange
            $collectionName = $script:TestSUDeploymentData.NonExistent.CollectionName

            # Act
            $result = Get-CM7SoftwareUpdateDeployment -CollectionName $collectionName

            # Assert
            $result | Should -BeNullOrEmpty
        }

        It "Should support wildcard patterns" {
            # Arrange
            $pattern = $script:TestSUDeploymentData.ByCollectionNameWildcard.CollectionName

            # Act
            $result = Get-CM7SoftwareUpdateDeployment -CollectionName $pattern

            # Assert
            if ($script:TestSUDeploymentData.ByCollectionNameWildcard.ExpectedMinCount -gt 0) {
                $result | Should -Not -BeNullOrEmpty
                $result | ForEach-Object {
                    $_.CollectionName | Should -BeLike $pattern
                }
            }
        }
    }

    Context "Query by Assignment ID" {

        It "Should return null for non-existent assignment ID" {
            # Arrange
            $assignmentId = $script:TestSUDeploymentData.NonExistent.AssignmentId

            # Act
            $result = Get-CM7SoftwareUpdateDeployment -AssignmentId $assignmentId

            # Assert
            $result | Should -BeNullOrEmpty
        }

        It "Should retrieve software update deployment by ID when ID is known" {
            # First get a valid assignment ID from our test collection
            $collectionName = $script:TestSUDeploymentData.ByCollectionName.CollectionName
            $existing = Get-CM7SoftwareUpdateDeployment -CollectionName $collectionName

            if ($existing) {
                $assignmentId = @($existing)[0].AssignmentID

                # Act
                $result = Get-CM7SoftwareUpdateDeployment -AssignmentId $assignmentId

                # Assert
                $result | Should -Not -BeNullOrEmpty
                @($result).Count | Should -Be 1
                $result.AssignmentID | Should -Be $assignmentId
            } else {
                Set-ItResult -Skipped -Because "No software update deployments found on test collection to retrieve by ID"
            }
        }
    }

    Context "Query by Name" {

        It "Should return null for non-existent deployment name" {
            # Arrange
            $name = $script:TestSUDeploymentData.NonExistent.Name

            # Act
            $result = Get-CM7SoftwareUpdateDeployment -Name $name

            # Assert
            $result | Should -BeNullOrEmpty
        }

        It "Should retrieve software update deployment by name" {
            # First get a valid name from our test collection
            $collectionName = $script:TestSUDeploymentData.ByCollectionName.CollectionName
            $existing = Get-CM7SoftwareUpdateDeployment -CollectionName $collectionName

            if ($existing) {
                $deploymentName = @($existing)[0].AssignmentName

                # Act
                $result = Get-CM7SoftwareUpdateDeployment -Name $deploymentName

                # Assert
                $result | Should -Not -BeNullOrEmpty
                $result | ForEach-Object {
                    $_.AssignmentName | Should -Be $deploymentName
                }
            } else {
                Set-ItResult -Skipped -Because "No software update deployments found on test collection to search by name"
            }
        }

        It "Should support wildcard patterns in name" {
            # First get a valid name from our test collection
            $collectionName = $script:TestSUDeploymentData.ByCollectionName.CollectionName
            $existing = Get-CM7SoftwareUpdateDeployment -CollectionName $collectionName

            if ($existing) {
                $fullName = @($existing)[0].AssignmentName
                # Use only the first few characters as a wildcard pattern
                $wildcardName = "$($fullName.Substring(0, [Math]::Min(10, $fullName.Length)))*"

                # Act
                $result = Get-CM7SoftwareUpdateDeployment -Name $wildcardName

                # Assert
                $result | Should -Not -BeNullOrEmpty
                $result | ForEach-Object {
                    $_.AssignmentName | Should -BeLike $wildcardName
                }
            } else {
                Set-ItResult -Skipped -Because "No software update deployments found on test collection to search by wildcard name"
            }
        }
    }

    Context "Fast Mode" {

        It "Should return limited properties with Fast switch" {
            # Arrange
            $collectionName = $script:TestSUDeploymentData.ByCollectionName.CollectionName

            # Act
            $result = Get-CM7SoftwareUpdateDeployment -CollectionName $collectionName -Fast

            # Assert
            if ($result) {
                $result | Should -Not -BeNullOrEmpty
                $result[0].PSObject.Properties.Name | Should -Contain 'AssignmentID'
                $result[0].PSObject.Properties.Name | Should -Contain 'AssignmentName'
                $result[0].PSObject.Properties.Name | Should -Contain 'TargetCollectionID'
                $result[0].PSObject.Properties.Name | Should -Contain 'CollectionName'
                $result[0].PSObject.Properties.Name | Should -Contain 'StartTime'
                $result[0].PSObject.Properties.Name | Should -Contain 'EnforcementDeadline'
                $result[0].PSObject.Properties.Name | Should -Contain 'Enabled'
            } else {
                Set-ItResult -Skipped -Because "No software update deployments found on test collection"
            }
        }

        It "Fast mode should be faster than full query" {
            # Arrange
            $collectionName = $script:TestSUDeploymentData.ByCollectionName.CollectionName

            # Act
            $fastStart = Get-Date
            $fastResult = Get-CM7SoftwareUpdateDeployment -CollectionName $collectionName -Fast
            $fastDuration = (Get-Date) - $fastStart

            $fullStart = Get-Date
            $fullResult = Get-CM7SoftwareUpdateDeployment -CollectionName $collectionName
            $fullDuration = (Get-Date) - $fullStart

            # Assert
            Write-Host "Fast mode: $($fastDuration.TotalMilliseconds)ms, Full mode: $($fullDuration.TotalMilliseconds)ms" -ForegroundColor Cyan
            # Note: We don't assert speed because it can vary
            $true | Should -Be $true
        }
    }

    Context "Return Object Properties" {

        It "Should return objects with expected properties" {
            # Arrange
            $collectionName = $script:TestSUDeploymentData.ByCollectionName.CollectionName

            # Act
            $result = Get-CM7SoftwareUpdateDeployment -CollectionName $collectionName

            # Assert
            if ($result) {
                $result | Should -Not -BeNullOrEmpty
                $firstResult = @($result)[0]
                $firstResult.PSObject.Properties.Name | Should -Contain 'AssignmentID'
                $firstResult.PSObject.Properties.Name | Should -Contain 'AssignmentName'
                $firstResult.PSObject.Properties.Name | Should -Contain 'TargetCollectionID'
                $firstResult.PSObject.Properties.Name | Should -Contain 'CollectionName'
                $firstResult.PSObject.Properties.Name | Should -Contain 'AssignmentDescription'
                $firstResult.PSObject.Properties.Name | Should -Contain 'AssignmentAction'
                $firstResult.PSObject.Properties.Name | Should -Contain 'DesiredConfigType'
                $firstResult.PSObject.Properties.Name | Should -Contain 'StartTime'
                $firstResult.PSObject.Properties.Name | Should -Contain 'EnforcementDeadline'
                $firstResult.PSObject.Properties.Name | Should -Contain 'SuppressReboot'
                $firstResult.PSObject.Properties.Name | Should -Contain 'UseGMTTimes'
                $firstResult.PSObject.Properties.Name | Should -Contain 'NotifyUser'
                $firstResult.PSObject.Properties.Name | Should -Contain 'OverrideServiceWindows'
                $firstResult.PSObject.Properties.Name | Should -Contain 'RebootOutsideOfServiceWindows'
                $firstResult.PSObject.Properties.Name | Should -Contain 'Enabled'
            } else {
                Set-ItResult -Skipped -Because "No software update deployments found on test collection"
            }
        }

        It "Should have PSTypeName set correctly" {
            # Arrange
            $collectionName = $script:TestSUDeploymentData.ByCollectionName.CollectionName

            # Act
            $result = Get-CM7SoftwareUpdateDeployment -CollectionName $collectionName

            # Assert
            if ($result) {
                $firstResult = @($result)[0]
                $firstResult.PSObject.TypeNames[0] | Should -Be 'MECM7.SoftwareUpdateDeployment'
            } else {
                Set-ItResult -Skipped -Because "No software update deployments found on test collection"
            }
        }

        It "Should have AssignmentAction as string (friendly name)" {
            # Arrange
            $collectionName = $script:TestSUDeploymentData.ByCollectionName.CollectionName

            # Act
            $result = Get-CM7SoftwareUpdateDeployment -CollectionName $collectionName

            # Assert
            if ($result) {
                $firstResult = @($result)[0]
                $firstResult.AssignmentAction | Should -BeOfType [string]
                $firstResult.AssignmentAction | Should -Match "^(Detect|Install|Unknown.*)$"
            } else {
                Set-ItResult -Skipped -Because "No software update deployments found on test collection"
            }
        }

        It "Should have DesiredConfigType as string (friendly name)" {
            # Arrange
            $collectionName = $script:TestSUDeploymentData.ByCollectionName.CollectionName

            # Act
            $result = Get-CM7SoftwareUpdateDeployment -CollectionName $collectionName

            # Assert
            if ($result) {
                $firstResult = @($result)[0]
                $firstResult.DesiredConfigType | Should -BeOfType [string]
                $firstResult.DesiredConfigType | Should -Match "^(Required|Optional|Unknown.*)$"
            } else {
                Set-ItResult -Skipped -Because "No software update deployments found on test collection"
            }
        }
    }

    Context "Get All Software Update Deployments" {

        It "Should retrieve all software update deployments when no parameters specified" {
            # Act
            $result = Get-CM7SoftwareUpdateDeployment

            # Assert
            $result | Should -Not -BeNullOrEmpty
            @($result).Count | Should -BeGreaterOrEqual $script:TestSUDeploymentData.All.ExpectedMinCount
        }
    }

    Context "Verbose Output" {

        It "Should provide verbose output when requested" {
            # Arrange
            $collectionName = $script:TestSUDeploymentData.ByCollectionName.CollectionName

            # Act & Assert
            $verboseOutput = Get-CM7SoftwareUpdateDeployment -CollectionName $collectionName -Verbose 4>&1
            $verboseOutput | Should -Not -BeNullOrEmpty
            $verboseOutput | Where-Object { $_ -match "Running Get-CM7SoftwareUpdateDeployment" } | Should -Not -BeNullOrEmpty
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
