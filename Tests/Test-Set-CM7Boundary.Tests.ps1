# Functional Tests for Set-CM7Boundary
# Creates test boundaries, modifies them with various parameter sets, and cleans up afterwards.

BeforeAll {
    # Load test declarations
    $declPath = Join-Path $PSScriptRoot "declarations.ps1"
    if (-not (Test-Path $declPath)) {
        $declPath = Join-Path (Get-Location) "declarations.ps1"
    }
    . $declPath

    # Load all functions
    $CodePath = Join-Path (Get-Item $PSScriptRoot).Parent.FullName "Code"
    Get-ChildItem -Path (Join-Path $CodePath "Private") -Filter "*.ps1" | ForEach-Object { . $_.FullName }
    Get-ChildItem -Path (Join-Path $CodePath "Public")  -Filter "*.ps1" | ForEach-Object { . $_.FullName }

    # Get test data for this function
    $script:TestSetBoundaryData = $script:TestData['Set-CM7Boundary']
    $script:TestConnectData     = $script:TestData['Connect-CM7']

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
    # Cleanup: remove any leftover test boundaries (by original or renamed names)
    $allTestNames = @(
        $script:TestSetBoundaryData.NewBoundaries.IPSubnet.Name,
        $script:TestSetBoundaryData.NewBoundaries.IPRange.Name,
        $script:TestSetBoundaryData.SetById.NewName,
        $script:TestSetBoundaryData.SetByInputObject.NewName,
        $script:TestSetBoundaryData.SetByName.NewName,
        $script:TestSetBoundaryData.SetNewType.NewName
    ) | Where-Object { $_ }

    foreach ($bName in $allTestNames) {
        $existing = Get-CM7Boundary -Name $bName -ErrorAction SilentlyContinue
        if ($existing) {
            Write-Host "AfterAll cleanup: removing leftover boundary '$bName'" -ForegroundColor Yellow
            Remove-CM7Boundary -Name $bName -Force -ErrorAction SilentlyContinue
        }
    }
}

Describe "Set-CM7Boundary Function Tests" -Tag "Integration", "Boundary", "Set" {

    # -----------------------------------------------------------------------
    Context "Test Data Validation" {

        It "Should have test data defined in declarations.ps1" {
            $script:TestSetBoundaryData | Should -Not -BeNullOrEmpty
            $script:TestData.ContainsKey('Set-CM7Boundary') | Should -Be $true
        }

        It "Should have required test data parameter sets" {
            $script:TestSetBoundaryData.ContainsKey('NewBoundaries')     | Should -Be $true
            $script:TestSetBoundaryData.ContainsKey('SetById')           | Should -Be $true
            $script:TestSetBoundaryData.ContainsKey('SetByInputObject')  | Should -Be $true
            $script:TestSetBoundaryData.ContainsKey('SetByName')         | Should -Be $true
            $script:TestSetBoundaryData.ContainsKey('SetNewType')        | Should -Be $true
            $script:TestSetBoundaryData.ContainsKey('WhatIf')            | Should -Be $true
            $script:TestSetBoundaryData.ContainsKey('NonExistent')       | Should -Be $true
        }

        It "Should output test data for verification" {
            Write-Host "`n=== Test Data for Set-CM7Boundary ===" -ForegroundColor Cyan
            Write-Host "NewBoundaries.IPSubnet.Name : $($script:TestSetBoundaryData.NewBoundaries.IPSubnet.Name)"   -ForegroundColor White
            Write-Host "NewBoundaries.IPRange.Name  : $($script:TestSetBoundaryData.NewBoundaries.IPRange.Name)"    -ForegroundColor White
            Write-Host "SetById.NewName             : $($script:TestSetBoundaryData.SetById.NewName)"               -ForegroundColor White
            Write-Host "SetByInputObject.NewName    : $($script:TestSetBoundaryData.SetByInputObject.NewName)"      -ForegroundColor White
            Write-Host "SetByName.NewName           : $($script:TestSetBoundaryData.SetByName.NewName)"             -ForegroundColor White
            Write-Host "SetNewType.NewType          : $($script:TestSetBoundaryData.SetNewType.NewType)"            -ForegroundColor White
            Write-Host "=========================================`n" -ForegroundColor Cyan
            $true | Should -Be $true
        }
    }

    # -----------------------------------------------------------------------
    Context "Connection Requirement" {

        It "Should throw if not connected to MECM" {
            $backupCim = $script:CMConnection.CimSession
            $script:CMConnection.CimSession = $null

            { Set-CM7Boundary -Id 1 -NewName "ShouldFail" } | Should -Throw "*not connected*"

            $script:CMConnection.CimSession = $backupCim
        }
    }

    # -----------------------------------------------------------------------
    Context "Set Boundary By Id (-Id / SetById)" {

        BeforeEach {
            # Ensure the IP Subnet test boundary exists
            $params = $script:TestSetBoundaryData.NewBoundaries.IPSubnet
            $existing = Get-CM7Boundary -Name $params.Name -ErrorAction SilentlyContinue
            if (-not $existing) {
                $script:SubnetBoundary = New-CM7Boundary -Name $params.Name -BoundaryType $params.BoundaryType -Value $params.Value -Force
                Write-Host "Created test boundary '$($params.Name)' (ID: $($script:SubnetBoundary.BoundaryID))" -ForegroundColor DarkGray
            } else {
                $script:SubnetBoundary = $existing
            }
        }

        AfterEach {
            # Remove any left-over renamed boundary so next test starts clean
            $newName = $script:TestSetBoundaryData.SetById.NewName
            $leftover = Get-CM7Boundary -Name $newName -ErrorAction SilentlyContinue
            if ($leftover) { Remove-CM7Boundary -Name $newName -Force -ErrorAction SilentlyContinue }
        }

        It "Should rename a boundary by -Id" {
            $params    = $script:TestSetBoundaryData.SetById
            $boundaryId = $script:SubnetBoundary.BoundaryID

            Set-CM7Boundary -Id $boundaryId -NewName $params.NewName -Force

            $result = Get-CM7Boundary -Name $params.NewName -ErrorAction SilentlyContinue
            $result | Should -Not -BeNullOrEmpty
            $result.DisplayName | Should -Be $params.NewName
        }

        It "Should rename a boundary using the -BoundaryId alias" {
            # Ensure the boundary is back to its original name first
            $origParams = $script:TestSetBoundaryData.NewBoundaries.IPSubnet
            $existing   = Get-CM7Boundary -Name $origParams.Name -ErrorAction SilentlyContinue
            if (-not $existing) {
                # It may have been renamed in the previous test – find by ID and reset
                $byId = Get-CM7Boundary -BoundaryId $script:SubnetBoundary.BoundaryID -ErrorAction SilentlyContinue
                if ($byId) {
                    Set-CM7Boundary -Id $byId.BoundaryID -NewName $origParams.Name -Force
                } else {
                    $script:SubnetBoundary = New-CM7Boundary -Name $origParams.Name -BoundaryType $origParams.BoundaryType -Value $origParams.Value -Force
                }
            }
            $fresh = Get-CM7Boundary -Name $origParams.Name
            $fresh | Should -Not -BeNullOrEmpty

            $params = $script:TestSetBoundaryData.SetById
            Set-CM7Boundary -BoundaryId $fresh.BoundaryID -NewName $params.NewName -Force

            $result = Get-CM7Boundary -Name $params.NewName -ErrorAction SilentlyContinue
            $result | Should -Not -BeNullOrEmpty
            $result.DisplayName | Should -Be $params.NewName
        }

        It "Should return the updated object when -PassThru is used" {
            $origParams = $script:TestSetBoundaryData.NewBoundaries.IPSubnet
            $existing   = Get-CM7Boundary -Name $origParams.Name -ErrorAction SilentlyContinue
            if (-not $existing) {
                $byId = Get-CM7Boundary -BoundaryId $script:SubnetBoundary.BoundaryID -ErrorAction SilentlyContinue
                if ($byId) {
                    Set-CM7Boundary -Id $byId.BoundaryID -NewName $origParams.Name -Force
                } else {
                    $script:SubnetBoundary = New-CM7Boundary -Name $origParams.Name -BoundaryType $origParams.BoundaryType -Value $origParams.Value -Force
                }
            }
            $fresh = Get-CM7Boundary -Name $origParams.Name

            $params = $script:TestSetBoundaryData.SetById
            $result = Set-CM7Boundary -Id $fresh.BoundaryID -NewName $params.NewName -Force -PassThru

            $result | Should -Not -BeNullOrEmpty
            $result.DisplayName | Should -Be $params.NewName
            $result.BoundaryID  | Should -Be $fresh.BoundaryID
        }
    }

    # -----------------------------------------------------------------------
    Context "Set Boundary By InputObject / Pipeline (SetByValue)" {

        BeforeEach {
            # Ensure the IP Range test boundary exists
            $params = $script:TestSetBoundaryData.NewBoundaries.IPRange
            $existing = Get-CM7Boundary -Name $params.Name -ErrorAction SilentlyContinue
            if (-not $existing) {
                $script:RangeBoundary = New-CM7Boundary -Name $params.Name -BoundaryType $params.BoundaryType -Value $params.Value -Force
                Write-Host "Created test boundary '$($params.Name)' (ID: $($script:RangeBoundary.BoundaryID))" -ForegroundColor DarkGray
            } else {
                $script:RangeBoundary = $existing
            }
        }

        AfterEach {
            $newName = $script:TestSetBoundaryData.SetByInputObject.NewName
            $leftover = Get-CM7Boundary -Name $newName -ErrorAction SilentlyContinue
            if ($leftover) { Remove-CM7Boundary -Name $newName -Force -ErrorAction SilentlyContinue }
        }

        It "Should rename a boundary via -InputObject" {
            $params      = $script:TestSetBoundaryData.SetByInputObject
            $origName    = $script:TestSetBoundaryData.NewBoundaries.IPRange.Name
            $boundaryObj = Get-CM7Boundary -Name $origName
            $boundaryObj | Should -Not -BeNullOrEmpty

            Set-CM7Boundary -InputObject $boundaryObj -NewName $params.NewName -Force

            $result = Get-CM7Boundary -Name $params.NewName -ErrorAction SilentlyContinue
            $result | Should -Not -BeNullOrEmpty
            $result.DisplayName | Should -Be $params.NewName
        }

        It "Should rename a boundary via pipeline" {
            $params   = $script:TestSetBoundaryData.SetByInputObject
            $origName = $script:TestSetBoundaryData.NewBoundaries.IPRange.Name
            # If the boundary was renamed in the previous It-block, reset it
            $existing = Get-CM7Boundary -Name $origName -ErrorAction SilentlyContinue
            if (-not $existing) {
                $byId = Get-CM7Boundary -BoundaryId $script:RangeBoundary.BoundaryID -ErrorAction SilentlyContinue
                if ($byId) {
                    Set-CM7Boundary -Id $byId.BoundaryID -NewName $origName -Force
                } else {
                    $script:RangeBoundary = New-CM7Boundary -Name $origName -BoundaryType $script:TestSetBoundaryData.NewBoundaries.IPRange.BoundaryType -Value $script:TestSetBoundaryData.NewBoundaries.IPRange.Value -Force
                }
            }
            $fresh = Get-CM7Boundary -Name $origName

            # Act: pipe into Set-CM7Boundary
            $fresh | Set-CM7Boundary -NewName $params.NewName -Force

            $result = Get-CM7Boundary -Name $params.NewName -ErrorAction SilentlyContinue
            $result | Should -Not -BeNullOrEmpty
            $result.DisplayName | Should -Be $params.NewName
        }
    }

    # -----------------------------------------------------------------------
    Context "Set Boundary By Type and Value (SetByName)" {

        BeforeEach {
            # Ensure IP Subnet boundary exists with its original name and value
            $params = $script:TestSetBoundaryData.NewBoundaries.IPSubnet
            $existing = Get-CM7Boundary -Name $params.Name -ErrorAction SilentlyContinue
            if (-not $existing) {
                New-CM7Boundary -Name $params.Name -BoundaryType $params.BoundaryType -Value $params.Value -Force | Out-Null
            }
        }

        AfterEach {
            $newName = $script:TestSetBoundaryData.SetByName.NewName
            $leftover = Get-CM7Boundary -Name $newName -ErrorAction SilentlyContinue
            if ($leftover) { Remove-CM7Boundary -Name $newName -Force -ErrorAction SilentlyContinue }
        }

        It "Should rename a boundary located by -Type and -Value" {
            $params  = $script:TestSetBoundaryData.SetByName
            $origData = $script:TestSetBoundaryData.NewBoundaries.IPSubnet

            Set-CM7Boundary -Type $origData.BoundaryType -Value $origData.Value -NewName $params.NewName -Force

            $result = Get-CM7Boundary -Name $params.NewName -ErrorAction SilentlyContinue
            $result | Should -Not -BeNullOrEmpty
            $result.DisplayName | Should -Be $params.NewName
        }
    }

    # -----------------------------------------------------------------------
    Context "Change Boundary Type and/or Value" {

        BeforeEach {
            # Ensure IP Subnet boundary is present with its original name
            $params = $script:TestSetBoundaryData.NewBoundaries.IPSubnet
            $existing = Get-CM7Boundary -Name $params.Name -ErrorAction SilentlyContinue
            if (-not $existing) {
                New-CM7Boundary -Name $params.Name -BoundaryType $params.BoundaryType -Value $params.Value -Force | Out-Null
            }
        }

        AfterEach {
            # Remove the (possibly-renamed) boundary
            $cleanNames = @(
                $script:TestSetBoundaryData.NewBoundaries.IPSubnet.Name,
                $script:TestSetBoundaryData.SetNewType.NewName
            )
            foreach ($n in $cleanNames) {
                $leftover = Get-CM7Boundary -Name $n -ErrorAction SilentlyContinue
                if ($leftover) { Remove-CM7Boundary -Name $n -Force -ErrorAction SilentlyContinue }
            }
        }

        It "Should update -NewValue of an existing boundary" {
            $params   = $script:TestSetBoundaryData.SetNewValue
            $origData = $script:TestSetBoundaryData.NewBoundaries.IPSubnet

            $boundary = Get-CM7Boundary -Name $origData.Name
            $boundary | Should -Not -BeNullOrEmpty

            Set-CM7Boundary -Id $boundary.BoundaryID -NewValue $params.NewValue -Force

            $updated = Get-CM7Boundary -BoundaryId $boundary.BoundaryID
            $updated.Value | Should -Be $params.NewValue
        }

        It "Should change -NewType and -NewValue together" {
            $params   = $script:TestSetBoundaryData.SetNewType
            $origData = $script:TestSetBoundaryData.NewBoundaries.IPSubnet

            # Re-create if the previous test changed its value
            $boundary = Get-CM7Boundary -BoundaryId (Get-CM7Boundary -Name $origData.Name -ErrorAction SilentlyContinue)?.BoundaryID -ErrorAction SilentlyContinue
            if (-not $boundary) {
                $leftoverByName = Get-CM7Boundary -Name $origData.Name -ErrorAction SilentlyContinue
                $boundary = $leftoverByName
            }
            if (-not $boundary) {
                $boundary = New-CM7Boundary -Name $origData.Name -BoundaryType $origData.BoundaryType -Value $origData.Value -Force
            }
            $boundary | Should -Not -BeNullOrEmpty

            $result = Set-CM7Boundary -Id $boundary.BoundaryID `
                                      -NewName  $params.NewName `
                                      -NewType  $params.NewType `
                                      -NewValue $params.NewValue `
                                      -Force -PassThru

            $result | Should -Not -BeNullOrEmpty
            $result.DisplayName  | Should -Be $params.NewName
            # BoundaryType int should match the new type
            $expectedInt = @{ IPSubnet=0; ADSite=1; IPv6Prefix=2; IPRange=3; Vpn=4 }[$params.NewType]
            $result.BoundaryType | Should -Be $expectedInt
            $result.Value        | Should -Be $params.NewValue
        }
    }

    # -----------------------------------------------------------------------
    Context "WhatIf Behaviour" {

        BeforeEach {
            # Ensure IP Subnet boundary exists
            $params = $script:TestSetBoundaryData.NewBoundaries.IPSubnet
            $existing = Get-CM7Boundary -Name $params.Name -ErrorAction SilentlyContinue
            if (-not $existing) {
                New-CM7Boundary -Name $params.Name -BoundaryType $params.BoundaryType -Value $params.Value -Force | Out-Null
            }
        }

        AfterEach {
            $params = $script:TestSetBoundaryData.NewBoundaries.IPSubnet
            $leftover = Get-CM7Boundary -Name $params.Name -ErrorAction SilentlyContinue
            if ($leftover) { Remove-CM7Boundary -Name $params.Name -Force -ErrorAction SilentlyContinue }
        }

        It "Should NOT apply changes when -WhatIf is supplied" {
            $params    = $script:TestSetBoundaryData.WhatIf
            $origData  = $script:TestSetBoundaryData.NewBoundaries.IPSubnet
            $boundary  = Get-CM7Boundary -Name $origData.Name
            $boundary | Should -Not -BeNullOrEmpty

            # Act with -WhatIf
            Set-CM7Boundary -Id $boundary.BoundaryID -NewName $params.NewName -WhatIf

            # Assert: the name should be unchanged
            $unchanged = Get-CM7Boundary -BoundaryId $boundary.BoundaryID
            $unchanged.DisplayName | Should -Be $origData.Name
        }

        It "Should return no output when -WhatIf is supplied (even with -PassThru)" {
            $params   = $script:TestSetBoundaryData.WhatIf
            $origData = $script:TestSetBoundaryData.NewBoundaries.IPSubnet
            $boundary = Get-CM7Boundary -Name $origData.Name

            $output = Set-CM7Boundary -Id $boundary.BoundaryID -NewName $params.NewName -WhatIf -PassThru
            $output | Should -BeNullOrEmpty
        }
    }

    # -----------------------------------------------------------------------
    Context "Error Handling" {

        It "Should throw when BoundaryID does not exist" {
            $params = $script:TestSetBoundaryData.NonExistent
            { Set-CM7Boundary -Id $params.BoundaryId -NewName "ShouldNotExist" -Force } | Should -Throw
        }

        It "Should warn and do nothing when no changes are specified" {
            $params   = $script:TestSetBoundaryData.NewBoundaries.IPSubnet
            $existing = Get-CM7Boundary -Name $params.Name -ErrorAction SilentlyContinue
            if (-not $existing) {
                $existing = New-CM7Boundary -Name $params.Name -BoundaryType $params.BoundaryType -Value $params.Value -Force
            }
            $existing | Should -Not -BeNullOrEmpty

            # No -New* parameters – should emit a warning (and not throw)
            $warnings = $null
            Set-CM7Boundary -Id $existing.BoundaryID -Force -WarningVariable warnings 3>&1 | Out-Null
            $warnings | Should -Not -BeNullOrEmpty
        }
    }

    # -----------------------------------------------------------------------
    Context "Full lifecycle: Create -> Modify -> Remove" {

        It "Should create, rename, change value, and remove an IP Subnet boundary" {
            $subnetData = $script:TestSetBoundaryData.NewBoundaries.IPSubnet

            # 1 - Create
            $existing = Get-CM7Boundary -Name $subnetData.Name -ErrorAction SilentlyContinue
            if (-not $existing) {
                $created = New-CM7Boundary -Name $subnetData.Name -BoundaryType $subnetData.BoundaryType -Value $subnetData.Value -Force
                $created | Should -Not -BeNullOrEmpty
                $created.DisplayName | Should -Be $subnetData.Name
            } else {
                $created = $existing
            }

            # 2 - Rename
            $renamedName = "Updated-$($subnetData.Name)"
            Set-CM7Boundary -Id $created.BoundaryID -NewName $renamedName -Force
            $afterRename = Get-CM7Boundary -BoundaryId $created.BoundaryID
            $afterRename.DisplayName | Should -Be $renamedName

            # 3 - Change value
            $newVal = $script:TestSetBoundaryData.SetNewValue.NewValue
            Set-CM7Boundary -Id $created.BoundaryID -NewValue $newVal -Force
            $afterValue = Get-CM7Boundary -BoundaryId $created.BoundaryID
            $afterValue.Value | Should -Be $newVal

            # 4 - Remove
            Remove-CM7Boundary -Id $created.BoundaryID -Force
            $afterRemove = Get-CM7Boundary -BoundaryId $created.BoundaryID -ErrorAction SilentlyContinue
            $afterRemove | Should -BeNullOrEmpty
        }

        It "Should create, rename, change type+value, and remove an IP Range boundary" {
            $rangeData = $script:TestSetBoundaryData.NewBoundaries.IPRange

            # 1 - Create
            $existing = Get-CM7Boundary -Name $rangeData.Name -ErrorAction SilentlyContinue
            if (-not $existing) {
                $created = New-CM7Boundary -Name $rangeData.Name -BoundaryType $rangeData.BoundaryType -Value $rangeData.Value -Force
                $created | Should -Not -BeNullOrEmpty
                $created.DisplayName | Should -Be $rangeData.Name
            } else {
                $created = $existing
            }

            # 2 - Update name only
            $newRangeName = "Updated-$($rangeData.Name)"
            Set-CM7Boundary -Id $created.BoundaryID -NewName $newRangeName -Force
            $afterRename = Get-CM7Boundary -BoundaryId $created.BoundaryID
            $afterRename.DisplayName | Should -Be $newRangeName

            # 3 - Update value
            Set-CM7Boundary -Id $created.BoundaryID -NewValue "192.168.5.1-192.168.5.255" -Force
            $afterValue = Get-CM7Boundary -BoundaryId $created.BoundaryID
            $afterValue.Value | Should -Be "192.168.5.1-192.168.5.255"

            # 4 - Remove
            Remove-CM7Boundary -Id $created.BoundaryID -Force
            $afterRemove = Get-CM7Boundary -BoundaryId $created.BoundaryID -ErrorAction SilentlyContinue
            $afterRemove | Should -BeNullOrEmpty
        }
    }
}
