# Functional Tests for Remove-CM7CollectionMembershipRule
# Tests the Remove-CM7CollectionMembershipRule function behavior and return values
#
# Strategy: Create a dedicated collection per rule type (if it doesn't exist).
# Add the required rules once during setup, then run tests that remove them.
# Collections are NOT removed after the test run - the user removes them manually.
# This avoids rapid add/remove/add timing conflicts with WMI/CIM propagation.

BeforeAll {
    # Load test declarations
    . (Join-Path $PSScriptRoot "declarations.ps1")

    # Load all functions
    $CodePath = Join-Path (Get-Item $PSScriptRoot).Parent.FullName "Code"
    Get-ChildItem -Path (Join-Path $CodePath "Private") -Filter "*.ps1" | ForEach-Object { . $_.FullName }
    Get-ChildItem -Path (Join-Path $CodePath "Public") -Filter "*.ps1" | ForEach-Object { . $_.FullName }

    # Get test data for this function
    $script:TestRemoveRuleData = $script:TestData['Remove-CM7CollectionMembershipRule']
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

    # Folder path for test collections
    $script:TestFolderPath = $DefaultPaths.DeviceCollection
    $script:LimitingCollectionId = $Defaults.LimitingCollectionId

    # ========================================================================
    # Helper functions
    # ========================================================================

    function Ensure-TestCollection {
        param(
            [string]$Name,
            [string]$Comment = "Auto-created for Remove-CM7CollectionMembershipRule tests"
        )
        $existing = Get-CM7Collection -Name $Name -ErrorAction SilentlyContinue
        if ($existing) {
            Write-Host "  Collection '$Name' already exists (ID: $($existing.CollectionID))" -ForegroundColor Gray
            return $existing
        }
        Write-Host "  Creating collection '$Name'..." -ForegroundColor Yellow
        $params = @{
            Name                 = $Name
            LimitingCollectionId = $script:LimitingCollectionId
            Comment              = $Comment
        }
        if ($script:TestFolderPath) {
            $params.FolderPath = $script:TestFolderPath
        }
        $newCollection = New-CM7Collection @params
        if (-not $newCollection) {
            throw "Failed to create test collection '$Name'"
        }
        Write-Host "  Created collection '$Name' (ID: $($newCollection.CollectionID))" -ForegroundColor Green
        # Allow time for collection to propagate
        Start-Sleep -Seconds 3
        return $newCollection
    }

    function Add-DirectRuleIfMissing {
        param(
            [string]$CollectionId,
            [int]$ResourceId
        )
        $rules = Get-CM7CollectionDirectMembershipRule -CollectionId $CollectionId -ErrorAction SilentlyContinue
        if ($rules | Where-Object { $_.ResourceID -eq $ResourceId }) {
            Write-Host "    Direct rule for ResourceId $ResourceId already exists" -ForegroundColor Gray
            return $true
        }
        Write-Host "    Adding direct rule for ResourceId $ResourceId..." -ForegroundColor Yellow
        try {
            $result = Add-CM7CollectionMembershipRule -CollectionId $CollectionId -RuleType Direct -ResourceId $ResourceId -Confirm:$false
            return ($null -ne $result)
        }
        catch {
            Write-Warning "Failed to add direct rule for ResourceId ${ResourceId}: $_"
            return $false
        }
    }

    function Add-QueryRuleIfMissing {
        param(
            [string]$CollectionId,
            [string]$RuleName,
            [string]$QueryExpression
        )
        $rules = Get-CM7CollectionQueryMembershipRule -CollectionId $CollectionId -ErrorAction SilentlyContinue
        if ($rules | Where-Object { $_.RuleName -eq $RuleName }) {
            Write-Host "    Query rule '$RuleName' already exists" -ForegroundColor Gray
            return $true
        }
        Write-Host "    Adding query rule '$RuleName'..." -ForegroundColor Yellow
        try {
            $result = Add-CM7CollectionMembershipRule -CollectionId $CollectionId -RuleType Query -RuleName $RuleName -QueryExpression $QueryExpression -Confirm:$false
            return ($null -ne $result)
        }
        catch {
            Write-Warning "Failed to add query rule '${RuleName}': $_"
            return $false
        }
    }

    function Add-IncludeRuleIfMissing {
        param(
            [string]$CollectionId,
            [string]$IncludeCollectionId
        )
        $rules = Get-CM7CollectionIncludeMembershipRule -CollectionId $CollectionId -ErrorAction SilentlyContinue
        if ($rules | Where-Object { $_.IncludeCollectionID -eq $IncludeCollectionId }) {
            Write-Host "    Include rule for $IncludeCollectionId already exists" -ForegroundColor Gray
            return $true
        }
        Write-Host "    Adding include rule for $IncludeCollectionId..." -ForegroundColor Yellow
        try {
            $result = Add-CM7CollectionMembershipRule -CollectionId $CollectionId -RuleType Include -IncludeCollectionId $IncludeCollectionId -Confirm:$false
            return ($null -ne $result)
        }
        catch {
            Write-Warning "Failed to add include rule for ${IncludeCollectionId}: $_"
            return $false
        }
    }

    function Add-ExcludeRuleIfMissing {
        param(
            [string]$CollectionId,
            [string]$ExcludeCollectionId
        )
        $rules = Get-CM7CollectionExcludeMembershipRule -CollectionId $CollectionId -ErrorAction SilentlyContinue
        if ($rules | Where-Object { $_.ExcludeCollectionID -eq $ExcludeCollectionId }) {
            Write-Host "    Exclude rule for $ExcludeCollectionId already exists" -ForegroundColor Gray
            return $true
        }
        Write-Host "    Adding exclude rule for $ExcludeCollectionId..." -ForegroundColor Yellow
        try {
            $result = Add-CM7CollectionMembershipRule -CollectionId $CollectionId -RuleType Exclude -ExcludeCollectionId $ExcludeCollectionId -Confirm:$false
            return ($null -ne $result)
        }
        catch {
            Write-Warning "Failed to add exclude rule for ${ExcludeCollectionId}: $_"
            return $false
        }
    }

    function Test-DirectRuleExists {
        param(
            [int]$ResourceId,
            [string]$CollectionId
        )
        $rules = Get-CM7CollectionDirectMembershipRule -CollectionId $CollectionId -ErrorAction SilentlyContinue
        if (-not $rules) { return $false }
        return ($rules | Where-Object { $_.ResourceID -eq $ResourceId }) -ne $null
    }

    function Test-QueryRuleExists {
        param(
            [string]$RuleName,
            [string]$CollectionId
        )
        $rules = Get-CM7CollectionQueryMembershipRule -CollectionId $CollectionId -ErrorAction SilentlyContinue
        if (-not $rules) { return $false }
        return ($rules | Where-Object { $_.RuleName -eq $RuleName }) -ne $null
    }

    function Test-IncludeRuleExists {
        param(
            [string]$IncludeCollectionId,
            [string]$CollectionId
        )
        $rules = Get-CM7CollectionIncludeMembershipRule -CollectionId $CollectionId -ErrorAction SilentlyContinue
        if (-not $rules) { return $false }
        return ($rules | Where-Object { $_.IncludeCollectionID -eq $IncludeCollectionId }) -ne $null
    }

    function Test-ExcludeRuleExists {
        param(
            [string]$ExcludeCollectionId,
            [string]$CollectionId
        )
        $rules = Get-CM7CollectionExcludeMembershipRule -CollectionId $CollectionId -ErrorAction SilentlyContinue
        if (-not $rules) { return $false }
        return ($rules | Where-Object { $_.ExcludeCollectionID -eq $ExcludeCollectionId }) -ne $null
    }

    function Wait-ForRule {
        param(
            [scriptblock]$TestScript,
            [string]$RuleDescription,
            [int]$TimeoutSeconds = 30,
            [int]$PollingIntervalSeconds = 2
        )
        $elapsed = 0
        while ($elapsed -lt $TimeoutSeconds) {
            if (& $TestScript) {
                Write-Host "  ✓ $RuleDescription verified" -ForegroundColor Green
                return $true
            }
            Start-Sleep -Seconds $PollingIntervalSeconds
            $elapsed += $PollingIntervalSeconds
        }
        Write-Warning "Timeout waiting for $RuleDescription (${elapsed}s)"
        return $false
    }

    function Wait-ForRuleRemoval {
        param(
            [scriptblock]$TestScript,
            [string]$RuleDescription,
            [int]$TimeoutSeconds = 30,
            [int]$PollingIntervalSeconds = 2
        )
        $elapsed = 0
        while ($elapsed -lt $TimeoutSeconds) {
            if (-not (& $TestScript)) {
                Write-Host "  ✓ $RuleDescription removal verified" -ForegroundColor Green
                return $true
            }
            Start-Sleep -Seconds $PollingIntervalSeconds
            $elapsed += $PollingIntervalSeconds
        }
        Write-Warning "Timeout waiting for $RuleDescription to be removed (${elapsed}s)"
        return $false
    }

    # ========================================================================
    # Setup: Create dedicated test collections and populate with rules
    # ========================================================================
    Write-Host "`n=== Setting up Remove-Rule test collections ===" -ForegroundColor Cyan

    # Resource IDs from declarations
    $script:ResourceId1 = $script:TestRemoveRuleData.DirectByCollectionNameAndResourceId.ResourceId
    $script:ResourceId2 = $script:TestRemoveRuleData.DirectByCollectionIdAndResourceName.ResourceId
    $script:ResourceName2 = $script:TestRemoveRuleData.DirectByCollectionIdAndResourceName.ResourceName
    $script:ResourceIdArray = $script:TestRemoveRuleData.DirectByCollectionNameAndResourceId.ResourceIdArray
    $script:WildcardPattern = $script:TestRemoveRuleData.DirectByWildcard.ResourceName

    # Include/Exclude collection IDs from declarations
    $script:IncludeCollectionId = $script:TestRemoveRuleData.IncludeByCollectionName.IncludeCollectionId
    $script:IncludeCollectionName = $script:TestRemoveRuleData.IncludeByCollectionName.IncludeCollectionName
    $script:ExcludeCollectionId = $script:TestRemoveRuleData.ExcludeByCollectionName.ExcludeCollectionId
    $script:ExcludeCollectionName = $script:TestRemoveRuleData.ExcludeByCollectionName.ExcludeCollectionName

    # Query expression for test query rules
    $script:QueryExpression = "select * from SMS_R_System where SMS_R_System.Name like 'TEST-%'"

    # -- Collection 1: For Direct rule removal (by CollectionName + ResourceId) --
    Write-Host "`n--- Direct rule collection (by Name) ---" -ForegroundColor Yellow
    $col1 = Ensure-TestCollection -Name "Test-Remove-Direct-ByName"
    $script:Col_DirectByName_Id = $col1.CollectionID
    $script:Col_DirectByName_Name = "Test-Remove-Direct-ByName"
    Add-DirectRuleIfMissing -CollectionId $script:Col_DirectByName_Id -ResourceId $script:ResourceId1

    # -- Collection 2: For Direct rule removal (by CollectionId) --
    Write-Host "`n--- Direct rule collection (by ID) ---" -ForegroundColor Yellow
    $col2 = Ensure-TestCollection -Name "Test-Remove-Direct-ById"
    $script:Col_DirectById_Id = $col2.CollectionID
    $script:Col_DirectById_Name = "Test-Remove-Direct-ById"
    Add-DirectRuleIfMissing -CollectionId $script:Col_DirectById_Id -ResourceId $script:ResourceId2

    # -- Collection 3: For Direct rule removal (by ResourceName) --
    Write-Host "`n--- Direct rule collection (by ResourceName) ---" -ForegroundColor Yellow
    $col3 = Ensure-TestCollection -Name "Test-Remove-Direct-ByResName"
    $script:Col_DirectByResName_Id = $col3.CollectionID
    $script:Col_DirectByResName_Name = "Test-Remove-Direct-ByResName"
    Add-DirectRuleIfMissing -CollectionId $script:Col_DirectByResName_Id -ResourceId $script:ResourceId2

    # -- Collection 4: For Direct rule multi-removal (array of ResourceIds) --
    Write-Host "`n--- Direct rule collection (multi-remove) ---" -ForegroundColor Yellow
    $col4 = Ensure-TestCollection -Name "Test-Remove-Direct-Multi"
    $script:Col_DirectMulti_Id = $col4.CollectionID
    $script:Col_DirectMulti_Name = "Test-Remove-Direct-Multi"
    foreach ($resId in $script:ResourceIdArray) {
        Add-DirectRuleIfMissing -CollectionId $script:Col_DirectMulti_Id -ResourceId $resId
    }

    # -- Collection 5: For Direct rule wildcard removal --
    Write-Host "`n--- Direct rule collection (wildcard) ---" -ForegroundColor Yellow
    $col5 = Ensure-TestCollection -Name "Test-Remove-Direct-Wildcard"
    $script:Col_DirectWildcard_Id = $col5.CollectionID
    $script:Col_DirectWildcard_Name = "Test-Remove-Direct-Wildcard"
    foreach ($resId in $script:ResourceIdArray) {
        Add-DirectRuleIfMissing -CollectionId $script:Col_DirectWildcard_Id -ResourceId $resId
    }

    # -- Collection 6: For Query rule removal (single) --
    Write-Host "`n--- Query rule collection (single) ---" -ForegroundColor Yellow
    $col6 = Ensure-TestCollection -Name "Test-Remove-Query-Single"
    $script:Col_QuerySingle_Id = $col6.CollectionID
    $script:Col_QuerySingle_Name = "Test-Remove-Query-Single"
    $script:QueryRuleName1 = "TestRemove-Query-Single"
    Add-QueryRuleIfMissing -CollectionId $script:Col_QuerySingle_Id -RuleName $script:QueryRuleName1 -QueryExpression $script:QueryExpression

    # -- Collection 7: For Query rule wildcard removal --
    Write-Host "`n--- Query rule collection (wildcard) ---" -ForegroundColor Yellow
    $col7 = Ensure-TestCollection -Name "Test-Remove-Query-Wildcard"
    $script:Col_QueryWildcard_Id = $col7.CollectionID
    $script:Col_QueryWildcard_Name = "Test-Remove-Query-Wildcard"
    $script:QueryWildcardRuleNames = @("TestRemove-QueryWC-1", "TestRemove-QueryWC-2", "TestRemove-QueryWC-3")
    foreach ($name in $script:QueryWildcardRuleNames) {
        Add-QueryRuleIfMissing -CollectionId $script:Col_QueryWildcard_Id -RuleName $name -QueryExpression $script:QueryExpression
    }

    # -- Collection 8: For Include rule removal (by ID) --
    Write-Host "`n--- Include rule collection (by ID) ---" -ForegroundColor Yellow
    $col8 = Ensure-TestCollection -Name "Test-Remove-Include-ById"
    $script:Col_IncludeById_Id = $col8.CollectionID
    $script:Col_IncludeById_Name = "Test-Remove-Include-ById"
    Add-IncludeRuleIfMissing -CollectionId $script:Col_IncludeById_Id -IncludeCollectionId $script:IncludeCollectionId

    # -- Collection 9: For Include rule removal (by Name) --
    Write-Host "`n--- Include rule collection (by Name) ---" -ForegroundColor Yellow
    $col9 = Ensure-TestCollection -Name "Test-Remove-Include-ByName"
    $script:Col_IncludeByName_Id = $col9.CollectionID
    $script:Col_IncludeByName_Name = "Test-Remove-Include-ByName"
    Add-IncludeRuleIfMissing -CollectionId $script:Col_IncludeByName_Id -IncludeCollectionId $script:IncludeCollectionId

    # -- Collection 10: For Exclude rule removal (by ID) --
    Write-Host "`n--- Exclude rule collection (by ID) ---" -ForegroundColor Yellow
    $col10 = Ensure-TestCollection -Name "Test-Remove-Exclude-ById"
    $script:Col_ExcludeById_Id = $col10.CollectionID
    $script:Col_ExcludeById_Name = "Test-Remove-Exclude-ById"
    Add-ExcludeRuleIfMissing -CollectionId $script:Col_ExcludeById_Id -ExcludeCollectionId $script:ExcludeCollectionId

    # -- Collection 11: For Exclude rule removal (by Name) --
    Write-Host "`n--- Exclude rule collection (by Name) ---" -ForegroundColor Yellow
    $col11 = Ensure-TestCollection -Name "Test-Remove-Exclude-ByName"
    $script:Col_ExcludeByName_Id = $col11.CollectionID
    $script:Col_ExcludeByName_Name = "Test-Remove-Exclude-ByName"
    Add-ExcludeRuleIfMissing -CollectionId $script:Col_ExcludeByName_Id -ExcludeCollectionId $script:ExcludeCollectionId

    # -- Collection 12: For WhatIf tests (rules should survive) --
    Write-Host "`n--- WhatIf test collection ---" -ForegroundColor Yellow
    $col12 = Ensure-TestCollection -Name "Test-Remove-WhatIf"
    $script:Col_WhatIf_Id = $col12.CollectionID
    $script:Col_WhatIf_Name = "Test-Remove-WhatIf"
    Add-DirectRuleIfMissing -CollectionId $script:Col_WhatIf_Id -ResourceId $script:ResourceId1
    $script:WhatIfQueryRuleName = "TestRemove-WhatIf-Query"
    Add-QueryRuleIfMissing -CollectionId $script:Col_WhatIf_Id -RuleName $script:WhatIfQueryRuleName -QueryExpression $script:QueryExpression
    Add-IncludeRuleIfMissing -CollectionId $script:Col_WhatIf_Id -IncludeCollectionId $script:IncludeCollectionId
    Add-ExcludeRuleIfMissing -CollectionId $script:Col_WhatIf_Id -ExcludeCollectionId $script:ExcludeCollectionId

    # ========================================================================
    # Wait for all rules to propagate
    # ========================================================================
    Write-Host "`nWaiting for all rules to propagate..." -ForegroundColor Cyan
    Start-Sleep -Seconds 5

    $allReady = $true

    # Verify direct rules
    foreach ($pair in @(
        @{ CollectionId = $script:Col_DirectByName_Id; ResourceId = $script:ResourceId1; Desc = "Direct-ByName" },
        @{ CollectionId = $script:Col_DirectById_Id; ResourceId = $script:ResourceId2; Desc = "Direct-ById" },
        @{ CollectionId = $script:Col_DirectByResName_Id; ResourceId = $script:ResourceId2; Desc = "Direct-ByResName" },
        @{ CollectionId = $script:Col_WhatIf_Id; ResourceId = $script:ResourceId1; Desc = "WhatIf-Direct" }
    )) {
        $rid = $pair.ResourceId
        $cid = $pair.CollectionId
        if (-not (Wait-ForRule -TestScript { Test-DirectRuleExists -ResourceId $rid -CollectionId $cid } -RuleDescription "$($pair.Desc) ResourceId $rid" -TimeoutSeconds 30)) {
            $allReady = $false
        }
    }

    # Verify multi direct rules
    foreach ($resId in $script:ResourceIdArray) {
        $cid = $script:Col_DirectMulti_Id
        if (-not (Wait-ForRule -TestScript { Test-DirectRuleExists -ResourceId $resId -CollectionId $cid } -RuleDescription "Direct-Multi ResourceId $resId" -TimeoutSeconds 30)) {
            $allReady = $false
        }
    }

    # Verify wildcard direct rules
    foreach ($resId in $script:ResourceIdArray) {
        $cid = $script:Col_DirectWildcard_Id
        if (-not (Wait-ForRule -TestScript { Test-DirectRuleExists -ResourceId $resId -CollectionId $cid } -RuleDescription "Direct-Wildcard ResourceId $resId" -TimeoutSeconds 30)) {
            $allReady = $false
        }
    }

    # Verify query rules
    $cid = $script:Col_QuerySingle_Id
    $rn = $script:QueryRuleName1
    if (-not (Wait-ForRule -TestScript { Test-QueryRuleExists -RuleName $rn -CollectionId $cid } -RuleDescription "Query-Single '$rn'" -TimeoutSeconds 30)) {
        $allReady = $false
    }
    foreach ($name in $script:QueryWildcardRuleNames) {
        $cid = $script:Col_QueryWildcard_Id
        $rn = $name
        if (-not (Wait-ForRule -TestScript { Test-QueryRuleExists -RuleName $rn -CollectionId $cid } -RuleDescription "Query-Wildcard '$rn'" -TimeoutSeconds 30)) {
            $allReady = $false
        }
    }

    # Verify include rules
    foreach ($pair in @(
        @{ CollectionId = $script:Col_IncludeById_Id; Desc = "Include-ById" },
        @{ CollectionId = $script:Col_IncludeByName_Id; Desc = "Include-ByName" },
        @{ CollectionId = $script:Col_WhatIf_Id; Desc = "WhatIf-Include" }
    )) {
        $cid = $pair.CollectionId
        $iid = $script:IncludeCollectionId
        if (-not (Wait-ForRule -TestScript { Test-IncludeRuleExists -IncludeCollectionId $iid -CollectionId $cid } -RuleDescription "$($pair.Desc) Include $iid" -TimeoutSeconds 30)) {
            $allReady = $false
        }
    }

    # Verify exclude rules
    foreach ($pair in @(
        @{ CollectionId = $script:Col_ExcludeById_Id; Desc = "Exclude-ById" },
        @{ CollectionId = $script:Col_ExcludeByName_Id; Desc = "Exclude-ByName" },
        @{ CollectionId = $script:Col_WhatIf_Id; Desc = "WhatIf-Exclude" }
    )) {
        $cid = $pair.CollectionId
        $eid = $script:ExcludeCollectionId
        if (-not (Wait-ForRule -TestScript { Test-ExcludeRuleExists -ExcludeCollectionId $eid -CollectionId $cid } -RuleDescription "$($pair.Desc) Exclude $eid" -TimeoutSeconds 30)) {
            $allReady = $false
        }
    }

    # Verify WhatIf query
    $cid = $script:Col_WhatIf_Id
    $rn = $script:WhatIfQueryRuleName
    if (-not (Wait-ForRule -TestScript { Test-QueryRuleExists -RuleName $rn -CollectionId $cid } -RuleDescription "WhatIf-Query '$rn'" -TimeoutSeconds 30)) {
        $allReady = $false
    }

    if ($allReady) {
        Write-Host "✓ All test rules successfully verified" -ForegroundColor Green
    } else {
        Write-Warning "Some test rules failed to propagate - tests may be skipped or fail"
    }
    Write-Host "=== Setup complete ===`n" -ForegroundColor Cyan
}

Describe "Remove-CM7CollectionMembershipRule Function Tests" -Tag "Integration", "Collection", "MembershipRule", "Remove" {

    Context "Test Data Validation" {

        It "Should have test data defined in declarations.ps1" {
            $script:TestRemoveRuleData | Should -Not -BeNullOrEmpty
            $script:TestData.ContainsKey('Remove-CM7CollectionMembershipRule') | Should -Be $true
        }

        It "Should have required test data parameter sets" {
            $script:TestRemoveRuleData.ContainsKey('DirectByCollectionNameAndResourceId') | Should -Be $true
            $script:TestRemoveRuleData.ContainsKey('QueryByCollectionName') | Should -Be $true
            $script:TestRemoveRuleData.ContainsKey('IncludeByCollectionName') | Should -Be $true
            $script:TestRemoveRuleData.ContainsKey('ExcludeByCollectionName') | Should -Be $true
        }

        It "Should output test data for verification" {
            Write-Host "`n=== Test Data for Remove-CM7CollectionMembershipRule ===" -ForegroundColor Cyan
            Write-Host "ResourceId1: $script:ResourceId1" -ForegroundColor White
            Write-Host "ResourceId2: $script:ResourceId2" -ForegroundColor White
            Write-Host "ResourceName2: $script:ResourceName2" -ForegroundColor White
            Write-Host "WildcardPattern: $script:WildcardPattern" -ForegroundColor White
            Write-Host "IncludeCollectionId: $script:IncludeCollectionId" -ForegroundColor White
            Write-Host "ExcludeCollectionId: $script:ExcludeCollectionId" -ForegroundColor White
            Write-Host "`nTest Collections:" -ForegroundColor Yellow
            Write-Host "  Direct-ByName:     $script:Col_DirectByName_Name ($script:Col_DirectByName_Id)" -ForegroundColor White
            Write-Host "  Direct-ById:       $script:Col_DirectById_Name ($script:Col_DirectById_Id)" -ForegroundColor White
            Write-Host "  Direct-ByResName:  $script:Col_DirectByResName_Name ($script:Col_DirectByResName_Id)" -ForegroundColor White
            Write-Host "  Direct-Multi:      $script:Col_DirectMulti_Name ($script:Col_DirectMulti_Id)" -ForegroundColor White
            Write-Host "  Direct-Wildcard:   $script:Col_DirectWildcard_Name ($script:Col_DirectWildcard_Id)" -ForegroundColor White
            Write-Host "  Query-Single:      $script:Col_QuerySingle_Name ($script:Col_QuerySingle_Id)" -ForegroundColor White
            Write-Host "  Query-Wildcard:    $script:Col_QueryWildcard_Name ($script:Col_QueryWildcard_Id)" -ForegroundColor White
            Write-Host "  Include-ById:      $script:Col_IncludeById_Name ($script:Col_IncludeById_Id)" -ForegroundColor White
            Write-Host "  Include-ByName:    $script:Col_IncludeByName_Name ($script:Col_IncludeByName_Id)" -ForegroundColor White
            Write-Host "  Exclude-ById:      $script:Col_ExcludeById_Name ($script:Col_ExcludeById_Id)" -ForegroundColor White
            Write-Host "  Exclude-ByName:    $script:Col_ExcludeByName_Name ($script:Col_ExcludeByName_Id)" -ForegroundColor White
            Write-Host "  WhatIf:            $script:Col_WhatIf_Name ($script:Col_WhatIf_Id)" -ForegroundColor White
            Write-Host "============================================================`n" -ForegroundColor Cyan
            $true | Should -Be $true
        }
    }

    Context "Connection Requirement" {

        It "Should fail if not connected to MECM" {
            # Arrange - Backup and clear connection
            $backupConnection = $script:CMConnection.Clone()
            $script:CMConnection.CimSession = $null

            # Act & Assert
            { Remove-CM7CollectionMembershipRule -CollectionName "Test" -RuleType Direct -ResourceId 1 -Force } | Should -Throw "*not connected*"

            # Restore connection
            $script:CMConnection = $backupConnection
        }
    }

    Context "Parameter Validation" {

        It "Should throw when ResourceId and ResourceName are missing for Direct rule" {
            { Remove-CM7CollectionMembershipRule -CollectionName $script:Col_DirectByName_Name -RuleType Direct -Force } | Should -Throw "*ResourceId*ResourceName*"
        }

        It "Should throw when RuleName is missing for Query rule" {
            { Remove-CM7CollectionMembershipRule -CollectionName $script:Col_QuerySingle_Name -RuleType Query -Force } | Should -Throw "*RuleName*"
        }

        It "Should throw when neither IncludeCollectionId nor IncludeCollectionName is specified for Include rule" {
            { Remove-CM7CollectionMembershipRule -CollectionName $script:Col_IncludeById_Name -RuleType Include -Force } | Should -Throw "*IncludeCollection*"
        }

        It "Should throw when neither ExcludeCollectionId nor ExcludeCollectionName is specified for Exclude rule" {
            { Remove-CM7CollectionMembershipRule -CollectionName $script:Col_ExcludeById_Name -RuleType Exclude -Force } | Should -Throw "*ExcludeCollection*"
        }
    }

    Context "Remove Direct Membership Rule" {

        It "Should remove a direct membership rule by collection name and ResourceId" {
            # Arrange - verify the rule exists on its dedicated collection
            $collectionName = $script:Col_DirectByName_Name
            $collectionId = $script:Col_DirectByName_Id
            $resourceId = $script:ResourceId1

            $exists = Test-DirectRuleExists -ResourceId $resourceId -CollectionId $collectionId
            if (-not $exists) {
                Set-ItResult -Skipped -Because "Direct rule for ResourceId $resourceId not found on '$collectionName'"
                return
            }

            # Act
            Write-Host "  Removing direct rule for ResourceId $resourceId from '$collectionName'" -ForegroundColor Gray
            $result = Remove-CM7CollectionMembershipRule -CollectionName $collectionName -RuleType Direct -ResourceId $resourceId -Force

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.RuleType | Should -Be 'Direct'
            $result.ResourceId | Should -Be $resourceId
            $result.Status | Should -Be 'Removed'
            $result.CollectionId | Should -Be $collectionId

            # Verify removal
            $removed = Wait-ForRuleRemoval -TestScript { Test-DirectRuleExists -ResourceId $resourceId -CollectionId $collectionId } -RuleDescription "Direct rule for ResourceId $resourceId" -TimeoutSeconds 30
            $removed | Should -Be $true
        }

        It "Should remove a direct membership rule by collection ID" {
            # Arrange - verify the rule exists on its dedicated collection
            $collectionId = $script:Col_DirectById_Id
            $resourceId = $script:ResourceId2

            $exists = Test-DirectRuleExists -ResourceId $resourceId -CollectionId $collectionId
            if (-not $exists) {
                Set-ItResult -Skipped -Because "Direct rule for ResourceId $resourceId not found on collection $collectionId"
                return
            }

            # Act
            Write-Host "  Removing direct rule by CollectionId from '$script:Col_DirectById_Name'" -ForegroundColor Gray
            $result = Remove-CM7CollectionMembershipRule -CollectionId $collectionId -RuleType Direct -ResourceId $resourceId -Force

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.RuleType | Should -Be 'Direct'
            $result.ResourceId | Should -Be $resourceId
            $result.Status | Should -Be 'Removed'
            $result.CollectionId | Should -Be $collectionId

            # Verify removal
            $removed = Wait-ForRuleRemoval -TestScript { Test-DirectRuleExists -ResourceId $resourceId -CollectionId $collectionId } -RuleDescription "Direct rule for ResourceId $resourceId" -TimeoutSeconds 30
            $removed | Should -Be $true
        }

        It "Should remove a direct membership rule by ResourceName" {
            # Arrange - verify the rule exists on its dedicated collection
            $collectionId = $script:Col_DirectByResName_Id
            $resourceId = $script:ResourceId2
            $resourceName = $script:ResourceName2

            $exists = Test-DirectRuleExists -ResourceId $resourceId -CollectionId $collectionId
            if (-not $exists) {
                Set-ItResult -Skipped -Because "Direct rule for ResourceId $resourceId not found on '$script:Col_DirectByResName_Name'"
                return
            }

            # Act
            Write-Host "  Removing direct rule by ResourceName: $resourceName from '$script:Col_DirectByResName_Name'" -ForegroundColor Gray
            $result = Remove-CM7CollectionMembershipRule -CollectionId $collectionId -RuleType Direct -ResourceName $resourceName -Force

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.RuleType | Should -Be 'Direct'
            $result.ResourceName | Should -Be $resourceName
            $result.Status | Should -Be 'Removed'
        }

        It "Should remove multiple direct membership rules with ResourceId array" {
            # Arrange - verify rules exist on the dedicated multi-remove collection
            $collectionId = $script:Col_DirectMulti_Id
            $collectionName = $script:Col_DirectMulti_Name
            $resourceIds = $script:ResourceIdArray

            if (-not $resourceIds -or $resourceIds.Count -lt 2) {
                Set-ItResult -Skipped -Because "ResourceIdArray not defined with multiple IDs in test data"
                return
            }

            # Verify all rules exist
            $missingRules = @()
            foreach ($resId in $resourceIds) {
                if (-not (Test-DirectRuleExists -ResourceId $resId -CollectionId $collectionId)) {
                    $missingRules += $resId
                }
            }
            if ($missingRules.Count -gt 0) {
                Set-ItResult -Skipped -Because "Direct rules for ResourceIds $($missingRules -join ', ') not found on '$collectionName'"
                return
            }

            # Act
            Write-Host "  Removing $($resourceIds.Count) direct rules from '$collectionName'" -ForegroundColor Gray
            $results = Remove-CM7CollectionMembershipRule -CollectionName $collectionName -RuleType Direct -ResourceId $resourceIds -Force

            # Assert
            $results | Should -Not -BeNullOrEmpty
            @($results).Count | Should -Be $resourceIds.Count
            $results | ForEach-Object {
                $_.RuleType | Should -Be 'Direct'
                $_.Status | Should -Be 'Removed'
            }

            # Verify all are removed
            foreach ($resId in $resourceIds) {
                $removed = Wait-ForRuleRemoval -TestScript { Test-DirectRuleExists -ResourceId $resId -CollectionId $collectionId } -RuleDescription "Direct rule for ResourceId $resId" -TimeoutSeconds 30
                $removed | Should -Be $true
            }
        }

        It "Should remove direct membership rules matching wildcard ResourceName" {
            # Arrange - verify rules exist on the dedicated wildcard collection
            $collectionId = $script:Col_DirectWildcard_Id
            $collectionName = $script:Col_DirectWildcard_Name
            $wildcardPattern = $script:WildcardPattern

            $existingRules = Get-CM7CollectionDirectMembershipRule -CollectionId $collectionId -ErrorAction SilentlyContinue
            if (-not $existingRules -or @($existingRules).Count -eq 0) {
                Set-ItResult -Skipped -Because "No direct rules found on '$collectionName'"
                return
            }

            $preRemoveCount = @($existingRules).Count
            Write-Host "  Found $preRemoveCount direct rule(s) on '$collectionName'" -ForegroundColor Gray

            # Act
            Write-Host "  Removing direct rules matching wildcard: $wildcardPattern" -ForegroundColor Gray
            $results = Remove-CM7CollectionMembershipRule -CollectionName $collectionName -RuleType Direct -ResourceName $wildcardPattern -Force

            # Assert
            $results | Should -Not -BeNullOrEmpty
            $results | ForEach-Object {
                $_.RuleType | Should -Be 'Direct'
                $_.Status | Should -Be 'Removed'
            }
        }
    }

    Context "Remove Query Membership Rule" {

        It "Should remove a query membership rule by collection name" {
            # Arrange
            $collectionId = $script:Col_QuerySingle_Id
            $collectionName = $script:Col_QuerySingle_Name
            $ruleName = $script:QueryRuleName1

            $exists = Test-QueryRuleExists -RuleName $ruleName -CollectionId $collectionId
            if (-not $exists) {
                Set-ItResult -Skipped -Because "Query rule '$ruleName' not found on '$collectionName'"
                return
            }

            # Act
            Write-Host "  Removing query rule '$ruleName' from '$collectionName'" -ForegroundColor Gray
            $result = Remove-CM7CollectionMembershipRule -CollectionName $collectionName -RuleType Query -RuleName $ruleName -Force

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.RuleType | Should -Be 'Query'
            $result.RuleName | Should -Be $ruleName
            $result.Status | Should -Be 'Removed'

            # Verify removal
            $removed = Wait-ForRuleRemoval -TestScript { Test-QueryRuleExists -RuleName $ruleName -CollectionId $collectionId } -RuleDescription "Query rule '$ruleName'" -TimeoutSeconds 30
            $removed | Should -Be $true
        }

        It "Should remove query membership rules matching wildcard RuleName" {
            # Arrange
            $collectionId = $script:Col_QueryWildcard_Id
            $collectionName = $script:Col_QueryWildcard_Name
            $wildcardPattern = "TestRemove-QueryWC-*"

            $existingRules = Get-CM7CollectionQueryMembershipRule -CollectionId $collectionId -ErrorAction SilentlyContinue
            $matchingRules = $existingRules | Where-Object { $_.RuleName -like $wildcardPattern }
            if (-not $matchingRules -or @($matchingRules).Count -eq 0) {
                Set-ItResult -Skipped -Because "No query rules matching '$wildcardPattern' found on '$collectionName'"
                return
            }

            $matchCount = @($matchingRules).Count
            Write-Host "  Found $matchCount query rule(s) matching '$wildcardPattern' on '$collectionName'" -ForegroundColor Gray

            # Act
            Write-Host "  Removing query rules matching: $wildcardPattern" -ForegroundColor Gray
            $results = Remove-CM7CollectionMembershipRule -CollectionName $collectionName -RuleType Query -RuleName $wildcardPattern -Force

            # Assert
            $results | Should -Not -BeNullOrEmpty
            @($results).Count | Should -BeGreaterOrEqual 2
            $results | ForEach-Object {
                $_.RuleType | Should -Be 'Query'
                $_.Status | Should -Be 'Removed'
            }
        }
    }

    Context "Remove Include Membership Rule" {

        It "Should remove an include membership rule by IncludeCollectionId" {
            # Arrange
            $collectionId = $script:Col_IncludeById_Id
            $collectionName = $script:Col_IncludeById_Name
            $includeCollectionId = $script:IncludeCollectionId

            $exists = Test-IncludeRuleExists -IncludeCollectionId $includeCollectionId -CollectionId $collectionId
            if (-not $exists) {
                Set-ItResult -Skipped -Because "Include rule for $includeCollectionId not found on '$collectionName'"
                return
            }

            # Act
            Write-Host "  Removing include rule for collection $includeCollectionId from '$collectionName'" -ForegroundColor Gray
            $result = Remove-CM7CollectionMembershipRule -CollectionName $collectionName -RuleType Include -IncludeCollectionId $includeCollectionId -Force

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.RuleType | Should -Be 'Include'
            $result.IncludeCollectionId | Should -Be $includeCollectionId
            $result.Status | Should -Be 'Removed'

            # Verify removal
            $removed = Wait-ForRuleRemoval -TestScript { Test-IncludeRuleExists -IncludeCollectionId $includeCollectionId -CollectionId $collectionId } -RuleDescription "Include rule for $includeCollectionId" -TimeoutSeconds 30
            $removed | Should -Be $true
        }

        It "Should remove an include membership rule by IncludeCollectionName" {
            # Arrange
            $collectionId = $script:Col_IncludeByName_Id
            $collectionName = $script:Col_IncludeByName_Name
            $includeCollectionName = $script:IncludeCollectionName
            $includeCollectionId = $script:IncludeCollectionId

            $exists = Test-IncludeRuleExists -IncludeCollectionId $includeCollectionId -CollectionId $collectionId
            if (-not $exists) {
                Set-ItResult -Skipped -Because "Include rule for $includeCollectionId not found on '$collectionName'"
                return
            }

            # Act
            Write-Host "  Removing include rule by collection name '$includeCollectionName' from '$collectionName'" -ForegroundColor Gray
            $result = Remove-CM7CollectionMembershipRule -CollectionName $collectionName -RuleType Include -IncludeCollectionName $includeCollectionName -Force

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.RuleType | Should -Be 'Include'
            $result.IncludeCollectionName | Should -Be $includeCollectionName
            $result.Status | Should -Be 'Removed'
        }
    }

    Context "Remove Exclude Membership Rule" {

        It "Should remove an exclude membership rule by ExcludeCollectionId" {
            # Arrange
            $collectionId = $script:Col_ExcludeById_Id
            $collectionName = $script:Col_ExcludeById_Name
            $excludeCollectionId = $script:ExcludeCollectionId

            $exists = Test-ExcludeRuleExists -ExcludeCollectionId $excludeCollectionId -CollectionId $collectionId
            if (-not $exists) {
                Set-ItResult -Skipped -Because "Exclude rule for $excludeCollectionId not found on '$collectionName'"
                return
            }

            # Act
            Write-Host "  Removing exclude rule for collection $excludeCollectionId from '$collectionName'" -ForegroundColor Gray
            $result = Remove-CM7CollectionMembershipRule -CollectionName $collectionName -RuleType Exclude -ExcludeCollectionId $excludeCollectionId -Force

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.RuleType | Should -Be 'Exclude'
            $result.ExcludeCollectionId | Should -Be $excludeCollectionId
            $result.Status | Should -Be 'Removed'

            # Verify removal
            $removed = Wait-ForRuleRemoval -TestScript { Test-ExcludeRuleExists -ExcludeCollectionId $excludeCollectionId -CollectionId $collectionId } -RuleDescription "Exclude rule for $excludeCollectionId" -TimeoutSeconds 30
            $removed | Should -Be $true
        }

        It "Should remove an exclude membership rule by ExcludeCollectionName" {
            # Arrange
            $collectionId = $script:Col_ExcludeByName_Id
            $collectionName = $script:Col_ExcludeByName_Name
            $excludeCollectionName = $script:ExcludeCollectionName
            $excludeCollectionId = $script:ExcludeCollectionId

            $exists = Test-ExcludeRuleExists -ExcludeCollectionId $excludeCollectionId -CollectionId $collectionId
            if (-not $exists) {
                Set-ItResult -Skipped -Because "Exclude rule for $excludeCollectionId not found on '$collectionName'"
                return
            }

            # Act
            Write-Host "  Removing exclude rule by collection name '$excludeCollectionName' from '$collectionName'" -ForegroundColor Gray
            $result = Remove-CM7CollectionMembershipRule -CollectionName $collectionName -RuleType Exclude -ExcludeCollectionName $excludeCollectionName -Force

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.RuleType | Should -Be 'Exclude'
            $result.ExcludeCollectionName | Should -Be $excludeCollectionName
            $result.Status | Should -Be 'Removed'
        }
    }

    Context "Error Handling" {

        It "Should throw for non-existent collection name" {
            { Remove-CM7CollectionMembershipRule -CollectionName "NonExistent-Collection-999" -RuleType Direct -ResourceId 1 -Force } | Should -Throw "*not found*"
        }

        It "Should throw for non-existent collection ID" {
            { Remove-CM7CollectionMembershipRule -CollectionId "XXX99999" -RuleType Direct -ResourceId 1 -Force } | Should -Throw "*not found*"
        }

        It "Should warn when removing non-existent direct rule" {
            $result = Remove-CM7CollectionMembershipRule -CollectionName $script:Col_WhatIf_Name -RuleType Direct -ResourceId 99999999 -Force -WarningAction SilentlyContinue
            $result | Should -BeNullOrEmpty
        }

        It "Should warn when removing non-existent query rule" {
            $result = Remove-CM7CollectionMembershipRule -CollectionName $script:Col_WhatIf_Name -RuleType Query -RuleName "NonExistent-Query-Rule-999" -Force -WarningAction SilentlyContinue
            $result | Should -BeNullOrEmpty
        }

        It "Should throw for non-existent include collection ID" {
            { Remove-CM7CollectionMembershipRule -CollectionName $script:Col_WhatIf_Name -RuleType Include -IncludeCollectionId "XXX99999" -Force } | Should -Throw "*not found*"
        }

        It "Should throw for non-existent exclude collection name" {
            { Remove-CM7CollectionMembershipRule -CollectionName $script:Col_WhatIf_Name -RuleType Exclude -ExcludeCollectionName "NonExistent-Collection-999" -Force } | Should -Throw "*not found*"
        }
    }

    Context "WhatIf Support" {

        It "Should support -WhatIf for Direct rule" {
            # Arrange
            $collectionId = $script:Col_WhatIf_Id
            $resourceId = $script:ResourceId1

            $exists = Test-DirectRuleExists -ResourceId $resourceId -CollectionId $collectionId
            if (-not $exists) {
                Set-ItResult -Skipped -Because "Direct rule for ResourceId $resourceId not found on WhatIf collection"
                return
            }

            # Act & Assert - should not throw, and should not actually remove
            { Remove-CM7CollectionMembershipRule -CollectionId $collectionId -RuleType Direct -ResourceId $resourceId -WhatIf } | Should -Not -Throw

            # Verify it still exists
            $stillExists = Test-DirectRuleExists -ResourceId $resourceId -CollectionId $collectionId
            $stillExists | Should -Be $true
        }

        It "Should support -WhatIf for Query rule" {
            # Arrange
            $collectionId = $script:Col_WhatIf_Id
            $ruleName = $script:WhatIfQueryRuleName

            $exists = Test-QueryRuleExists -RuleName $ruleName -CollectionId $collectionId
            if (-not $exists) {
                Set-ItResult -Skipped -Because "Query rule '$ruleName' not found on WhatIf collection"
                return
            }

            # Act & Assert
            { Remove-CM7CollectionMembershipRule -CollectionId $collectionId -RuleType Query -RuleName $ruleName -WhatIf } | Should -Not -Throw

            # Verify it still exists
            $stillExists = Test-QueryRuleExists -RuleName $ruleName -CollectionId $collectionId
            $stillExists | Should -Be $true
        }

        It "Should support -WhatIf for Include rule" {
            # Arrange
            $collectionId = $script:Col_WhatIf_Id
            $includeCollectionId = $script:IncludeCollectionId

            $exists = Test-IncludeRuleExists -IncludeCollectionId $includeCollectionId -CollectionId $collectionId
            if (-not $exists) {
                Set-ItResult -Skipped -Because "Include rule for $includeCollectionId not found on WhatIf collection"
                return
            }

            # Act & Assert
            { Remove-CM7CollectionMembershipRule -CollectionId $collectionId -RuleType Include -IncludeCollectionId $includeCollectionId -WhatIf } | Should -Not -Throw

            # Verify it still exists
            $stillExists = Test-IncludeRuleExists -IncludeCollectionId $includeCollectionId -CollectionId $collectionId
            $stillExists | Should -Be $true
        }

        It "Should support -WhatIf for Exclude rule" {
            # Arrange
            $collectionId = $script:Col_WhatIf_Id
            $excludeCollectionId = $script:ExcludeCollectionId

            $exists = Test-ExcludeRuleExists -ExcludeCollectionId $excludeCollectionId -CollectionId $collectionId
            if (-not $exists) {
                Set-ItResult -Skipped -Because "Exclude rule for $excludeCollectionId not found on WhatIf collection"
                return
            }

            # Act & Assert
            { Remove-CM7CollectionMembershipRule -CollectionId $collectionId -RuleType Exclude -ExcludeCollectionId $excludeCollectionId -WhatIf } | Should -Not -Throw

            # Verify it still exists
            $stillExists = Test-ExcludeRuleExists -ExcludeCollectionId $excludeCollectionId -CollectionId $collectionId
            $stillExists | Should -Be $true
        }
    }
}

AfterAll {
    Write-Host "`n=== Test run complete ===" -ForegroundColor Cyan
    Write-Host "Test collections are preserved. Delete them manually when no longer needed:" -ForegroundColor Gray
    Write-Host "  Test-Remove-Direct-ByName, Test-Remove-Direct-ById, Test-Remove-Direct-ByResName" -ForegroundColor Gray
    Write-Host "  Test-Remove-Direct-Multi, Test-Remove-Direct-Wildcard" -ForegroundColor Gray
    Write-Host "  Test-Remove-Query-Single, Test-Remove-Query-Wildcard" -ForegroundColor Gray
    Write-Host "  Test-Remove-Include-ById, Test-Remove-Include-ByName" -ForegroundColor Gray
    Write-Host "  Test-Remove-Exclude-ById, Test-Remove-Exclude-ByName" -ForegroundColor Gray
    Write-Host "  Test-Remove-WhatIf" -ForegroundColor Gray
}
