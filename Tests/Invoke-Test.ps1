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

.PARAMETER PSVersion
    Which PowerShell version(s) to run tests in.
    'Current' runs only in the current session.
    'Both' runs in both PowerShell 7.x and 5.1 (default).
    '5.1' runs only in PowerShell 5.1 via subprocess.

.EXAMPLE
    .\Invoke-Test.ps1 -FunctionName "Get-CM7Collection" -PSVersion Both
    Run tests in both PowerShell 7.x and 5.1.

.EXAMPLE
    .\Invoke-Test.ps1 -FunctionName "Get-CM7Collection" -PSVersion Current
    Run tests only in the current PowerShell version.

.EXAMPLE
    .\Invoke-Test.ps1 -PSVersion 5.1
    Run all functional tests only in PowerShell 5.1 (via subprocess).

.NOTES
    This script requires Pester 5.2.2 or higher.
    When using -PSVersion Both, PowerShell 5.1 tests run in a subprocess via powershell.exe.
    Pester 5.2.2+ must be installed in both PowerShell versions for dual-version testing.
#>
[CmdletBinding()]
param(
    [Parameter(Position=0)]
    [ArgumentCompleter({
        param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
        # Resolve the Tests folder from the script being invoked
        $scriptFile = $commandAst.CommandElements[0].Value
        if ($scriptFile) {
            $resolved = Resolve-Path $scriptFile -ErrorAction SilentlyContinue
            if ($resolved) { $testsPath = Split-Path -Parent $resolved }
        }
        if (-not $testsPath) { $testsPath = $PSScriptRoot }
        if (-not $testsPath) { $testsPath = $PWD.Path }
        Get-ChildItem -Path $testsPath -Filter "Test-*.Tests.ps1" -ErrorAction SilentlyContinue |
            ForEach-Object { $_.Name -replace '^Test-(.+)\.Tests\.ps1$', '$1' } |
            Where-Object { $_ -like "$wordToComplete*" } |
            Sort-Object |
            ForEach-Object {
                [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
            }
    })]
    [ValidateScript({
        if ([string]::IsNullOrEmpty($_)) { return $true }
        $testsPath = $PSScriptRoot
        if (-not $testsPath) { $testsPath = Split-Path -Parent $PSCommandPath }
        $testFile = Join-Path $testsPath "Test-$_.Tests.ps1"
        if (Test-Path $testFile) { return $true }
        $available = (Get-ChildItem -Path $testsPath -Filter "Test-*.Tests.ps1" -ErrorAction SilentlyContinue |
            ForEach-Object { $_.Name -replace '^Test-(.+)\.Tests\.ps1$', '$1' } |
            Sort-Object) -join ', '
        throw "Test file 'Test-$_.Tests.ps1' not found. Available: $available"
    })]
    [string]$FunctionName,

    [Parameter()]
    [string[]]$Tag,

    [Parameter()]
    [ValidateSet('None', 'Normal', 'Detailed', 'Diagnostic')]
    [string]$Output = 'Detailed',

    [Parameter()]
    [switch]$PassThru,

    [Parameter()]
    [switch]$IncludeStructuralTests,

    [Parameter()]
    [ValidateSet('Current', 'Both', '5.1')]
    [string]$PSVersion = 'Both',

    # Internal parameters for subprocess mode (cross-version testing)
    [Parameter(DontShow)]
    [switch]$SubprocessMode,

    [Parameter(DontShow)]
    [string]$ResultFile
)

#region Subprocess Mode - used for cross-version testing
if ($SubprocessMode) {
    # Minimal execution mode for testing in a different PowerShell version
    # Results are exported as JSON to $ResultFile
    if ((Get-Module -Name Pester).Version -match '^3\.\d{1}\.\d{1}') {
        try { Remove-Module -Name Pester -ErrorAction Stop } catch {}
    }
    if (-not (Get-Module -Name Pester -ListAvailable | Where-Object { $_.Version -ge '5.2.2' })) {
        @{
            Error     = "Pester 5.2.2+ not available in PowerShell $($PSVersionTable.PSVersion)"
            PSVersion = $PSVersionTable.PSVersion.ToString()
        } | ConvertTo-Json -Depth 3 | Set-Content -Path $ResultFile -Encoding UTF8
        exit 1
    }
    Import-Module -Name Pester -MinimumVersion 5.2.2 -ErrorAction Stop

    $TestsPath = $PSScriptRoot
    $Root = (Get-Item $TestsPath).Parent.FullName
    $DeclarationsPath = Join-Path -Path $TestsPath -ChildPath "declarations.ps1"
    if (Test-Path -Path $DeclarationsPath) { . $DeclarationsPath }

    # Handle comma-joined tags from -File parameter passing
    if ($Tag) {
        $Tag = @($Tag | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    }

    $subTestFiles = @()
    if ($FunctionName) {
        $subTestFile = Join-Path -Path $TestsPath -ChildPath "Test-$FunctionName.Tests.ps1"
        if (-not (Test-Path $subTestFile)) {
            @{
                Error     = "Test file not found: Test-$FunctionName.Tests.ps1"
                PSVersion = $PSVersionTable.PSVersion.ToString()
            } | ConvertTo-Json -Depth 3 | Set-Content -Path $ResultFile -Encoding UTF8
            exit 1
        }
        $subTestFiles = @($subTestFile)
    }
    else {
        $subTestFiles = @(Get-ChildItem -Path $TestsPath -Filter "Test-*.Tests.ps1" -ErrorAction SilentlyContinue)
    }

    $subPesterConfig = @{
        Run    = @{ Path = $subTestFiles; PassThru = $true }
        Output = @{ Verbosity = 'None' }
    }

    if ($FunctionName) {
        $subCodePath = Join-Path -Path $Root -ChildPath "Code"
        $subPublicPath = Join-Path $subCodePath -ChildPath 'Public'
        $subPrivatePath = Join-Path $subCodePath -ChildPath 'Private'
        $subFuncFile = Get-ChildItem -Path $subPublicPath -Filter "$FunctionName.ps1" -ErrorAction SilentlyContinue
        if (-not $subFuncFile) {
            $subFuncFile = Get-ChildItem -Path $subPrivatePath -Filter "$FunctionName.ps1" -ErrorAction SilentlyContinue
        }
        if ($subFuncFile) {
            $subPesterConfig.CodeCoverage = @{
                Enabled      = $true
                Path         = @($subFuncFile.FullName)
                OutputFormat = 'JaCoCo'
            }
        }
    }

    if ($Tag) { $subPesterConfig.Filter = @{ Tag = $Tag } }

    $subConfig = New-PesterConfiguration -Hashtable $subPesterConfig

    try {
        $subResult = Invoke-Pester -Configuration $subConfig

        $subCoveragePercent = "-"
        if ($subResult.CodeCoverage -and $subResult.CodeCoverage.Count -gt 0) {
            $subCoverageStr = "$($subResult.CodeCoverage[0])"
            if ($subCoverageStr -match '([0-9.]+)%') {
                $subCoveragePercent = "$($matches[1])%"
            }
        }

        $failedTestsList = @()
        foreach ($ft in $subResult.Failed) {
            $failedMsg = ''
            if ($ft.ErrorRecord) { $failedMsg = $ft.ErrorRecord.Exception.Message }
            $failedTestsList += @{
                Name    = $ft.ExpandedName
                Message = $failedMsg
            }
        }

        @{
            PSVersion       = $PSVersionTable.PSVersion.ToString()
            TotalCount      = $subResult.TotalCount
            PassedCount     = $subResult.PassedCount
            FailedCount     = $subResult.FailedCount
            SkippedCount    = $subResult.SkippedCount
            DurationMs      = [math]::Round($subResult.Duration.TotalMilliseconds)
            CoveragePercent = $subCoveragePercent
            FailedTests     = $failedTestsList
        } | ConvertTo-Json -Depth 5 | Set-Content -Path $ResultFile -Encoding UTF8
    }
    catch {
        @{
            Error     = "Test execution failed: $_"
            PSVersion = $PSVersionTable.PSVersion.ToString()
        } | ConvertTo-Json -Depth 3 | Set-Content -Path $ResultFile -Encoding UTF8
        exit 1
    }

    exit 0
}
#endregion

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
                            # Robustly parse the comment-based help block for .PARAMETER documentation
                            $functionSource = $Ast.Extent.Text
                            $paramName = $_
                            $paramPattern = "\.PARAMETER\s+$paramName([\r\n]+.+?)+(?=\r\n\.|\r\n\#|\r\n\S|$)"
                            $paramRegex = [regex]::new($paramPattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase -bor [System.Text.RegularExpressions.RegexOptions]::Singleline)
                            $match = $paramRegex.Match($functionSource)
                            $hasDoc = $match.Success -and ($match.Value -match "\S{3,}") # Require at least 3 non-whitespace chars
                            $hasDoc | Should -Be $true -Because "Parameter '$paramName' must have .PARAMETER documentation in the comment-based help block."
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

                            if ( ( $Declaration -notmatch $VariableTypeEscaped ) -and ( $Declaration -notmatch $VariableTypeFullEscaped ) ) {
                                Write-Host "`nParameter '$currentParam' declaration:" -ForegroundColor Red
                                Write-Host "  $Declaration" -ForegroundColor Yellow
                                Write-Host "Expected type: $VariableType or $VariableTypeFull" -ForegroundColor Cyan
                            }

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

# Detect PowerShell version for dual-version testing
$isPS7 = $PSVersionTable.PSVersion.Major -ge 6
$currentPSLabel = "PowerShell $($PSVersionTable.PSVersion.Major).$($PSVersionTable.PSVersion.Minor)"
$runInCurrent = ($PSVersion -eq 'Current') -or ($PSVersion -eq 'Both')
$runInPS51 = ($PSVersion -eq 'Both') -or ($PSVersion -eq '5.1')

# If already in PS 5.1 and -PSVersion is '5.1', run in current session
if (-not $isPS7 -and $PSVersion -eq '5.1') {
    $runInCurrent = $true
    $runInPS51 = $false
}

# If in PS 7.x and -PSVersion is '5.1', skip current session (only subprocess)
if ($isPS7 -and $PSVersion -eq '5.1') {
    $runInCurrent = $false
}

Write-Host "[TEST] Current session: $currentPSLabel" -ForegroundColor Cyan
if ($runInCurrent) { Write-Host "[TEST] Will test in: $currentPSLabel" -ForegroundColor Gray }
if ($runInPS51 -and $isPS7) { Write-Host "[TEST] Will test in: PowerShell 5.1 (subprocess)" -ForegroundColor Gray }
Write-Host ""

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
    $currentResult = $null
    $ps51ResultData = $null

    # ==================== Run in current PowerShell version ====================
    if ($runInCurrent) {
        Write-Host ""
        Write-Host "========================================" -ForegroundColor Blue
        Write-Host "Running Functional Tests in $currentPSLabel" -ForegroundColor Blue
        Write-Host "========================================" -ForegroundColor Blue
        Write-Host ""

        $currentResult = Invoke-Pester -Configuration $config
    }

    # ==================== Run in PowerShell 5.1 (subprocess) ====================
    if ($runInPS51 -and $isPS7) {
        Write-Host ""
        Write-Host "========================================" -ForegroundColor Magenta
        Write-Host "Running Functional Tests in PowerShell 5.1" -ForegroundColor Magenta
        Write-Host "========================================" -ForegroundColor Magenta
        Write-Host ""

        $ps51Exe = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
        if (-not (Test-Path $ps51Exe)) {
            Write-Warning "Windows PowerShell 5.1 not found at: $ps51Exe"
        }
        else {
            $tempResultFile = [System.IO.Path]::GetTempFileName()
            try {
                $scriptPath = $MyInvocation.MyCommand.Path
                if (-not $scriptPath) {
                    $scriptPath = Join-Path $TestsPath 'Invoke-Test.ps1'
                }

                Write-Host "[TEST] Launching PowerShell 5.1 subprocess..." -ForegroundColor Gray
                Write-Host ""

                $subArgs = @(
                    '-NoProfile'
                    '-ExecutionPolicy'
                    'Bypass'
                    '-File'
                    $scriptPath
                    '-SubprocessMode'
                    '-ResultFile'
                    $tempResultFile
                )
                if ($FunctionName) { $subArgs += @('-FunctionName', $FunctionName) }
                if ($Tag) { $subArgs += @('-Tag', ($Tag -join ',')) }

                & $ps51Exe @subArgs 2>&1 | ForEach-Object {
                    if ($_ -is [System.Management.Automation.ErrorRecord]) {
                        Write-Host "  PS 5.1 ERROR: $_" -ForegroundColor Red
                    }
                }

                if (Test-Path $tempResultFile) {
                    $jsonContent = Get-Content -Path $tempResultFile -Raw
                    if ($jsonContent) {
                        $ps51ResultData = $jsonContent | ConvertFrom-Json
                        if ($ps51ResultData.Error) {
                            Write-Warning "PowerShell 5.1: $($ps51ResultData.Error)"
                            $ps51ResultData = $null
                        }
                    }
                }
                else {
                    Write-Warning "No result file produced by PowerShell 5.1 subprocess"
                }
            }
            catch {
                Write-Warning "Failed to run tests in PowerShell 5.1: $_"
            }
            finally {
                if (Test-Path $tempResultFile) {
                    Remove-Item $tempResultFile -Force -ErrorAction SilentlyContinue
                }
            }
        }
    }

    # ==================== Calculate combined results ====================
    $totalTests = 0
    $totalPassed = 0
    $totalFailed = 0
    $totalSkipped = 0

    if ($structuralResult) {
        $totalTests += $structuralResult.TotalCount
        $totalPassed += $structuralResult.PassedCount
        $totalFailed += $structuralResult.FailedCount
        $totalSkipped += $structuralResult.SkippedCount
    }

    if ($currentResult) {
        $totalTests += $currentResult.TotalCount
        $totalPassed += $currentResult.PassedCount
        $totalFailed += $currentResult.FailedCount
        $totalSkipped += $currentResult.SkippedCount
    }

    if ($ps51ResultData) {
        $totalTests += $ps51ResultData.TotalCount
        $totalPassed += $ps51ResultData.PassedCount
        $totalFailed += $ps51ResultData.FailedCount
        $totalSkipped += $ps51ResultData.SkippedCount
    }

    # Display summary
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "Test Summary" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan

    if ($structuralResult) {
        Write-Host "Structural:      Passed $($structuralResult.PassedCount)/$($structuralResult.TotalCount)" -ForegroundColor Gray
    }

    if ($currentResult) {
        $currentDuration = $currentResult.Duration
        $currentColor = if ($currentResult.FailedCount -gt 0) { 'Yellow' } else { 'Gray' }
        Write-Host "${currentPSLabel}:  Passed $($currentResult.PassedCount)/$($currentResult.TotalCount) | Failed $($currentResult.FailedCount) | Skipped $($currentResult.SkippedCount) | Duration $currentDuration" -ForegroundColor $currentColor
    }

    if ($ps51ResultData) {
        $ps51DurMs = $ps51ResultData.DurationMs
        $ps51DurationStr = if ($ps51DurMs -lt 1000) { "${ps51DurMs}ms" } else { "$([math]::Round($ps51DurMs / 1000, 2))s" }
        $ps51Color = if ($ps51ResultData.FailedCount -gt 0) { 'Yellow' } else { 'Gray' }
        Write-Host "PowerShell 5.1:  Passed $($ps51ResultData.PassedCount)/$($ps51ResultData.TotalCount) | Failed $($ps51ResultData.FailedCount) | Skipped $($ps51ResultData.SkippedCount) | Duration $ps51DurationStr" -ForegroundColor $ps51Color
    }

    Write-Host "----------------------------------------" -ForegroundColor Cyan
    Write-Host "Total:   $totalTests" -ForegroundColor White
    Write-Host "Passed:  $totalPassed" -ForegroundColor Green
    Write-Host "Failed:  $totalFailed" -ForegroundColor $(if($totalFailed -gt 0) { 'Red' } else { 'Gray' })
    Write-Host "Skipped: $totalSkipped" -ForegroundColor Yellow
    Write-Host "========================================" -ForegroundColor Cyan

    # Check for failures across all test runs
    $hasFailures = $totalFailed -gt 0

    if ($hasFailures) {
        Write-Host ""
        Write-Host "Failed tests:" -ForegroundColor Red

        if ($structuralResult -and $structuralResult.FailedCount -gt 0) {
            Write-Host "  Structural:" -ForegroundColor Yellow
            foreach ($test in $structuralResult.Failed) {
                Write-Host "    - $($test.ExpandedName)" -ForegroundColor Red
                if ($test.ErrorRecord) {
                    Write-Host "      $($test.ErrorRecord.Exception.Message)" -ForegroundColor Gray
                }
            }
        }

        if ($currentResult -and $currentResult.FailedCount -gt 0) {
            Write-Host "  ${currentPSLabel}:" -ForegroundColor Yellow
            foreach ($test in $currentResult.Failed) {
                Write-Host "    - $($test.ExpandedName)" -ForegroundColor Red
                if ($test.ErrorRecord) {
                    Write-Host "      $($test.ErrorRecord.Exception.Message)" -ForegroundColor Gray
                }
            }
        }

        if ($ps51ResultData -and $ps51ResultData.FailedCount -gt 0 -and $ps51ResultData.FailedTests) {
            Write-Host "  PowerShell 5.1:" -ForegroundColor Yellow
            foreach ($ft in $ps51ResultData.FailedTests) {
                Write-Host "    - $($ft.Name)" -ForegroundColor Red
                if ($ft.Message) {
                    Write-Host "      $($ft.Message)" -ForegroundColor Gray
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

            $coverageContent = Get-Content -Path $CoverageFilePath -Raw
            $lines = @($coverageContent -split "`n")

            # Helper function: update or insert a row in a specific section table, then sort rows
            function Update-CoverageSection {
                param(
                    [string[]]$FileLines,
                    [string]$SectionHeader,
                    [string]$NewRow,
                    [string]$FuncName
                )

                # Find section header
                $sectionIdx = -1
                $escapedHeader = [regex]::Escape($SectionHeader)
                for ($i = 0; $i -lt $FileLines.Count; $i++) {
                    if ($FileLines[$i].TrimEnd() -match "^${escapedHeader}\s*$") {
                        $sectionIdx = $i
                        break
                    }
                }
                if ($sectionIdx -lt 0) { return $FileLines }

                # Find table separator (|---|---|...)
                $separatorIdx = -1
                for ($i = $sectionIdx + 1; $i -lt $FileLines.Count; $i++) {
                    if ($FileLines[$i] -match '^\|\s*[-:]+\s*\|') {
                        $separatorIdx = $i
                        break
                    }
                    if ($FileLines[$i] -match '^##') { break }
                }
                if ($separatorIdx -lt 0) { return $FileLines }

                # Collect data rows and find table boundaries
                $dataRows = [System.Collections.ArrayList]@()
                $tableEndIdx = $separatorIdx
                for ($i = $separatorIdx + 1; $i -lt $FileLines.Count; $i++) {
                    $trimmed = $FileLines[$i].TrimEnd()
                    if ($trimmed -match '^\|.+\|$') {
                        [void]$dataRows.Add($trimmed)
                        $tableEndIdx = $i
                    }
                    elseif ($trimmed -eq '') {
                        continue
                    }
                    else {
                        break
                    }
                }

                # Update existing row or add new one
                $escapedFn = [regex]::Escape($FuncName)
                $rowFound = $false
                for ($j = 0; $j -lt $dataRows.Count; $j++) {
                    if ($dataRows[$j] -match "^\|\s*${escapedFn}\s*\|") {
                        $dataRows[$j] = $NewRow
                        $rowFound = $true
                        break
                    }
                }
                if (-not $rowFound) { [void]$dataRows.Add($NewRow) }

                # Sort rows alphabetically by function name (first column)
                $sortedRows = @($dataRows | Sort-Object {
                    if ($_ -match '^\|\s*([^\|]+?)\s*\|') { $matches[1].Trim() } else { $_ }
                })

                # Reconstruct file lines
                $newLines = @()
                $newLines += $FileLines[0..$separatorIdx]
                $newLines += $sortedRows
                if ($tableEndIdx -lt ($FileLines.Count - 1)) {
                    $newLines += $FileLines[($tableEndIdx + 1)..($FileLines.Count - 1)]
                }

                return $newLines
            }

            # Helper: determine test status emoji
            function Get-TestStatusText {
                param([int]$PassedCount, [int]$FailedCount, [int]$SkippedCount)
                if ($FailedCount -gt 0) { return "🔴 Failed" }
                if ($SkippedCount -gt 0 -and $PassedCount -gt 0) { return "🟡 Partial" }
                if ($PassedCount -gt 0) { return "🟢 Passed" }
                return "⏳ Not Run"
            }

            # Helper: format duration
            function Format-TestDuration {
                param([double]$Milliseconds)
                if ($Milliseconds -lt 1000) { return "$([math]::Round($Milliseconds))ms" }
                return "$([math]::Round($Milliseconds / 1000, 2))s"
            }

            # Determine which section headers to update based on PS version
            $currentSectionHeader = if ($isPS7) { "## PowerShell 7.x" } else { "## PowerShell 5.1" }

            if ($FunctionName) {
                $testFileName = "Test-$FunctionName.Tests.ps1"

                # Update current PS version table
                if ($currentResult) {
                    $status = Get-TestStatusText -PassedCount $currentResult.PassedCount -FailedCount $currentResult.FailedCount -SkippedCount $currentResult.SkippedCount
                    $durationStr = Format-TestDuration -Milliseconds $currentResult.Duration.TotalMilliseconds

                    $coveragePercent = "-"
                    if ($currentResult.CodeCoverage -and $currentResult.CodeCoverage.Count -gt 0) {
                        $coverageStr = "$($currentResult.CodeCoverage[0])"
                        if ($coverageStr -match '([0-9.]+)%') {
                            $coveragePercent = "$($matches[1])%"
                        }
                    }

                    $newRow = "| $FunctionName | $status | $($currentResult.PassedCount) | $($currentResult.FailedCount) | $($currentResult.SkippedCount) | $coveragePercent | $durationStr |"
                    $lines = Update-CoverageSection -FileLines $lines -SectionHeader $currentSectionHeader -NewRow $newRow -FuncName $FunctionName
                }

                # Update PowerShell 5.1 table (from subprocess results)
                if ($ps51ResultData -and -not $ps51ResultData.Error) {
                    $status = Get-TestStatusText -PassedCount $ps51ResultData.PassedCount -FailedCount $ps51ResultData.FailedCount -SkippedCount $ps51ResultData.SkippedCount
                    $durationStr = Format-TestDuration -Milliseconds $ps51ResultData.DurationMs
                    $coveragePercent = if ($ps51ResultData.CoveragePercent -and $ps51ResultData.CoveragePercent -ne '-') { $ps51ResultData.CoveragePercent } else { "-" }

                    $newRow = "| $FunctionName | $status | $($ps51ResultData.PassedCount) | $($ps51ResultData.FailedCount) | $($ps51ResultData.SkippedCount) | $coveragePercent | $durationStr |"
                    $lines = Update-CoverageSection -FileLines $lines -SectionHeader "## PowerShell 5.1" -NewRow $newRow -FuncName $FunctionName
                }
            }

            # Update the "Last Updated" timestamp
            $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            for ($i = 0; $i -lt $lines.Count; $i++) {
                if ($lines[$i] -match "^\*\*Last Updated:\*\*") {
                    $lines[$i] = "**Last Updated:** $timestamp"
                    break
                }
            }

            # Write back to the file
            $coverageContent = ($lines -join "`n").TrimEnd("`r", "`n")
            [System.IO.File]::WriteAllText($CoverageFilePath, $coverageContent + "`n")

            Write-Host "Test-Coverage.md updated successfully!" -ForegroundColor Green
        }
    }
    catch {
        Write-Warning "Failed to update Test-Coverage.md: $_"
    }

    # Return result object if requested
    if ($PassThru) {
        $combinedResult = [PSCustomObject]@{
            CurrentVersion = $currentResult
            PS51           = $ps51ResultData
            Structural     = $structuralResult
        }
        return $combinedResult
    }

    # Exit with appropriate code
    if ($hasFailures) {
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
