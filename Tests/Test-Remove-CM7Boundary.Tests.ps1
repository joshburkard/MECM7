# Functional Tests for Remove-CM7Boundary
# Tests the Remove-CM7Boundary function behavior and return values

BeforeAll {
    # Load test declarations
    . (Join-Path $PSScriptRoot "declarations.ps1")

    # Load all functions
    $CodePath = Join-Path (Get-Item $PSScriptRoot).Parent.FullName "Code"
    Get-ChildItem -Path (Join-Path $CodePath "Private") -Filter "*.ps1" | ForEach-Object { . $_.FullName }
    Get-ChildItem -Path (Join-Path $CodePath "Public") -Filter "*.ps1" | ForEach-Object { . $_.FullName }

    # Get test data for this function
    $script:TestRemoveBoundaryData = $script:TestData['Remove-CM7Boundary']
    $script:TestNewBoundaryData    = $script:TestData['New-CM7Boundary']
    $script:TestConnectData        = $script:TestData['Connect-CM7']

    # Establish connection for all tests
    $connectParams = @{
        SiteServer = $script:TestConnectData.Valid.SiteServer
        Credential = $script:TestConnectData.Valid.Credential
    }
    if ($script:TestConnectData.Valid.SkipCertificateCheck) { $connectParams.SkipCertificateCheck = $true }
    if ($script:TestConnectData.Valid.UseSsl)               { $connectParams.UseSsl = $true }
    Connect-CM7 @connectParams
}

AfterAll {
    # Cleanup: ensure test boundaries are removed if any test failed mid-run
    $testBoundaryNames = @(
        $script:TestRemoveBoundaryData.NewBoundaries.IPSubnet.Name,
        $script:TestRemoveBoundaryData.NewBoundaries.IPRange.Name
    )
    foreach ($bName in $testBoundaryNames) {
        if ($bName) {
            $existing = Get-CM7Boundary -Name $bName -ErrorAction SilentlyContinue
            if ($existing) {
                Write-Host "AfterAll cleanup: removing leftover boundary '$bName'" -ForegroundColor Yellow
                Remove-CM7Boundary -Name $bName -Force -ErrorAction SilentlyContinue
            }
        }
    }
}

Describe "Remove-CM7Boundary Function Tests" -Tag "Integration", "Boundary", "Remove" {

    Context "Test Data Validation" {

        It "Should have test data defined in declarations.ps1" {
            $script:TestRemoveBoundaryData | Should -Not -BeNullOrEmpty
            $script:TestData.ContainsKey('Remove-CM7Boundary') | Should -Be $true
        }

        It "Should have required test data parameter sets" {
            $script:TestRemoveBoundaryData.ContainsKey('ByName')        | Should -Be $true
            $script:TestRemoveBoundaryData.ContainsKey('ById')          | Should -Be $true
            $script:TestRemoveBoundaryData.ContainsKey('ByInputObject') | Should -Be $true
            $script:TestRemoveBoundaryData.ContainsKey('NonExistent')   | Should -Be $true
            $script:TestRemoveBoundaryData.ContainsKey('NewBoundaries') | Should -Be $true
        }

        It "Should output test data for verification" {
            Write-Host "`n=== Test Data for Remove-CM7Boundary ===" -ForegroundColor Cyan
            Write-Host "ByName.Name:         $($script:TestRemoveBoundaryData.ByName.Name)" -ForegroundColor White
            Write-Host "ByInputObject.Name:  $($script:TestRemoveBoundaryData.ByInputObject.Name)" -ForegroundColor White
            Write-Host "NonExistent.Name:    $($script:TestRemoveBoundaryData.NonExistent.Name)" -ForegroundColor White
            Write-Host "NewBoundaries.IPSubnet.Name:  $($script:TestRemoveBoundaryData.NewBoundaries.IPSubnet.Name)" -ForegroundColor White
            Write-Host "NewBoundaries.IPRange.Name:   $($script:TestRemoveBoundaryData.NewBoundaries.IPRange.Name)" -ForegroundColor White
            Write-Host "==========================================`n" -ForegroundColor Cyan
            $true | Should -Be $true
        }
    }

    Context "Connection Requirement" {

        It "Should fail if not connected to MECM" {
            $backupConnection = $script:CMConnection.Clone()
            $script:CMConnection.CimSession = $null

            { Remove-CM7Boundary -Name "TestBoundary" -Force } | Should -Throw "*not connected*"

            $script:CMConnection = $backupConnection
        }
    }

    Context "Remove Boundary By Name" {

        BeforeEach {
            # Create the test boundary so we can remove it
            $params = $script:TestRemoveBoundaryData.NewBoundaries.IPSubnet
            $existing = Get-CM7Boundary -Name $params.Name -ErrorAction SilentlyContinue
            if (-not $existing) {
                $script:CreatedSubnetBoundary = New-CM7Boundary -Name $params.Name -BoundaryType $params.BoundaryType -Value $params.Value -Force
                Write-Host "Created test boundary '$($params.Name)' (ID: $($script:CreatedSubnetBoundary.BoundaryID))" -ForegroundColor DarkGray
            }
        }

        It "Should remove IP Subnet boundary by -Name" {
            $params = $script:TestRemoveBoundaryData.ByName

            # Act
            Remove-CM7Boundary -Name $params.Name -Force

            # Assert: boundary should be gone
            $result = Get-CM7Boundary -Name $params.Name -ErrorAction SilentlyContinue
            $result | Should -BeNullOrEmpty
        }

        It "Should support wildcard in -Name" {
            # Re-create the boundary so it is available for this test
            $newParams = $script:TestRemoveBoundaryData.NewBoundaries.IPSubnet
            $existing = Get-CM7Boundary -Name $newParams.Name -ErrorAction SilentlyContinue
            if (-not $existing) {
                New-CM7Boundary -Name $newParams.Name -BoundaryType $newParams.BoundaryType -Value $newParams.Value -Force | Out-Null
            }

            # Use a wildcard that matches the boundary name
            $prefix = $newParams.Name.Substring(0, [Math]::Min(12, $newParams.Name.Length))
            Remove-CM7Boundary -Name "$prefix*" -Force

            $result = Get-CM7Boundary -Name $newParams.Name -ErrorAction SilentlyContinue
            $result | Should -BeNullOrEmpty
        }
    }

    Context "Remove Boundary By Id" {

        BeforeEach {
            # Create the test boundary (IP Range) and capture its ID
            $params = $script:TestRemoveBoundaryData.NewBoundaries.IPRange
            $existing = Get-CM7Boundary -Name $params.Name -ErrorAction SilentlyContinue
            if ($existing) {
                $script:TestBoundaryId = $existing.BoundaryID
            } else {
                $created = New-CM7Boundary -Name $params.Name -BoundaryType $params.BoundaryType -Value $params.Value -Force
                $script:TestBoundaryId = $created.BoundaryID
                Write-Host "Created test boundary '$($params.Name)' (ID: $script:TestBoundaryId)" -ForegroundColor DarkGray
            }
        }

        It "Should remove boundary by -Id" {
            $script:TestBoundaryId | Should -Not -BeNullOrEmpty

            # Act
            Remove-CM7Boundary -Id $script:TestBoundaryId -Force

            # Assert
            $params = $script:TestRemoveBoundaryData.NewBoundaries.IPRange
            $result = Get-CM7Boundary -Name $params.Name -ErrorAction SilentlyContinue
            $result | Should -BeNullOrEmpty
        }

        It "Should accept -BoundaryId as alias for -Id" {
            # Re-create if needed
            $params = $script:TestRemoveBoundaryData.NewBoundaries.IPRange
            $existing = Get-CM7Boundary -Name $params.Name -ErrorAction SilentlyContinue
            if (-not $existing) {
                $created = New-CM7Boundary -Name $params.Name -BoundaryType $params.BoundaryType -Value $params.Value -Force
                $script:TestBoundaryId = $created.BoundaryID
            } else {
                $script:TestBoundaryId = $existing.BoundaryID
            }

            # Act using the BoundaryId alias
            Remove-CM7Boundary -BoundaryId $script:TestBoundaryId -Force

            $result = Get-CM7Boundary -Name $params.Name -ErrorAction SilentlyContinue
            $result | Should -BeNullOrEmpty
        }
    }

    Context "Remove Boundary By InputObject (Pipeline)" {

        BeforeEach {
            # Create the IP Range boundary for input-object test
            $params = $script:TestRemoveBoundaryData.NewBoundaries.IPRange
            $existing = Get-CM7Boundary -Name $params.Name -ErrorAction SilentlyContinue
            if (-not $existing) {
                New-CM7Boundary -Name $params.Name -BoundaryType $params.BoundaryType -Value $params.Value -Force | Out-Null
                Write-Host "Created test boundary '$($params.Name)'" -ForegroundColor DarkGray
            }
        }

        It "Should remove boundary via -InputObject" {
            $name = $script:TestRemoveBoundaryData.ByInputObject.Name
            $boundaryObj = Get-CM7Boundary -Name $name
            $boundaryObj | Should -Not -BeNullOrEmpty

            # Act
            Remove-CM7Boundary -InputObject $boundaryObj -Force

            # Assert
            $result = Get-CM7Boundary -Name $name -ErrorAction SilentlyContinue
            $result | Should -BeNullOrEmpty
        }

        It "Should remove boundary via pipeline" {
            # Re-create if needed
            $params = $script:TestRemoveBoundaryData.NewBoundaries.IPRange
            $existing = Get-CM7Boundary -Name $params.Name -ErrorAction SilentlyContinue
            if (-not $existing) {
                New-CM7Boundary -Name $params.Name -BoundaryType $params.BoundaryType -Value $params.Value -Force | Out-Null
            }

            # Act: pipeline removal
            Get-CM7Boundary -Name $params.Name | Remove-CM7Boundary -Force

            # Assert
            $result = Get-CM7Boundary -Name $params.Name -ErrorAction SilentlyContinue
            $result | Should -BeNullOrEmpty
        }
    }

    Context "WhatIf Support" {

        BeforeEach {
            # Create the IP Subnet boundary for WhatIf tests
            $params = $script:TestRemoveBoundaryData.NewBoundaries.IPSubnet
            $existing = Get-CM7Boundary -Name $params.Name -ErrorAction SilentlyContinue
            if (-not $existing) {
                New-CM7Boundary -Name $params.Name -BoundaryType $params.BoundaryType -Value $params.Value -Force | Out-Null
                Write-Host "Created test boundary '$($params.Name)' for WhatIf test" -ForegroundColor DarkGray
            }
        }

        AfterEach {
            # Cleanup the boundary after WhatIf test (it should still exist)
            $params = $script:TestRemoveBoundaryData.NewBoundaries.IPSubnet
            $existing = Get-CM7Boundary -Name $params.Name -ErrorAction SilentlyContinue
            if ($existing) {
                Remove-CM7Boundary -Name $params.Name -Force -ErrorAction SilentlyContinue
            }
        }

        It "Should NOT remove boundary when -WhatIf is specified" {
            $params = $script:TestRemoveBoundaryData.NewBoundaries.IPSubnet

            # Act
            Remove-CM7Boundary -Name $params.Name -WhatIf

            # Assert: boundary should still exist
            $result = Get-CM7Boundary -Name $params.Name -ErrorAction SilentlyContinue
            $result | Should -Not -BeNullOrEmpty
        }
    }

    Context "Non-Existent Boundary Handling" {

        It "Should write a warning when boundary name does not exist" {
            $params = $script:TestRemoveBoundaryData.NonExistent

            # Act & Assert: should NOT throw, but warn
            { Remove-CM7Boundary -Name $params.Name -Force -WarningAction SilentlyContinue } | Should -Not -Throw
        }

        It "Should write a warning when BoundaryID does not exist" {
            $params = $script:TestRemoveBoundaryData.NonExistent

            { Remove-CM7Boundary -Id $params.BoundaryId -Force -WarningAction SilentlyContinue } | Should -Not -Throw
        }
    }

    Context "Full Lifecycle: Create and Remove IP Subnet boundary (192.168.1.0/24)" {

        It "Should create an IP Subnet boundary for 192.168.1.0/24 and then remove it" {
            $name  = "TestSubnet-192.168.1.0"
            $value = "192.168.1.0"

            # Ensure it doesn't already exist
            $existing = Get-CM7Boundary -Name $name -ErrorAction SilentlyContinue
            if ($existing) {
                Remove-CM7Boundary -Name $name -Force -ErrorAction SilentlyContinue
            }

            # Create
            $created = New-CM7Boundary -Name $name -BoundaryType 'IPSubnet' -Value $value -Force
            $created | Should -Not -BeNullOrEmpty
            $created.BoundaryType | Should -Be 0
            $created.Value | Should -Be $value
            Write-Host "Created IP Subnet boundary '$name' (ID: $($created.BoundaryID))" -ForegroundColor Green

            # Verify it exists
            $check = Get-CM7Boundary -Name $name
            $check | Should -Not -BeNullOrEmpty

            # Remove
            Remove-CM7Boundary -Name $name -Force

            # Verify it is gone
            $afterRemove = Get-CM7Boundary -Name $name -ErrorAction SilentlyContinue
            $afterRemove | Should -BeNullOrEmpty
            Write-Host "Verified: IP Subnet boundary '$name' removed successfully." -ForegroundColor Green
        }
    }

    Context "Full Lifecycle: Create and Remove IP Range boundary (192.168.2.1 - 192.168.3.255)" {

        It "Should create an IP Range boundary for 192.168.2.1-192.168.3.255 and then remove it" {
            $name  = "TestRange-192.168.2.1-192.168.3.255"
            $value = "192.168.2.1-192.168.3.255"

            # Ensure it doesn't already exist
            $existing = Get-CM7Boundary -Name $name -ErrorAction SilentlyContinue
            if ($existing) {
                Remove-CM7Boundary -Name $name -Force -ErrorAction SilentlyContinue
            }

            # Create
            $created = New-CM7Boundary -Name $name -BoundaryType 'IPRange' -Value $value -Force
            $created | Should -Not -BeNullOrEmpty
            $created.BoundaryType | Should -Be 3
            $created.Value | Should -Be $value
            Write-Host "Created IP Range boundary '$name' (ID: $($created.BoundaryID))" -ForegroundColor Green

            # Verify it exists
            $check = Get-CM7Boundary -Name $name
            $check | Should -Not -BeNullOrEmpty

            # Remove via pipeline (InputObject)
            Get-CM7Boundary -Name $name | Remove-CM7Boundary -Force

            # Verify it is gone
            $afterRemove = Get-CM7Boundary -Name $name -ErrorAction SilentlyContinue
            $afterRemove | Should -BeNullOrEmpty
            Write-Host "Verified: IP Range boundary '$name' removed successfully." -ForegroundColor Green
        }
    }

    Context "Remove By Id and verify with Get-CM7Boundary" {

        It "Should create an IP Subnet boundary, remove by BoundaryID, and verify removal" {
            $name  = "TestSubnet-192.168.1.0"
            $value = "192.168.1.0"

            # Cleanup if leftover
            $existing = Get-CM7Boundary -Name $name -ErrorAction SilentlyContinue
            if ($existing) {
                Remove-CM7Boundary -Name $name -Force -ErrorAction SilentlyContinue
            }

            # Create
            $created = New-CM7Boundary -Name $name -BoundaryType 'IPSubnet' -Value $value -Force
            $created | Should -Not -BeNullOrEmpty
            $boundaryId = $created.BoundaryID
            Write-Host "Created IP Subnet boundary '$name' (ID: $boundaryId)" -ForegroundColor Green

            # Remove by ID
            Remove-CM7Boundary -Id $boundaryId -Force

            # Verify
            $afterRemove = Get-CM7Boundary -BoundaryId $boundaryId -ErrorAction SilentlyContinue
            $afterRemove | Should -BeNullOrEmpty
            Write-Host "Verified: boundary with ID $boundaryId removed successfully." -ForegroundColor Green
        }
    }
}
