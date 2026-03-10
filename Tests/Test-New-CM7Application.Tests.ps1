# Functional Tests for New-CM7Application
# Tests the New-CM7Application function behavior and return values
#
# NOTE: SMS_Application deletion requires two steps (unlike other SCCM WMI classes):
#   1. Retire:  Invoke-CimMethod -MethodName SetIsExpired -Arguments @{Expired=$true}
#   2. Delete:  Remove-CimInstance

BeforeAll {
    # Load test declarations
    . (Join-Path $PSScriptRoot "declarations.ps1")

    # Load all functions
    $CodePath = Join-Path (Get-Item $PSScriptRoot).Parent.FullName "Code"
    Get-ChildItem -Path (Join-Path $CodePath "Private") -Filter "*.ps1" | ForEach-Object { . $_.FullName }
    Get-ChildItem -Path (Join-Path $CodePath "Public") -Filter "*.ps1" | ForEach-Object { . $_.FullName }

    # Get test data for this function
    $script:TestAppData    = $script:TestData['New-CM7Application']
    $script:TestConnectData = $script:TestData['Connect-CM7']

    # Track created application CI_IDs for cleanup
    $script:CreatedAppIds = @()

    # Build connection parameters
    $connectParams = @{
        SiteServer = $script:TestConnectData.Valid.SiteServer
        Credential = $script:TestConnectData.Valid.Credential
    }
    if ($script:TestConnectData.Valid.SkipCertificateCheck) { $connectParams.SkipCertificateCheck = $true }
    if ($script:TestConnectData.Valid.UseSsl)                { $connectParams.UseSsl                = $true }

    Connect-CM7 @connectParams
}

# Helper: retire + delete an SMS_Application by CI_ID
function Remove-CM7ApplicationById {
    param([int]$CI_ID)
    $ns      = "root/SMS/site_$($script:CMConnection.SiteCode)"
    $session = $script:CMConnection.CimSession
    try {
        # Step 1 – retire (required before WMI deletion for SMS_Application)
        Invoke-CimMethod -CimSession $session -Namespace $ns `
            -Query "SELECT * FROM SMS_Application WHERE CI_ID = $CI_ID AND IsLatest = 1" `
            -MethodName SetIsExpired -Arguments @{ Expired = $true } -ErrorAction SilentlyContinue | Out-Null
        # Step 2 – delete all versions
        Remove-CimInstance -CimSession $session -Namespace $ns `
            -Query "SELECT * FROM SMS_Application WHERE CI_ID = $CI_ID" -ErrorAction SilentlyContinue
    } catch {
        Write-Warning "  Failed to remove application CI_ID $CI_ID : $_"
    }
}

Describe 'New-CM7Application Function Tests' -Tag 'Integration', 'Application', 'New' {

    # ──────────────────────────────────────────────────────────────────────────
    Context 'Test Data Validation' {

        It 'Should have test data defined in declarations.ps1' {
            $script:TestAppData | Should -Not -BeNullOrEmpty
            $script:TestData.ContainsKey('New-CM7Application') | Should -Be $true
        }

        It 'Should have required test data parameter sets' {
            $script:TestAppData.ContainsKey('Basic')     | Should -Be $true
            $script:TestAppData.ContainsKey('Duplicate') | Should -Be $true
        }

        It 'Should output test data for verification' {
            Write-Host "`n=== Test Data for New-CM7Application ===" -ForegroundColor Cyan
            Write-Host 'Basic:' -ForegroundColor Yellow
            $script:TestAppData.Basic.GetEnumerator() | ForEach-Object {
                Write-Host ("  {0}: {1}" -f $_.Key, $_.Value) -ForegroundColor White
            }
            Write-Host 'Duplicate:' -ForegroundColor Yellow
            $script:TestAppData.Duplicate.GetEnumerator() | ForEach-Object {
                Write-Host ("  {0}: {1}" -f $_.Key, $_.Value) -ForegroundColor White
            }
            Write-Host "============================================================`n" -ForegroundColor Cyan
            $true | Should -Be $true
        }
    }

    # ──────────────────────────────────────────────────────────────────────────
    Context 'Connection Requirement' {

        It 'Should fail if not connected to MECM' {
            $backupConnection           = $script:CMConnection.Clone()
            $script:CMConnection.CimSession = $null
            { New-CM7Application -Name 'X' -Publisher 'P' -SoftwareVersion '1.0' } |
                Should -Throw "*not connected*"
            $script:CMConnection = $backupConnection
        }
    }

    # ──────────────────────────────────────────────────────────────────────────
    Context 'Create Basic Application' {

        It 'Should create an application with mandatory parameters only' {
            # Arrange – unique name to avoid collisions with existing apps
            $uniqueName = "PESTER_APP_Basic_$(Get-Date -Format 'yyyyMMddHHmmss')"

            # Act
            $result = New-CM7Application -Name $uniqueName `
                -Publisher $script:TestAppData.Basic.Publisher `
                -SoftwareVersion $script:TestAppData.Basic.SoftwareVersion

            # Assert
            $result                      | Should -Not -BeNullOrEmpty
            $result.CI_ID                | Should -BeGreaterThan 0
            $result.LocalizedDisplayName | Should -Be $uniqueName
            $result.Manufacturer         | Should -Be $script:TestAppData.Basic.Publisher
            $result.SoftwareVersion      | Should -Be $script:TestAppData.Basic.SoftwareVersion

            # Track for cleanup
            $script:CreatedAppIds += $result.CI_ID
        }

        It 'Should create an application with all advanced parameters' {
            # Arrange
            $uniqueName = "PESTER_APP_Full_$(Get-Date -Format 'yyyyMMddHHmmss')"
            $params     = $script:TestAppData.Basic.Clone()
            $params['Name'] = $uniqueName

            # Act
            $result = New-CM7Application @params

            # Assert – properties accessible via WMI after creation
            $result                      | Should -Not -BeNullOrEmpty
            $result.CI_ID                | Should -BeGreaterThan 0
            $result.LocalizedDisplayName | Should -Be $uniqueName
            $result.Manufacturer         | Should -Be $params.Publisher
            $result.SoftwareVersion      | Should -Be $params.SoftwareVersion
            $result.IsEnabled            | Should -Be $params.IsEnabled
            $result.IsHidden             | Should -Be $params.IsHidden
            $result.IsLatest             | Should -Be $true

            # Track for cleanup
            $script:CreatedAppIds += $result.CI_ID
        }
    }

    # ──────────────────────────────────────────────────────────────────────────
    Context 'Return Object Properties' {

        It 'Should return an object with the expected standard properties' {
            # Arrange
            $uniqueName = "PESTER_APP_Props_$(Get-Date -Format 'yyyyMMddHHmmss')"

            # Act
            $result = New-CM7Application -Name $uniqueName `
                -Publisher 'TestPub' -SoftwareVersion '1.0' -Description 'Property check'

            # Assert – property names are present
            $result | Should -Not -BeNullOrEmpty
            $result.PSObject.Properties.Name | Should -Contain 'CI_ID'
            $result.PSObject.Properties.Name | Should -Contain 'CI_UniqueID'
            $result.PSObject.Properties.Name | Should -Contain 'LocalizedDisplayName'
            $result.PSObject.Properties.Name | Should -Contain 'Manufacturer'
            $result.PSObject.Properties.Name | Should -Contain 'SoftwareVersion'
            $result.PSObject.Properties.Name | Should -Contain 'IsEnabled'
            $result.PSObject.Properties.Name | Should -Contain 'IsHidden'
            $result.PSObject.Properties.Name | Should -Contain 'IsDeployed'
            $result.PSObject.Properties.Name | Should -Contain 'IsExpired'
            $result.PSObject.Properties.Name | Should -Contain 'IsLatest'
            $result.PSObject.Properties.Name | Should -Contain 'DateCreated'
            $result.PSObject.Properties.Name | Should -Contain 'DateLastModified'
            $result.PSObject.Properties.Name | Should -Contain 'NumberOfDeploymentTypes'
            $result.PSObject.Properties.Name | Should -Contain 'NumberOfDeployments'

            # Track for cleanup
            $script:CreatedAppIds += $result.CI_ID
        }

        It 'Should have the PSTypeName set to MECM7.Application' {
            # Arrange
            $uniqueName = "PESTER_APP_Type_$(Get-Date -Format 'yyyyMMddHHmmss')"

            # Act
            $result = New-CM7Application -Name $uniqueName -Publisher 'TestPub' -SoftwareVersion '1.0'

            # Assert
            if ($result) {
                $result.PSObject.TypeNames[0] | Should -Be 'MECM7.Application'
            }

            # Track for cleanup
            if ($result) { $script:CreatedAppIds += $result.CI_ID }
        }

        It 'Should have correct default values for a new empty application' {
            # Arrange
            $uniqueName = "PESTER_APP_Defaults_$(Get-Date -Format 'yyyyMMddHHmmss')"

            # Act
            $result = New-CM7Application -Name $uniqueName -Publisher 'TestPub' -SoftwareVersion '1.0'

            # Assert
            $result.IsEnabled            | Should -Be $true
            $result.IsHidden             | Should -Be $false
            $result.IsDeployed           | Should -Be $false
            $result.IsExpired            | Should -Be $false
            $result.IsLatest             | Should -Be $true
            $result.NumberOfDeployments  | Should -Be 0

            # Track for cleanup
            $script:CreatedAppIds += $result.CI_ID
        }
    }

    # ──────────────────────────────────────────────────────────────────────────
    Context 'Error Handling' {

        It 'Should throw for a duplicate application name' {
            # Arrange – create the first instance, then attempt a duplicate
            $uniqueName = "PESTER_APP_Dup_$(Get-Date -Format 'yyyyMMddHHmmss')"
            $first = New-CM7Application -Name $uniqueName -Publisher 'TestPub' -SoftwareVersion '1.0'
            $script:CreatedAppIds += $first.CI_ID

            # Act & Assert
            { New-CM7Application -Name $uniqueName -Publisher 'TestPub' -SoftwareVersion '1.0' } |
                Should -Throw "*already exists*"
        }
    }

    # ──────────────────────────────────────────────────────────────────────────
    Context 'Verbose Output' {

        It 'Should provide verbose output when -Verbose is used' {
            # Arrange
            $uniqueName = "PESTER_APP_Verbose_$(Get-Date -Format 'yyyyMMddHHmmss')"

            # Act
            $verboseOutput = New-CM7Application -Name $uniqueName `
                -Publisher 'TestPub' -SoftwareVersion '1.0' -Verbose 4>&1

            # Assert
            $verboseOutput | Should -Not -BeNullOrEmpty
            $verboseMessages = $verboseOutput | Where-Object { $_ -is [System.Management.Automation.VerboseRecord] }
            ($verboseMessages | Where-Object { $_.Message -match 'Running New-CM7Application' }) |
                Should -Not -BeNullOrEmpty

            # Track for cleanup
            $resultObj = $verboseOutput | Where-Object { $_ -isnot [System.Management.Automation.VerboseRecord] }
            if ($resultObj -and $resultObj.CI_ID) { $script:CreatedAppIds += $resultObj.CI_ID }
        }
    }
}

AfterAll {
    # Clean up: retire + delete all test applications created during this run.
    # SMS_Application requires SetIsExpired(Expired=true) before Remove-CimInstance succeeds.
    if ($script:CMConnection.CimSession -and $script:CreatedAppIds.Count -gt 0) {
        $uniqueIds = $script:CreatedAppIds | Select-Object -Unique
        Write-Host "Test cleanup: Removing $($uniqueIds.Count) test application(s)" -ForegroundColor Yellow
        foreach ($id in $uniqueIds) {
            $ns      = "root/SMS/site_$($script:CMConnection.SiteCode)"
            $session = $script:CMConnection.CimSession
            try {
                # Step 1 – retire (required before WMI deletion for SMS_Application)
                Invoke-CimMethod -CimSession $session -Namespace $ns `
                    -Query "SELECT * FROM SMS_Application WHERE CI_ID = $id AND IsLatest = 1" `
                    -MethodName SetIsExpired -Arguments @{ Expired = $true } -ErrorAction SilentlyContinue | Out-Null
                # Step 2 – delete all versions
                Remove-CimInstance -CimSession $session -Namespace $ns `
                    -Query "SELECT * FROM SMS_Application WHERE CI_ID = $id" -ErrorAction SilentlyContinue
            } catch {
                Write-Warning "  Failed to remove application CI_ID $id : $_"
            }
            Write-Host "  Removed application CI_ID: $id" -ForegroundColor Green
        }
        Write-Host 'Test cleanup: Done' -ForegroundColor Green
    }
}
