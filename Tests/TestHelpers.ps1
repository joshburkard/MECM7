# Shared Test Helpers for SCCM Admin Service Module Tests
# This file contains common functions used across multiple test files

function Initialize-TestEnvironment {
    <#
    .SYNOPSIS
        Loads test declarations and required functions for testing
    #>
    [CmdletBinding()]
    param()

    # Always load declarations to set script-scope variables for the calling test file
    # Credentials are cached globally, so no repeated prompts
    $TestRoot = $PSScriptRoot
    $DeclarationsPath = Join-Path -Path $TestRoot -ChildPath "declarations.ps1"
    if(Test-Path -Path $DeclarationsPath){
        . $DeclarationsPath
    }
    else{
        throw "declarations.ps1 not found. Please copy declarations_sample.ps1 to declarations.ps1 and configure your test values."
    }

    # Get module root (load functions if they're not already available in this scope)
    if(-not (Get-Command -Name Connect-CMAS -ErrorAction SilentlyContinue)){
        $Root = (Get-Item $TestRoot).Parent.FullName
        $CodePath = Join-Path -Path $Root -ChildPath "Code"

        Write-Verbose "Loading module functions into test scope..."

        # Load private functions
        Get-ChildItem -Path (Join-Path $CodePath "Private") -Filter "*.ps1" | ForEach-Object {
            . $_.FullName
        }

        # Load public functions
        Get-ChildItem -Path (Join-Path $CodePath "Public") -Filter "*.ps1" | ForEach-Object {
            . $_.FullName
        }
    }
}

function Connect-TestEnvironment {
    <#
    .SYNOPSIS
        Establishes a connection to the test SCCM environment
    #>
    [CmdletBinding()]
    param()

    if(-not $script:TestSiteServer){
        throw "Test environment not initialized. Call Initialize-TestEnvironment first."
    }

    $params = @{
        SiteServer = $script:TestSiteServer
    }

    if($script:TestSkipCertificateCheck){
        $params.SkipCertificateCheck = $true
    }

    if($null -ne $script:TestCredential){
        $params.Credential = $script:TestCredential
    }

    Connect-CMAS @params
}

function Assert-PropertyExists {
    <#
    .SYNOPSIS
        Helper function to assert that a property exists on an object
    #>
    param(
        [Parameter(Mandatory)]
        $Object,

        [Parameter(Mandatory)]
        [string]$PropertyName
    )

    $Object.PSObject.Properties.Name | Should -Contain $PropertyName
}

function Assert-NoMetadataProperties {
    <#
    .SYNOPSIS
        Helper function to assert that WMI and OData metadata properties are excluded
    #>
    param(
        [Parameter(Mandatory)]
        $Object
    )

    # Check no WMI metadata (properties starting with __)
    $Object.PSObject.Properties.Name | Where-Object { $_ -like "__*" } | Should -BeNullOrEmpty

    # Check no OData metadata (properties matching @odata)
    $Object.PSObject.Properties.Name | Where-Object { $_ -match "@odata" } | Should -BeNullOrEmpty
}
