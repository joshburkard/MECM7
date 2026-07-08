# Functional Tests for Get-CM7SoftwareUpdateSyncStatus
# Tests the Get-CM7SoftwareUpdateSyncStatus function behavior and return values

BeforeAll {
    # Load test declarations
    . (Join-Path $PSScriptRoot "declarations.ps1")

    # Load all functions
    $CodePath = Join-Path (Get-Item $PSScriptRoot).Parent.FullName "Code"
    Get-ChildItem -Path (Join-Path $CodePath "Private") -Filter "*.ps1" | ForEach-Object { . $_.FullName }
    Get-ChildItem -Path (Join-Path $CodePath "Public") -Filter "*.ps1" | ForEach-Object { . $_.FullName }

    # Get test data for this function
    $script:TestSyncStatusData = $script:TestData['Get-CM7SoftwareUpdateSyncStatus']
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

Describe "Get-CM7SoftwareUpdateSyncStatus Function Tests" -Tag "Integration", "SoftwareUpdateSyncStatus" {

    Context "Test Data Validation" {

        It "Should have test data defined in declarations.ps1" {
            # Assert
            $script:TestSyncStatusData | Should -Not -BeNullOrEmpty
            $script:TestData.ContainsKey('Get-CM7SoftwareUpdateSyncStatus') | Should -Be $true
        }

        It "Should have required test data parameter sets" {
            # Assert
            $script:TestSyncStatusData.ContainsKey('All') | Should -Be $true
        }

        It "Should output test data for verification" {
            # Output test data
            Write-Host "`n=== Test Data for Get-CM7SoftwareUpdateSyncStatus ===" -ForegroundColor Cyan
            Write-Host "All:" -ForegroundColor Yellow
            Write-Host "  ExpectedMinCount: $($script:TestSyncStatusData.All.ExpectedMinCount)" -ForegroundColor White
            Write-Host "  KnownLastSyncStates: $($script:TestSyncStatusData.All.KnownLastSyncStates -join ', ')" -ForegroundColor White
            Write-Host "============================================================`n" -ForegroundColor Cyan

            # This test always passes, it's just for output
            $true | Should -Be $true
        }
    }

    Context "Connection Requirement" {

        It "Should throw when not connected to MECM" {
            # Arrange - Backup and clear connection
            $backupConnection = $script:CMConnection.Clone()
            $script:CMConnection.CimSession = $null

            # Act & Assert
            { Get-CM7SoftwareUpdateSyncStatus } | Should -Throw

            # Restore connection
            $script:CMConnection = $backupConnection
        }
    }

    Context "Return Value" {

        It "Should return at least one sync status object" {
            # Act
            $result = Get-CM7SoftwareUpdateSyncStatus

            # Assert
            $result | Should -Not -BeNullOrEmpty
            @($result).Count | Should -BeGreaterOrEqual $script:TestSyncStatusData.All.ExpectedMinCount
        }

        It "Should return a CimInstance object" {
            # Act
            $result = Get-CM7SoftwareUpdateSyncStatus

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.GetType().Name | Should -Be 'CimInstance'
        }

        It "Should have a LastSyncState property" {
            # Act
            $result = Get-CM7SoftwareUpdateSyncStatus

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.PSObject.Properties['LastSyncState'] | Should -Not -BeNullOrEmpty
        }

        It "Should have a LastSyncStatus NoteProperty with a string value" {
            # Act
            $result = Get-CM7SoftwareUpdateSyncStatus

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $noteProperty = $result.PSObject.Properties['LastSyncStatus']
            $noteProperty | Should -Not -BeNullOrEmpty
            $noteProperty.MemberType | Should -Be 'NoteProperty'
            $noteProperty.Value | Should -BeOfType [string]
            $noteProperty.Value | Should -Not -BeNullOrEmpty
        }

        It "Should have a LastSyncStatus value that is a known sync state description" {
            # Arrange
            $knownStates = @(
                'WSUS Synchronization done (Success)',
                'WSUS Synchronization failed',
                'WSUS Synchronization in progress. Current phase: Synchronizing WSUS Server',
                'WSUS Synchronization in progress. Current phase: Synchronizing site database',
                'WSUS Synchronization in progress. Current phase: Synchronizing Internet facing WSUS Server',
                'Content of WSUS server is out of sync with upstream server',
                'WSUS synchronization complete, with pending license terms downloads',
                'Unknown'
            )

            # Act
            $result = Get-CM7SoftwareUpdateSyncStatus

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.LastSyncStatus | Should -BeIn $knownStates
        }
    }

    Context "Mock-based Unit Tests" {

        It "Should return null when no sync status is found" {
            # Arrange
            Mock Get-CimInstance { return $null }

            # Act
            $result = Get-CM7SoftwareUpdateSyncStatus

            # Assert
            $result | Should -BeNullOrEmpty
        }

        It "Should map LastSyncState <State> to '<Expected>'" -ForEach @(
            @{ State = 6702; Expected = 'WSUS Synchronization done (Success)' }
            @{ State = 6703; Expected = 'WSUS Synchronization failed' }
            @{ State = 6704; Expected = 'WSUS Synchronization in progress. Current phase: Synchronizing WSUS Server' }
            @{ State = 6705; Expected = 'WSUS Synchronization in progress. Current phase: Synchronizing site database' }
            @{ State = 6706; Expected = 'WSUS Synchronization in progress. Current phase: Synchronizing Internet facing WSUS Server' }
            @{ State = 6707; Expected = 'Content of WSUS server is out of sync with upstream server' }
            @{ State = 6708; Expected = 'WSUS synchronization complete, with pending license terms downloads' }
            @{ State = 9999; Expected = 'Unknown' }
        ) {
            # Arrange
            $testState = $State
            Mock Get-CimInstance { [PSCustomObject]@{ LastSyncState = $testState } }

            # Act
            $result = Get-CM7SoftwareUpdateSyncStatus

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.LastSyncStatus | Should -Be $Expected
        }
    }
}
