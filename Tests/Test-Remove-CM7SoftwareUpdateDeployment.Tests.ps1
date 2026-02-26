
# Functional Tests for Remove-CM7SoftwareUpdateDeployment

BeforeAll {
    . (Join-Path $PSScriptRoot "declarations.ps1")
    $CodePath = Join-Path (Get-Item $PSScriptRoot).Parent.FullName "Code"
    Get-ChildItem -Path (Join-Path $CodePath "Private") -Filter "*.ps1" | ForEach-Object { . $_.FullName }
    Get-ChildItem -Path (Join-Path $CodePath "Public") -Filter "*.ps1" | ForEach-Object { . $_.FullName }
    $script:TestRemoveSUDData = $script:TestData['Remove-CM7SoftwareUpdateDeployment']
    $script:TestConnectData = $script:TestData['Connect-CM7']
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

    # create test deployments if needed
    $params = Get-TestData -FunctionName 'Remove-CM7SoftwareUpdateDeployment' -ParameterSet 'ByGroupNameAndCollectionName'
    New-CM7SoftwareUpdateDeployment @params


    $params = Get-TestData -FunctionName 'Remove-CM7SoftwareUpdateDeployment' -ParameterSet 'ByGroupIDAndCollectionID'
    New-CM7SoftwareUpdateDeployment @params

    Start-Sleep -Seconds 5
}

Describe "Remove-CM7SoftwareUpdateDeployment Function Tests" -Tag "Integration", "SoftwareUpdateDeployment", "Remove" {

    Context "Test Data Validation" {
        It "Should have test data defined in declarations.ps1" {
            $script:TestRemoveSUDData | Should -Not -BeNullOrEmpty
            $script:TestData.ContainsKey('Remove-CM7SoftwareUpdateDeployment') | Should -Be $true
        }
        It "Should have required test data parameter sets" {
            $script:TestRemoveSUDData.ContainsKey('ByGroupNameAndCollectionName') | Should -Be $true
            $script:TestRemoveSUDData.ContainsKey('ByGroupIDAndCollectionID') | Should -Be $true
            $script:TestRemoveSUDData.ContainsKey('NonExistent') | Should -Be $true
        }
    }

    Context "Connection Requirement" {
        It "Should fail if not connected to MECM" {
            $backupConnection = $script:CMConnection.Clone()
            $script:CMConnection.CimSession = $null
            { Remove-CM7SoftwareUpdateDeployment -SoftwareUpdateGroupName "Test" -CollectionName "Test" } | Should -Throw "*not connected*"
            $script:CMConnection = $backupConnection
        }
    }

    Context "WhatIf Support" {
        It "Should support -WhatIf parameter" {
            $params = Get-TestData -FunctionName 'Remove-CM7SoftwareUpdateDeployment' -ParameterSet 'ByGroupNameAndCollectionName'
            { Remove-CM7SoftwareUpdateDeployment @params -WhatIf } | Should -Not -Throw
        }
    }

    Context "Remove Deployments" {
        It "Should remove deployment by Names" {
            $params = Get-TestData -FunctionName 'Remove-CM7SoftwareUpdateDeployment' -ParameterSet 'ByGroupNameAndCollectionName'
            { Remove-CM7SoftwareUpdateDeployment @params -Force -Confirm:$false } | Should -Not -Throw
        }
        It "Should remove deployment for Test-SUG from Test-Collection-Exclude" {
            $params = Get-TestData -FunctionName 'Remove-CM7SoftwareUpdateDeployment' -ParameterSet 'ByGroupIDAndCollectionID'
            { Remove-CM7SoftwareUpdateDeployment @params -Force -Confirm:$false } | Should -Not -Throw
        }
    }

    Context "Error Handling" {
        It "Should throw for non-existent SUG or collection" {
            $params = Get-TestData -FunctionName 'Remove-CM7SoftwareUpdateDeployment' -ParameterSet 'NonExistent'
            { Remove-CM7SoftwareUpdateDeployment @params -Force -Confirm:$false 2>$null } | Should -Throw
        }
    }
}
