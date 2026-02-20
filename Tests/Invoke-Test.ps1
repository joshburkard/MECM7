<#
.SYNOPSIS
    Run tests for a specific function or all functional tests.

.DESCRIPTION
    This script allows you to easily run Pester tests for individual functions or all functional tests.
    It automatically loads declarations and dependencies before running the tests.

.PARAMETER FunctionName
    The name of the function to test (e.g., "Get-CMASCollection").
    If not specified, runs all functional tests (Test-*.Tests.ps1).

.PARAMETER Tag
    Optional tag(s) to filter tests (e.g., "Integration", "Unit").

.PARAMETER Output
    Pester output level: None, Normal, Detailed, Diagnostic. Default is Detailed.

.PARAMETER PassThru
    Return the Pester result object.

.PARAMETER IncludeStructuralTests
    Include structural tests (naming, parameters, documentation) for the function.
    Only applied when testing a specific function with -FunctionName.

.EXAMPLE
    .\Invoke-Test.ps1 -FunctionName "Get-CMASCollection"
    Run tests for the Get-CMASCollection function.

.EXAMPLE
    .\Invoke-Test.ps1 -FunctionName "Get-CMASCollection" -IncludeStructuralTests
    Run both structural and functional tests for Get-CMASCollection.

.EXAMPLE
    .\Invoke-Test.ps1 -FunctionName "Get-CMASCollectionExcludeMembershipRule" -Output Normal
    Run tests with normal output level.

.EXAMPLE
    .\Invoke-Test.ps1
    Run all functional tests (Test-*.Tests.ps1 files).

.EXAMPLE
    .\Invoke-Test.ps1 -Tag "Integration"
    Run all functional tests tagged with "Integration".

.EXAMPLE
    .\Invoke-Test.ps1 -FunctionName "Invoke-CMASScript" -Tag "Unit"
    Run only Unit tests for Invoke-CMASScript.

.NOTES
    This script requires Pester 5.2.2 or higher.
#>
[CmdletBinding()]
param(
    [Parameter(Position=0)]
    [string]$FunctionName,

    [Parameter()]
    [string[]]$Tag,

    [Parameter()]
    [ValidateSet('None', 'Normal', 'Detailed', 'Diagnostic')]
    [string]$Output = 'Detailed',

    [Parameter()]
    [switch]$PassThru,

    [Parameter()]
    [switch]$IncludeStructuralTests
)

Clear-Host
Write-Host "========================================" -ForegroundColor Cyan

# Ensure Pester 5.x is loaded
if((Get-Module -Name Pester).Version -match '^3\.\d{1}\.\d{1}'){
    try {
        Remove-Module -Name Pester -ErrorAction Stop
        Write-Host "[TEST] Removing Pester 3.x" -ForegroundColor Yellow
    } catch {}
}

if(-not (Get-Module -Name Pester -ListAvailable | Where-Object { $_.Version -ge '5.2.2' })) {
    Write-Error "Pester 5.2.2 or higher is required. Install with: Install-Module -Name Pester -MinimumVersion 5.2.2 -Force"
    exit 1
}

Import-Module -Name Pester -MinimumVersion 5.2.2 -ErrorAction Stop

# Get script paths
$TestsPath = $PSScriptRoot
$Root = (Get-Item $TestsPath).Parent.FullName
$DeclarationsPath = Join-Path -Path $TestsPath -ChildPath "declarations.ps1"

# Check if declarations.ps1 exists
if(-not (Test-Path -Path $DeclarationsPath)) {
    Write-Warning "declarations.ps1 not found. Please copy declarations_sample.ps1 to declarations.ps1 and configure your test values."
    Write-Warning "Some tests may be skipped or fail without proper configuration."
    Write-Host ""
    $continue = Read-Host "Continue anyway? (y/n)"
    if($continue -ne 'y') {
        exit 0
    }
}
else {
    # Load declarations for sensitive value checks and test data
    Write-Host "[TEST] Loading test declarations from declarations.ps1" -ForegroundColor Green
    . $DeclarationsPath
}

# Determine which test file(s) to run
$testFiles = @()

if ($FunctionName) {
    # Run test for specific function
    $testFile = Join-Path -Path $TestsPath -ChildPath "Test-$FunctionName.Tests.ps1"

    if(-not (Test-Path -Path $testFile)) {
        Write-Error "Test file not found: $testFile"
        Write-Host ""
        Write-Host "Available test files:" -ForegroundColor Cyan
        Get-ChildItem -Path $TestsPath -Filter "Test-*.Tests.ps1" | ForEach-Object {
            $funcName = $_.Name -replace '^Test-(.+)\.Tests\.ps1$', '$1'
            Write-Host "  - $funcName" -ForegroundColor Gray
        }
        exit 1
    }

    $testFiles += $testFile
    Write-Host "[TEST] Running tests for function: $FunctionName" -ForegroundColor Green
    Write-Host "[TEST] Test file: $(Split-Path -Leaf $testFile)" -ForegroundColor Gray

    # Run structural tests if requested
    if($IncludeStructuralTests) {
        Write-Host "[TEST] Including structural tests" -ForegroundColor Cyan
    }
}
else {
    # Run all functional tests
    $testFiles = Get-ChildItem -Path $TestsPath -Filter "Test-*.Tests.ps1" -ErrorAction SilentlyContinue

    if($testFiles.Count -eq 0) {
        Write-Warning "No functional test files found (Test-*.Tests.ps1)."
        exit 0
    }

    Write-Host "[TEST] Running ALL functional tests ($($testFiles.Count) files)" -ForegroundColor Green

    # Structural tests only run for specific functions
    if($IncludeStructuralTests) {
        Write-Warning "Structural tests are only available when testing a specific function with -FunctionName"
        $IncludeStructuralTests = $false
    }
}

Write-Host ""

# Run structural tests first if requested (only for specific function)
$structuralResult = $null
if($IncludeStructuralTests -and $FunctionName) {
    Write-Host "========================================" -ForegroundColor Yellow
    Write-Host "Running Structural Tests for $FunctionName" -ForegroundColor Yellow
    Write-Host "========================================" -ForegroundColor Yellow
    Write-Host ""

    # Load module settings for prefix
    $CISourcePath = Join-Path -Path $Root -ChildPath "CI"
    $Settings = Join-Path -Path $CISourcePath -ChildPath "Module-Settings.json"
    $CommonPrefix = "CMAS"  # Default
    if(Test-Path -Path $Settings) {
        $ModuleSettings = Get-content -Path $Settings | ConvertFrom-Json
        $CommonPrefix = $ModuleSettings.ModulePrefix
    }

    # Find the function file
    $CodeSourcePath = Join-Path -Path $Root -ChildPath "Code"
    $PublicPath = Join-Path $CodeSourcePath -ChildPath 'Public'
    $PrivatePath = Join-Path $CodeSourcePath -ChildPath 'Private'

    $functionFile = Get-ChildItem -Path $PublicPath -Filter "$FunctionName.ps1" -ErrorAction SilentlyContinue
    if(-not $functionFile) {
        $functionFile = Get-ChildItem -Path $PrivatePath -Filter "$FunctionName.ps1" -ErrorAction SilentlyContinue
    }

    if($functionFile) {
        # Load the function
        . $functionFile.FullName

        # Get function metadata
        $ScriptName = $functionFile.BaseName
        $Verb = @( $($ScriptName) -split '-' )[0]
        try {
            $FunctionPrefix = @( $ScriptName -split '-' )[1].Substring( 0, $CommonPrefix.Length )
        }
        catch {
            $FunctionPrefix = @( $ScriptName -split '-' )[1]
        }

        $ScriptCommand = Get-Command -Name $ScriptName -ErrorAction SilentlyContinue
        if(-not $ScriptCommand) {
            Write-Error "Function $ScriptName could not be loaded from $($functionFile.FullName)"
            exit 1
        }

        # Get detailed help - must be done after function is loaded
        $DetailedHelp  = Get-Help $ScriptName -Detailed

        if($ScriptCommand) {
            $Ast = $ScriptCommand.ScriptBlock.Ast

            # Capture sensitive values for the closure (dot-sourced from declarations.ps1)
            $CapturedSensitiveValues = if ($SensitiveValues) { $SensitiveValues } else { @() }
            $CapturedRoot = $Root
            $CapturedFunctionFile = $functionFile

            # Create structural tests in-memory
            $structuralTestScript = {
                Describe "Structural Tests for $ScriptName" -Tag "Structural" {

                    Context "Naming Conventions" {

                        It "Should have an approved verb: $Verb" {
                            $Verb -in (Get-Verb).Verb | Should -BeTrue
                        }

                        It "Should have the module prefix '$CommonPrefix'" {
                            $FunctionPrefix | Should -Be $CommonPrefix
                        }
                    }

                    Context "Documentation" {

                        It "Should have a SYNOPSIS" {
                            $Ast -match 'SYNOPSIS' | Should -BeTrue
                        }

                        It "Should have a DESCRIPTION" {
                            $Ast -match 'DESCRIPTION' | Should -BeTrue
                        }

                        It "Should have at least one EXAMPLE" {
                            $Ast -match 'EXAMPLE' | Should -BeTrue
                        }
                    }

                    Context "Function Structure" {

                        It "Should have a CmdletBinding attribute" {
                            $hasCmdletBinding = [boolean]( @( $Ast.FindAll( { $true }, $true ) ) |
                                Where-Object { $_.TypeName.Name -eq 'cmdletbinding' } )
                            $hasCmdletBinding | Should -Be $true
                        }
                    }

                    Context "CIM Compatibility (no legacy WMI commands)" {

                        # Legacy WMI cmdlets that are not available in PowerShell 7.x
                        $wmiCmdlets = @(
                            'Get-WmiObject',
                            'Set-WmiInstance',
                            'Remove-WmiObject',
                            'Invoke-WmiMethod',
                            'Register-WmiEvent'
                        )

                        # Legacy WMI aliases
                        $wmiAliases = @( 'gwmi', 'swmi', 'rwmi' )

                        # Legacy WMI type accelerators ([WMI], [WMIClass], [WMISearcher])
                        $wmiTypeAccelerators = @( 'WMI', 'WMIClass', 'WMISearcher' )

                        # Get the raw source text of the function for checking
                        $sourceText = $Ast.Extent.Text

                        It "Should not use legacy WMI cmdlet '<_>'" -ForEach $wmiCmdlets {
                            $sourceText -match "\b$([regex]::Escape($_))\b" | Should -BeFalse -Because "'$_' is not available in PowerShell 7.x. Use the CIM equivalent instead."
                        }

                        It "Should not use legacy WMI alias '<_>'" -ForEach $wmiAliases {
                            # Check command AST nodes to avoid false positives in comments/strings used as names
                            $currentAlias = $_
                            $commandAsts = @( $Ast.FindAll( { param($node) $node -is [System.Management.Automation.Language.CommandAst] }, $true ) )
                            $usesAlias = $commandAsts | Where-Object { $_.GetCommandName() -eq $currentAlias }
                            $usesAlias | Should -BeNullOrEmpty -Because "Alias '$currentAlias' maps to a legacy WMI cmdlet not available in PowerShell 7.x."
                        }

                        It "Should not use legacy WMI type accelerator '[<_>]'" -ForEach $wmiTypeAccelerators {
                            $typeAsts = @( $Ast.FindAll( { param($node) $node -is [System.Management.Automation.Language.TypeExpressionAst] -or $node -is [System.Management.Automation.Language.TypeConstraintAst] }, $true ) )
                            $usesType = $typeAsts | Where-Object { $_.TypeName.Name -eq $_ }
                            $usesType | Should -BeNullOrEmpty -Because "Type accelerator '[$_]' is a legacy WMI type not available in PowerShell 7.x. Use CIM classes instead."
                        }
                    }

                    Context "Parameter Documentation" {
                        $DefaultParams = @( 'Verbose', 'Debug', 'ErrorAction', 'WarningAction', 'InformationAction',
                                           'ErrorVariable', 'WarningVariable', 'InformationVariable', 'OutVariable',
                                           'OutBuffer', 'PipelineVariable', 'ProgressAction', 'WhatIf', 'Confirm')

                        $parameterKeys = @( $ScriptCommand.Parameters.Keys | Where-Object { $_ -notin $DefaultParams } | Sort-Object )

                        It "Should have help text for parameter '<_>'" -ForEach @( $parameterKeys ) {
                            $helpParamNames = @($DetailedHelp.parameters.parameter).name
                            $_ -in $helpParamNames | Should -Be $true
                        }

                        It "Should have type declaration for parameter '<_>'" -ForEach @( $parameterKeys ) {
                            $currentParam = $_
                            $Declaration = ( ( @( $Ast.FindAll( { $true }, $true ) ) |
                                Where-Object { $_.Name.Extent.Text -eq "`$$currentParam" } ).Extent.Text -replace 'INT32', 'INT' )
                            $VariableTypeFull = "\[$( $ScriptCommand.Parameters.$currentParam.ParameterType.FullName )\]"
                            $VariableType = $ScriptCommand.Parameters.$currentParam.ParameterType.Name -replace 'INT32', 'INT' `
                                -replace 'Int64', 'long' -replace 'String\[\]', 'String' -replace 'SwitchParameter', 'Switch'

                            # Escape regex special characters in type names (e.g., [] in array types)
                            $VariableTypeEscaped = [regex]::Escape($VariableType)
                            $VariableTypeFullEscaped = [regex]::Escape($VariableTypeFull)

                            ( $Declaration -match $VariableTypeEscaped ) -or ( $Declaration -match $VariableTypeFullEscaped ) | Should -Be $true
                        }
                    }

                    Context "Sensitive Value Leakage" {

                        It "Function file should not contain any sensitive values from declarations" {
                            # Build sensitive string values to check (exclude empty/null and PSCredential objects)
                            $sensitiveStrings = @()
                            if ($CapturedSensitiveValues -and $CapturedSensitiveValues.Count -gt 0) {
                                foreach ($val in $CapturedSensitiveValues) {
                                    if ($null -eq $val) { continue }
                                    if ($val -is [System.Management.Automation.PSCredential]) {
                                        $uname = $val.UserName
                                        $pword = $val.GetNetworkCredential().Password
                                        if (-not [string]::IsNullOrWhiteSpace($uname)) { $sensitiveStrings += $uname }
                                        if (-not [string]::IsNullOrWhiteSpace($pword)) { $sensitiveStrings += $pword }
                                    }
                                    elseif ($val -is [string] -and -not [string]::IsNullOrWhiteSpace($val)) {
                                        $sensitiveStrings += $val
                                    }
                                    else {
                                        $strVal = "$val"
                                        if (-not [string]::IsNullOrWhiteSpace($strVal)) { $sensitiveStrings += $strVal }
                                    }
                                }
                                $sensitiveStrings = @($sensitiveStrings | Select-Object -Unique)
                            }

                            if ($sensitiveStrings.Count -eq 0) {
                                Set-ItResult -Skipped -Because 'No sensitive values defined in declarations.ps1'
                                return
                            }

                            $content = Get-Content -Path $CapturedFunctionFile.FullName -Raw
                            $foundValues = @()
                            foreach ($sensitive in $sensitiveStrings) {
                                # Use word boundaries for short values to avoid false positives
                                # (e.g., SiteCode matching inside file extension ".psd1")
                                $pattern = [regex]::Escape($sensitive)
                                if ($sensitive.Length -le 5) { $pattern = "(?<![a-zA-Z0-9])$pattern(?![a-zA-Z0-9])" }
                                if ($content -match $pattern) {
                                    $foundValues += $sensitive
                                }
                            }
                            if ($foundValues.Count -gt 0) {
                                $detailMsg = ($foundValues | ForEach-Object { "  '$_'" }) -join "`n"
                                Write-Host "`nSensitive values detected in $($CapturedFunctionFile.Name):" -ForegroundColor Red
                                Write-Host $detailMsg -ForegroundColor Yellow
                            }
                            $foundValues | Should -BeNullOrEmpty -Because "Code files tracked by git must not contain sensitive values.`nDetected values:`n$( ($foundValues | ForEach-Object { '  -> ' + $_ }) -join "`n" )"
                        }

                        It "No git-tracked file should contain sensitive values" {
                            # Build sensitive string values
                            $sensitiveStrings = @()
                            if ($CapturedSensitiveValues -and $CapturedSensitiveValues.Count -gt 0) {
                                foreach ($val in $CapturedSensitiveValues) {
                                    if ($null -eq $val) { continue }
                                    if ($val -is [System.Management.Automation.PSCredential]) {
                                        $uname = $val.UserName
                                        $pword = $val.GetNetworkCredential().Password
                                        if (-not [string]::IsNullOrWhiteSpace($uname)) { $sensitiveStrings += $uname }
                                        if (-not [string]::IsNullOrWhiteSpace($pword)) { $sensitiveStrings += $pword }
                                    }
                                    elseif ($val -is [string] -and -not [string]::IsNullOrWhiteSpace($val)) {
                                        $sensitiveStrings += $val
                                    }
                                    else {
                                        $strVal = "$val"
                                        if (-not [string]::IsNullOrWhiteSpace($strVal)) { $sensitiveStrings += $strVal }
                                    }
                                }
                                $sensitiveStrings = @($sensitiveStrings | Select-Object -Unique)
                            }

                            if ($sensitiveStrings.Count -eq 0) {
                                Set-ItResult -Skipped -Because 'No sensitive values defined in declarations.ps1'
                                return
                            }

                            # Get all git-tracked files
                            $trackedFiles = @()
                            try {
                                Push-Location -Path $CapturedRoot
                                $gitFiles = git ls-files --cached 2>$null
                                if ($gitFiles) {
                                    $trackedFiles = $gitFiles | Where-Object {
                                        $_ -match '\.(ps1|psm1|psd1|md|txt|xml|json|yml|yaml|csv)$'
                                    } | ForEach-Object { Join-Path -Path $CapturedRoot -ChildPath $_ } | Where-Object { Test-Path $_ }
                                }
                            }
                            catch { }
                            finally { Pop-Location }

                            if ($trackedFiles.Count -eq 0) {
                                Set-ItResult -Skipped -Because 'Could not enumerate git-tracked files'
                                return
                            }

                            $violations = @()
                            foreach ($filePath in $trackedFiles) {
                                $content = Get-Content -Path $filePath -Raw -ErrorAction SilentlyContinue
                                if ([string]::IsNullOrEmpty($content)) { continue }

                                foreach ($sensitive in $sensitiveStrings) {
                                    # Use word boundaries for short values to avoid false positives
                                    # (e.g., SiteCode matching inside file extension ".psd1")
                                    $pattern = [regex]::Escape($sensitive)
                                    if ($sensitive.Length -le 5) { $pattern = "(?<![a-zA-Z0-9])$pattern(?![a-zA-Z0-9])" }
                                    if ($content -match $pattern) {
                                        $relativePath = $filePath.Replace($CapturedRoot, '').TrimStart('\', '/')
                                        $violations += "  [$relativePath] contains '$sensitive'"
                                    }
                                }
                            }
                            if ($violations.Count -gt 0) {
                                Write-Host "`nSensitive values detected in git-tracked files:" -ForegroundColor Red
                                $violations | ForEach-Object { Write-Host $_ -ForegroundColor Yellow }
                            }
                            $violations | Should -BeNullOrEmpty -Because "Git-tracked files must not contain sensitive values (credentials, server names, site codes).`nViolations:`n$($violations -join "`n")"
                        }
                    }
                }
            }.GetNewClosure()

            # Run structural tests
            $structuralConfig = New-PesterConfiguration
            $structuralConfig.Run.ScriptBlock = $structuralTestScript
            $structuralConfig.Run.PassThru = $true
            $structuralConfig.Output.Verbosity = $Output

            $structuralResult = Invoke-Pester -Configuration $structuralConfig

            Write-Host ""
            Write-Host "Structural Tests: Passed $($structuralResult.PassedCount)/$($structuralResult.TotalCount)" -ForegroundColor $(if($structuralResult.FailedCount -eq 0) { 'Green' } else { 'Yellow' })
            Write-Host ""
        }
        else {
            Write-Warning "Could not load function '$FunctionName' for structural testing"
        }
    }
    else {
        Write-Warning "Function file not found for '$FunctionName'"
    }

    Write-Host "========================================" -ForegroundColor Yellow
    Write-Host "Running Functional Tests for $FunctionName" -ForegroundColor Yellow
    Write-Host "========================================" -ForegroundColor Yellow
    Write-Host ""
}

# Build Pester configuration
$pesterConfig = @{
    Run = @{
        Path = $testFiles
        PassThru = $true  # Always get results for summary
    }
    Output = @{
        Verbosity = $Output
    }
}

# Add code coverage if testing a specific function
if ($FunctionName) {
    $CodeSourcePath = Join-Path -Path $Root -ChildPath "Code"
    $PublicPath = Join-Path $CodeSourcePath -ChildPath 'Public'
    $PrivatePath = Join-Path $CodeSourcePath -ChildPath 'Private'

    $functionFile = Get-ChildItem -Path $PublicPath -Filter "$FunctionName.ps1" -ErrorAction SilentlyContinue
    if (-not $functionFile) {
        $functionFile = Get-ChildItem -Path $PrivatePath -Filter "$FunctionName.ps1" -ErrorAction SilentlyContinue
    }

    if ($functionFile) {
        $pesterConfig.CodeCoverage = @{
            Enabled = $true
            Path = @($functionFile.FullName)
            OutputFormat = 'JaCoCo'
        }
    }
}

if($Tag) {
    $pesterConfig.Filter = @{
        Tag = $Tag
    }
    Write-Host "[TEST] Filtering by tag(s): $($Tag -join ', ')" -ForegroundColor Cyan
    Write-Host ""
}

# Create Pester configuration
$config = New-PesterConfiguration -Hashtable $pesterConfig

# Run tests
try {
    $result = Invoke-Pester -Configuration $config

    # Calculate combined results if structural tests were run
    $totalTests = $result.TotalCount
    $totalPassed = $result.PassedCount
    $totalFailed = $result.FailedCount
    $totalSkipped = $result.SkippedCount

    if($structuralResult) {
        $totalTests += $structuralResult.TotalCount
        $totalPassed += $structuralResult.PassedCount
        $totalFailed += $structuralResult.FailedCount
        $totalSkipped += $structuralResult.SkippedCount
    }

    # Display summary
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "Test Summary" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    if($structuralResult) {
        Write-Host "Structural: $($structuralResult.PassedCount)/$($structuralResult.TotalCount) passed" -ForegroundColor Gray
        Write-Host "Functional: $($result.PassedCount)/$($result.TotalCount) passed" -ForegroundColor Gray
        Write-Host "----------------------------------------" -ForegroundColor Cyan
    }
    Write-Host "Total:   $totalTests" -ForegroundColor White
    Write-Host "Passed:  $totalPassed" -ForegroundColor Green
    Write-Host "Failed:  $totalFailed" -ForegroundColor $(if($totalFailed -gt 0) { 'Red' } else { 'Gray' })
    Write-Host "Skipped: $totalSkipped" -ForegroundColor Yellow
    Write-Host "Duration: $($result.Duration)" -ForegroundColor Gray
    Write-Host "========================================" -ForegroundColor Cyan

    # Check for failures in either structural or functional tests
    $hasFailures = $totalFailed -gt 0

    if($hasFailures) {
        Write-Host ""
        Write-Host "Failed tests:" -ForegroundColor Red

        # Show structural test failures if any
        if($structuralResult -and $structuralResult.FailedCount -gt 0) {
            Write-Host "  Structural:" -ForegroundColor Yellow
            foreach($test in $structuralResult.Failed) {
                Write-Host "    - $($test.ExpandedName)" -ForegroundColor Red
                if($test.ErrorRecord) {
                    Write-Host "      $($test.ErrorRecord.Exception.Message)" -ForegroundColor Gray
                }
            }
        }

        # Show functional test failures if any
        if($result.FailedCount -gt 0) {
            Write-Host "  Functional:" -ForegroundColor Yellow
            foreach($test in $result.Failed) {
                Write-Host "    - $($test.ExpandedName)" -ForegroundColor Red
                if($test.ErrorRecord) {
                    Write-Host "      $($test.ErrorRecord.Exception.Message)" -ForegroundColor Gray
                }
            }
        }
    }
    else {
        Write-Host ""
        Write-Host "All tests passed! ✓" -ForegroundColor Green
    }

    # Update Test-Coverage.md
    try {
        $CoverageFilePath = Join-Path -Path $Root -ChildPath "Test-Coverage.md"

        if (Test-Path -Path $CoverageFilePath) {
            Write-Host ""
            Write-Host "Updating Test-Coverage.md..." -ForegroundColor Cyan

            # Read the coverage file
            $coverageContent = Get-Content -Path $CoverageFilePath -Raw

            if ($FunctionName) {
                # Update coverage for a single function

                # Determine status
                $status = "🟢 Passed"
                if ($result.FailedCount -gt 0) {
                    $status = "🔴 Failed"
                }
                elseif ($result.SkippedCount -gt 0 -and $result.PassedCount -gt 0) {
                    $status = "🟡 Partial"
                }

                # Format duration
                $durationMs = [math]::Round($result.Duration.TotalMilliseconds)
                $durationStr = if ($durationMs -lt 1000) { "$($durationMs)ms" } else { "$([math]::Round($result.Duration.TotalSeconds, 2))s" }

                # Calculate code coverage percentage
                $coveragePercent = "-"
                if ($result.CodeCoverage -and $result.CodeCoverage.Count -gt 0) {
                    # CodeCoverage returns strings like "55.1% / 75%"
                    $coverageStr = "$($result.CodeCoverage[0])"
                    if ($coverageStr -match '^([0-9.]+)%') {
                        $coveragePercent = "$($matches[1])%"
                    }
                }

                # Find and replace the row for this function
                $newRow = "| $FunctionName | Test-$FunctionName.Tests.ps1 | $status | $($result.PassedCount) | $($result.FailedCount) | $($result.SkippedCount) | $coveragePercent | $durationStr |"

                # Split content into lines for easier replacement
                $lines = $coverageContent -split "`n"
                $found = $false
                for ($i = 0; $i -lt $lines.Count; $i++) {
                    if ($lines[$i] -match "^\|\s*$([regex]::Escape($FunctionName))\s*\|") {
                        $lines[$i] = $newRow
                        $found = $true
                        break
                    }
                }

                if ($found) {
                    $coverageContent = $lines -join "`n"
                }
                else {
                    # If the function row is not found, append it to the end of the table
                    # Find the table header separator line (like |---|---|)
                    $separatorIndex = -1
                    for ($i = 0; $i -lt $lines.Count; $i++) {
                        if ($lines[$i] -match '^\|\s*[-]+\s*\|') {
                            $separatorIndex = $i
                            break
                        }
                    }

                    if ($separatorIndex -ge 0) {
                        # Find the last table row after the separator (before any non-table content)
                        $lastTableRowIndex = $separatorIndex
                        for ($i = $separatorIndex + 1; $i -lt $lines.Count; $i++) {
                            if ($lines[$i] -match '^\|.+\|$') {
                                $lastTableRowIndex = $i
                            }
                            elseif ($lines[$i].Trim() -eq '') {
                                # Skip empty lines
                                continue
                            }
                            else {
                                # Hit non-table content, stop
                                break
                            }
                        }

                        # Insert after the last table row
                        $beforeInsert = $lines[0..$lastTableRowIndex]
                        $afterInsert = if ($lastTableRowIndex -lt ($lines.Count - 1)) { $lines[($lastTableRowIndex + 1)..($lines.Count - 1)] } else { @() }
                        $lines = $beforeInsert + $newRow + $afterInsert
                    }
                    else {
                        # If no separator line is found, just append to the end
                        $lines += $newRow
                    }
                    $coverageContent = $lines -join "`n"
                }
            }
            else {
                # Update coverage for all functions by parsing test results

                # Extract results from each test file
                foreach ($testFile in $result.TestResult) {
                    # Extract function name from test file path
                    if ($testFile.FileName -match 'Test-(.+)\.Tests\.ps1$') {
                        $functionName = $matches[1]

                        # Group tests by function to get aggregate results
                        $functionTests = @($result.TestResult | Where-Object { $_.FileName -like "*Test-$functionName.Tests.ps1*" })

                        if ($functionTests.Count -gt 0) {
                            $passed = @($functionTests | Where-Object { $_.Result -eq 'Passed' }).Count
                            $failed = @($functionTests | Where-Object { $_.Result -eq 'Failed' }).Count
                            $skipped = @($functionTests | Where-Object { $_.Result -eq 'Skipped' }).Count

                            # Determine status
                            $status = "🟢 Passed"
                            if ($failed -gt 0) {
                                $status = "🔴 Failed"
                            }
                            elseif ($skipped -gt 0 -and $passed -gt 0) {
                                $status = "🟡 Partial"
                            }

                            # Format duration (estimate from test duration)
                            $totalDuration = ($functionTests | Measure-Object -Property Duration -Sum).Sum
                            $durationMs = [math]::Round($totalDuration.TotalMilliseconds)
                            $durationStr = if ($durationMs -lt 1000) { "$($durationMs)ms" } else { "$([math]::Round($totalDuration.TotalSeconds, 2))s" }

                            # Calculate code coverage percentage
                            $coveragePercent = "-"
                            if ($result.CodeCoverage -and $result.CodeCoverage.Count -gt 0) {
                                # CodeCoverage returns strings like "55.1% / 75%"
                                $coverageStr = "$($result.CodeCoverage[0])"
                                if ($coverageStr -match '^([0-9.]+)%') {
                                    $coveragePercent = "$($matches[1])%"
                                }
                            }

                            # Find and replace the row
                            $newRow = "| $functionName | $status | $passed | $failed | $skipped | $coveragePercent | $durationStr |"

                            # Split content into lines for easier replacement
                            $lines = $coverageContent -split "`n"
                            for ($i = 0; $i -lt $lines.Count; $i++) {
                                if ($lines[$i] -match "^\|\s*$([regex]::Escape($functionName))\s*\|") {
                                    $lines[$i] = $newRow
                                    $coverageContent = $lines -join "`n"
                                    break
                                }
                            }
                        }
                    }
                }
            }

            # Update the "Last Updated" timestamp
            $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            $lines = $coverageContent -split "`n"
            for ($i = 0; $i -lt $lines.Count; $i++) {
                if ($lines[$i] -match "^\*\*Last Updated:\*\*") {
                    $lines[$i] = "**Last Updated:** $timestamp"
                    break
                }
            }
            $coverageContent = $lines -join "`n"

            # Write back to the file
            Set-Content -Path $CoverageFilePath -Value $coverageContent

            Write-Host "Test-Coverage.md updated successfully!" -ForegroundColor Green
        }
    }
    catch {
        Write-Warning "Failed to update Test-Coverage.md: $_"
    }

    # Return result object if requested
    if($PassThru) {
        # Combine results
        $combinedResult = $result
        if($structuralResult) {
            Add-Member -InputObject $combinedResult -NotePropertyName 'StructuralResult' -NotePropertyValue $structuralResult -Force
        }
        return $combinedResult
    }

    # Exit with appropriate code
    if($hasFailures) {
        exit 1
    }
    else {
        exit 0
    }
}
catch {
    Write-Error "Failed to run tests: $_"
    exit 1
}
