# Functional Tests for New-CM7TaskSequenceDeployment
# Tests the New-CM7TaskSequenceDeployment function behavior and return values

BeforeAll {
    # Load test declarations
    . (Join-Path $PSScriptRoot "declarations.ps1")

    # Load all functions
    $CodePath = Join-Path (Get-Item $PSScriptRoot).Parent.FullName "Code"
    Get-ChildItem -Path (Join-Path $CodePath "Private") -Filter "*.ps1" | ForEach-Object { . $_.FullName }
    Get-ChildItem -Path (Join-Path $CodePath "Public") -Filter "*.ps1" | ForEach-Object { . $_.FullName }

    # Get test data for this function
    $script:TestNewTSDData = $script:TestData['New-CM7TaskSequenceDeployment']
    $script:TestConnectData = $script:TestData['Connect-CM7']

    # Track created deployments for cleanup
    $script:CreatedAdvertisementIds = @()

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

Describe "New-CM7TaskSequenceDeployment Function Tests" -Tag "Integration", "TaskSequenceDeployment", "New" {

    Context "Test Data Validation" {

        It "Should have test data defined in declarations.ps1" {
            # Assert
            $script:TestNewTSDData | Should -Not -BeNullOrEmpty
            $script:TestData.ContainsKey('New-CM7TaskSequenceDeployment') | Should -Be $true
        }

        It "Should have required test data parameter sets" {
            # Assert
            $script:TestNewTSDData.ContainsKey('BasicDeployment') | Should -Be $true
            $script:TestNewTSDData.ContainsKey('RequiredDeployment') | Should -Be $true
            $script:TestNewTSDData.ContainsKey('NonExistentTaskSequence') | Should -Be $true
            $script:TestNewTSDData.ContainsKey('NonExistentCollection') | Should -Be $true
        }

        It "Should output test data for verification" {
            # Output test data
            Write-Host "`n=== Test Data for New-CM7TaskSequenceDeployment ===" -ForegroundColor Cyan
            Write-Host "BasicDeployment:" -ForegroundColor Yellow
            Write-Host "  TaskSequencePackageId: $($script:TestNewTSDData.BasicDeployment.TaskSequencePackageId)" -ForegroundColor White
            Write-Host "  TaskSequenceName: $($script:TestNewTSDData.BasicDeployment.TaskSequenceName)" -ForegroundColor White
            Write-Host "  CollectionName: $($script:TestNewTSDData.BasicDeployment.CollectionName)" -ForegroundColor White
            Write-Host "  DeployPurpose: $($script:TestNewTSDData.BasicDeployment.DeployPurpose)" -ForegroundColor White

            Write-Host "RequiredDeployment:" -ForegroundColor Yellow
            Write-Host "  DeployPurpose: $($script:TestNewTSDData.RequiredDeployment.DeployPurpose)" -ForegroundColor White
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
            { New-CM7TaskSequenceDeployment -TaskSequencePackageId "SD100FAD" -CollectionName "Test" } | Should -Throw "*not connected*"

            # Restore connection
            $script:CMConnection = $backupConnection
        }
    }

    Context "Create Basic Available Deployment" {

        It "Should create an available task sequence deployment by PackageId" {
            # Arrange
            $packageId = $script:TestNewTSDData.BasicDeployment.TaskSequencePackageId
            $collectionName = $script:TestNewTSDData.BasicDeployment.CollectionName
            $uniqueDeploymentName = "Test-TSD-Basic-$(Get-Date -Format 'yyyyMMdd_HHmmss')"

            # Act
            $result = New-CM7TaskSequenceDeployment `
                -TaskSequencePackageId $packageId `
                -CollectionName $collectionName `
                -DeploymentName $uniqueDeploymentName `
                -Force

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.AdvertisementName | Should -Be $uniqueDeploymentName
            $result.AdvertisementID | Should -Not -BeNullOrEmpty
            $result.PackageID | Should -Be $packageId
            $result.ProgramName | Should -Be '*'

            # Track for cleanup
            $script:CreatedAdvertisementIds += $result.AdvertisementID
        }

        It "Should create a deployment by TaskSequenceName" {
            # Arrange
            $tsName = $script:TestNewTSDData.BasicDeployment.TaskSequenceName
            $collectionName = $script:TestNewTSDData.BasicDeployment.CollectionName
            $uniqueDeploymentName = "Test-TSD-ByName-$(Get-Date -Format 'yyyyMMdd_HHmmss')"

            # Act
            $result = New-CM7TaskSequenceDeployment `
                -TaskSequenceName $tsName `
                -CollectionName $collectionName `
                -DeploymentName $uniqueDeploymentName `
                -Force

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.AdvertisementName | Should -Be $uniqueDeploymentName
            $result.PackageID | Should -Be $script:TestNewTSDData.BasicDeployment.TaskSequencePackageId
            $result.TaskSequenceName | Should -Be $tsName

            # Track for cleanup
            $script:CreatedAdvertisementIds += $result.AdvertisementID
        }

        It "Should create a deployment with comment" {
            # Arrange
            $packageId = $script:TestNewTSDData.WithComment.TaskSequencePackageId
            $collectionName = $script:TestNewTSDData.WithComment.CollectionName
            $uniqueDeploymentName = "Test-TSD-Comment-$(Get-Date -Format 'yyyyMMdd_HHmmss')"
            $comment = $script:TestNewTSDData.WithComment.Comment

            # Act
            $result = New-CM7TaskSequenceDeployment `
                -TaskSequencePackageId $packageId `
                -CollectionName $collectionName `
                -DeploymentName $uniqueDeploymentName `
                -Comment $comment `
                -Force

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.AdvertisementName | Should -Be $uniqueDeploymentName
            $result.Comment | Should -Be $comment

            # Track for cleanup
            $script:CreatedAdvertisementIds += $result.AdvertisementID
        }

        It "Should create a deployment with AvailableDateTime" {
            # Arrange
            $packageId = $script:TestNewTSDData.BasicDeployment.TaskSequencePackageId
            $collectionName = $script:TestNewTSDData.BasicDeployment.CollectionName
            $uniqueDeploymentName = "Test-TSD-AvailDT-$(Get-Date -Format 'yyyyMMdd_HHmmss')"
            $availableTime = Get-Date

            # Act
            $result = New-CM7TaskSequenceDeployment `
                -TaskSequencePackageId $packageId `
                -CollectionName $collectionName `
                -DeploymentName $uniqueDeploymentName `
                -AvailableDateTime $availableTime `
                -Force

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.PresentTime | Should -Not -BeNullOrEmpty

            # Track for cleanup
            $script:CreatedAdvertisementIds += $result.AdvertisementID
        }
    }

    Context "Create Required Deployment" {

        It "Should create a required task sequence deployment" {
            # Arrange
            $packageId = $script:TestNewTSDData.RequiredDeployment.TaskSequencePackageId
            $collectionName = $script:TestNewTSDData.RequiredDeployment.CollectionName
            $uniqueDeploymentName = "Test-TSD-Required-$(Get-Date -Format 'yyyyMMdd_HHmmss')"

            # Act
            $result = New-CM7TaskSequenceDeployment `
                -TaskSequencePackageId $packageId `
                -CollectionName $collectionName `
                -DeploymentName $uniqueDeploymentName `
                -DeployPurpose Required `
                -Force

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.AdvertisementName | Should -Be $uniqueDeploymentName
            # Required deployments should have the IMMEDIATE flag (0x20) set in AdvertFlags
            ($result.AdvertFlags -band 0x20) | Should -Be 0x20

            # Track for cleanup
            $script:CreatedAdvertisementIds += $result.AdvertisementID
        }

        It "Should create a required deployment with deadline" {
            # Arrange
            $packageId = $script:TestNewTSDData.WithDeadline.TaskSequencePackageId
            $collectionName = $script:TestNewTSDData.WithDeadline.CollectionName
            $uniqueDeploymentName = "Test-TSD-Deadline-$(Get-Date -Format 'yyyyMMdd_HHmmss')"
            $deadline = (Get-Date).AddDays($script:TestNewTSDData.WithDeadline.DeadlineDays)

            # Act
            $result = New-CM7TaskSequenceDeployment `
                -TaskSequencePackageId $packageId `
                -CollectionName $collectionName `
                -DeploymentName $uniqueDeploymentName `
                -DeployPurpose Required `
                -DeadlineDateTime $deadline `
                -Force

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.AdvertisementName | Should -Be $uniqueDeploymentName
            $result.ExpirationTime | Should -Not -BeNullOrEmpty

            # Track for cleanup
            $script:CreatedAdvertisementIds += $result.AdvertisementID
        }
    }

    Context "Create Deployment with CollectionId" {

        It "Should create a deployment using collection ID" {
            # Arrange - Resolve collection ID dynamically
            $namespace = "root/SMS/site_$($script:CMConnection.SiteCode)"
            $collName = $script:TestNewTSDData.BasicDeployment.CollectionName
            $collection = Get-CimInstance -CimSession $script:CMConnection.CimSession `
                -Namespace $namespace `
                -Query "SELECT CollectionID FROM SMS_Collection WHERE CollectionType = 2 AND Name = '$collName'"

            if (-not $collection) {
                Set-ItResult -Skipped -Because "Could not resolve collection for ID-based test"
                return
            }

            $packageId = $script:TestNewTSDData.BasicDeployment.TaskSequencePackageId
            $uniqueDeploymentName = "Test-TSD-ById-$(Get-Date -Format 'yyyyMMdd_HHmmss')"

            # Act
            $result = New-CM7TaskSequenceDeployment `
                -TaskSequencePackageId $packageId `
                -CollectionId $collection.CollectionID `
                -DeploymentName $uniqueDeploymentName `
                -Force

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.AdvertisementName | Should -Be $uniqueDeploymentName
            $result.CollectionID | Should -Be $collection.CollectionID

            # Track for cleanup
            $script:CreatedAdvertisementIds += $result.AdvertisementID
        }
    }

    Context "Error Handling" {

        It "Should throw for non-existent task sequence" {
            # Arrange
            $nonExistentPkgId = $script:TestNewTSDData.NonExistentTaskSequence.TaskSequencePackageId
            $collectionName = $script:TestNewTSDData.NonExistentTaskSequence.CollectionName

            # Act & Assert
            { New-CM7TaskSequenceDeployment -TaskSequencePackageId $nonExistentPkgId -CollectionName $collectionName -Force } | Should -Throw "*not found*"
        }

        It "Should throw for non-existent collection" {
            # Arrange
            $packageId = $script:TestNewTSDData.NonExistentCollection.TaskSequencePackageId
            $collectionName = $script:TestNewTSDData.NonExistentCollection.CollectionName

            # Act & Assert
            { New-CM7TaskSequenceDeployment -TaskSequencePackageId $packageId -CollectionName $collectionName -Force } | Should -Throw "*not found*"
        }
    }

    Context "WhatIf Support" {

        It "Should support -WhatIf parameter" {
            # Arrange
            $packageId = $script:TestNewTSDData.BasicDeployment.TaskSequencePackageId
            $collectionName = $script:TestNewTSDData.BasicDeployment.CollectionName
            $uniqueDeploymentName = "Test-TSD-WhatIf-$(Get-Date -Format 'yyyyMMdd_HHmmss')"

            # Act & Assert - should not throw, and should not actually create
            { New-CM7TaskSequenceDeployment `
                -TaskSequencePackageId $packageId `
                -CollectionName $collectionName `
                -DeploymentName $uniqueDeploymentName `
                -WhatIf } | Should -Not -Throw

            # Verify the deployment was NOT created
            $namespace = "root/SMS/site_$($script:CMConnection.SiteCode)"
            $checkQuery = "SELECT AdvertisementID FROM SMS_Advertisement WHERE AdvertisementName = '$uniqueDeploymentName'"
            $check = Get-CimInstance -CimSession $script:CMConnection.CimSession -Namespace $namespace -Query $checkQuery
            $check | Should -BeNullOrEmpty
        }
    }

    Context "Return Object Properties" {

        It "Should return objects with expected properties" {
            # Arrange
            $packageId = $script:TestNewTSDData.BasicDeployment.TaskSequencePackageId
            $collectionName = $script:TestNewTSDData.BasicDeployment.CollectionName
            $uniqueDeploymentName = "Test-TSD-ReturnProps-$(Get-Date -Format 'yyyyMMdd_HHmmss')"

            # Act
            $result = New-CM7TaskSequenceDeployment `
                -TaskSequencePackageId $packageId `
                -CollectionName $collectionName `
                -DeploymentName $uniqueDeploymentName `
                -Force

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.PSObject.Properties.Name | Should -Contain 'AdvertisementID'
            $result.PSObject.Properties.Name | Should -Contain 'AdvertisementName'
            $result.PSObject.Properties.Name | Should -Contain 'CollectionID'
            $result.PSObject.Properties.Name | Should -Contain 'CollectionName'
            $result.PSObject.Properties.Name | Should -Contain 'PackageID'
            $result.PSObject.Properties.Name | Should -Contain 'TaskSequenceName'
            $result.PSObject.Properties.Name | Should -Contain 'ProgramName'
            $result.PSObject.Properties.Name | Should -Contain 'SourceSite'
            $result.PSObject.Properties.Name | Should -Contain 'AdvertFlags'
            $result.PSObject.Properties.Name | Should -Contain 'RemoteClientFlags'
            $result.PSObject.Properties.Name | Should -Contain 'PresentTime'
            $result.PSObject.Properties.Name | Should -Contain 'ExpirationTime'

            # Track for cleanup
            $script:CreatedAdvertisementIds += $result.AdvertisementID
        }

        It "Should have PSTypeName set correctly" {
            # Arrange
            $packageId = $script:TestNewTSDData.BasicDeployment.TaskSequencePackageId
            $collectionName = $script:TestNewTSDData.BasicDeployment.CollectionName
            $uniqueDeploymentName = "Test-TSD-PSTypeName-$(Get-Date -Format 'yyyyMMdd_HHmmss')"

            # Act
            $result = New-CM7TaskSequenceDeployment `
                -TaskSequencePackageId $packageId `
                -CollectionName $collectionName `
                -DeploymentName $uniqueDeploymentName `
                -Force

            # Assert
            if ($result) {
                $result.PSObject.TypeNames[0] | Should -Be 'MECM7.TaskSequenceDeployment'
            }

            # Track for cleanup
            if ($result) { $script:CreatedAdvertisementIds += $result.AdvertisementID }
        }

        It "Should have ProgramName set to '*' for task sequence deployments" {
            # Arrange
            $packageId = $script:TestNewTSDData.BasicDeployment.TaskSequencePackageId
            $collectionName = $script:TestNewTSDData.BasicDeployment.CollectionName
            $uniqueDeploymentName = "Test-TSD-ProgramName-$(Get-Date -Format 'yyyyMMdd_HHmmss')"

            # Act
            $result = New-CM7TaskSequenceDeployment `
                -TaskSequencePackageId $packageId `
                -CollectionName $collectionName `
                -DeploymentName $uniqueDeploymentName `
                -Force

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.ProgramName | Should -Be '*'

            # Track for cleanup
            $script:CreatedAdvertisementIds += $result.AdvertisementID
        }

        It "Should auto-generate deployment name from TS and collection names" {
            # Arrange
            $packageId = $script:TestNewTSDData.BasicDeployment.TaskSequencePackageId
            $collectionName = $script:TestNewTSDData.BasicDeployment.CollectionName

            # Act - no explicit DeploymentName
            $result = New-CM7TaskSequenceDeployment `
                -TaskSequencePackageId $packageId `
                -CollectionName $collectionName `
                -Force

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.AdvertisementName | Should -Match $script:TestNewTSDData.BasicDeployment.TaskSequenceName
            $result.AdvertisementName | Should -Match $collectionName

            # Track for cleanup
            $script:CreatedAdvertisementIds += $result.AdvertisementID
        }

        It "Should have default AdvertFlags matching native cmdlet defaults" {
            # Arrange
            $packageId = $script:TestNewTSDData.BasicDeployment.TaskSequencePackageId
            $collectionName = $script:TestNewTSDData.BasicDeployment.CollectionName
            $uniqueDeploymentName = "Test-TSD-Flags-$(Get-Date -Format 'yyyyMMdd_HHmmss')"

            # Act - use all defaults (Available deployment)
            $result = New-CM7TaskSequenceDeployment `
                -TaskSequencePackageId $packageId `
                -CollectionName $collectionName `
                -DeploymentName $uniqueDeploymentName `
                -AvailableDateTime (Get-Date) `
                -Force

            # Assert
            $result | Should -Not -BeNullOrEmpty
            # Default AdvertFlags for Available deployment should be 0x8b0000 (9109504)
            # USE_REMOTE_DP (0x800000) + DONOT_FALLBACK (0x080000) +
            # REBOOT_OUTSIDE (0x020000) + OVERRIDE_SERVICE_WINDOWS (0x010000)
            $result.AdvertFlags | Should -Be 0x8b0000

            # Default RemoteClientFlags should be 0x8850 (34896)
            # USE_METERED (0x8000) + ALLOW_INTERNET (0x0800) +
            # RERUN_IF_FAILED (0x0040) + ALLOW_SHARED (0x0010)
            $result.RemoteClientFlags | Should -Be 0x8850

            # Track for cleanup
            $script:CreatedAdvertisementIds += $result.AdvertisementID
        }
    }

    Context "Verbose Output" {

        It "Should provide verbose output when requested" {
            # Arrange
            $packageId = $script:TestNewTSDData.BasicDeployment.TaskSequencePackageId
            $collectionName = $script:TestNewTSDData.BasicDeployment.CollectionName
            $uniqueDeploymentName = "Test-TSD-Verbose-$(Get-Date -Format 'yyyyMMdd_HHmmss')"

            # Act
            $verboseOutput = New-CM7TaskSequenceDeployment `
                -TaskSequencePackageId $packageId `
                -CollectionName $collectionName `
                -DeploymentName $uniqueDeploymentName `
                -Force -Verbose 4>&1

            # Assert
            $verboseOutput | Should -Not -BeNullOrEmpty
            $verboseMessages = $verboseOutput | Where-Object { $_ -is [System.Management.Automation.VerboseRecord] }
            $runningMessage = $verboseMessages | Where-Object { $_.Message -match "Running New-CM7TaskSequenceDeployment" }
            $runningMessage | Should -Not -BeNullOrEmpty

            # Check for AdvertFlags verbose output
            $flagsMessage = $verboseMessages | Where-Object { $_.Message -match "AdvertFlags ==" }
            $flagsMessage | Should -Not -BeNullOrEmpty

            # Check for RemoteClientFlags verbose output
            $rcfMessage = $verboseMessages | Where-Object { $_.Message -match "RemoteClientFlags ==" }
            $rcfMessage | Should -Not -BeNullOrEmpty

            # Track for cleanup - extract the actual result from verbose output
            $resultObj = $verboseOutput | Where-Object { $_ -isnot [System.Management.Automation.VerboseRecord] }
            if ($resultObj -and $resultObj.AdvertisementID) {
                $script:CreatedAdvertisementIds += $resultObj.AdvertisementID
            }
        }
    }
}

AfterAll {
    # Clean up: remove all test task sequence deployments created during tests
    if ($script:CMConnection.CimSession -and $script:CreatedAdvertisementIds.Count -gt 0) {
        $namespace = "root/SMS/site_$($script:CMConnection.SiteCode)"
        $uniqueIds = $script:CreatedAdvertisementIds | Select-Object -Unique
        Write-Host "Test cleanup: Removing $($uniqueIds.Count) test task sequence deployment(s)" -ForegroundColor Yellow
        foreach ($id in $uniqueIds) {
            try {
                $deploymentQuery = "SELECT * FROM SMS_Advertisement WHERE AdvertisementID = '$id'"
                $deployment = Get-CimInstance -CimSession $script:CMConnection.CimSession -Namespace $namespace -Query $deploymentQuery
                if ($deployment) {
                    Remove-CimInstance -CimSession $script:CMConnection.CimSession -InputObject $deployment -ErrorAction SilentlyContinue
                    Write-Host "  Removed task sequence deployment: AdvertisementID $id" -ForegroundColor Green
                }
            }
            catch {
                Write-Warning "  Failed to remove task sequence deployment AdvertisementID '$id': $_"
            }
        }
        Write-Host "Test cleanup: Done" -ForegroundColor Green
    }
}
