<#
.SYNOPSIS
    Creates Markdown documentation for PowerShell module functions

.DESCRIPTION
    This script analyzes a PowerShell module and generates individual Markdown files for each function,
    based on the comment-based help including SYNOPSIS, DESCRIPTION, PARAMETERS, EXAMPLES, and NOTES.
    It now also properly handles dynamic parameters defined in DynamicParam blocks.

.PARAMETER ModulePath
    Path to the PowerShell module (.psm1) file or directory containing .ps1 files

.PARAMETER OutputFolder
    Folder where the Markdown documentation will be created

.EXAMPLE
    .\modules\DevOps.TCMDB\CI\Create-ModuleDocumentation.ps1 -ModulePath '.\modules\DevOps.TCMDB\Code\Public\' -OutputFolder '.\modules\DevOps.TCMDB\Help\'

.EXAMPLE
    .\Scripts\CMDB-Module\CI\Create-ModuleDocumentation.ps1 -ModulePath '.\Scripts\CMDB-Module\Code\Public\' -OutputFolder '.\Scripts\CMDB-Module\Help\' -FunctionName New-CMDBAsset

.NOTES
    Author: Josua Burkard
    Date: 13/05/2025
    Version: 1.0.4
#>

switch ( $ExecutionContext.Host.Name ) {
    "ConsoleHost" { Write-Verbose "Runbook is executed from PowerShell Console"; if ( [boolean]$MyInvocation.ScriptName ) { if ( ( $MyInvocation.ScriptName ).EndsWith( ".psm1" ) ) { $CurrentFile = [System.IO.FileInfo]$Script:MyInvocation.ScriptName } else { $CurrentFile = [System.IO.FileInfo]$MyInvocation.ScriptName } } elseif ( [boolean]$MyInvocation.MyCommand ) { if ( [boolean]$MyInvocation.MyCommand.Source ) { if ( ( $MyInvocation.MyCommand.Source ).EndsWith( ".psm1" ) ) { $CurrentFile = [System.IO.FileInfo]$MyInvocation.MyCommand.Source } else { $CurrentFile = [System.IO.FileInfo]$MyInvocation.MyCommand.Source } } else { $CurrentFile = [System.IO.FileInfo]$MyInvocation.MyCommand.Path } } }
    "Visual Studio Code Host" { Write-Verbose 'Runbook is executed from Visual Studio Code'; If ( [boolean]( $psEditor.GetEditorContext().CurrentFile.Path ) ) { Write-Verbose "c"; $CurrentFile = [System.IO.FileInfo]$psEditor.GetEditorContext().CurrentFile.Path } else { if ( ( [System.IO.FileInfo]$MyInvocation.ScriptName ).Extension -eq '.psm1' ) { Write-Verbose "d1"; $PSCallStack = Get-PSCallStack; $CurrentFile =[System.IO.FileInfo] @( $PSCallStack | Where-Object { $_.ScriptName -match '.ps1'} )[0].ScriptName } else { Write-Verbose "d2";  $CurrentFile = [System.IO.FileInfo]$MyInvocation.scriptname } } }
    "Windows PowerShell ISE Host" { Write-Verbose 'Runbook is executed from ISE'; Write-Verbose "  CurrentFile"; $CurrentFile = [System.IO.FileInfo]( $psISE.CurrentFile.FullPath ) }
}

$ModulePath = Join-Path -Path $CurrentFile.Directory.Parent.FullName -ChildPath "Code"
$OutputFolder = Join-Path -Path $CurrentFile.Directory.Parent.FullName -ChildPath "Help"

#region functions
# Ensure output folder exists
if (-not (Test-Path -Path $OutputFolder)) {
    New-Item -Path $OutputFolder -ItemType Directory -Force | Out-Null
    Write-Verbose "Created output folder: $OutputFolder"
}

# Normalize line endings function
function Set-LineEndings {
    param (
        [string]$Text
    )

    # First convert all CRLF to LF
    $Text = $Text -replace "`r`n", "`n"

    # Then convert any remaining CR to LF
    $Text = $Text -replace "`r", "`n"

    return $Text
}

# Convert text to markdown format with proper line breaks
function Format-TextForMarkdown {
    param (
        [string]$Text
    )

    if ([string]::IsNullOrEmpty($Text)) {
        return ""
    }

    # Normalize line endings first
    $Text = Set-LineEndings -Text $Text

    # Split the text into lines
    $lines = $Text -split "`n"

    # Process lines for markdown - a single line break in source becomes a space,
    # two consecutive line breaks become a paragraph break
    $result = @()
    $emptyLineCount = 0

    foreach ($line in $lines) {
        $trimmedLine = $line.Trim()

        if ([string]::IsNullOrWhiteSpace($trimmedLine)) {
            # Count empty lines
            $emptyLineCount++

            # If we have two or more consecutive empty lines, add a paragraph break
            if ($emptyLineCount -eq 1) {
                $result += ""
            }
        }
        else {
            # Reset empty line counter and add the non-empty line
            $emptyLineCount = 0
            $result += $trimmedLine
        }
    }

    return $result
}

# Function to extract only the text from the description block, excluding parameter info
function Get-DescriptionText {
    param (
        [string]$DescriptionText
    )

    if ([string]::IsNullOrEmpty($DescriptionText)) {
        return ""
    }

    # Pattern to find common parameter list formats in description
    $paramListPattern = "(?ms)(?:This function (has|uses) (?:the following |)parameters:.*)|(?:(?:the function|it) uses (?:dynamic |)parameters(?: for| like).*)"

    # If the pattern is found, get only the text before it
    if ($DescriptionText -match $paramListPattern) {
        return ($DescriptionText -split $Matches[0])[0].Trim()
    }

    return $DescriptionText
}

# Function to extract function details using AST (Abstract Syntax Tree)
function Get-FunctionDetails {
    param (
        [string]$ModuleContent
    )

    $ast = [System.Management.Automation.Language.Parser]::ParseInput($ModuleContent, [ref]$null, [ref]$null)
    $functions = $ast.FindAll({ $args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true)

    return $functions
}

# Function to extract DynamicParam block from a function
function Get-DynamicParamBlock {
    param (
        [System.Management.Automation.Language.FunctionDefinitionAst]$Function
    )

    # Find the DynamicParam block within the function
    $functionBody = $Function.Body
    if (-not $functionBody) {
        return $null
    }

    # Look for named blocks in the function body
    $namedBlocks = $functionBody.FindAll({
        $args[0] -is [System.Management.Automation.Language.NamedBlockAst]
    }, $false)

    # Find the DynamicParam block
    $dynamicParamBlock = $namedBlocks | Where-Object { $_.BlockKind -eq 'DynamicParam' }

    return $dynamicParamBlock
}

# Function to extract dynamic parameter details from a DynamicParam block
function Get-DynamicParameterDetails {
    param (
        [System.Management.Automation.Language.NamedBlockAst]$DynamicParamBlock,
        [string]$FunctionText,
        [hashtable]$HelpSections
    )

    if (-not $DynamicParamBlock) {
        return @()
    }

    $dynamicParameters = @()

    # Extract the text of the DynamicParam block for additional processing
    $blockText = $DynamicParamBlock.Extent.Text

    # Look for parameter configuration patterns like @{ Name = "ParameterName" ... }
    $paramConfigPattern = '(?ms)Name\s*=\s*"([^"]+)".*?Mandatory\s*=\s*(\$(?:true|false)|true|false)'
    $paramMatches = [regex]::Matches($blockText, $paramConfigPattern)

    foreach ($match in $paramMatches) {
        $paramName = $match.Groups[1].Value
        $isMandatory = $match.Groups[2].Value.ToLower() -in @('$true', 'true')

        # Extract the getter function for this parameter
        $getterPattern = "(?ms)Name\s*=\s*""$paramName"".*?GetterFunction\s*=\s*""([^"]+)"""
        $getterMatch = [regex]::Match($blockText, $getterPattern)
        $getterFunction = if ($getterMatch.Success) { $getterMatch.Groups[1].Value } else { "" }

        # Try to find a description for this parameter from the parameter sections
        $description = ""
        if ($HelpSections -and $HelpSections.ContainsKey("PARAMETER")) {
            $paramPattern = "(?ms)-$paramName\s*(.*?)(?=-\w|\s*$)"
            $paramMatch = [regex]::Match($HelpSections["PARAMETER"], $paramPattern)
            if ($paramMatch.Success) {
                $description = $paramMatch.Groups[1].Value.Trim()
            }
        }

        # If not found in parameter section, look for it in the full function help
        if ([string]::IsNullOrWhiteSpace($description)) {
            $descriptionPattern = "(?ms)\.PARAMETER\s+$paramName\s*(.*?)(?=\.PARAMETER|\.[A-Z][A-Za-z]+|\s*$)"
            $descriptionMatch = [regex]::Match($FunctionText, $descriptionPattern)
            $description = if ($descriptionMatch.Success) {
                $descriptionMatch.Groups[1].Value.Trim()
            } else {
                "Dynamic parameter. Tab completion shows available values."
            }
        }

        $dynamicParameters += @{
            Name = $paramName
            Description = $description
            IsMandatory = $isMandatory
            GetterFunction = $getterFunction
        }
    }

    return $dynamicParameters
}

# Function to extract raw help block content from file
function Get-RawHelpBlock {
    param (
        [System.Management.Automation.Language.FunctionDefinitionAst]$Function,
        [string]$FileContent
    )

    $funcName = $Function.Name

    # Normalize line endings in the file content
    $FileContent = Set-LineEndings -Text $FileContent

    # Look for help block before the function definition
    $beforePattern = "(?ms)<#(.*?)#>\s*function\s+$funcName\b"
    $beforeMatch = [regex]::Match($FileContent, $beforePattern)

    if ($beforeMatch.Success) {
        Write-Verbose "Found help block before function $funcName"
        return $beforeMatch.Groups[1].Value
    }

    # Look for help block inside the function
    $insidePattern = "(?ms)function\s+$funcName.*?{.*?<#(.*?)#>"
    $insideMatch = [regex]::Match($FileContent, $insidePattern)

    if ($insideMatch.Success) {
        Write-Verbose "Found help block inside function $funcName"
        return $insideMatch.Groups[1].Value
    }

    Write-Verbose "No help block found for function $funcName"
    return $null
}

# Extract help sections directly from raw help text
function Get-HelpSections {
    param (
        [string]$HelpBlock
    )

    if (-not $HelpBlock) {
        return @{}
    }

    # Normalize line endings
    $HelpBlock = Set-LineEndings -Text $HelpBlock

    $sections = @{}

    # Find all section headers in the help block
    # $sectionHeaderPattern = "(?m)^\s*\.([A-Z][A-Za-z]+)\s*$"
    $sectionHeaderPattern = "(?m)^\s*\.([A-Z][A-Za-z]+.*\n)"
    $sectionHeaders = [regex]::Matches($HelpBlock, $sectionHeaderPattern) | ForEach-Object { $_.Groups[1].Value }

    Write-Verbose "Found these section headers: $($sectionHeaders -join ', ')"

    # Process each section - get pairs of section headers to determine section boundaries
    $headerPositions = @{}
    $exampleHeaders = 0
    foreach ($match in [regex]::Matches($HelpBlock, $sectionHeaderPattern)) {
        $headerName = $match.Groups[1].Value.Trim()
        if ($headerName -ne 'EXAMPLE') {
            $headerPositions[$headerName] = $match.Index
        } else {
            $headerPositions["${headerName}-${exampleHeaders}"] = $match.Index
            $exampleHeaders++
        }
    }

    # Sort headers by their position in the document
    $sortedHeaders = $headerPositions.GetEnumerator() | Sort-Object Value | ForEach-Object { $_.Key }

    Write-Verbose "Headers in order: $($sortedHeaders -join ', ')"

    # Extract content between each header and the next one
    for ($i = 0; $i -lt $sortedHeaders.Count; $i++) {
        $currentHeader = $sortedHeaders[$i].Trim()
        $currentPos = $headerPositions[$currentHeader]
        $sectionStart = $HelpBlock.IndexOf("`n", $currentPos + 1) + 1

        if ($sectionStart -le 0) {
            # Skip if we can't find the start of the section
            continue
        }

        if ($i -lt $sortedHeaders.Count - 1) {
            $nextHeader = $sortedHeaders[$i + 1]
            $nextPos = $headerPositions[$nextHeader]
            $sectionEnd = $HelpBlock.LastIndexOf("`n", $nextPos)
            if ($sectionEnd -le $sectionStart) {
                $sectionEnd = $nextPos
            }
        }
        else {
            # Last section - goes to the end of the help block
            $sectionEnd = $HelpBlock.Length
        }

        $sectionLength = $sectionEnd - $sectionStart
        if ($sectionLength -gt 0) {
            $content = $HelpBlock.Substring($sectionStart, $sectionLength).Trim()
            $sections[$currentHeader] = $content

            Write-Verbose "${currentHeader} section found with length: $($content.Length)"
            if ($content.Length -gt 0) {
                $snippetLength = [Math]::Min(50, $content.Length)
                Write-Verbose "${currentHeader} start: '$($content.Substring(0, $snippetLength))...'"
            }
        }
    }

    # Handle examples as a special case with multiple .EXAMPLE sections
    if ($sectionHeaders -contains "EXAMPLE") {
        $examples = @()
        $examplePatterns = [regex]::Matches($HelpBlock, "(?ms)\.EXAMPLE\s*(.*?)(?=\.EXAMPLE|\.(?!EXAMPLE)[A-Z][A-Za-z]+|\s*$)")

        Write-Verbose "Found $($examplePatterns.Count) examples"

        $index = 1
        foreach ($match in $examplePatterns) {
            $content = $match.Groups[1].Value.Trim()
            $examples += @{
                Index = $index
                Content = $content
            }

            Write-Verbose "Example $index content length: $($content.Length) characters"
            if ($content.Length -gt 0) {
                $snippetLength = [Math]::Min(50, $content.Length)
                Write-Verbose "Example $index start: '$($content.Substring(0, $snippetLength))...'"
            }

            $index++
        }

        $sections["EXAMPLES"] = $examples
    }

    # Extract all parameter descriptions from the help block
    if ($sectionHeaders -contains "PARAMETER") {
        $parameterSection = ""
        $paramMatches = [regex]::Matches($HelpBlock, "(?ms)\.PARAMETER\s+(\w+)\s*(.*?)(?=\.PARAMETER|\.[A-Z][A-Za-z]+|\s*$)")

        foreach ($match in $paramMatches) {
            $paramName = $match.Groups[1].Value.Trim()
            $paramDesc = $match.Groups[2].Value.Trim()
            $parameterSection += "-$paramName $paramDesc`n`n"
        }

        $sections["PARAMETER"] = $parameterSection
    }

    return $sections
}

# Function to extract comment-based help using PowerShell's Get-Help cmdlet
function Get-CommentBasedHelp {
    param (
        [System.Management.Automation.Language.FunctionDefinitionAst]$Function
    )

    $funcName = $Function.Name

    # Create a temporary script to use Get-Help
    $tempScriptPath = [System.IO.Path]::GetTempFileName() + ".ps1"
    $Function.Extent.Text | Out-File -FilePath $tempScriptPath -Encoding utf8

    # Import the temporary script
    . $tempScriptPath

    # Get the help for the function
    $help = Get-Help -Name $funcName -Full

    # Delete the temporary script
    Remove-Item -Path $tempScriptPath -Force

    return $help
}

# Function to generate markdown documentation for a function
function New-FunctionMarkdown {
    param (
        [Parameter(Mandatory = $true)]
        [object]$Help,

        [Parameter(Mandatory = $true)]
        [string]$OutputFolder,

        [Parameter(Mandatory = $false)]
        [hashtable]$HelpSections,

        [Parameter(Mandatory = $false)]
        [object[]]$DynamicParameters,

        [Parameter(Mandatory = $false)]
        [switch]$HasDynamicParams
    )

    $funcName = $Help.Name
    $outputPath = Join-Path -Path $OutputFolder -ChildPath "$funcName.md"

    Write-Verbose "Generating documentation for $funcName"

    # Initialize content array
    $contentLines = @()

    # Add function name heading
    $contentLines += "# $funcName"
    $contentLines += ""

    # Add Synopsis
    $contentLines += "## SYNOPSIS"
    if ($HelpSections -and $HelpSections.ContainsKey("SYNOPSIS")) {
        $formatted = Format-TextForMarkdown -Text $HelpSections["SYNOPSIS"]
        $contentLines += $formatted
    } else {
        $contentLines += $Help.Synopsis
    }
    $contentLines += ""

    # Add Description - strip out parameter lists from description
    $contentLines += "## DESCRIPTION"
    if ($HelpSections -and $HelpSections.ContainsKey("DESCRIPTION")) {
        $descriptionText = Get-DescriptionText -DescriptionText $HelpSections["DESCRIPTION"]
        $formatted = Format-TextForMarkdown -Text $descriptionText
        $contentLines += $formatted
    }
    elseif ($Help.Description -is [string]) {
        $contentLines += $Help.Description
    }
    elseif ($Help.Description.Text) {
        if ($Help.Description.Text -is [array]) {
            $descriptionText = $Help.Description.Text -join "`n"
            $cleanedText = Get-DescriptionText -DescriptionText $descriptionText
            $contentLines += $cleanedText
        } else {
            $cleanedText = Get-DescriptionText -DescriptionText $Help.Description.Text
            $contentLines += $cleanedText
        }
    }
    else {
        $contentLines += "No description available."
    }
    $contentLines += ""

    # Add parameters section
    $contentLines += "## PARAMETERS"
    $contentLines += ""

    # Add regular parameters first
    if ($Help.Parameters.Parameter) {
        # Convert to array if it's a single parameter
        $parameters = $Help.Parameters.Parameter
        if (-not ($parameters -is [array])) {
            $parameters = @($parameters)
        }

        foreach ($parameter in $parameters) {
            $contentLines += "### $($parameter.Name)"

            # Parameter description
            if ($parameter.Description.Text -is [array]) {
                $contentLines += $parameter.Description.Text
            } else {
                $contentLines += $parameter.Description.Text
            }
            $contentLines += ""

            # Parameter details
            $contentLines += "- Type: $($parameter.Type.Name)"
            $contentLines += "- Required: $($parameter.Required)"
            if ($parameter.DefaultValue) {
                $contentLines += "- Default value: $($parameter.DefaultValue)"
            }
            $contentLines += "- Accept pipeline input: $($parameter.PipelineInput)"
            $contentLines += "- Accept wildcard characters: $($parameter.Globbing)"
            $contentLines += ""
        }
    }

    # Add dynamic parameters
    if ($DynamicParameters -and $DynamicParameters.Count -gt 0) {
        foreach ($dynamicParam in $DynamicParameters) {
            $contentLines += "### $($dynamicParam.Name)"
            $contentLines += $dynamicParam.Description
            $contentLines += ""
            $contentLines += "- Type: String"
            $contentLines += "- Required: $($dynamicParam.IsMandatory)"
            if ($dynamicParam.GetterFunction) {
                $contentLines += "- Values retrieved from: $($dynamicParam.GetterFunction)"
            }
            $contentLines += "- Dynamic parameter with tab completion"
            $contentLines += ""
        }
    }
    elseif ($HasDynamicParams) {
        $contentLines += "### Dynamic Parameters"
        $contentLines += ""
        $contentLines += "This function uses dynamic parameters, which are only available under certain conditions."
        $contentLines += "Refer to the function description for details on available dynamic parameters."
        $contentLines += ""
    }

    # Add examples - use direct examples from help sections if available
    if ($HelpSections -and [boolean]( $HelpSections.Keys | Where-Object { $_ -match 'EXAMPLE' } ) ) {
        $contentLines += "## EXAMPLES"
        $contentLines += ""

        foreach ($exampleKey in ( $HelpSections.Keys | Where-Object { $_ -match 'EXAMPLE' } ) ) {
            $exampleNumber = [int]( $exampleKey.Split('-')[1] )
            $contentLines += "### Example $($exampleNumber + 1)"

            # Use six backticks to ensure markdown doesn't interpret any content inside
            $contentLines += "``````powershell"

            $ExampleContent = $HelpSections."${exampleKey}".Split("`r`n")
            $leadingSpaces = 0
            foreach ($line in $ExampleContent) {
                if ( $line -notmatch '\.EXAMPLE' ) {
                    if ( $leadingSpaces -eq 0 ) {
                        $leadingSpaces = $line.Length - $line.TrimStart().Length
                    }
                    if ($line.Length -gt $leadingSpaces) {
                        $contentLines += $line.Substring($leadingSpaces)
                    }
                }
            }
            # $contentLines += $HelpSections."${exampleKey}"
            $contentLines += "``````"
            $contentLines += ""
        }
    }
    # Fall back to examples from Get-Help if no direct examples
    elseif ($Help.Examples -and $Help.Examples.Example) {
        $contentLines += "## EXAMPLES"
        $contentLines += ""

        # Handle if there's only one example (not in an array)
        $examples = $Help.Examples.Example
        if (-not ($examples -is [array])) {
            $examples = @($examples)
        }

        $exampleIndex = 1
        foreach ($example in $examples) {
            $contentLines += "### Example $exampleIndex"

            # Use six backticks to ensure markdown doesn't interpret any content inside
            $contentLines += "``````powershell"
            $contentLines += $example.Code
            $contentLines += "``````"

            # Add remarks if available
            if ($example.Remarks) {
                if ($example.Remarks.Text -is [array]) {
                    $remarkText = ($example.Remarks.Text -join "`n").Trim()
                    if ($remarkText) {
                        $contentLines += ""
                        $contentLines += $remarkText
                    }
                } else {
                    $remarkText = $example.Remarks.Text.Trim()
                    if ($remarkText) {
                        $contentLines += ""
                        $contentLines += $remarkText
                    }
                }
            }

            $contentLines += ""
            $exampleIndex++
        }
    }

    # Add notes if available
    if ($HelpSections -and $HelpSections.ContainsKey("NOTES")) {
        $contentLines += "## NOTES"
        $formatted = Format-TextForMarkdown -Text $HelpSections["NOTES"]
        $contentLines += $formatted
        $contentLines += ""
    }
    elseif ($Help.AlertSet -and $Help.AlertSet.Alert) {
        $contentLines += "## NOTES"

        if ($Help.AlertSet.Alert.Text -is [array]) {
            $contentLines += $Help.AlertSet.Alert.Text
        } else {
            $contentLines += $Help.AlertSet.Alert.Text
        }
        $contentLines += ""
    }

    # Join the content lines with Windows-style CRLF line endings
    $content = $contentLines -join "`r`n"

    # Write the markdown content to the file (using UTF-8 without BOM)
    [System.IO.File]::WriteAllText($outputPath, $content, [System.Text.UTF8Encoding]::new($false))

    Write-Verbose "Documentation for $funcName created at $outputPath"

    return $outputPath
}

# Function to create a table of contents file
function New-TableOfContents {
    param (
        [string[]]$FunctionNames,
        [string]$OutputFolder,
        [string]$ModuleName
    )

    $tocPath = Join-Path -Path $OutputFolder -ChildPath "README.md"

    # Build TOC content
    $contentLines = @()
    $contentLines += "# $ModuleName Module Documentation"
    $contentLines += ""
    $contentLines += "This documentation provides details on the functions available in the $ModuleName PowerShell module."
    $contentLines += ""
    $contentLines += "## Functions"
    $contentLines += ""
    $contentLines += "| Function Name | Synopsis |"
    $contentLines += "|---------------|----------|"

    foreach ($funcName in ($FunctionNames | Sort-Object)) {
        # Try to get the function help
        $tempFunctionPath = Join-Path -Path $OutputFolder -ChildPath "$funcName.md"
        if (Test-Path -Path $tempFunctionPath) {
            $content = [System.IO.File]::ReadAllText($tempFunctionPath, [System.Text.Encoding]::UTF8)

            # Extract synopsis using regex
            $synopsisMatch = [regex]::Match($content, '## SYNOPSIS\s*(.*?)(?=\s*##|\s*$)', [System.Text.RegularExpressions.RegexOptions]::Singleline)
            $synopsis = if ($synopsisMatch.Success) {
                ($synopsisMatch.Groups[1].Value -replace '\s+', ' ').Trim()
            } else {
                "No synopsis available"
            }

            $contentLines += "| [$funcName](./$funcName.md) | $synopsis |"
        }
    }

    # Join the content lines with Unix-style LF line endings
    $content = $contentLines -join "`n"

    # Write the TOC content to the file (using UTF-8 without BOM)
    [System.IO.File]::WriteAllText($tocPath, $content, [System.Text.UTF8Encoding]::new($false))

    Write-Verbose "Table of contents created at $tocPath"

    return $tocPath
}

# Process individual PS1 files within a directory
function Process-ModuleFiles {
    param (
        [string]$DirectoryPath,
        [string]$OutputFolder
    )

    # Get all PS1 files in the directory
    $ps1Files = Get-ChildItem -Path $DirectoryPath -Filter "*.ps1" -Recurse

    $functionNames = @()

    foreach ($file in $ps1Files) {
        Write-Verbose "Processing file: $($file.FullName)"

        # Get the file content with proper encoding
        $fileContent = [System.IO.File]::ReadAllText($file.FullName, [System.Text.Encoding]::UTF8)

        # Get all functions in the file
        $ast = [System.Management.Automation.Language.Parser]::ParseInput($fileContent, [ref]$null, [ref]$null)
        $functions = $ast.FindAll({ $args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true)

        foreach ($function in $functions) {
            try {
                $funcName = $function.Name
                $functionNames += $funcName

                Write-Verbose "Processing function: $funcName"

                # Get raw help block
                $helpBlock = Get-RawHelpBlock -Function $function -FileContent $fileContent

                # Extract sections from help block
                $helpSections = $null
                if ($helpBlock) {
                    $helpSections = Get-HelpSections -HelpBlock $helpBlock
                    Write-Verbose "Extracted $($helpSections.Keys.Count) help sections for $funcName"
                }

                # Check for DynamicParam block and extract details
                $dynamicParamBlock = Get-DynamicParamBlock -Function $function
                $hasDynamicParams = $null -ne $dynamicParamBlock
                $dynamicParameters = $null

                if ($hasDynamicParams) {
                    Write-Verbose "Function $funcName has a DynamicParam block"
                    $dynamicParameters = Get-DynamicParameterDetails -DynamicParamBlock $dynamicParamBlock -FunctionText $fileContent -HelpSections $helpSections
                    Write-Verbose "Found $($dynamicParameters.Count) dynamic parameters in function $funcName"
                }

                # Get PowerShell help
                $help = Get-CommentBasedHelp -Function $function

                # Generate markdown documentation
                $docPath = New-FunctionMarkdown -Help $help -OutputFolder $OutputFolder -HelpSections $helpSections `
                           -DynamicParameters $dynamicParameters -HasDynamicParams:$hasDynamicParams

                Write-Verbose "Created documentation for $funcName at $docPath"
            }
            catch {
                Write-Warning "Error processing function $($function.Name): $_"
                # Continue with the next function
            }
        }
    }

    return $functionNames
}
#endregion functions

# Main script execution
try {
    Write-Verbose "Script started with ModulePath: $ModulePath and OutputFolder: $OutputFolder"

    # Check if module path exists
    if (-not (Test-Path -Path $ModulePath)) {
        throw "Module path not found at: $ModulePath"
    }

    # Get module name from the file name if it's a file
    if (Test-Path -Path $ModulePath -PathType Leaf) {
        $moduleName = [System.IO.Path]::GetFileNameWithoutExtension($ModulePath)

        Write-Verbose "Processing module file: $moduleName"

        # Get the module content with proper encoding
        $moduleContent = [System.IO.File]::ReadAllText($ModulePath, [System.Text.Encoding]::UTF8)

        # Get all functions in the module
        $functions = Get-FunctionDetails -ModuleContent $moduleContent

        Write-Verbose "Found $($functions.Count) functions in the module"

        # Create documentation for each function
        $functionNames = @()

        $filteredFunctions = $functions
        if ( [boolean]$FunctionName ) {
            $filteredFunctions = $filteredFunctions | Where-Object { $_.Name -eq $FunctionName}
        }

        foreach ($function in $filteredFunctions ) {
            try {
                $funcName = $function.Name
                $functionNames += $funcName

                Write-Verbose "Processing function: $funcName"

                # Get raw help block
                $helpBlock = Get-RawHelpBlock -Function $function -FileContent $moduleContent

                # Extract sections from help block
                $helpSections = $null
                if ($helpBlock) {
                    $helpSections = Get-HelpSections -HelpBlock $helpBlock
                    Write-Verbose "Extracted $($helpSections.Keys.Count) help sections for $funcName"
                }

                # Check for DynamicParam block and extract details
                $dynamicParamBlock = Get-DynamicParamBlock -Function $function
                $hasDynamicParams = $null -ne $dynamicParamBlock
                $dynamicParameters = $null

                if ($hasDynamicParams) {
                    Write-Verbose "Function $funcName has a DynamicParam block"
                    $dynamicParameters = Get-DynamicParameterDetails -DynamicParamBlock $dynamicParamBlock -FunctionText $moduleContent -HelpSections $helpSections
                    Write-Verbose "Found $($dynamicParameters.Count) dynamic parameters in function $funcName"
                }

                # Get PowerShell help
                $help = Get-CommentBasedHelp -Function $function

                # Generate markdown documentation
                $docPath = New-FunctionMarkdown -Help $help -OutputFolder $OutputFolder -HelpSections $helpSections `
                           -DynamicParameters $dynamicParameters -HasDynamicParams:$hasDynamicParams

                Write-Verbose "Created documentation for $funcName at $docPath"
            }
            catch {
                Write-Warning "Error processing function $($function.Name): $_"
                # Continue with the next function
            }
        }
    } elseif (Test-Path -Path $ModulePath -PathType Container) {
        # If it's a directory, process all PS1 files
        $moduleName = (Get-Item -Path $ModulePath).Name

        Write-Verbose "Processing module directory: $moduleName"

        # Process all PS1 files in the directory
        $functionNames = Process-ModuleFiles -DirectoryPath $ModulePath -OutputFolder $OutputFolder
    } else {
        throw "Invalid module path: $ModulePath"
    }

    # Create table of contents
    $tocPath = New-TableOfContents -FunctionNames $functionNames -OutputFolder $OutputFolder -ModuleName $moduleName

    Write-Output "Documentation generation complete. Documentation is available at: $OutputFolder"
    Write-Output "Table of contents available at: $tocPath"
}
catch {
    Write-Error "An error occurred: $_"
    exit 1
}
