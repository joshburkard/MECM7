# Functional Tests for New-CM7SoftwareUpdateGroup
# Tests the New-CM7SoftwareUpdateGroup function behavior and return values

BeforeAll {
    # Load test declarations
    . (Join-Path $PSScriptRoot "declarations.ps1")

    # Load all functions
    $CodePath = Join-Path (Get-Item $PSScriptRoot).Parent.FullName "Code"
    Get-ChildItem -Path (Join-Path $CodePath "Private") -Filter "*.ps1" | ForEach-Object { . $_.FullName }
    Get-ChildItem -Path (Join-Path $CodePath "Public") -Filter "*.ps1" | ForEach-Object { . $_.FullName }

    # Get test data for this function
    $script:TestNewSUGData = $script:TestData['New-CM7SoftwareUpdateGroup']
    $script:TestConnectData = $script:TestData['Connect-CM7']

    # Track created software update groups for cleanup
    $script:CreatedGroupIds = @()

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

Describe "New-CM7SoftwareUpdateGroup Function Tests" -Tag "Integration", "SoftwareUpdateGroup", "New" {

    Context "Test Data Validation" {

        It "Should have test data defined in declarations.ps1" {
            # Assert
            $script:TestNewSUGData | Should -Not -BeNullOrEmpty
            $script:TestData.ContainsKey('New-CM7SoftwareUpdateGroup') | Should -Be $true
        }

        It "Should have required test data parameter sets" {
            # Assert
            $script:TestNewSUGData.ContainsKey('BasicGroup') | Should -Be $true
            $script:TestNewSUGData.ContainsKey('WithUpdates') | Should -Be $true
            $script:TestNewSUGData.ContainsKey('DuplicateName') | Should -Be $true
        }

        It "Should output test data for verification" {
            # Output test data
            Write-Host "`n=== Test Data for New-CM7SoftwareUpdateGroup ===" -ForegroundColor Cyan
            Write-Host "BasicGroup:" -ForegroundColor Yellow
            Write-Host "  Name: $($script:TestNewSUGData.BasicGroup.Name)" -ForegroundColor White
            Write-Host "  Description: $($script:TestNewSUGData.BasicGroup.Description)" -ForegroundColor White

            Write-Host "DuplicateName:" -ForegroundColor Yellow
            Write-Host "  Name: $($script:TestNewSUGData.DuplicateName.Name)" -ForegroundColor White
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
            { New-CM7SoftwareUpdateGroup -Name "Test" } | Should -Throw "*not connected*"

            # Restore connection
            $script:CMConnection = $backupConnection
        }
    }

    Context "Create Basic Software Update Group" {

        It "Should create a software update group with name only" {
            # Arrange
            $uniqueName = "$($script:TestNewSUGData.BasicGroup.Name)-$(Get-Date -Format 'yyyyMMdd_HHmmss')"

            # Act
            $result = New-CM7SoftwareUpdateGroup -Name $uniqueName -Force

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.LocalizedDisplayName | Should -Be $uniqueName
            $result.CI_ID | Should -BeGreaterThan 0

            # Track for cleanup
            $script:CreatedGroupIds += $result.CI_ID
        }

        It "Should create a software update group with name and description" {
            # Arrange
            $uniqueName = "$($script:TestNewSUGData.BasicGroup.Name)-Desc-$(Get-Date -Format 'yyyyMMdd_HHmmss')"
            $description = $script:TestNewSUGData.BasicGroup.Description

            # Act
            $result = New-CM7SoftwareUpdateGroup -Name $uniqueName -Description $description -Force

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.LocalizedDisplayName | Should -Be $uniqueName
            $result.LocalizedDescription | Should -Be $description
            $result.CI_ID | Should -BeGreaterThan 0

            # Track for cleanup
            $script:CreatedGroupIds += $result.CI_ID
        }
    }

    Context "Create Software Update Group with Updates" {

        It "Should create a software update group with update CI_IDs" {
            # Arrange - Get some real updates to add
            $updates = Get-CimInstance -CimSession $script:CMConnection.CimSession `
                -Namespace "root/SMS/site_$($script:CMConnection.SiteCode)" `
                -Query "SELECT CI_ID FROM SMS_SoftwareUpdate WHERE IsExpired = 0 AND IsSuperseded = 0" |
                Select-Object -First 2

            if (-not $updates) {
                Set-ItResult -Skipped -Because "No non-expired, non-superseded software updates found in the environment"
                return
            }

            $uniqueName = "$($script:TestNewSUGData.WithUpdates.Name)-$(Get-Date -Format 'yyyyMMdd_HHmmss')"
            $updateIds = @($updates | ForEach-Object { [int]$_.CI_ID })

            # Act
            $result = New-CM7SoftwareUpdateGroup -Name $uniqueName -UpdateId $updateIds -Force

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.LocalizedDisplayName | Should -Be $uniqueName
            $result.CI_ID | Should -BeGreaterThan 0

            # Track for cleanup
            $script:CreatedGroupIds += $result.CI_ID
        }

        It "Should create a software update group using -SoftwareUpdateIds alias" {
            # Arrange - Get some real updates to add
            $updates = Get-CimInstance -CimSession $script:CMConnection.CimSession `
                -Namespace "root/SMS/site_$($script:CMConnection.SiteCode)" `
                -Query "SELECT CI_ID FROM SMS_SoftwareUpdate WHERE IsExpired = 0 AND IsSuperseded = 0" |
                Select-Object -First 1

            if (-not $updates) {
                Set-ItResult -Skipped -Because "No non-expired, non-superseded software updates found in the environment"
                return
            }

            $uniqueName = "$($script:TestNewSUGData.WithUpdates.Name)-Alias-$(Get-Date -Format 'yyyyMMdd_HHmmss')"
            $updateIds = @($updates | ForEach-Object { [int]$_.CI_ID })

            # Act
            $result = New-CM7SoftwareUpdateGroup -Name $uniqueName -SoftwareUpdateId $updateIds -Force

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.LocalizedDisplayName | Should -Be $uniqueName
            $result.CI_ID | Should -BeGreaterThan 0

            # Track for cleanup
            $script:CreatedGroupIds += $result.CI_ID
        }
    }

    Context "Error Handling" {

        It "Should throw for duplicate software update group name" {
            # Arrange - The existing group from test data
            $duplicateName = $script:TestNewSUGData.DuplicateName.Name

            # Act & Assert
            { New-CM7SoftwareUpdateGroup -Name $duplicateName -Force } | Should -Throw "*already exists*"
        }
    }

    Context "WhatIf Support" {

        It "Should support -WhatIf parameter" {
            # Arrange
            $uniqueName = "Test-SUG-WhatIf-$(Get-Date -Format 'yyyyMMdd_HHmmss')"

            # Act & Assert - should not throw, and should not actually create
            { New-CM7SoftwareUpdateGroup -Name $uniqueName -WhatIf } | Should -Not -Throw

            # Verify the software update group was NOT created
            $checkQuery = "SELECT CI_ID FROM SMS_AuthorizationList WHERE LocalizedDisplayName = '$uniqueName'"
            $namespace = "root/SMS/site_$($script:CMConnection.SiteCode)"
            $check = Get-CimInstance -CimSession $script:CMConnection.CimSession -Namespace $namespace -Query $checkQuery
            $check | Should -BeNullOrEmpty
        }
    }

    Context "Return Object Properties" {

        It "Should return objects with expected properties" {
            # Arrange
            $uniqueName = "Test-SUG-ReturnProps-$(Get-Date -Format 'yyyyMMdd_HHmmss')"

            # Act
            $result = New-CM7SoftwareUpdateGroup -Name $uniqueName -Force

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.PSObject.Properties.Name | Should -Contain 'CI_ID'
            $result.PSObject.Properties.Name | Should -Contain 'CI_UniqueID'
            $result.PSObject.Properties.Name | Should -Contain 'LocalizedDisplayName'
            $result.PSObject.Properties.Name | Should -Contain 'LocalizedDescription'
            $result.PSObject.Properties.Name | Should -Contain 'IsDeployed'
            $result.PSObject.Properties.Name | Should -Contain 'IsExpired'
            $result.PSObject.Properties.Name | Should -Contain 'IsSuperseded'
            $result.PSObject.Properties.Name | Should -Contain 'NumberOfUpdates'
            $result.PSObject.Properties.Name | Should -Contain 'DateCreated'
            $result.PSObject.Properties.Name | Should -Contain 'DateLastModified'

            # Track for cleanup
            $script:CreatedGroupIds += $result.CI_ID
        }

        It "Should have PSTypeName set correctly" {
            # Arrange
            $uniqueName = "Test-SUG-PSTypeName-$(Get-Date -Format 'yyyyMMdd_HHmmss')"

            # Act
            $result = New-CM7SoftwareUpdateGroup -Name $uniqueName -Force

            # Assert
            if ($result) {
                $result.PSObject.TypeNames[0] | Should -Be 'MECM7.SoftwareUpdateGroup'
            }

            # Track for cleanup
            if ($result) { $script:CreatedGroupIds += $result.CI_ID }
        }

        It "Should have default values for a new empty group" {
            # Arrange
            $uniqueName = "Test-SUG-Defaults-$(Get-Date -Format 'yyyyMMdd_HHmmss')"

            # Act
            $result = New-CM7SoftwareUpdateGroup -Name $uniqueName -Force

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.IsDeployed | Should -Be $false
            $result.NumberOfUpdates | Should -Be 0

            # Track for cleanup
            $script:CreatedGroupIds += $result.CI_ID
        }
    }

    Context "Verbose Output" {

        It "Should provide verbose output when requested" {
            # Arrange
            $uniqueName = "Test-SUG-Verbose-$(Get-Date -Format 'yyyyMMdd_HHmmss')"

            # Act
            $verboseOutput = New-CM7SoftwareUpdateGroup -Name $uniqueName -Force -Verbose 4>&1

            # Assert
            $verboseOutput | Should -Not -BeNullOrEmpty
            $verboseMessages = $verboseOutput | Where-Object { $_ -is [System.Management.Automation.VerboseRecord] }
            $runningMessage = $verboseMessages | Where-Object { $_.Message -match "Running New-CM7SoftwareUpdateGroup" }
            $runningMessage | Should -Not -BeNullOrEmpty

            # Track for cleanup - extract the actual result from verbose output
            $resultObj = $verboseOutput | Where-Object { $_ -isnot [System.Management.Automation.VerboseRecord] }
            if ($resultObj -and $resultObj.CI_ID) {
                $script:CreatedGroupIds += $resultObj.CI_ID
            }
        }
    }
}

AfterAll {
    # Clean up: remove all test software update groups created during tests
    if ($script:CMConnection.CimSession -and $script:CreatedGroupIds.Count -gt 0) {
        $namespace = "root/SMS/site_$($script:CMConnection.SiteCode)"
        $uniqueIds = $script:CreatedGroupIds | Select-Object -Unique
        Write-Host "Test cleanup: Removing $($uniqueIds.Count) test software update group(s)" -ForegroundColor Yellow
        foreach ($id in $uniqueIds) {
            try {
                $groupQuery = "SELECT * FROM SMS_AuthorizationList WHERE CI_ID = $id"
                $group = Get-CimInstance -CimSession $script:CMConnection.CimSession -Namespace $namespace -Query $groupQuery
                if ($group) {
                    Remove-CimInstance -CimSession $script:CMConnection.CimSession -InputObject $group -ErrorAction SilentlyContinue
                    Write-Host "  Removed software update group: CI_ID $id" -ForegroundColor Green
                }
            }
            catch {
                Write-Warning "  Failed to remove software update group CI_ID '$id': $_"
            }
        }
        Write-Host "Test cleanup: Done" -ForegroundColor Green
    }
}
