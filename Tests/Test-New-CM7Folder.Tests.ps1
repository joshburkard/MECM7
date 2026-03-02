# Functional Tests for New-CM7Folder
# Tests the New-CM7Folder function behavior and return values

BeforeAll {
    . (Join-Path $PSScriptRoot "declarations.ps1")
    $CodePath = Join-Path (Get-Item $PSScriptRoot).Parent.FullName "Code"
    Get-ChildItem -Path (Join-Path $CodePath "Private") -Filter "*.ps1" | ForEach-Object { . $_.FullName }
    Get-ChildItem -Path (Join-Path $CodePath "Public") -Filter "*.ps1" | ForEach-Object { . $_.FullName }
    $script:TestFolderData = $script:TestData['New-CM7Folder']
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

Describe 'New-CM7Folder' {
    Context "Test Data Validation" {
        It "Should have test data defined in declarations.ps1" {
            $script:TestFolderData | Should -Not -BeNullOrEmpty
            $script:TestData.ContainsKey('New-CM7Folder') | Should -Be $true
        }
        It "Should have required test data parameter sets" {
            $script:TestFolderData.ContainsKey('ByParentPath') | Should -Be $true
            $script:TestFolderData.ContainsKey('ByParentObject') | Should -Be $true
            $script:TestFolderData.ContainsKey('DuplicateName') | Should -Be $true
            $script:TestFolderData.ContainsKey('WhatIf') | Should -Be $true
        }
    }

    Context 'ByParentPath' {
        It 'Creates folder by parent path' {
            $params = $script:TestFolderData.ByParentPath
            $result = New-CM7Folder -ParentFolderPath $params.ParentFolderPath -Name $params.Name -ObjectType $params.ObjectType
            @($result).count | Should -Be $params.ExpectedCount
            $result.Name | Should -Be $params.ExpectedName
        }
    }
    Context 'ByParentObject' {
        It 'Creates folder by parent object' {
            $params = $script:TestFolderData.ByParentObject
            $parentFolder = Get-CM7Folder -ContainerNodeID $params.ParentContainerNodeID
            $result = New-CM7Folder -InputObject $parentFolder -Name $params.Name -ObjectType $params.ObjectType
            @($result).count | Should -Be $params.ExpectedCount
            $result.Name | Should -Be $params.ExpectedName
        }
    }
    Context 'DuplicateName' {
        It 'Throws for duplicate folder name' {
            $params = $script:TestFolderData.DuplicateName
            { New-CM7Folder -ParentFolderPath $params.ParentFolderPath -Name $params.Name -ObjectType $params.ObjectType } | Should -Throw
        }
    }
    Context 'WhatIf' {
        It 'Supports WhatIf parameter' {
            $params = $script:TestFolderData.WhatIf
            { New-CM7Folder -ParentFolderPath $params.ParentFolderPath -Name $params.Name -ObjectType $params.ObjectType -WhatIf } | Should -Not -Throw
            $namespace = "root/SMS/site_$($script:CMConnection.SiteCode)"
            $query = "SELECT * FROM SMS_ObjectContainerNode WHERE Name = '$($params.Name)'"
            $check = Get-CimInstance -CimSession $script:CMConnection.CimSession -Namespace $namespace -Query $query
            $check | Should -BeNullOrEmpty
        }
    }
}
