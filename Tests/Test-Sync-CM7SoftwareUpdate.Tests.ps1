# ============================================================================
# Tests for Sync-CM7SoftwareUpdate
# ============================================================================
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

Describe 'Sync-CM7SoftwareUpdate' {
    Context 'Connection Required' {
        It 'should throw when Connect-CM7 has not been called' {
            # Arrange - Backup and clear connection
            $backupConnection = $script:CMConnection.Clone()
            $script:CMConnection.CimSession = $null

            # Test that the function throws
            { Sync-CM7SoftwareUpdate -FullSync $false } | Should -Throw

            # Restore connection
            $script:CMConnection = $backupConnection
        }
    }
    Context 'Basic Sync' {
        It 'Should perform a delta sync without error' {
            $result = Sync-CM7SoftwareUpdate -FullSync $false
            $result | Should -Not -BeNullOrEmpty
        }
    }
    Context 'Full Sync' {
        It 'Should perform a full sync without error' {
            $result = Sync-CM7SoftwareUpdate -FullSync $true
            $result | Should -Not -BeNullOrEmpty
        }
    }
    Context 'ShouldProcess/WhatIf' {
        It 'Should support -WhatIf' {
            { Sync-CM7SoftwareUpdate -FullSync $false -WhatIf } | Should -Not -Throw
        }
    }
}
