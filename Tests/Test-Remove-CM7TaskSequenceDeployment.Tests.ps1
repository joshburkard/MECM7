# Functional Tests for Remove-CM7TaskSequenceDeployment
# Tests the Remove-CM7TaskSequenceDeployment function behavior and return values
# Test deployments are created dynamically using New-CM7TaskSequenceDeployment
# and removed during the test run itself

BeforeAll {
    # Load test declarations
    . (Join-Path $PSScriptRoot "declarations.ps1")

    # Load all functions
    $CodePath = Join-Path (Get-Item $PSScriptRoot).Parent.FullName "Code"
    Get-ChildItem -Path (Join-Path $CodePath "Private") -Filter "*.ps1" | ForEach-Object { . $_.FullName }
    Get-ChildItem -Path (Join-Path $CodePath "Public") -Filter "*.ps1" | ForEach-Object { . $_.FullName }

    # Get test data for this function
    $script:TestRemoveTSDData = $script:TestData['Remove-CM7TaskSequenceDeployment']
    $script:TestConnectData = $script:TestData['Connect-CM7']

    # Track created deployments for cleanup (in case tests fail before removing them)
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

    # Helper function to create a test deployment for removal tests
    function New-TestDeploymentForRemoval {
        param(
            [string]$NamePrefix = "Test-RemoveTSD",
            [string]$CollectionName = $script:TestRemoveTSDData.TestDeployment.CollectionName,
            [string]$TaskSequencePackageId = $script:TestRemoveTSDData.TestDeployment.TaskSequencePackageId
        )
        $uniqueName = "$NamePrefix-$(Get-Date -Format 'yyyyMMdd_HHmmss_fff')-$([guid]::NewGuid().ToString().Substring(0, 8))"
        $result = New-CM7TaskSequenceDeployment `
            -TaskSequencePackageId $TaskSequencePackageId `
            -CollectionName $CollectionName `
            -DeploymentName $uniqueName `
            -Force
        if ($result) {
            $script:CreatedAdvertisementIds += $result.AdvertisementID
            Write-Host "  Created test deployment: $($result.AdvertisementName) ($($result.AdvertisementID))" -ForegroundColor Gray
        }
        return $result
    }
}

Describe "Remove-CM7TaskSequenceDeployment Function Tests" -Tag "Integration", "TaskSequenceDeployment", "Remove" {

    Context "Test Data Validation" {

        It "Should have test data defined in declarations.ps1" {
            # Assert
            $script:TestRemoveTSDData | Should -Not -BeNullOrEmpty
            $script:TestData.ContainsKey('Remove-CM7TaskSequenceDeployment') | Should -Be $true
        }

        It "Should have required test data parameter sets" {
            # Assert
            $script:TestRemoveTSDData.ContainsKey('TestDeployment') | Should -Be $true
            $script:TestRemoveTSDData.ContainsKey('NonExistentDeployment') | Should -Be $true
            $script:TestRemoveTSDData.ContainsKey('NonExistentCollection') | Should -Be $true
        }

        It "Should output test data for verification" {
            # Output test data
            Write-Host "`n=== Test Data for Remove-CM7TaskSequenceDeployment ===" -ForegroundColor Cyan
            Write-Host "TestDeployment:" -ForegroundColor Yellow
            Write-Host "  TaskSequencePackageId: $($script:TestRemoveTSDData.TestDeployment.TaskSequencePackageId)" -ForegroundColor White
            Write-Host "  TaskSequenceName: $($script:TestRemoveTSDData.TestDeployment.TaskSequenceName)" -ForegroundColor White
            Write-Host "  CollectionName: $($script:TestRemoveTSDData.TestDeployment.CollectionName)" -ForegroundColor White

            Write-Host "NonExistentDeployment:" -ForegroundColor Yellow
            Write-Host "  AdvertisementID: $($script:TestRemoveTSDData.NonExistentDeployment.AdvertisementID)" -ForegroundColor White
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
            { Remove-CM7TaskSequenceDeployment -AdvertisementID "SD120BD2" } | Should -Throw "*not connected*"

            # Restore connection
            $script:CMConnection = $backupConnection
        }
    }

    Context "Remove Deployment by AdvertisementID" {

        It "Should create and then remove a deployment by AdvertisementID" {
            # Arrange - Create a test deployment first
            $testDeployment = New-TestDeploymentForRemoval -NamePrefix "Test-RemoveTSD-ByAdvID"
            $testDeployment | Should -Not -BeNullOrEmpty
            $advId = $testDeployment.AdvertisementID

            # Act - Remove by AdvertisementID
            $result = Remove-CM7TaskSequenceDeployment -AdvertisementID $advId -Force

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.AdvertisementID | Should -Be $advId
            $result.Status | Should -Be 'Removed'

            # Verify deployment is actually gone
            $namespace = "root/SMS/site_$($script:CMConnection.SiteCode)"
            $check = Get-CimInstance -CimSession $script:CMConnection.CimSession -Namespace $namespace -Query "SELECT AdvertisementID FROM SMS_Advertisement WHERE AdvertisementID = '$advId'"
            $check | Should -BeNullOrEmpty

            # Remove from cleanup tracking since we already removed it
            $script:CreatedAdvertisementIds = $script:CreatedAdvertisementIds | Where-Object { $_ -ne $advId }
        }
    }

    Context "Remove Deployment by CollectionName" {

        It "Should create and then remove a deployment by CollectionName" {
            # Arrange - Create a test deployment first
            $testDeployment = New-TestDeploymentForRemoval -NamePrefix "Test-RemoveTSD-ByColl"
            $testDeployment | Should -Not -BeNullOrEmpty
            $advId = $testDeployment.AdvertisementID
            $collName = $script:TestRemoveTSDData.TestDeployment.CollectionName

            # Act - Remove by CollectionName (may remove multiple, so filter result)
            $results = @(Remove-CM7TaskSequenceDeployment -CollectionName $collName -Force)

            # Assert - at least one should have been removed
            $results | Should -Not -BeNullOrEmpty
            $ourResult = $results | Where-Object { $_.AdvertisementID -eq $advId }
            $ourResult | Should -Not -BeNullOrEmpty
            $ourResult.Status | Should -Be 'Removed'

            # Verify deployment is actually gone
            $namespace = "root/SMS/site_$($script:CMConnection.SiteCode)"
            $check = Get-CimInstance -CimSession $script:CMConnection.CimSession -Namespace $namespace -Query "SELECT AdvertisementID FROM SMS_Advertisement WHERE AdvertisementID = '$advId'"
            $check | Should -BeNullOrEmpty

            # Remove ALL returned IDs from cleanup tracking
            foreach ($r in $results) {
                $script:CreatedAdvertisementIds = $script:CreatedAdvertisementIds | Where-Object { $_ -ne $r.AdvertisementID }
            }
        }
    }

    Context "Remove Deployment by DeploymentName" {

        It "Should create and then remove a deployment by DeploymentName" {
            # Arrange - Create a test deployment first
            $testDeployment = New-TestDeploymentForRemoval -NamePrefix "Test-RemoveTSD-ByName"
            $testDeployment | Should -Not -BeNullOrEmpty
            $advId = $testDeployment.AdvertisementID
            $deploymentName = $testDeployment.AdvertisementName

            # Act - Remove by deployment name
            $result = Remove-CM7TaskSequenceDeployment -DeploymentName $deploymentName -Force

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.AdvertisementID | Should -Be $advId
            $result.AdvertisementName | Should -Be $deploymentName
            $result.Status | Should -Be 'Removed'

            # Verify deployment is actually gone
            $namespace = "root/SMS/site_$($script:CMConnection.SiteCode)"
            $check = Get-CimInstance -CimSession $script:CMConnection.CimSession -Namespace $namespace -Query "SELECT AdvertisementID FROM SMS_Advertisement WHERE AdvertisementID = '$advId'"
            $check | Should -BeNullOrEmpty

            # Remove from cleanup tracking
            $script:CreatedAdvertisementIds = $script:CreatedAdvertisementIds | Where-Object { $_ -ne $advId }
        }

        It "Should remove deployments by wildcard DeploymentName" {
            # Arrange - Create a test deployment first
            $testDeployment = New-TestDeploymentForRemoval -NamePrefix "Test-RemoveTSD-Wildcard"
            $testDeployment | Should -Not -BeNullOrEmpty
            $advId = $testDeployment.AdvertisementID

            # Act - Remove by wildcard deployment name
            $results = @(Remove-CM7TaskSequenceDeployment -DeploymentName "Test-RemoveTSD-Wildcard*" -Force)

            # Assert
            $results | Should -Not -BeNullOrEmpty
            $ourResult = $results | Where-Object { $_.AdvertisementID -eq $advId }
            $ourResult | Should -Not -BeNullOrEmpty
            $ourResult.Status | Should -Be 'Removed'

            # Remove ALL returned IDs from cleanup tracking
            foreach ($r in $results) {
                $script:CreatedAdvertisementIds = $script:CreatedAdvertisementIds | Where-Object { $_ -ne $r.AdvertisementID }
            }
        }
    }

    Context "Remove Deployment by InputObject" {

        It "Should remove a deployment using InputObject from Get-CM7TaskSequenceDeployment" {
            # Arrange - Create a test deployment first
            $testDeployment = New-TestDeploymentForRemoval -NamePrefix "Test-RemoveTSD-InputObj"
            $testDeployment | Should -Not -BeNullOrEmpty
            $advId = $testDeployment.AdvertisementID

            # Get the deployment object via Get-CM7TaskSequenceDeployment
            $deployObj = Get-CM7TaskSequenceDeployment -AdvertisementID $advId
            $deployObj | Should -Not -BeNullOrEmpty

            # Act - Remove by InputObject
            $result = Remove-CM7TaskSequenceDeployment -InputObject $deployObj -Force

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.AdvertisementID | Should -Be $advId
            $result.Status | Should -Be 'Removed'

            # Remove from cleanup tracking
            $script:CreatedAdvertisementIds = $script:CreatedAdvertisementIds | Where-Object { $_ -ne $advId }
        }

        It "Should remove a deployment via pipeline" {
            # Arrange - Create a test deployment first
            $testDeployment = New-TestDeploymentForRemoval -NamePrefix "Test-RemoveTSD-Pipeline"
            $testDeployment | Should -Not -BeNullOrEmpty
            $advId = $testDeployment.AdvertisementID

            # Act - Remove via pipeline
            $result = Get-CM7TaskSequenceDeployment -AdvertisementID $advId | Remove-CM7TaskSequenceDeployment -Force

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.AdvertisementID | Should -Be $advId
            $result.Status | Should -Be 'Removed'

            # Remove from cleanup tracking
            $script:CreatedAdvertisementIds = $script:CreatedAdvertisementIds | Where-Object { $_ -ne $advId }
        }
    }

    Context "Error Handling" {

        It "Should throw for non-existent AdvertisementID" {
            # Arrange
            $nonExistentId = $script:TestRemoveTSDData.NonExistentDeployment.AdvertisementID

            # Act & Assert
            { Remove-CM7TaskSequenceDeployment -AdvertisementID $nonExistentId -Force } | Should -Throw "*not found*"
        }

        It "Should throw for non-existent collection name" {
            # Arrange
            $nonExistentColl = $script:TestRemoveTSDData.NonExistentCollection.CollectionName

            # Act & Assert
            { Remove-CM7TaskSequenceDeployment -CollectionName $nonExistentColl -Force } | Should -Throw "*not found*"
        }

        It "Should throw when InputObject has no AdvertisementID property" {
            # Arrange
            $badObj = [PSCustomObject]@{ Name = "Test"; SomeOtherProperty = "Value" }

            # Act & Assert
            { Remove-CM7TaskSequenceDeployment -InputObject $badObj -Force } | Should -Throw "*AdvertisementID*"
        }
    }

    Context "WhatIf Support" {

        It "Should support -WhatIf parameter without actually removing" {
            # Arrange - Create a test deployment
            $testDeployment = New-TestDeploymentForRemoval -NamePrefix "Test-RemoveTSD-WhatIf"
            $testDeployment | Should -Not -BeNullOrEmpty
            $advId = $testDeployment.AdvertisementID

            # Act - WhatIf should not remove
            { Remove-CM7TaskSequenceDeployment -AdvertisementID $advId -WhatIf } | Should -Not -Throw

            # Assert - Deployment should still exist
            $namespace = "root/SMS/site_$($script:CMConnection.SiteCode)"
            $check = Get-CimInstance -CimSession $script:CMConnection.CimSession -Namespace $namespace -Query "SELECT AdvertisementID FROM SMS_Advertisement WHERE AdvertisementID = '$advId'"
            $check | Should -Not -BeNullOrEmpty

            # Clean up - actually remove it
            Remove-CM7TaskSequenceDeployment -AdvertisementID $advId -Force
            $script:CreatedAdvertisementIds = $script:CreatedAdvertisementIds | Where-Object { $_ -ne $advId }
        }
    }

    Context "Return Object Properties" {

        It "Should return objects with expected properties" {
            # Arrange - Create a test deployment
            $testDeployment = New-TestDeploymentForRemoval -NamePrefix "Test-RemoveTSD-Props"
            $testDeployment | Should -Not -BeNullOrEmpty
            $advId = $testDeployment.AdvertisementID

            # Act
            $result = Remove-CM7TaskSequenceDeployment -AdvertisementID $advId -Force

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.PSObject.Properties.Name | Should -Contain 'AdvertisementID'
            $result.PSObject.Properties.Name | Should -Contain 'AdvertisementName'
            $result.PSObject.Properties.Name | Should -Contain 'CollectionID'
            $result.PSObject.Properties.Name | Should -Contain 'CollectionName'
            $result.PSObject.Properties.Name | Should -Contain 'PackageID'
            $result.PSObject.Properties.Name | Should -Contain 'TaskSequenceName'
            $result.PSObject.Properties.Name | Should -Contain 'Status'
            $result.Status | Should -Be 'Removed'

            # Remove from cleanup tracking
            $script:CreatedAdvertisementIds = $script:CreatedAdvertisementIds | Where-Object { $_ -ne $advId }
        }

        It "Should have PSTypeName set correctly" {
            # Arrange - Create a test deployment
            $testDeployment = New-TestDeploymentForRemoval -NamePrefix "Test-RemoveTSD-PSType"
            $testDeployment | Should -Not -BeNullOrEmpty
            $advId = $testDeployment.AdvertisementID

            # Act
            $result = Remove-CM7TaskSequenceDeployment -AdvertisementID $advId -Force

            # Assert
            if ($result) {
                $result.PSObject.TypeNames[0] | Should -Be 'MECM7.RemovedTaskSequenceDeployment'
            }

            # Remove from cleanup tracking
            $script:CreatedAdvertisementIds = $script:CreatedAdvertisementIds | Where-Object { $_ -ne $advId }
        }
    }

    Context "Verbose Output" {

        It "Should provide verbose output when requested" {
            # Arrange - Create a test deployment
            $testDeployment = New-TestDeploymentForRemoval -NamePrefix "Test-RemoveTSD-Verbose"
            $testDeployment | Should -Not -BeNullOrEmpty
            $advId = $testDeployment.AdvertisementID

            # Act
            $verboseOutput = Remove-CM7TaskSequenceDeployment -AdvertisementID $advId -Force -Verbose 4>&1

            # Assert
            $verboseOutput | Should -Not -BeNullOrEmpty
            $verboseMessages = $verboseOutput | Where-Object { $_ -is [System.Management.Automation.VerboseRecord] }
            $runningMessage = $verboseMessages | Where-Object { $_.Message -match "Running Remove-CM7TaskSequenceDeployment" }
            $runningMessage | Should -Not -BeNullOrEmpty

            # Remove from cleanup tracking
            $resultObj = $verboseOutput | Where-Object { $_ -isnot [System.Management.Automation.VerboseRecord] }
            if ($resultObj -and $resultObj.AdvertisementID) {
                $script:CreatedAdvertisementIds = $script:CreatedAdvertisementIds | Where-Object { $_ -ne $resultObj.AdvertisementID }
            } else {
                $script:CreatedAdvertisementIds = $script:CreatedAdvertisementIds | Where-Object { $_ -ne $advId }
            }
        }
    }
}

AfterAll {
    # Clean up: remove any remaining test deployments that weren't cleaned up during tests
    if ($script:CMConnection.CimSession -and $script:CreatedAdvertisementIds.Count -gt 0) {
        $namespace = "root/SMS/site_$($script:CMConnection.SiteCode)"
        $uniqueIds = $script:CreatedAdvertisementIds | Select-Object -Unique
        Write-Host "Test cleanup: Removing $($uniqueIds.Count) remaining test task sequence deployment(s)" -ForegroundColor Yellow
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
