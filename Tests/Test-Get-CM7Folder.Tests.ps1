# Functional Tests for Get-CM7Folder
# Tests the Get-CM7Folder function behavior and return values

BeforeAll {
    # Debug: Show PowerShell version and $PSScriptRoot
    Write-Host "[DEBUG] PowerShell Version: $($PSVersionTable.PSVersion)" -ForegroundColor Magenta
    Write-Host "[DEBUG] PSScriptRoot: $PSScriptRoot" -ForegroundColor Magenta
    # Try to resolve declarations.ps1 path for both PS 5.1 and 7.x
    $declPath = Join-Path $PSScriptRoot "declarations.ps1"
    if (-not (Test-Path $declPath)) {
        $declPath = Join-Path (Get-Location) "declarations.ps1"
        Write-Host "[DEBUG] declarations.ps1 fallback path: $declPath" -ForegroundColor Magenta
    }
    . $declPath
    # Debug: Show $script:TestData keys
    Write-Host "[DEBUG] $script:TestData keys: $($script:TestData.Keys -join ', ')" -ForegroundColor Magenta
    # Debug: Show $script:TestFolderData value
    $script:TestFolderData = $script:TestData['Get-CM7Folder']
    Write-Host "[DEBUG] $($script:TestFolderData): $($script:TestFolderData | Out-String)" -ForegroundColor Magenta

    # Load all functions
    $CodePath = Join-Path (Get-Item $PSScriptRoot).Parent.FullName "Code"
    Get-ChildItem -Path (Join-Path $CodePath "Private") -Filter "*.ps1" | ForEach-Object { . $_.FullName }
    Get-ChildItem -Path (Join-Path $CodePath "Public") -Filter "*.ps1" | ForEach-Object { . $_.FullName }

    # Get test data for this function
    $script:TestFolderData = $script:TestData['Get-CM7Folder']
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

Describe 'Get-CM7Folder' {
    Context "Test Data Validation" {

        It "Should have test data defined in declarations.ps1" {
            # Assert
            $script:TestFolderData | Should -Not -BeNullOrEmpty
            $script:TestData.ContainsKey('Get-CM7Folder') | Should -Be $true
        }

        It "Should have required test data parameter sets" {
            # Assert
            $script:TestFolderData.ContainsKey('ByPath') | Should -Be $true
            $script:TestFolderData.ContainsKey('ById') | Should -Be $true
            $script:TestFolderData.ContainsKey('ByParentId') | Should -Be $true
            $script:TestFolderData.ContainsKey('NonExistent') | Should -Be $true
        }

        It "Should output test data for verification" {
            # Output test data
            Write-Host "`n=== Test Data for Get-CM7Folder ===" -ForegroundColor Cyan
            Write-Host "ByPath:" -ForegroundColor Yellow
            Write-Host "  Path: $($script:TestFolderData.ByPath.Path)" -ForegroundColor White
            Write-Host "  ExpectedCount: $($script:TestFolderData.ByPath.ExpectedCount)" -ForegroundColor White

            Write-Host "ById:" -ForegroundColor Yellow
            Write-Host "  ContainerNodeID: $($script:TestFolderData.ById.ContainerNodeID)" -ForegroundColor White
            Write-Host "  ExpectedMinCount: $($script:TestFolderData.ById.ExpectedMinCount)" -ForegroundColor White

            Write-Host "ByParentId:" -ForegroundColor Yellow
            Write-Host "  ParentContainerNodeID: $($script:TestFolderData.ByParentId.ParentContainerNodeID)" -ForegroundColor White
            Write-Host "  ExpectedMinCount: $($script:TestFolderData.ByParentId.ExpectedMinCount)" -ForegroundColor White

            Write-Host "NonExistent:" -ForegroundColor Yellow
            Write-Host "  Path: $($script:TestFolderData.NonExistent.Path)" -ForegroundColor White
            Write-Host "  ExpectedCount: $($script:TestFolderData.NonExistent.ExpectedCount)" -ForegroundColor White
            Write-Host "============================================================`n" -ForegroundColor Cyan

            # This test always passes, it's just for output
            $true | Should -Be $true
        }
    }

    Context "Connection Requirement" {

        It "Should fail if not connected to MECM" {
            # Arrange - Backup and clear connection
            $backupConnection = $script:CMConnection.Clone()
            $script:CMConnection.CimSession = $null

            # Act & Assert
            { Get-CM7DeviceVariable -DeviceName "Test" } | Should -Throw "*not connected*"

            # Restore connection
            $script:CMConnection = $backupConnection
        }
    }

    Context 'ByPath' {
        It 'Returns folder by path' {
            $result = Get-CM7Folder -Path $script:TestFolderData.ByPath.Path -ObjectType $script:TestFolderData.ByPath.ObjectType
            @($result).count | Should -Be $script:TestFolderData.ByPath.ExpectedCount
            $result | Should -Not -BeNullOrEmpty
        }
    }
    Context 'ByID' {
        It 'Returns folders by ID' {
            $result = Get-CM7Folder -ContainerNodeID $script:TestFolderData.ById.ContainerNodeID
            @($result).count | Should -Be $script:TestFolderData.ById.ExpectedMinCount
            $result | Should -Not -BeNullOrEmpty
        }
    }
    Context 'ByParentID' {
        It 'Returns folders by Parent ID' {
            $result = Get-CM7Folder -ParentContainerNodeID $script:TestFolderData.ByParentId.ParentContainerNodeID
            @($result).count | Should -Be $script:TestFolderData.ByParentId.ExpectedMinCount
            $result | Should -Not -BeNullOrEmpty
        }
    }
    Context 'ByParentObject' {
        It 'Returns folders by Parent Object' {
            $parentFolder = Get-CM7Folder -ContainerNodeID $script:TestFolderData.ByParentId.ParentContainerNodeID
            $result = Get-CM7Folder -ParentFolder $parentFolder
            @($result).count | Should -Be $script:TestFolderData.ByParentId.ExpectedMinCount
            $result | Should -Not -BeNullOrEmpty
        }
    }
    Context 'NonExistent' {
        It 'Returns nothing for non-existent folder' {
            $result = Get-CM7Folder -Path $script:TestFolderData.NonExistent.Path -ObjectType $script:TestFolderData.NonExistent.ObjectType
            $result | Should -BeNullOrEmpty
        }
    }
    Context 'RootFolders' {
        It 'Returns all root folders' {
            $result = Get-CM7Folder -ObjectType "DeviceCollection"
            $result | Should -Not -BeNullOrEmpty
        }
    }
}
