# Functional Tests for Invoke-CM7CollectionUpdate
# Tests the Invoke-CM7CollectionUpdate function behavior and return values

BeforeAll {
    # Load test declarations
    . (Join-Path $PSScriptRoot "declarations.ps1")

    # Load all functions
    $CodePath = Join-Path (Get-Item $PSScriptRoot).Parent.FullName "Code"
    Get-ChildItem -Path (Join-Path $CodePath "Private") -Filter "*.ps1" | ForEach-Object { . $_.FullName }
    Get-ChildItem -Path (Join-Path $CodePath "Public") -Filter "*.ps1" | ForEach-Object { . $_.FullName }

    # Get test data for this function
    $script:TestCollectionUpdateData = $script:TestData['Invoke-CM7CollectionUpdate']
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

Describe "Invoke-CM7CollectionUpdate Function Tests" -Tag "Integration", "CollectionUpdate" {

    Context "Test Data Validation" {

        It "Should have test data defined in declarations.ps1" {
            # Assert
            $script:TestCollectionUpdateData | Should -Not -BeNullOrEmpty
            $script:TestData.ContainsKey('Invoke-CM7CollectionUpdate') | Should -Be $true
        }

        It "Should have required test data parameter sets" {
            # Assert
            $script:TestCollectionUpdateData.ContainsKey('ByName') | Should -Be $true
            $script:TestCollectionUpdateData.ContainsKey('ByCollectionId') | Should -Be $true
        }

        It "Should output test data for verification" {
            # Output test data
            Write-Host "`n=== Test Data for Invoke-CM7CollectionUpdate ===" -ForegroundColor Cyan
            Write-Host "ByName:" -ForegroundColor Yellow
            Write-Host "  Name: $($script:TestCollectionUpdateData.ByName.Name)" -ForegroundColor White

            Write-Host "ByCollectionId:" -ForegroundColor Yellow
            Write-Host "  CollectionId: $($script:TestCollectionUpdateData.ByCollectionId.CollectionId)" -ForegroundColor White
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
            { Invoke-CM7CollectionUpdate -Name "test" } | Should -Throw "*not connected*"

            # Restore connection
            $script:CMConnection = $backupConnection
        }
    }

    Context "Parameter Validation" {

        It "Should require Name parameter in ByName parameter set" {
            $cmd = Get-Command Invoke-CM7CollectionUpdate
            $paramSet = $cmd.ParameterSets | Where-Object { $_.Name -eq 'ByName' }
            $nameParam = $paramSet.Parameters | Where-Object { $_.Name -eq 'Name' }
            $nameParam.IsMandatory | Should -Be $true
        }

        It "Should require CollectionId parameter in ByCollectionId parameter set" {
            $cmd = Get-Command Invoke-CM7CollectionUpdate
            $paramSet = $cmd.ParameterSets | Where-Object { $_.Name -eq 'ByCollectionId' }
            $collParam = $paramSet.Parameters | Where-Object { $_.Name -eq 'CollectionId' }
            $collParam.IsMandatory | Should -Be $true
        }

        It "Should support ShouldProcess (-WhatIf and -Confirm)" {
            $cmd = Get-Command Invoke-CM7CollectionUpdate
            $cmd.Parameters.ContainsKey('WhatIf') | Should -Be $true
            $cmd.Parameters.ContainsKey('Confirm') | Should -Be $true
        }

        It "Should have two parameter sets" {
            $cmd = Get-Command Invoke-CM7CollectionUpdate
            $cmd.ParameterSets.Count | Should -Be 2
        }

        It "Should have ByName as default parameter set" {
            $cmd = Get-Command Invoke-CM7CollectionUpdate
            $cmd.DefaultParameterSet | Should -Be 'ByName'
        }

        It "Should have Name at Position 0" {
            $cmd = Get-Command Invoke-CM7CollectionUpdate
            $param = $cmd.Parameters['Name']
            $positionAttr = $param.Attributes | Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] -and $_.Position -eq 0 }
            $positionAttr | Should -Not -BeNullOrEmpty
        }
    }

    Context "Update Collection by Name" {

        It "Should update collection by name" {
            # Arrange
            $collectionName = $script:TestCollectionUpdateData.ByName.Name

            # Act
            $result = Invoke-CM7CollectionUpdate -Name $collectionName

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.ReturnValue | Should -Be 0
            $result.Name | Should -Be $collectionName
            $result.CollectionId | Should -Not -BeNullOrEmpty
        }

        It "Should fail for non-existent collection name" {
            # Act & Assert
            { Invoke-CM7CollectionUpdate -Name "NonExistent-Collection-XYZ999" -ErrorAction Stop } | Should -Throw "*Could not find collection*"
        }
    }

    Context "Update Collection by CollectionId" {

        It "Should update collection by CollectionId" {
            # Arrange
            $collectionId = $script:TestCollectionUpdateData.ByCollectionId.CollectionId

            # Act
            $result = Invoke-CM7CollectionUpdate -CollectionId $collectionId

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.ReturnValue | Should -Be 0
            $result.CollectionId | Should -Be $collectionId
            $result.Name | Should -Not -BeNullOrEmpty
        }

        It "Should fail for non-existent CollectionId" {
            # Act & Assert
            { Invoke-CM7CollectionUpdate -CollectionId "XXX99999" -ErrorAction Stop } | Should -Throw "*Could not find collection*"
        }
    }

    Context "Return Object Properties" {

        It "Should return object with expected properties" {
            # Arrange
            $collectionName = $script:TestCollectionUpdateData.ByName.Name

            # Act
            $result = Invoke-CM7CollectionUpdate -Name $collectionName

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.PSObject.Properties.Name | Should -Contain 'CollectionId'
            $result.PSObject.Properties.Name | Should -Contain 'Name'
            $result.PSObject.Properties.Name | Should -Contain 'CollectionType'
            $result.PSObject.Properties.Name | Should -Contain 'ReturnValue'
        }

        It "Should have PSTypeName set correctly" {
            # Arrange
            $collectionName = $script:TestCollectionUpdateData.ByName.Name

            # Act
            $result = Invoke-CM7CollectionUpdate -Name $collectionName

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.PSObject.TypeNames[0] | Should -Be 'MECM7.CollectionUpdate'
        }

        It "Should return correct CollectionType value" {
            # Arrange
            $collectionName = $script:TestCollectionUpdateData.ByName.Name

            # Act
            $result = Invoke-CM7CollectionUpdate -Name $collectionName

            # Assert
            $result.CollectionType | Should -BeIn @('Device', 'User', 'Unknown')
        }
    }

    Context "WhatIf Support" {

        It "Should support -WhatIf without executing" {
            # Arrange
            $collectionName = $script:TestCollectionUpdateData.ByName.Name

            # Act
            $result = Invoke-CM7CollectionUpdate -Name $collectionName -WhatIf

            # Assert - WhatIf should return no output
            $result | Should -BeNullOrEmpty
        }
    }

    Context "Verbose Output" {

        It "Should provide verbose output when requested" {
            # Arrange
            $collectionName = $script:TestCollectionUpdateData.ByName.Name

            # Act & Assert
            $verboseOutput = Invoke-CM7CollectionUpdate -Name $collectionName -Verbose 4>&1
            $verboseOutput | Should -Not -BeNullOrEmpty
            $verboseOutput | Where-Object { $_ -match "Running Invoke-CM7CollectionUpdate" } | Should -Not -BeNullOrEmpty
            $verboseOutput | Where-Object { $_ -match "Execution of WQL query" } | Should -Not -BeNullOrEmpty
        }

        It "Should show ReturnValue in verbose output" {
            # Arrange
            $collectionName = $script:TestCollectionUpdateData.ByName.Name

            # Act
            $verboseOutput = Invoke-CM7CollectionUpdate -Name $collectionName -Verbose 4>&1

            # Assert
            $verboseOutput | Where-Object { $_ -match "ReturnValue" } | Should -Not -BeNullOrEmpty
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
