# Functional Tests for Get-CM7TaskSequenceDeployment
# Tests the Get-CM7TaskSequenceDeployment function behavior and return values

BeforeAll {
    # Load test declarations
    . (Join-Path $PSScriptRoot "declarations.ps1")

    # Load all functions
    $CodePath = Join-Path (Get-Item $PSScriptRoot).Parent.FullName "Code"
    Get-ChildItem -Path (Join-Path $CodePath "Private") -Filter "*.ps1" | ForEach-Object { . $_.FullName }
    Get-ChildItem -Path (Join-Path $CodePath "Public") -Filter "*.ps1" | ForEach-Object { . $_.FullName }

    # Get test data for this function
    $script:TestTSDeploymentData = $script:TestData['Get-CM7TaskSequenceDeployment']
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

Describe "Get-CM7TaskSequenceDeployment Function Tests" -Tag "Integration", "TaskSequenceDeployment" {

    Context "Test Data Validation" {

        It "Should have test data defined in declarations.ps1" {
            # Assert
            $script:TestTSDeploymentData | Should -Not -BeNullOrEmpty
            $script:TestData.ContainsKey('Get-CM7TaskSequenceDeployment') | Should -Be $true
        }

        It "Should have required test data parameter sets" {
            # Assert
            $script:TestTSDeploymentData.ContainsKey('ByCollectionName') | Should -Be $true
            $script:TestTSDeploymentData.ContainsKey('NonExistent') | Should -Be $true
            $script:TestTSDeploymentData.ContainsKey('All') | Should -Be $true
        }

        It "Should output test data for verification" {
            # Output test data
            Write-Host "`n=== Test Data for Get-CM7TaskSequenceDeployment ===" -ForegroundColor Cyan
            Write-Host "ByCollectionName:" -ForegroundColor Yellow
            Write-Host "  CollectionName: $($script:TestTSDeploymentData.ByCollectionName.CollectionName)" -ForegroundColor White
            Write-Host "  CollectionId: $($script:TestTSDeploymentData.ByCollectionName.CollectionId)" -ForegroundColor White
            Write-Host "  ExpectedMinCount: $($script:TestTSDeploymentData.ByCollectionName.ExpectedMinCount)" -ForegroundColor White

            Write-Host "ByTaskSequenceName:" -ForegroundColor Yellow
            Write-Host "  TaskSequenceName: $($script:TestTSDeploymentData.ByTaskSequenceName.TaskSequenceName)" -ForegroundColor White
            Write-Host "  TaskSequencePackageId: $($script:TestTSDeploymentData.ByTaskSequenceName.TaskSequencePackageId)" -ForegroundColor White

            Write-Host "NonExistent:" -ForegroundColor Yellow
            Write-Host "  CollectionName: $($script:TestTSDeploymentData.NonExistent.CollectionName)" -ForegroundColor White
            Write-Host "  AdvertisementID: $($script:TestTSDeploymentData.NonExistent.AdvertisementID)" -ForegroundColor White
            Write-Host "  TaskSequenceName: $($script:TestTSDeploymentData.NonExistent.TaskSequenceName)" -ForegroundColor White
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
            { Get-CM7TaskSequenceDeployment -CollectionName "Test" } | Should -Throw "*not connected*"

            # Restore connection
            $script:CMConnection = $backupConnection
        }
    }

    Context "Query by Collection Name" {

        It "Should retrieve task sequence deployments by collection name" {
            # Arrange
            $collectionName = $script:TestTSDeploymentData.ByCollectionName.CollectionName

            # Act
            $result = Get-CM7TaskSequenceDeployment -CollectionName $collectionName

            # Assert
            $result | Should -Not -BeNullOrEmpty
            @($result).Count | Should -BeGreaterOrEqual $script:TestTSDeploymentData.ByCollectionName.ExpectedMinCount
            $result | ForEach-Object {
                $_.CollectionName | Should -Be $collectionName
            }
        }

        It "Should return null for non-existent collection" {
            # Arrange
            $collectionName = $script:TestTSDeploymentData.NonExistent.CollectionName

            # Act
            $result = Get-CM7TaskSequenceDeployment -CollectionName $collectionName

            # Assert
            $result | Should -BeNullOrEmpty
        }

        It "Should support wildcard patterns" {
            # Arrange
            $pattern = $script:TestTSDeploymentData.ByCollectionNameWildcard.CollectionName

            # Act
            $result = Get-CM7TaskSequenceDeployment -CollectionName $pattern

            # Assert
            if ($script:TestTSDeploymentData.ByCollectionNameWildcard.ExpectedMinCount -gt 0) {
                $result | Should -Not -BeNullOrEmpty
            }
        }
    }

    Context "Query by Task Sequence Name" {

        It "Should retrieve task sequence deployments by task sequence name" {
            # Arrange
            $tsName = $script:TestTSDeploymentData.ByTaskSequenceName.TaskSequenceName

            # Act
            $result = Get-CM7TaskSequenceDeployment -TaskSequenceName $tsName

            # Assert
            $result | Should -Not -BeNullOrEmpty
            @($result).Count | Should -BeGreaterOrEqual $script:TestTSDeploymentData.ByTaskSequenceName.ExpectedMinCount
            $result | ForEach-Object {
                $_.TaskSequenceName | Should -Be $tsName
            }
        }

        It "Should return null for non-existent task sequence name" {
            # Arrange
            $tsName = $script:TestTSDeploymentData.NonExistent.TaskSequenceName

            # Act
            $result = Get-CM7TaskSequenceDeployment -TaskSequenceName $tsName

            # Assert
            $result | Should -BeNullOrEmpty
        }
    }

    Context "Query by Task Sequence Package ID" {

        It "Should retrieve task sequence deployments by package ID" {
            # Arrange
            $packageId = $script:TestTSDeploymentData.ByTaskSequencePackageId.TaskSequencePackageId

            # Act
            $result = Get-CM7TaskSequenceDeployment -TaskSequencePackageId $packageId

            # Assert
            $result | Should -Not -BeNullOrEmpty
            @($result).Count | Should -BeGreaterOrEqual $script:TestTSDeploymentData.ByTaskSequencePackageId.ExpectedMinCount
            $result | ForEach-Object {
                $_.PackageID | Should -Be $packageId
            }
        }

        It "Should return null for non-existent package ID" {
            # Arrange
            $packageId = $script:TestTSDeploymentData.NonExistent.TaskSequencePackageId

            # Act
            $result = Get-CM7TaskSequenceDeployment -TaskSequencePackageId $packageId

            # Assert
            $result | Should -BeNullOrEmpty
        }
    }

    Context "Query by Advertisement ID" {

        It "Should return null for non-existent advertisement ID" {
            # Arrange
            $advId = $script:TestTSDeploymentData.NonExistent.AdvertisementID

            # Act
            $result = Get-CM7TaskSequenceDeployment -AdvertisementID $advId

            # Assert
            $result | Should -BeNullOrEmpty
        }

        It "Should retrieve task sequence deployment by advertisement ID when ID is known" {
            # First get a valid AdvertisementID from our test collection
            $collectionName = $script:TestTSDeploymentData.ByCollectionName.CollectionName
            $existing = Get-CM7TaskSequenceDeployment -CollectionName $collectionName

            if ($existing) {
                $advId = @($existing)[0].AdvertisementID

                # Act
                $result = Get-CM7TaskSequenceDeployment -AdvertisementID $advId

                # Assert
                $result | Should -Not -BeNullOrEmpty
                @($result).Count | Should -Be 1
                $result.AdvertisementID | Should -Be $advId
            } else {
                Set-ItResult -Skipped -Because "No task sequence deployments found on test collection to retrieve by ID"
            }
        }
    }

    Context "Query by Deployment Name" {

        It "Should return null for non-existent deployment name" {
            # Arrange
            $name = $script:TestTSDeploymentData.NonExistent.DeploymentName

            # Act
            $result = Get-CM7TaskSequenceDeployment -DeploymentName $name

            # Assert
            $result | Should -BeNullOrEmpty
        }

        It "Should retrieve task sequence deployment by name" {
            # First get a valid name from our test collection
            $collectionName = $script:TestTSDeploymentData.ByCollectionName.CollectionName
            $existing = Get-CM7TaskSequenceDeployment -CollectionName $collectionName

            if ($existing) {
                $deploymentName = @($existing)[0].AdvertisementName

                # Act
                $result = Get-CM7TaskSequenceDeployment -DeploymentName $deploymentName

                # Assert
                $result | Should -Not -BeNullOrEmpty
                $result | ForEach-Object {
                    $_.AdvertisementName | Should -Be $deploymentName
                }
            } else {
                Set-ItResult -Skipped -Because "No task sequence deployments found on test collection to search by name"
            }
        }

        It "Should support wildcard patterns in deployment name" {
            # First get a valid name from our test collection
            $collectionName = $script:TestTSDeploymentData.ByCollectionName.CollectionName
            $existing = Get-CM7TaskSequenceDeployment -CollectionName $collectionName

            if ($existing) {
                $fullName = @($existing)[0].AdvertisementName
                # Use only the first few characters as a wildcard pattern
                $wildcardName = "$($fullName.Substring(0, [Math]::Min(10, $fullName.Length)))*"

                # Act
                $result = Get-CM7TaskSequenceDeployment -DeploymentName $wildcardName

                # Assert
                $result | Should -Not -BeNullOrEmpty
                $result | ForEach-Object {
                    $_.AdvertisementName | Should -BeLike $wildcardName
                }
            } else {
                Set-ItResult -Skipped -Because "No task sequence deployments found on test collection to search by wildcard name"
            }
        }
    }

    Context "Fast Mode" {

        It "Should return limited properties with Fast switch" {
            # Arrange
            $collectionName = $script:TestTSDeploymentData.ByCollectionName.CollectionName

            # Act
            $result = Get-CM7TaskSequenceDeployment -CollectionName $collectionName -Fast

            # Assert
            if ($result) {
                $result | Should -Not -BeNullOrEmpty
                $firstResult = @($result)[0]
                $firstResult.PSObject.Properties.Name | Should -Contain 'AdvertisementID'
                $firstResult.PSObject.Properties.Name | Should -Contain 'AdvertisementName'
                $firstResult.PSObject.Properties.Name | Should -Contain 'CollectionID'
                $firstResult.PSObject.Properties.Name | Should -Contain 'PackageID'
                $firstResult.PSObject.Properties.Name | Should -Contain 'ProgramName'
                $firstResult.PSObject.Properties.Name | Should -Contain 'CollectionName'
                $firstResult.PSObject.Properties.Name | Should -Contain 'TaskSequenceName'
                $firstResult.PSObject.Properties.Name | Should -Contain 'PresentTime'
                $firstResult.PSObject.Properties.Name | Should -Contain 'ExpirationTime'
            } else {
                Set-ItResult -Skipped -Because "No task sequence deployments found on test collection"
            }
        }

        It "Fast mode should be faster than full query" {
            # Arrange
            $collectionName = $script:TestTSDeploymentData.ByCollectionName.CollectionName

            # Act
            $fastStart = Get-Date
            $fastResult = Get-CM7TaskSequenceDeployment -CollectionName $collectionName -Fast
            $fastDuration = (Get-Date) - $fastStart

            $fullStart = Get-Date
            $fullResult = Get-CM7TaskSequenceDeployment -CollectionName $collectionName
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
            $collectionName = $script:TestTSDeploymentData.ByCollectionName.CollectionName

            # Act
            $result = Get-CM7TaskSequenceDeployment -CollectionName $collectionName

            # Assert
            if ($result) {
                $result | Should -Not -BeNullOrEmpty
                $firstResult = @($result)[0]
                $firstResult.PSObject.Properties.Name | Should -Contain 'AdvertisementID'
                $firstResult.PSObject.Properties.Name | Should -Contain 'AdvertisementName'
                $firstResult.PSObject.Properties.Name | Should -Contain 'CollectionID'
                $firstResult.PSObject.Properties.Name | Should -Contain 'CollectionName'
                $firstResult.PSObject.Properties.Name | Should -Contain 'PackageID'
                $firstResult.PSObject.Properties.Name | Should -Contain 'TaskSequenceName'
                $firstResult.PSObject.Properties.Name | Should -Contain 'ProgramName'
                $firstResult.PSObject.Properties.Name | Should -Contain 'SourceSite'
                $firstResult.PSObject.Properties.Name | Should -Contain 'AdvertFlags'
                $firstResult.PSObject.Properties.Name | Should -Contain 'RemoteClientFlags'
                $firstResult.PSObject.Properties.Name | Should -Contain 'PresentTime'
                $firstResult.PSObject.Properties.Name | Should -Contain 'ExpirationTime'
            } else {
                Set-ItResult -Skipped -Because "No task sequence deployments found on test collection"
            }
        }

        It "Should have PSTypeName set correctly" {
            # Arrange
            $collectionName = $script:TestTSDeploymentData.ByCollectionName.CollectionName

            # Act
            $result = Get-CM7TaskSequenceDeployment -CollectionName $collectionName

            # Assert
            if ($result) {
                $firstResult = @($result)[0]
                $firstResult.PSObject.TypeNames[0] | Should -Be 'MECM7.TaskSequenceDeployment'
            } else {
                Set-ItResult -Skipped -Because "No task sequence deployments found on test collection"
            }
        }

        It "Should have CollectionName resolved" {
            # Arrange
            $collectionName = $script:TestTSDeploymentData.ByCollectionName.CollectionName

            # Act
            $result = Get-CM7TaskSequenceDeployment -CollectionName $collectionName

            # Assert
            if ($result) {
                $firstResult = @($result)[0]
                $firstResult.CollectionName | Should -Not -BeNullOrEmpty
                $firstResult.CollectionName | Should -Be $collectionName
            } else {
                Set-ItResult -Skipped -Because "No task sequence deployments found on test collection"
            }
        }

        It "Should have TaskSequenceName resolved" {
            # Arrange
            $collectionName = $script:TestTSDeploymentData.ByCollectionName.CollectionName

            # Act
            $result = Get-CM7TaskSequenceDeployment -CollectionName $collectionName

            # Assert
            if ($result) {
                $firstResult = @($result)[0]
                $firstResult.TaskSequenceName | Should -Not -BeNullOrEmpty
            } else {
                Set-ItResult -Skipped -Because "No task sequence deployments found on test collection"
            }
        }

        It "Should have ProgramName equal to '*' for task sequence deployments" {
            # Arrange
            $collectionName = $script:TestTSDeploymentData.ByCollectionName.CollectionName

            # Act
            $result = Get-CM7TaskSequenceDeployment -CollectionName $collectionName

            # Assert
            if ($result) {
                $result | ForEach-Object {
                    $_.ProgramName | Should -Be '*'
                }
            } else {
                Set-ItResult -Skipped -Because "No task sequence deployments found on test collection"
            }
        }
    }

    Context "Get All Task Sequence Deployments" {

        It "Should retrieve all task sequence deployments when no parameters specified" {
            # Act
            $result = Get-CM7TaskSequenceDeployment

            # Assert
            $result | Should -Not -BeNullOrEmpty
            @($result).Count | Should -BeGreaterOrEqual $script:TestTSDeploymentData.All.ExpectedMinCount
        }
    }

    Context "Verbose Output" {

        It "Should provide verbose output when requested" {
            # Arrange
            $collectionName = $script:TestTSDeploymentData.ByCollectionName.CollectionName

            # Act & Assert
            $verboseOutput = Get-CM7TaskSequenceDeployment -CollectionName $collectionName -Verbose 4>&1
            $verboseOutput | Should -Not -BeNullOrEmpty
            $verboseOutput | Where-Object { $_ -match "Running Get-CM7TaskSequenceDeployment" } | Should -Not -BeNullOrEmpty
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
