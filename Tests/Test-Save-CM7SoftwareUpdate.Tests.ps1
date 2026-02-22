# Test-Save-CM7SoftwareUpdate.Tests.ps1
# Automated tests for Save-CM7SoftwareUpdate

BeforeAll {
    . (Join-Path $PSScriptRoot "declarations.ps1")

    $CodePath = Join-Path (Get-Item $PSScriptRoot).Parent.FullName "Code"
    Get-ChildItem -Path (Join-Path $CodePath "Private") -Filter "*.ps1" | ForEach-Object { . $_.FullName }
    Get-ChildItem -Path (Join-Path $CodePath "Public") -Filter "*.ps1" | ForEach-Object { . $_.FullName }

    $script:TestSetTSDData = $script:TestData['Set-CM7TaskSequenceDeployment']
    $script:TestConnectData = $script:TestData['Connect-CM7']
    $script:CreatedAdvertisementIds = @()

    $connectParams = @{
        SiteServer = $script:TestConnectData.Valid.SiteServer
        Credential = $script:TestConnectData.Valid.Credential
    }
    if ($script:TestConnectData.Valid.SkipCertificateCheck) { $connectParams.SkipCertificateCheck = $true }
    if ($script:TestConnectData.Valid.UseSsl) { $connectParams.UseSsl = $true }
    Connect-CM7 @connectParams
}

Describe 'Save-CM7SoftwareUpdate' {
    Context 'Connection Required' {
        It 'should throw when Connect-CM7 has not been called' {
            # Save the current connection state
            $savedConnection = $script:CMConnection

            # Clear the connection to simulate not being connected
            $script:CMConnection = $null

            # Test that the function throws
            { Save-CM7SoftwareUpdate -SoftwareUpdateGroupName "TestGroup" -DeploymentPackageName "TestPackage" } | Should -Throw

            # Restore the connection for other tests
            $script:CMConnection = $savedConnection
        }
    }
    Context 'By SoftwareUpdateGroupName' {
        It 'should save updates from group to package' {
            $params = $script:TestData['Save-CM7SoftwareUpdate']['ByGroupName']
            $result = Save-CM7SoftwareUpdate @params
            $result.Status | Should -Be 'Success'
            $result.UpdatesSucceeded | Should -BeGreaterThan 0
            $result.Errors | Should -BeNullOrEmpty
        }
    }
    Context 'By SUG ID and PackageID' {
        It 'should save updates from group to package by ID' {
            $params = $script:TestData['Save-CM7SoftwareUpdate']['ByGroupIDAndPackageID']
            $result = Save-CM7SoftwareUpdate @params
            $result.Status | Should -Be 'Success'
            $result.UpdatesSucceeded | Should -BeGreaterThan 0
            $result.Errors | Should -BeNullOrEmpty
        }
    }
    Context 'By SUG Object and PackageName' {
        It 'should save updates from group to package by object' {
            $params = $script:TestData['Save-CM7SoftwareUpdate']['ByGroupName']
            $group = Get-CM7SoftwareUpdateGroup -Name $params.SoftwareUpdateGroupName

             # Create a new hashtable with the group object instead of the ID
            $result = Save-CM7SoftwareUpdate -DeploymentPackageName $params.DeploymentPackageName -SoftwareUpdateGroup $group
            $result.Status | Should -Be 'Success'
            $result.UpdatesSucceeded | Should -BeGreaterThan 0
            $result.Errors | Should -BeNullOrEmpty
        }
    }
    Context 'By SoftwareUpdateID' {
        It 'should save updates by ID to package' {
            $params = $script:TestData['Save-CM7SoftwareUpdate']['ByUpdateID']
            $result = Save-CM7SoftwareUpdate @params
            $result.Status | Should -Be 'Success'
            $result.UpdatesSucceeded | Should -BeGreaterThan 0
            $result.Errors | Should -BeNullOrEmpty
        }
    }
    Context 'By wrong SoftwareUpdateID' {
        It 'should fail for non-existent update ID' {
            $params = $script:TestData['Save-CM7SoftwareUpdate']['ByWrongUpdateID']
            $result = Save-CM7SoftwareUpdate @params
            $result.Status | Should -Be 'Error'
            $result.UpdatesSucceeded | Should -Be 0
            $result.Errors | Should -Not -BeNullOrEmpty
        }
    }
    Context 'By SoftwareUpdateName' {
        It 'should save updates by name to package' {
            $params = $script:TestData['Save-CM7SoftwareUpdate']['ByUpdateName']
            $result = Save-CM7SoftwareUpdate @params
            $result.Status | Should -Be 'Success'
            $result.UpdatesSucceeded | Should -BeGreaterThan 0
            $result.Errors | Should -BeNullOrEmpty
        }
    }
    Context 'By UpdateID and PackageID' {
        It 'should save updates by ID to package by ID' {
            $params = $script:TestData['Save-CM7SoftwareUpdate']['ByUpdateIDandPackageID']
            $result = Save-CM7SoftwareUpdate @params
            $result.Status | Should -Be 'Success'
            $result.UpdatesSucceeded | Should -BeGreaterThan 0
            $result.Errors | Should -BeNullOrEmpty
        }
    }
    Context 'By Update Object and Package ID' {
        It 'should save updates by object to package by ID' {
            $params = $script:TestData['Save-CM7SoftwareUpdate']['ByUpdateIDandPackageID']

            $update = Get-CM7SoftwareUpdate -ArticleId $params.SoftwareUpdateId

            $result = Save-CM7SoftwareUpdate -DeploymentPackageID $params.DeploymentPackageID -SoftwareUpdate $update

            $result.Status | Should -Be 'Success'
            $result.UpdatesSucceeded | Should -BeGreaterThan 0
            $result.Errors | Should -BeNullOrEmpty
        }
    }
    Context 'Download Only' {
        It 'should download updates without saving to package' {
            $params = $script:TestData['Save-CM7SoftwareUpdate']['DownloadOnly']
            $result = Save-CM7SoftwareUpdate @params -DownloadOnly
            $result.Status | Should -Be 'Success'
            $result.UpdatesSucceeded | Should -BeGreaterThan 0
            $result.Errors | Should -BeNullOrEmpty
        }
    }
    Context 'Invalid Group' {
        It 'should fail for non-existent group' {
            $params = $script:TestData['Save-CM7SoftwareUpdate']['InvalidGroup']
            $result = Save-CM7SoftwareUpdate @params
            $result.Status | Should -Be 'Error'
            $result.Errors | Should -Not -BeNullOrEmpty
        }
    }
    Context 'Invalid Package' {
        It 'should fail for non-existent package' {
            $params = $script:TestData['Save-CM7SoftwareUpdate']['InvalidPackage']
            $result = Save-CM7SoftwareUpdate @params
            $result.Status | Should -Be 'Error'
            $result.Errors | Should -Not -BeNullOrEmpty
        }
    }
}
