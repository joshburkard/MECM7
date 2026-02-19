# Functional Tests for New-CM7SoftwareUpdateDeployment
# Tests the New-CM7SoftwareUpdateDeployment function behavior and return values

BeforeAll {
    # Load test declarations
    . (Join-Path $PSScriptRoot "declarations.ps1")

    # Load all functions
    $CodePath = Join-Path (Get-Item $PSScriptRoot).Parent.FullName "Code"
    Get-ChildItem -Path (Join-Path $CodePath "Private") -Filter "*.ps1" | ForEach-Object { . $_.FullName }
    Get-ChildItem -Path (Join-Path $CodePath "Public") -Filter "*.ps1" | ForEach-Object { . $_.FullName }

    # Get test data for this function
    $script:TestNewSUDData = $script:TestData['New-CM7SoftwareUpdateDeployment']
    $script:TestConnectData = $script:TestData['Connect-CM7']

    # Track created deployments for cleanup
    $script:CreatedDeploymentIds = @()

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

Describe "New-CM7SoftwareUpdateDeployment Function Tests" -Tag "Integration", "SoftwareUpdateDeployment", "New" {

    Context "Test Data Validation" {

        It "Should have test data defined in declarations.ps1" {
            # Assert
            $script:TestNewSUDData | Should -Not -BeNullOrEmpty
            $script:TestData.ContainsKey('New-CM7SoftwareUpdateDeployment') | Should -Be $true
        }

        It "Should have required test data parameter sets" {
            # Assert
            $script:TestNewSUDData.ContainsKey('BasicDeployment') | Should -Be $true
            $script:TestNewSUDData.ContainsKey('AvailableDeployment') | Should -Be $true
            $script:TestNewSUDData.ContainsKey('NonExistentGroup') | Should -Be $true
            $script:TestNewSUDData.ContainsKey('NonExistentCollection') | Should -Be $true
            $script:TestNewSUDData.ContainsKey('EmptySoftwareUpdateGroup') | Should -Be $true
        }

        It "Should output test data for verification" {
            # Output test data
            Write-Host "`n=== Test Data for New-CM7SoftwareUpdateDeployment ===" -ForegroundColor Cyan
            Write-Host "BasicDeployment:" -ForegroundColor Yellow
            Write-Host "  SoftwareUpdateGroupName: $($script:TestNewSUDData.BasicDeployment.SoftwareUpdateGroupName)" -ForegroundColor White
            Write-Host "  CollectionName: $($script:TestNewSUDData.BasicDeployment.CollectionName)" -ForegroundColor White
            Write-Host "  DeploymentType: $($script:TestNewSUDData.BasicDeployment.DeploymentType)" -ForegroundColor White

            Write-Host "AvailableDeployment:" -ForegroundColor Yellow
            Write-Host "  DeploymentType: $($script:TestNewSUDData.AvailableDeployment.DeploymentType)" -ForegroundColor White
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
            { New-CM7SoftwareUpdateDeployment -SoftwareUpdateGroupName "Test" -CollectionName "Test" } | Should -Throw "*not connected*"

            # Restore connection
            $script:CMConnection = $backupConnection
        }
    }

    Context "Create Basic Required Deployment" {

        It "Should create a required software update deployment" {
            # Arrange
            $groupName = $script:TestNewSUDData.BasicDeployment.SoftwareUpdateGroupName
            $collectionName = $script:TestNewSUDData.BasicDeployment.CollectionName
            $uniqueDeploymentName = "Test-SUD-Basic-$(Get-Date -Format 'yyyyMMdd_HHmmss')"

            # Act
            $result = New-CM7SoftwareUpdateDeployment `
                -SoftwareUpdateGroupName $groupName `
                -CollectionName $collectionName `
                -DeploymentName $uniqueDeploymentName `
                -Force

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.AssignmentName | Should -Be $uniqueDeploymentName
            $result.AssignmentID | Should -BeGreaterThan 0
            $result.DesiredConfigType | Should -Be 'Required'

            # Track for cleanup
            $script:CreatedDeploymentIds += $result.AssignmentID
        }

        It "Should create a deployment with description" {
            # Arrange
            $groupName = $script:TestNewSUDData.BasicDeployment.SoftwareUpdateGroupName
            $collectionName = $script:TestNewSUDData.BasicDeployment.CollectionName
            $uniqueDeploymentName = "Test-SUD-Desc-$(Get-Date -Format 'yyyyMMdd_HHmmss')"
            $description = "Test deployment created by automated tests"

            # Act
            $result = New-CM7SoftwareUpdateDeployment `
                -SoftwareUpdateGroupName $groupName `
                -CollectionName $collectionName `
                -DeploymentName $uniqueDeploymentName `
                -Description $description `
                -Force

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.AssignmentName | Should -Be $uniqueDeploymentName
            $result.AssignmentDescription | Should -Be $description

            # Track for cleanup
            $script:CreatedDeploymentIds += $result.AssignmentID
        }
    }

    Context "Create Available Deployment" {

        It "Should create an available (optional) software update deployment" {
            # Arrange
            $groupName = $script:TestNewSUDData.AvailableDeployment.SoftwareUpdateGroupName
            $collectionName = $script:TestNewSUDData.AvailableDeployment.CollectionName
            $uniqueDeploymentName = "Test-SUD-Available-$(Get-Date -Format 'yyyyMMdd_HHmmss')"

            # Act
            $result = New-CM7SoftwareUpdateDeployment `
                -SoftwareUpdateGroupName $groupName `
                -CollectionName $collectionName `
                -DeploymentName $uniqueDeploymentName `
                -DeploymentType Available `
                -Force

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.AssignmentName | Should -Be $uniqueDeploymentName
            $result.DesiredConfigType | Should -Be 'Available'

            # Track for cleanup
            $script:CreatedDeploymentIds += $result.AssignmentID
        }
    }

    Context "Create Deployment with Deadline" {

        It "Should create a deployment with a specific deadline" {
            # Arrange
            $groupName = $script:TestNewSUDData.BasicDeployment.SoftwareUpdateGroupName
            $collectionName = $script:TestNewSUDData.BasicDeployment.CollectionName
            $uniqueDeploymentName = "Test-SUD-Deadline-$(Get-Date -Format 'yyyyMMdd_HHmmss')"
            $deadline = (Get-Date).AddDays(7)

            # Act
            $result = New-CM7SoftwareUpdateDeployment `
                -SoftwareUpdateGroupName $groupName `
                -CollectionName $collectionName `
                -DeploymentName $uniqueDeploymentName `
                -DeadlineDateTime $deadline `
                -Force

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.AssignmentName | Should -Be $uniqueDeploymentName
            $result.EnforcementDeadline | Should -Not -BeNullOrEmpty

            # Track for cleanup
            $script:CreatedDeploymentIds += $result.AssignmentID
        }
    }

    Context "Create Deployment with SoftwareUpdateGroupId and CollectionId" {

        It "Should create a deployment using group CI_ID and collection ID" {
            # Arrange - Resolve group and collection IDs dynamically
            $namespace = "root/SMS/site_$($script:CMConnection.SiteCode)"
            $groupName = $script:TestNewSUDData.BasicDeployment.SoftwareUpdateGroupName

            $group = Get-CimInstance -CimSession $script:CMConnection.CimSession `
                -Namespace $namespace `
                -Query "SELECT CI_ID FROM SMS_AuthorizationList WHERE LocalizedDisplayName = '$groupName'"

            $collName = $script:TestNewSUDData.BasicDeployment.CollectionName
            $collection = Get-CimInstance -CimSession $script:CMConnection.CimSession `
                -Namespace $namespace `
                -Query "SELECT CollectionID FROM SMS_Collection WHERE Name = '$collName'"

            if (-not $group -or -not $collection) {
                Set-ItResult -Skipped -Because "Could not resolve software update group or collection for ID-based test"
                return
            }

            $uniqueDeploymentName = "Test-SUD-ById-$(Get-Date -Format 'yyyyMMdd_HHmmss')"

            # Act
            $result = New-CM7SoftwareUpdateDeployment `
                -SoftwareUpdateGroupId ([int]$group.CI_ID) `
                -CollectionId $collection.CollectionID `
                -DeploymentName $uniqueDeploymentName `
                -Force

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.AssignmentName | Should -Be $uniqueDeploymentName
            $result.TargetCollectionID | Should -Be $collection.CollectionID

            # Track for cleanup
            $script:CreatedDeploymentIds += $result.AssignmentID
        }
    }

    Context "Error Handling" {

        It "Should throw for non-existent software update group" {
            # Arrange
            $nonExistentGroup = $script:TestNewSUDData.NonExistentGroup.SoftwareUpdateGroupName
            $collectionName = $script:TestNewSUDData.NonExistentGroup.CollectionName

            # Act & Assert
            { New-CM7SoftwareUpdateDeployment -SoftwareUpdateGroupName $nonExistentGroup -CollectionName $collectionName -Force } | Should -Throw "*not found*"
        }

        It "Should throw for non-existent collection" {
            # Arrange
            $groupName = $script:TestNewSUDData.NonExistentCollection.SoftwareUpdateGroupName
            $collectionName = $script:TestNewSUDData.NonExistentCollection.CollectionName

            # Act & Assert
            { New-CM7SoftwareUpdateDeployment -SoftwareUpdateGroupName $groupName -CollectionName $collectionName -Force } | Should -Throw "*not found*"
        }

        It "Should throw for empty software update group (no updates)" {
            # Arrange
            $groupName = $script:TestNewSUDData.EmptySoftwareUpdateGroup.SoftwareUpdateGroupName
            $collectionName = $script:TestNewSUDData.EmptySoftwareUpdateGroup.CollectionName

            # Act & Assert
            { New-CM7SoftwareUpdateDeployment -SoftwareUpdateGroupName $groupName -CollectionName $collectionName -Force } | Should -Throw "*contains no updates*"
        }
    }

    Context "WhatIf Support" {

        It "Should support -WhatIf parameter" {
            # Arrange
            $groupName = $script:TestNewSUDData.BasicDeployment.SoftwareUpdateGroupName
            $collectionName = $script:TestNewSUDData.BasicDeployment.CollectionName
            $uniqueDeploymentName = "Test-SUD-WhatIf-$(Get-Date -Format 'yyyyMMdd_HHmmss')"

            # Act & Assert - should not throw, and should not actually create
            { New-CM7SoftwareUpdateDeployment `
                -SoftwareUpdateGroupName $groupName `
                -CollectionName $collectionName `
                -DeploymentName $uniqueDeploymentName `
                -WhatIf } | Should -Not -Throw

            # Verify the deployment was NOT created
            $namespace = "root/SMS/site_$($script:CMConnection.SiteCode)"
            $checkQuery = "SELECT AssignmentID FROM SMS_UpdateGroupAssignment WHERE AssignmentName = '$uniqueDeploymentName'"
            $check = Get-CimInstance -CimSession $script:CMConnection.CimSession -Namespace $namespace -Query $checkQuery
            $check | Should -BeNullOrEmpty
        }
    }

    Context "Return Object Properties" {

        It "Should return objects with expected properties" {
            # Arrange
            $groupName = $script:TestNewSUDData.BasicDeployment.SoftwareUpdateGroupName
            $collectionName = $script:TestNewSUDData.BasicDeployment.CollectionName
            $uniqueDeploymentName = "Test-SUD-ReturnProps-$(Get-Date -Format 'yyyyMMdd_HHmmss')"

            # Act
            $result = New-CM7SoftwareUpdateDeployment `
                -SoftwareUpdateGroupName $groupName `
                -CollectionName $collectionName `
                -DeploymentName $uniqueDeploymentName `
                -Force

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.PSObject.Properties.Name | Should -Contain 'AssignmentID'
            $result.PSObject.Properties.Name | Should -Contain 'AssignmentName'
            $result.PSObject.Properties.Name | Should -Contain 'TargetCollectionID'
            $result.PSObject.Properties.Name | Should -Contain 'CollectionName'
            $result.PSObject.Properties.Name | Should -Contain 'AssignmentDescription'
            $result.PSObject.Properties.Name | Should -Contain 'AssignmentAction'
            $result.PSObject.Properties.Name | Should -Contain 'DesiredConfigType'
            $result.PSObject.Properties.Name | Should -Contain 'StartTime'
            $result.PSObject.Properties.Name | Should -Contain 'EnforcementDeadline'
            $result.PSObject.Properties.Name | Should -Contain 'SuppressReboot'
            $result.PSObject.Properties.Name | Should -Contain 'UseGMTTimes'
            $result.PSObject.Properties.Name | Should -Contain 'NotifyUser'
            $result.PSObject.Properties.Name | Should -Contain 'OverrideServiceWindows'
            $result.PSObject.Properties.Name | Should -Contain 'RebootOutsideOfServiceWindows'
            $result.PSObject.Properties.Name | Should -Contain 'Enabled'

            # Track for cleanup
            $script:CreatedDeploymentIds += $result.AssignmentID
        }

        It "Should have PSTypeName set correctly" {
            # Arrange
            $groupName = $script:TestNewSUDData.BasicDeployment.SoftwareUpdateGroupName
            $collectionName = $script:TestNewSUDData.BasicDeployment.CollectionName
            $uniqueDeploymentName = "Test-SUD-PSTypeName-$(Get-Date -Format 'yyyyMMdd_HHmmss')"

            # Act
            $result = New-CM7SoftwareUpdateDeployment `
                -SoftwareUpdateGroupName $groupName `
                -CollectionName $collectionName `
                -DeploymentName $uniqueDeploymentName `
                -Force

            # Assert
            if ($result) {
                $result.PSObject.TypeNames[0] | Should -Be 'MECM7.SoftwareUpdateDeployment'
            }

            # Track for cleanup
            if ($result) { $script:CreatedDeploymentIds += $result.AssignmentID }
        }

        It "Should have friendly name strings for AssignmentAction and DesiredConfigType" {
            # Arrange
            $groupName = $script:TestNewSUDData.BasicDeployment.SoftwareUpdateGroupName
            $collectionName = $script:TestNewSUDData.BasicDeployment.CollectionName
            $uniqueDeploymentName = "Test-SUD-FriendlyNames-$(Get-Date -Format 'yyyyMMdd_HHmmss')"

            # Act
            $result = New-CM7SoftwareUpdateDeployment `
                -SoftwareUpdateGroupName $groupName `
                -CollectionName $collectionName `
                -DeploymentName $uniqueDeploymentName `
                -Force

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.AssignmentAction | Should -Match "^(Detect|Apply)$"
            $result.DesiredConfigType | Should -Match "^(Required|Available)$"

            # Track for cleanup
            $script:CreatedDeploymentIds += $result.AssignmentID
        }

        It "Should have default values for a new deployment" {
            # Arrange
            $groupName = $script:TestNewSUDData.BasicDeployment.SoftwareUpdateGroupName
            $collectionName = $script:TestNewSUDData.BasicDeployment.CollectionName
            $uniqueDeploymentName = "Test-SUD-Defaults-$(Get-Date -Format 'yyyyMMdd_HHmmss')"

            # Act
            $result = New-CM7SoftwareUpdateDeployment `
                -SoftwareUpdateGroupName $groupName `
                -CollectionName $collectionName `
                -DeploymentName $uniqueDeploymentName `
                -Force

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.Enabled | Should -Be $true
            $result.AssignmentAction | Should -Be 'Apply'
            $result.DesiredConfigType | Should -Be 'Required'

            # Track for cleanup
            $script:CreatedDeploymentIds += $result.AssignmentID
        }
    }

    Context "Verbose Output" {

        It "Should provide verbose output when requested" {
            # Arrange
            $groupName = $script:TestNewSUDData.BasicDeployment.SoftwareUpdateGroupName
            $collectionName = $script:TestNewSUDData.BasicDeployment.CollectionName
            $uniqueDeploymentName = "Test-SUD-Verbose-$(Get-Date -Format 'yyyyMMdd_HHmmss')"

            # Act
            $verboseOutput = New-CM7SoftwareUpdateDeployment `
                -SoftwareUpdateGroupName $groupName `
                -CollectionName $collectionName `
                -DeploymentName $uniqueDeploymentName `
                -Force -Verbose 4>&1

            # Assert
            $verboseOutput | Should -Not -BeNullOrEmpty
            $verboseMessages = $verboseOutput | Where-Object { $_ -is [System.Management.Automation.VerboseRecord] }
            $runningMessage = $verboseMessages | Where-Object { $_.Message -match "Running New-CM7SoftwareUpdateDeployment" }
            $runningMessage | Should -Not -BeNullOrEmpty

            # Track for cleanup - extract the actual result from verbose output
            $resultObj = $verboseOutput | Where-Object { $_ -isnot [System.Management.Automation.VerboseRecord] }
            if ($resultObj -and $resultObj.AssignmentID) {
                $script:CreatedDeploymentIds += $resultObj.AssignmentID
            }
        }
    }
}

AfterAll {
    # Clean up: remove all test software update deployments created during tests
    if ($script:CMConnection.CimSession -and $script:CreatedDeploymentIds.Count -gt 0) {
        $namespace = "root/SMS/site_$($script:CMConnection.SiteCode)"
        $uniqueIds = $script:CreatedDeploymentIds | Select-Object -Unique
        Write-Host "Test cleanup: Removing $($uniqueIds.Count) test software update deployment(s)" -ForegroundColor Yellow
        foreach ($id in $uniqueIds) {
            try {
                $deploymentQuery = "SELECT * FROM SMS_UpdateGroupAssignment WHERE AssignmentID = $id"
                $deployment = Get-CimInstance -CimSession $script:CMConnection.CimSession -Namespace $namespace -Query $deploymentQuery
                if ($deployment) {
                    Remove-CimInstance -CimSession $script:CMConnection.CimSession -InputObject $deployment -ErrorAction SilentlyContinue
                    Write-Host "  Removed software update deployment: AssignmentID $id" -ForegroundColor Green
                }
            }
            catch {
                Write-Warning "  Failed to remove software update deployment AssignmentID '$id': $_"
            }
        }
        Write-Host "Test cleanup: Done" -ForegroundColor Green
    }
}
