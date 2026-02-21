# Functional Tests for Remove-CM7SoftwareUpdateDeploymentPackage
# Tests the Remove-CM7SoftwareUpdateDeploymentPackage function behavior and return values
# Test packages are created dynamically using New-CM7SoftwareUpdateDeploymentPackage
# and removed during the test run itself

BeforeAll {
    # Load test declarations
    . (Join-Path $PSScriptRoot "declarations.ps1")

    # Load all functions
    $CodePath = Join-Path (Get-Item $PSScriptRoot).Parent.FullName "Code"
    Get-ChildItem -Path (Join-Path $CodePath "Private") -Filter "*.ps1" | ForEach-Object { . $_.FullName }
    Get-ChildItem -Path (Join-Path $CodePath "Public") -Filter "*.ps1" | ForEach-Object { . $_.FullName }

    # Get test data for this function
    $script:TestRemoveSUDPkgData = $script:TestData['Remove-CM7SoftwareUpdateDeploymentPackage']
    $script:TestNewSUDPkgData = $script:TestData['New-CM7SoftwareUpdateDeploymentPackage']
    $script:TestConnectData = $script:TestData['Connect-CM7']

    # Track created package IDs for cleanup
    $script:CreatedPackageIds = @()

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

Describe 'Remove-CM7SoftwareUpdateDeploymentPackage' {
    Context 'Basic removal by name' {
        It 'Creates and then removes a deployment package by name' {
            $params = Get-TestData -FunctionName 'New-CM7SoftwareUpdateDeploymentPackage' -ParameterSet 'Basic'
            $pkg = New-CM7SoftwareUpdateDeploymentPackage @params
            $pkg | Should -Not -BeNullOrEmpty
            $script:CreatedPackageIds += $pkg.PackageID

            $result = Remove-CM7SoftwareUpdateDeploymentPackage -Name $pkg.Name -Force
            $result | Should -Not -BeNullOrEmpty
            $result.PackageID | Should -Be $pkg.PackageID
            $result.Status | Should -Be 'Removed'
        }
    }
    Context 'Removal by PackageID' {
        It 'Creates and then removes a deployment package by ID' {
            $params = Get-TestData -FunctionName 'New-CM7SoftwareUpdateDeploymentPackage' -ParameterSet 'Basic'
            $pkg = New-CM7SoftwareUpdateDeploymentPackage @params
            $pkg | Should -Not -BeNullOrEmpty
            $script:CreatedPackageIds += $pkg.PackageID

            $result = Remove-CM7SoftwareUpdateDeploymentPackage -Id $pkg.PackageID -Force
            $result | Should -Not -BeNullOrEmpty
            $result.PackageID | Should -Be $pkg.PackageID
            $result.Status | Should -Be 'Removed'
        }
    }
    Context 'Removal by InputObject' {
        It 'Removes a deployment package using InputObject' {
            $params = Get-TestData -FunctionName 'New-CM7SoftwareUpdateDeploymentPackage' -ParameterSet 'Basic'
            $pkg = New-CM7SoftwareUpdateDeploymentPackage @params
            $pkg | Should -Not -BeNullOrEmpty
            $script:CreatedPackageIds += $pkg.PackageID

            $result = Remove-CM7SoftwareUpdateDeploymentPackage -InputObject $pkg -Force
            $result | Should -Not -BeNullOrEmpty
            $result.PackageID | Should -Be $pkg.PackageID
            $result.Status | Should -Be 'Removed'
        }
    }
    Context 'Non-existent package' {
        It 'Throws when removing a non-existent package by name' {
            $params = Get-TestData -FunctionName 'Remove-CM7SoftwareUpdateDeploymentPackage' -ParameterSet 'NonExistent'
            { Remove-CM7SoftwareUpdateDeploymentPackage -Name $params.Name -Force } | Should -Throw
        }
        It 'Throws when removing a non-existent package by ID' {
            $params = Get-TestData -FunctionName 'Remove-CM7SoftwareUpdateDeploymentPackage' -ParameterSet 'NonExistent'
            { Remove-CM7SoftwareUpdateDeploymentPackage -Id $params.Id -Force } | Should -Throw
        }
    }
}

AfterAll {
    Write-Host "Starting cleanup of created deployment packages..."
    if ($script:CMConnection.CimSession -and $script:CreatedPackageIds.Count -gt 0) {
        foreach ($id in $script:CreatedPackageIds) {
            $namespace = "root/SMS/site_$($script:CMConnection.SiteCode)"
            $cimSession = $script:CMConnection.CimSession
            Write-Host "  Cleaning up deployment package with ID: $id"
            $package = Get-CimInstance -CimSession $cimSession -Namespace $namespace -ClassName "SMS_SoftwareUpdatesPackage" -Filter "PackageID = '$id'"
            if ($package) {
                Write-Host "Removing deployment package: $($package.Name) with ID: $id"
                Remove-CimInstance -CimInstance $package -ErrorAction Ignore
            }
        }
    }
}
