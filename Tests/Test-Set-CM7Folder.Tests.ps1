# Tests for Set-CM7Folder
# Creates, renames, moves, and removes child folders under DeviceCollection\TestCollections

BeforeAll {
    # Debug: Show PowerShell version and $PSScriptRoot
    #Write-Host "[DEBUG] PowerShell Version: $($PSVersionTable.PSVersion)" -ForegroundColor Magenta
    #Write-Host "[DEBUG] PSScriptRoot: $PSScriptRoot" -ForegroundColor Magenta
    # Try to resolve declarations.ps1 path for both PS 5.1 and 7.x
    $declPath = Join-Path $PSScriptRoot "declarations.ps1"
    if (-not (Test-Path $declPath)) {
        $declPath = Join-Path (Get-Location) "declarations.ps1"
        #Write-Host "[DEBUG] declarations.ps1 fallback path: $declPath" -ForegroundColor Magenta
    }
    . $declPath
    # Debug: Show $script:TestData keys
    #Write-Host "[DEBUG] $script:TestData keys: $($script:TestData.Keys -join ', ')" -ForegroundColor Magenta
    # Debug: Show $script:TestFolderData value
    $script:TestFolderData = $script:TestData['Set-CM7Folder']
    #Write-Host "[DEBUG] $($script:TestFolderData): $($script:TestFolderData | Out-String)" -ForegroundColor Magenta

    # Load all functions
    $CodePath = Join-Path (Get-Item $PSScriptRoot).Parent.FullName "Code"
    Get-ChildItem -Path (Join-Path $CodePath "Private") -Filter "*.ps1" | ForEach-Object { . $_.FullName }
    Get-ChildItem -Path (Join-Path $CodePath "Public") -Filter "*.ps1" | ForEach-Object { . $_.FullName }

    # Get test data for this function
    $script:TestFolderData = $script:TestData['Set-CM7Folder']
    $script:TestConnectData = $script:TestData['Connect-CM7']

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

Describe 'Set-CM7Folder Functionality' {
    Context "Test Data Validation" {
        It "Should have test data defined in declarations.ps1" {
            $script:TestFolderData | Should -Not -BeNullOrEmpty
            $script:TestData.ContainsKey('Set-CM7Folder') | Should -Be $true
        }
        It "Should have required test data parameter sets" {
            $script:TestFolderData.ContainsKey('Rename') | Should -Be $true
            $script:TestFolderData.ContainsKey('Move') | Should -Be $true
            $script:TestFolderData.ContainsKey('ById') | Should -Be $true
            $script:TestFolderData.ContainsKey('WhatIf') | Should -Be $true
        }
    }

    Context 'Rename folder by path' {
        It 'Renames a child folder' {
            $params = $script:TestFolderData.Rename
            $folder = New-CM7Folder -ParentFolderPath $params.Path -Name "TestByName-$(Get-Date -Format 'yyyyMMdd_HHmmss')" -ObjectType $params.ObjectType
            $folder | Should -Not -BeNullOrEmpty
            $newName = "RenamedByName-$(Get-Date -Format 'yyyyMMdd_HHmmss')"
            ( Set-CM7Folder -Path $params.Path -Name $folder.Name -NewName $newName -ObjectType $params.ObjectType ) | Should -Not -BeNullOrEmpty
            $renamed = Get-CM7Folder -Path ( Join-Path -Path $params.Path -ChildPath $newName ) -ObjectType $params.ObjectType
            $renamed.Name | Should -Be $newName
        }
    }
    Context 'Move folder to new parent' {
        It 'Moves a child folder' {
            $params = $script:TestFolderData.Move
            $folder = New-CM7Folder -ParentFolderPath $params.Path -Name $params.Name -ObjectType $params.ObjectType
            $folder | Should -Not -BeNullOrEmpty
            Set-CM7Folder -Path $params.Path -Name $params.Name -NewParentPath $params.NewParentPath -ObjectType $params.ObjectType | Should -Not -BeNullOrEmpty
            $moved = Get-CM7Folder -Path ( Join-Path -Path $params.NewParentPath -ChildPath $params.Name ) -ObjectType $params.ObjectType
            $moved | Should -Not -BeNullOrEmpty
        }
    }
    Context 'Rename folder by ID' {
        It 'Renames a folder using ContainerNodeID' {
            $params = $script:TestFolderData.ById
            $folder = New-CM7Folder -ParentFolderPath $params.Path -Name $params.Name -ObjectType $params.ObjectType
            $folder | Should -Not -BeNullOrEmpty
            Set-CM7Folder -ContainerNodeID $folder.ContainerNodeID -NewName $params.NewName -ObjectType $params.ObjectType | Should -Not -BeNullOrEmpty
            $renamed = Get-CM7Folder -ContainerNodeID $folder.ContainerNodeID -ObjectType $params.ObjectType
            $renamed.Name | Should -Be $params.NewName
        }
    }
    Context 'WhatIf scenario' {
        It 'Shows WhatIf output' {
            $params = $script:TestFolderData.WhatIf
            $folder = Get-CM7Folder -Path $params.Path -ObjectType $params.ObjectType
            Set-CM7Folder -ContainerNodeID $folder.ContainerNodeID -NewName $params.NewName -ObjectType $params.ObjectType -WhatIf | Should -BeNullOrEmpty
        }
    }
}
