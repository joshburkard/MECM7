#region prepare folders
$Current          = (Split-Path -Path $MyInvocation.MyCommand.Path)
$Root             = ((Get-Item $Current).Parent).FullName
$CodeSourcePath   = Join-Path -Path $Root -ChildPath "Code"
$PublicFunctions  = Join-Path $CodeSourcePath -ChildPath 'Public'
$PrivateFunctions = Join-Path $CodeSourcePath -ChildPath 'Private'
$CISourcePath     = Join-Path -Path $Root -ChildPath "CI"
$Settings         = Join-Path -Path $CISourcePath -ChildPath "Module-Settings.json"
#endregion

#region Module-Settings
if([String]::IsNullOrEmpty($ModulePrefix)){
    $ModuleSettings = Get-content -Path $Settings | ConvertFrom-Json
    $ModulePrefix   = $ModuleSettings.ModulePrefix
}
$CommonPrefix = $ModulePrefix
#endregion

#region Load Test Declarations
$DeclarationsPath = Join-Path -Path $Current -ChildPath "declarations.ps1"
if(Test-Path -Path $DeclarationsPath){
    Write-Host "[TEST] Loading test declarations from declarations.ps1" -ForegroundColor Green
    . $DeclarationsPath
}
else{
    Write-Warning "[TEST] declarations.ps1 not found. Please copy declarations_sample.ps1 to declarations.ps1 and configure your test values."
    Write-Warning "[TEST] Integration tests will be skipped."
}
#endregion

BeforeDiscovery {
    $CodeFile = @()
    $CodeFile += Get-ChildItem -Path $PublicFunctions  -Filter "*.ps1"
    $CodeFile += Get-ChildItem -Path $PrivateFunctions -Filter "*.ps1"

    # Gather git-tracked files for sensitive value check
    $script:TrackedFiles = @()
    try {
        Push-Location -Path $Root
        $gitFiles = git ls-files --cached 2>$null
        if ($gitFiles) {
            $script:TrackedFiles = $gitFiles | Where-Object {
                $_ -match '\.(ps1|psm1|psd1|md|txt|xml|json|yml|yaml|csv)$'
            } | ForEach-Object { Join-Path -Path $Root -ChildPath $_ } | Where-Object { Test-Path $_ }
        }
    }
    catch {
        Write-Warning "Could not enumerate git-tracked files: $_"
    }
    finally {
        Pop-Location
    }

    # Build sensitive string values to check (exclude empty/null and PSCredential objects)
    $script:SensitiveStringsToCheck = @()
    if ($SensitiveValues) {
        foreach ($val in $SensitiveValues) {
            if ($null -eq $val) { continue }
            if ($val -is [System.Management.Automation.PSCredential]) {
                # Extract username and password string from credential
                $uname = $val.UserName
                $pword = $val.GetNetworkCredential().Password
                if (-not [string]::IsNullOrWhiteSpace($uname)) { $script:SensitiveStringsToCheck += $uname }
                if (-not [string]::IsNullOrWhiteSpace($pword)) { $script:SensitiveStringsToCheck += $pword }
            }
            elseif ($val -is [string] -and -not [string]::IsNullOrWhiteSpace($val)) {
                $script:SensitiveStringsToCheck += $val
            }
            else {
                $strVal = "$val"
                if (-not [string]::IsNullOrWhiteSpace($strVal)) { $script:SensitiveStringsToCheck += $strVal }
            }
        }
        # Deduplicate
        $script:SensitiveStringsToCheck = @($script:SensitiveStringsToCheck | Select-Object -Unique)
    }
}

foreach($file in $CodeFile){

    . ($file.FullName)

    #region variable
    $ScriptName = $file.BaseName
    $Verb = @( $($ScriptName) -split '-' )[0]

    try {
        $FunctionPrefix = @( $ScriptName -split '-' )[1].Substring( 0, $CommonPrefix.Length )
    }
    catch {
        $FunctionPrefix = @( $ScriptName -split '-' )[1]
    }

    $DetailedHelp  = Get-Help $ScriptName -Detailed
    $ScriptCommand = Get-Command -Name $ScriptName -All
    $Ast           = $ScriptCommand.ScriptBlock.Ast
    #endregion

    Describe "Test Code-file $($file.Name)" {

        Context "Naming of $($file.BaseName)" {

            It "$ScriptName should have an approved verb -> $Verb" -TestCases @{ Verb = $Verb} {
                ( $Verb -in @( Get-Verb ).Verb ) | Should -BeTrue
            }

            It "$ScriptName Noun should have the Prefix '$($CommonPrefix)'" -TestCases @{ FunctionPrefix = $FunctionPrefix; CommonPrefix = $CommonPrefix } {
                $FunctionPrefix | Should -Be $CommonPrefix
            }

        }

        Context "Synopsis of $($file.BaseName)" {

            It "$ScriptName should have a SYNOPSIS" -TestCases @{ Ast = $Ast } {
                ( $Ast.Extent.Text -match 'SYNOPSIS' ) | Should -BeTrue
            }

            It "$ScriptName should have a DESCRIPTION" -TestCases @{ Ast = $Ast } {
                ( $Ast.Extent.Text -match 'DESCRIPTION' ) | Should -BeTrue
            }

            It "$ScriptName should have a EXAMPLE" -TestCases @{ Ast = $Ast } {
                ( $Ast.Extent.Text -match 'EXAMPLE' ) | Should -BeTrue
            }

        }

        Context "CIM Compatibility of $($file.BaseName) (no legacy WMI commands)" {

            # Legacy WMI cmdlets that are not available in PowerShell 7.x
            $wmiCmdlets = @( 'Get-WmiObject', 'Set-WmiInstance', 'Remove-WmiObject', 'Invoke-WmiMethod', 'Register-WmiEvent' )
            $wmiAliases = @( 'gwmi', 'swmi', 'rwmi' )
            $wmiTypeAccelerators = @( 'WMI', 'WMIClass', 'WMISearcher' )
            $sourceText = $Ast.Extent.Text

            foreach ($cmdlet in $wmiCmdlets) {
                It "$ScriptName should not use legacy WMI cmdlet '$cmdlet'" -TestCases @{ sourceText = $sourceText; cmdlet = $cmdlet } {
                    $sourceText -match "\b$([regex]::Escape($cmdlet))\b" | Should -BeFalse -Because "'$cmdlet' is not available in PowerShell 7.x. Use the CIM equivalent instead."
                }
            }

            foreach ($alias in $wmiAliases) {
                It "$ScriptName should not use legacy WMI alias '$alias'" -TestCases @{ Ast = $Ast; alias = $alias } {
                    $commandAsts = @( $Ast.FindAll( { param($node) $node -is [System.Management.Automation.Language.CommandAst] }, $true ) )
                    $usesAlias = $commandAsts | Where-Object { $_.GetCommandName() -eq $alias }
                    $usesAlias | Should -BeNullOrEmpty -Because "Alias '$alias' maps to a legacy WMI cmdlet not available in PowerShell 7.x."
                }
            }

            foreach ($typeAcc in $wmiTypeAccelerators) {
                It "$ScriptName should not use legacy WMI type accelerator '[$typeAcc]'" -TestCases @{ Ast = $Ast; typeAcc = $typeAcc } {
                    $typeAsts = @( $Ast.FindAll( { param($node) $node -is [System.Management.Automation.Language.TypeExpressionAst] -or $node -is [System.Management.Automation.Language.TypeConstraintAst] }, $true ) )
                    $usesType = $typeAsts | Where-Object { $_.TypeName.Name -eq $typeAcc }
                    $usesType | Should -BeNullOrEmpty -Because "Type accelerator '[$typeAcc]' is a legacy WMI type not available in PowerShell 7.x. Use CIM classes instead."
                }
            }
        }

        Context "Sensitive Value Leakage in $($file.BaseName)" {

            It "$($file.Name) should not contain any sensitive values from declarations" -TestCases @{ file = $file; SensitiveStringsToCheck = $script:SensitiveStringsToCheck } {
                if ($SensitiveStringsToCheck.Count -eq 0) {
                    Set-ItResult -Skipped -Because 'No sensitive values defined in declarations.ps1 (all empty or not loaded)'
                    return
                }

                $content = Get-Content -Path $file.FullName -Raw
                $foundValues = @()
                foreach ($sensitive in $SensitiveStringsToCheck) {
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
                    Write-Host "`nSensitive values detected in $($file.Name):" -ForegroundColor Red
                    Write-Host $detailMsg -ForegroundColor Yellow
                }
                $foundValues | Should -BeNullOrEmpty -Because "Code files tracked by git must not contain sensitive values.`nDetected values:`n$( ($foundValues | ForEach-Object { '  -> ' + $_ }) -join "`n" )"
            }
        }

        Context "Parameters of $($file.BaseName)" {

            It "$($file.Name) should have a function named $($file.BaseName)" -TestCases @{ Ast = $Ast; ScriptName = $ScriptName } {
                ($Ast.Extent.Text -match "function $ScriptName") | Should -be $true
            }

            It "$ScriptName should have a CmdletBinding" -TestCases @{ Ast = $Ast } {
                [boolean]( @( $Ast.FindAll( { $true } , $true ) ) | Where-Object { $_.TypeName.Name -eq 'cmdletbinding' } ) | Should -Be $true
            }

            $DefaultParams = @( 'Verbose', 'Debug', 'ErrorAction', 'WarningAction', 'InformationAction', 'ErrorVariable', 'WarningVariable', 'InformationVariable', 'OutVariable', 'OutBuffer', 'PipelineVariable', 'ProgressAction')
            foreach ( $p in @( $ScriptCommand.Parameters.Keys | Where-Object { $_ -notin $DefaultParams } | Sort-Object ) ) {

                It "$ScriptName the Help-text for paramater '$( $p )' should exist" {
                    ( $p -in $DetailedHelp.parameters.parameter.name ) | Should -Be $true
                }
                $Declaration = ( ( @( $Ast.FindAll( { $true } , $true ) ) | Where-Object { $_.Name.Extent.Text -eq "$('$')$p" } ).Extent.Text -replace 'INT32', 'INT' )
                #$VariableType = ( "\[$( $ScriptCommand.Parameters."$p".ParameterType.Name )\]" -replace 'INT32', 'INT' )
                $VariableTypeFull = "\[$( $ScriptCommand.Parameters."$p".ParameterType.FullName )\]"
                $VariableType = $ScriptCommand.Parameters."$p".ParameterType.Name
                $VariableType = $VariableType -replace 'INT32', 'INT'
                $VariableType = $VariableType -replace 'Int64', 'long'
                $VariableType = $VariableType -replace 'String\[\]', 'String'
                $VariableType = $VariableType -replace 'SwitchParameter', 'Switch'

                # Escape regex special characters in type names (e.g., [] in array types)
                $VariableTypeEscaped = [regex]::Escape($VariableType)
                $VariableTypeFullEscaped = [regex]::Escape($VariableTypeFull)

                It "$ScriptName type '[$( $ScriptCommand.Parameters."$p".ParameterType.Name )]' should be declared for parameter '$( $p )'" {
                    ( ( $Declaration -match $VariableTypeEscaped ) -or ( $Declaration -match $VariableTypeFullEscaped ) ) | Should -Be $true
                }
            }

        }
    }

}

# ============================================================================
# Sensitive Values Leakage Check - All Git-Tracked Files
# ============================================================================
Describe "Sensitive Value Leakage Check across all git-tracked files" -Tag "Security" {

    Context "No sensitive values in git-tracked files" {

        It "Should have sensitive values defined for testing" {
            if ($script:SensitiveStringsToCheck.Count -eq 0) {
                Set-ItResult -Skipped -Because 'No sensitive values defined in declarations.ps1 (all empty or not loaded)'
                return
            }
            $script:SensitiveStringsToCheck.Count | Should -BeGreaterThan 0
        }

        It "Should have git-tracked files to scan" {
            if ($script:TrackedFiles.Count -eq 0) {
                Set-ItResult -Skipped -Because 'Could not enumerate git-tracked files (not a git repository or git not available)'
                return
            }
            $script:TrackedFiles.Count | Should -BeGreaterThan 0
        }

        It "No git-tracked file should contain sensitive values" -TestCases @{ TrackedFiles = $script:TrackedFiles; SensitiveStringsToCheck = $script:SensitiveStringsToCheck } {
            if ($SensitiveStringsToCheck.Count -eq 0 -or $TrackedFiles.Count -eq 0) {
                Set-ItResult -Skipped -Because 'No sensitive values or no git-tracked files to scan'
                return
            }

            $violations = @()
            foreach ($filePath in $TrackedFiles) {
                $content = Get-Content -Path $filePath -Raw -ErrorAction SilentlyContinue
                if ([string]::IsNullOrEmpty($content)) { continue }

                foreach ($sensitive in $SensitiveStringsToCheck) {
                    # Use word boundaries for short values to avoid false positives
                    # (e.g., SiteCode matching inside file extension ".psd1")
                    $pattern = [regex]::Escape($sensitive)
                    if ($sensitive.Length -le 5) { $pattern = "(?<![a-zA-Z0-9])$pattern(?![a-zA-Z0-9])" }
                    if ($content -match $pattern) {
                        $relativePath = $filePath.Replace($Root, '').TrimStart('\', '/')
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
