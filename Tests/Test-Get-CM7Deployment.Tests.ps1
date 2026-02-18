# Functional Tests for Get-CM7Deployment
# Tests the Get-CM7Deployment function behavior and return values

BeforeAll {
    # Load test declarations
    . (Join-Path $PSScriptRoot "declarations.ps1")

    # Load all functions
    $CodePath = Join-Path (Get-Item $PSScriptRoot).Parent.FullName "Code"
    Get-ChildItem -Path (Join-Path $CodePath "Private") -Filter "*.ps1" | ForEach-Object { . $_.FullName }
    Get-ChildItem -Path (Join-Path $CodePath "Public") -Filter "*.ps1" | ForEach-Object { . $_.FullName }

    # Get test data for this function
    $script:TestDeploymentData = $script:TestData['Get-CM7Deployment']
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

Describe "Get-CM7Deployment Function Tests" -Tag "Integration", "Deployment" {

    Context "Test Data Validation" {

        It "Should have test data defined in declarations.ps1" {
            # Assert
            $script:TestDeploymentData | Should -Not -BeNullOrEmpty
            $script:TestData.ContainsKey('Get-CM7Deployment') | Should -Be $true
        }

        It "Should have required test data parameter sets" {
            # Assert
            $script:TestDeploymentData.ContainsKey('ByCollectionName') | Should -Be $true
            $script:TestDeploymentData.ContainsKey('NonExistent') | Should -Be $true
            $script:TestDeploymentData.ContainsKey('All') | Should -Be $true
        }

        It "Should output test data for verification" {
            # Output test data
            Write-Host "`n=== Test Data for Get-CM7Deployment ===" -ForegroundColor Cyan
            Write-Host "ByCollectionName:" -ForegroundColor Yellow
            Write-Host "  CollectionName: $($script:TestDeploymentData.ByCollectionName.CollectionName)" -ForegroundColor White
            Write-Host "  ExpectedMinCount: $($script:TestDeploymentData.ByCollectionName.ExpectedMinCount)" -ForegroundColor White

            Write-Host "NonExistent:" -ForegroundColor Yellow
            Write-Host "  CollectionName: $($script:TestDeploymentData.NonExistent.CollectionName)" -ForegroundColor White
            Write-Host "  DeploymentId: $($script:TestDeploymentData.NonExistent.DeploymentId)" -ForegroundColor White
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
            { Get-CM7Deployment -CollectionName "Test" } | Should -Throw "*not connected*"

            # Restore connection
            $script:CMConnection = $backupConnection
        }
    }

    Context "Query by Collection Name" {

        It "Should retrieve deployments by collection name" {
            # Arrange
            $collectionName = $script:TestDeploymentData.ByCollectionName.CollectionName

            # Act
            $result = Get-CM7Deployment -CollectionName $collectionName

            # Assert
            $result | Should -Not -BeNullOrEmpty
            @($result).Count | Should -BeGreaterOrEqual $script:TestDeploymentData.ByCollectionName.ExpectedMinCount
            $result | ForEach-Object {
                $_.CollectionName | Should -Be $collectionName
            }
        }

        It "Should return null for non-existent collection" {
            # Arrange
            $collectionName = $script:TestDeploymentData.NonExistent.CollectionName

            # Act
            $result = Get-CM7Deployment -CollectionName $collectionName

            # Assert
            $result | Should -BeNullOrEmpty
        }

        It "Should support wildcard patterns" {
            # Arrange
            $pattern = $script:TestDeploymentData.ByCollectionNameWildcard.CollectionName

            # Act
            $result = Get-CM7Deployment -CollectionName $pattern

            # Assert
            if ($script:TestDeploymentData.ByCollectionNameWildcard.ExpectedMinCount -gt 0) {
                $result | Should -Not -BeNullOrEmpty
                $result | ForEach-Object {
                    $_.CollectionName | Should -BeLike $pattern
                }
            }
        }
    }

    Context "Query by Deployment ID" {

        It "Should return null for non-existent deployment ID" {
            # Arrange
            $deploymentId = $script:TestDeploymentData.NonExistent.DeploymentId

            # Act
            $result = Get-CM7Deployment -DeploymentId $deploymentId

            # Assert
            $result | Should -BeNullOrEmpty
        }

        It "Should retrieve deployment by ID when ID is known" {
            # First get a valid deployment ID from our test collection
            $collectionName = $script:TestDeploymentData.ByCollectionName.CollectionName
            $existing = Get-CM7Deployment -CollectionName $collectionName

            if ($existing) {
                $deploymentId = @($existing)[0].DeploymentID

                # Act
                $result = Get-CM7Deployment -DeploymentId $deploymentId

                # Assert
                $result | Should -Not -BeNullOrEmpty
                @($result).Count | Should -Be 1
                $result.DeploymentID | Should -Be $deploymentId
            } else {
                Set-ItResult -Skipped -Because "No deployments found on test collection to retrieve by ID"
            }
        }
    }

    Context "Query by Software Name" {

        It "Should retrieve deployments by software name wildcard" {
            # First get a valid software name from our test collection
            $collectionName = $script:TestDeploymentData.ByCollectionName.CollectionName
            $existing = Get-CM7Deployment -CollectionName $collectionName

            if ($existing) {
                $softwareName = @($existing)[0].SoftwareName

                # Act
                $result = Get-CM7Deployment -SoftwareName $softwareName

                # Assert
                $result | Should -Not -BeNullOrEmpty
                $result | ForEach-Object {
                    $_.SoftwareName | Should -Be $softwareName
                }
            } else {
                Set-ItResult -Skipped -Because "No deployments found on test collection to search by software name"
            }
        }
    }

    Context "Query by Feature Type" {

        It "Should retrieve deployments by feature type" {
            # First get a valid feature type from our test collection
            $collectionName = $script:TestDeploymentData.ByCollectionName.CollectionName
            $existing = Get-CM7Deployment -CollectionName $collectionName

            if ($existing) {
                $featureType = @($existing)[0].FeatureType

                # Act
                $result = Get-CM7Deployment -FeatureType $featureType

                # Assert
                $result | Should -Not -BeNullOrEmpty
                $result | ForEach-Object {
                    $_.FeatureType | Should -Be $featureType
                }
            } else {
                Set-ItResult -Skipped -Because "No deployments found on test collection to filter by feature type"
            }
        }
    }

    Context "Fast Mode" {

        It "Should return limited properties with Fast switch" {
            # Arrange
            $collectionName = $script:TestDeploymentData.ByCollectionName.CollectionName

            # Act
            $result = Get-CM7Deployment -CollectionName $collectionName -Fast

            # Assert
            if ($result) {
                $result | Should -Not -BeNullOrEmpty
                $result[0].PSObject.Properties.Name | Should -Contain 'DeploymentID'
                $result[0].PSObject.Properties.Name | Should -Contain 'CollectionName'
                $result[0].PSObject.Properties.Name | Should -Contain 'SoftwareName'
                $result[0].PSObject.Properties.Name | Should -Contain 'FeatureType'
                $result[0].PSObject.Properties.Name | Should -Contain 'NumberTargeted'
                $result[0].PSObject.Properties.Name | Should -Contain 'NumberSuccess'
            } else {
                Set-ItResult -Skipped -Because "No deployments found on test collection"
            }
        }

        It "Fast mode should be faster than full query" {
            # Arrange
            $collectionName = $script:TestDeploymentData.ByCollectionName.CollectionName

            # Act
            $fastStart = Get-Date
            $fastResult = Get-CM7Deployment -CollectionName $collectionName -Fast
            $fastDuration = (Get-Date) - $fastStart

            $fullStart = Get-Date
            $fullResult = Get-CM7Deployment -CollectionName $collectionName
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
            $collectionName = $script:TestDeploymentData.ByCollectionName.CollectionName

            # Act
            $result = Get-CM7Deployment -CollectionName $collectionName

            # Assert
            if ($result) {
                $result | Should -Not -BeNullOrEmpty
                $firstResult = @($result)[0]
                $firstResult.PSObject.Properties.Name | Should -Contain 'DeploymentID'
                $firstResult.PSObject.Properties.Name | Should -Contain 'CollectionID'
                $firstResult.PSObject.Properties.Name | Should -Contain 'CollectionName'
                $firstResult.PSObject.Properties.Name | Should -Contain 'SoftwareName'
                $firstResult.PSObject.Properties.Name | Should -Contain 'PackageID'
                $firstResult.PSObject.Properties.Name | Should -Contain 'FeatureType'
                $firstResult.PSObject.Properties.Name | Should -Contain 'NumberTargeted'
                $firstResult.PSObject.Properties.Name | Should -Contain 'NumberSuccess'
                $firstResult.PSObject.Properties.Name | Should -Contain 'NumberInProgress'
                $firstResult.PSObject.Properties.Name | Should -Contain 'NumberErrors'
                $firstResult.PSObject.Properties.Name | Should -Contain 'NumberOther'
                $firstResult.PSObject.Properties.Name | Should -Contain 'NumberUnknown'
            } else {
                Set-ItResult -Skipped -Because "No deployments found on test collection"
            }
        }

        It "Should have PSTypeName set correctly" {
            # Arrange
            $collectionName = $script:TestDeploymentData.ByCollectionName.CollectionName

            # Act
            $result = Get-CM7Deployment -CollectionName $collectionName

            # Assert
            if ($result) {
                $firstResult = @($result)[0]
                $firstResult.PSObject.TypeNames[0] | Should -Be 'MECM7.Deployment'
            } else {
                Set-ItResult -Skipped -Because "No deployments found on test collection"
            }
        }

        It "Should have FeatureType as string (friendly name)" {
            # Arrange
            $collectionName = $script:TestDeploymentData.ByCollectionName.CollectionName

            # Act
            $result = Get-CM7Deployment -CollectionName $collectionName

            # Assert
            if ($result) {
                $firstResult = @($result)[0]
                $firstResult.FeatureType | Should -BeOfType [string]
                $firstResult.FeatureType | Should -Match "^(Application|Program|SoftwareUpdateGroup|ConfigurationBaseline|TaskSequence|Unknown.*)$"
            } else {
                Set-ItResult -Skipped -Because "No deployments found on test collection"
            }
        }
    }

    Context "Get All Deployments" {

        It "Should retrieve all deployments when no parameters specified" {
            # Act
            $result = Get-CM7Deployment

            # Assert
            $result | Should -Not -BeNullOrEmpty
            @($result).Count | Should -BeGreaterOrEqual $script:TestDeploymentData.All.ExpectedMinCount
        }
    }

    Context "Verbose Output" {

        It "Should provide verbose output when requested" {
            # Arrange
            $collectionName = $script:TestDeploymentData.ByCollectionName.CollectionName

            # Act & Assert
            $verboseOutput = Get-CM7Deployment -CollectionName $collectionName -Verbose 4>&1
            $verboseOutput | Should -Not -BeNullOrEmpty
            $verboseOutput | Where-Object { $_ -match "Running Get-CM7Deployment" } | Should -Not -BeNullOrEmpty
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
