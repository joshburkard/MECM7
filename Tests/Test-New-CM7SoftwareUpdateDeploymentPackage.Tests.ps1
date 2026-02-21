BeforeAll {
    # Load test declarations
    . (Join-Path $PSScriptRoot "declarations.ps1")

    # Load all functions
    $CodePath = Join-Path (Get-Item $PSScriptRoot).Parent.FullName "Code"
    Get-ChildItem -Path (Join-Path $CodePath "Private") -Filter "*.ps1" | ForEach-Object { . $_.FullName }
    Get-ChildItem -Path (Join-Path $CodePath "Public") -Filter "*.ps1" | ForEach-Object { . $_.FullName }

    # Get test data for this function
    $script:TestNewSUDData = $script:TestData['New-CM7SoftwareUpdateDeploymentPackage']
    $script:TestConnectData = $script:TestData['Connect-CM7']

    # Track created deployments for cleanup
    $script:CreatedDeploymentIds = @()

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

Describe 'New-CM7SoftwareUpdateDeploymentPackage' {
    Context 'Basic creation' {
        It 'Creates a deployment package at the specified path' {
            $params = Get-TestData -FunctionName 'New-CM7SoftwareUpdateDeploymentPackage' -ParameterSet 'Basic'
            $result = New-CM7SoftwareUpdateDeploymentPackage @params
            $result.Name | Should -Be $params.Name
            $result.PkgSourcePath | Should -Be $params.Path
            $script:CreatedDeploymentIds += $result.PackageID
        }
    }
    Context 'Duplicate creation' {
        It 'Throws when a deployment package with the same name already exists' {
            $params = Get-TestData -FunctionName 'New-CM7SoftwareUpdateDeploymentPackage' -ParameterSet 'DuplicateName'
            { New-CM7SoftwareUpdateDeploymentPackage @params } | Should -Throw
        }
    }
    Context 'Invalid path' {
        It 'Throws when path is invalid' {
            $params = Get-TestData -FunctionName 'New-CM7SoftwareUpdateDeploymentPackage' -ParameterSet 'InvalidPath'
            { New-CM7SoftwareUpdateDeploymentPackage @params } | Should -Throw
        }
    }

}

AfterAll {
    write-host "Starting cleanup of created deployment packages..."
    # Cleanup created deployments
    if ($script:CMConnection.CimSession -and $script:CreatedDeploymentIds.Count -gt 0) {
        foreach ($id in $script:CreatedDeploymentIds) {
            # this functiopn does not exist yet, so we have to call the CIM method directly for now
            $namespace = "root/SMS/site_$($script:CMConnection.SiteCode)"
            $cimSession = $script:CMConnection.CimSession
            Write-Host "  Cleaning up deployment package with ID: $id"
            $package = Get-CimInstance -CimSession $cimSession -Namespace $namespace -ClassName "SMS_SoftwareUpdatesPackage" -Filter "PackageID = '$id'"
            if ($package) {
                write-host "Removing deployment package: $($package.Name) with ID: $id"
                Remove-CimInstance -CimInstance $package -ErrorAction Ignore
            }
        }
    }
}
