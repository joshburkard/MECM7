# Functional Tests for Remove-CM7Folder
# Tests the Remove-CM7Folder function behavior and return values

BeforeAll {
    . (Join-Path $PSScriptRoot "declarations.ps1")
    $CodePath = Join-Path (Get-Item $PSScriptRoot).Parent.FullName "Code"
    Get-ChildItem -Path (Join-Path $CodePath "Private") -Filter "*.ps1" | ForEach-Object { . $_.FullName }
    Get-ChildItem -Path (Join-Path $CodePath "Public") -Filter "*.ps1" | ForEach-Object { . $_.FullName }
    $script:TestFolderData = $script:TestData['Remove-CM7Folder']
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
}

Describe 'Remove-CM7Folder' {
    Context "Test Data Validation" {
        It "Should have test data defined in declarations.ps1" {
            $script:TestFolderData | Should -Not -BeNullOrEmpty
            $script:TestData.ContainsKey('Remove-CM7Folder') | Should -Be $true
        }
        It "Should have required test data parameter sets" {
            $script:TestFolderData.ContainsKey('ByPath') | Should -Be $true
            $script:TestFolderData.ContainsKey('ById') | Should -Be $true
            $script:TestFolderData.ContainsKey('ByParentId') | Should -Be $true
            $script:TestFolderData.ContainsKey('ByInputObject') | Should -Be $true
            $script:TestFolderData.ContainsKey('WhatIf') | Should -Be $true
        }
    }

    Context 'ByPath' {
        It 'Removes folder by path' {
            $params = $script:TestFolderData.ByPath
            $folder = New-CM7Folder -ParentFolderPath $params.Path -Name $params.Name -ObjectType $params.ObjectType
            Start-Sleep -Seconds 1 # Ensure folder creation is processed before removal
            Remove-CM7Folder -Path (Join-Path $params.Path $params.Name) -ObjectType $params.ObjectType -Confirm:$false
            $result = Get-CM7Folder -Path (Join-Path $params.Path $params.Name) -ObjectType $params.ObjectType
            @($result).Count | Should -Be $params.ExpectedCount
        }
    }
    Context 'ById' {
        It 'Removes folder by ContainerNodeID' {
            $params = $script:TestFolderData.ById
            $folder = New-CM7Folder -ParentFolderPath $params.Path -Name 'RemoveByIdTest' -ObjectType $params.ObjectType
            Start-Sleep -Seconds 1 # Ensure folder creation is processed before removal
            Remove-CM7Folder -ContainerNodeID $folder.ContainerNodeID -ObjectType $params.ObjectType -Confirm:$false
            $result = Get-CM7Folder -ContainerNodeID $folder.ContainerNodeID -ObjectType $params.ObjectType
            @($result).Count | Should -Be $params.ExpectedCount
        }
    }
    Context 'ByParentId' {
        It 'Removes folder by parent ID and name' {
            $params = $script:TestFolderData.ByParentId
            $folder = New-CM7Folder -ParentFolderPath $params.Path -Name 'RemoveByParentIdTest' -ObjectType $params.ObjectType
            Start-Sleep -Seconds 1 # Ensure folder creation is processed before removal
            Remove-CM7Folder -Name 'RemoveByParentIdTest' -ParentContainerNodeID $params.ParentContainerNodeID -ObjectType $params.ObjectType -Confirm:$false
            $result = Get-CM7Folder -Path (Join-Path $params.Path 'RemoveByParentIdTest') -ObjectType $params.ObjectType
            @($result).Count | Should -Be $params.ExpectedCount
        }
    }
    Context 'ByInputObject' {
        It 'Removes folder by input object' {
            $params = $script:TestFolderData.ByInputObject
            $folder = New-CM7Folder -ParentFolderPath $params.Path -Name 'RemoveByInputObjectTest' -ObjectType $params.ObjectType
            Start-Sleep -Seconds 1 # Ensure folder creation is processed before removal
            $inputObj = Get-CM7Folder -Path (Join-Path $params.Path 'RemoveByInputObjectTest') -ObjectType $params.ObjectType
            Remove-CM7Folder -InputObject $inputObj -ObjectType $params.ObjectType -Confirm:$false
            $result = Get-CM7Folder -Path (Join-Path $params.Path 'RemoveByInputObjectTest') -ObjectType $params.ObjectType
            @($result).Count | Should -Be $params.ExpectedCount
        }
    }
    Context 'WhatIf' {
        It 'Supports WhatIf parameter' {
            $params = $script:TestFolderData.WhatIf
            $folder = New-CM7Folder -ParentFolderPath $params.Path -Name 'RemoveByWhatIfTest' -ObjectType $params.ObjectType
            { Remove-CM7Folder -Path (Join-Path $params.Path 'RemoveByWhatIfTest') -ObjectType $params.ObjectType -WhatIf } | Should -Not -Throw
            $result = Get-CM7Folder -Path (Join-Path $params.Path 'RemoveByWhatIfTest') -ObjectType $params.ObjectType
            @($result).Count | Should -Be $params.ExpectedCount

            Remove-CM7Folder -Path (Join-Path $params.Path 'RemoveByWhatIfTest') -ObjectType $params.ObjectType -Confirm:$false
        }
    }
}
