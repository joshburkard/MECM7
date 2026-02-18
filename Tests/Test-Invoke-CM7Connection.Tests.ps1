# Functional Tests for Invoke-CM7Connection (Private Helper Function)
# Tests the internal CIM session creation and SMS Provider discovery

BeforeAll {
    # Load test declarations
    . (Join-Path $PSScriptRoot "declarations.ps1")

    # Load all functions
    $CodePath = Join-Path (Get-Item $PSScriptRoot).Parent.FullName "Code"
    Get-ChildItem -Path (Join-Path $CodePath "Private") -Filter "*.ps1" | ForEach-Object { . $_.FullName }
    Get-ChildItem -Path (Join-Path $CodePath "Public") -Filter "*.ps1" | ForEach-Object { . $_.FullName }

    # Get test data for this function (uses Connect-CM7 test data since this is internal to Connect-CM7)
    $script:TestConnectData = $script:TestData['Connect-CM7']
}

Describe "Invoke-CM7Connection Function Tests" -Tag "Integration", "PrivateFunction", "Connection" {

    Context "Test Data Validation" {

        It "Should have test data defined in declarations.ps1" {
            # Assert
            $script:TestConnectData | Should -Not -BeNullOrEmpty
            $script:TestData.ContainsKey('Connect-CM7') | Should -Be $true
        }

        It "Should have valid and invalid test data parameter sets" {
            # Assert
            $script:TestConnectData.ContainsKey('Valid') | Should -Be $true
            $script:TestConnectData.ContainsKey('Invalid') | Should -Be $true
        }

        It "Should output test data for reference" {
            # Output test data
            Write-Host "`n=== Test Data for Invoke-CM7Connection ===" -ForegroundColor Cyan
            Write-Host "Valid SiteServer: $($script:TestConnectData.Valid.SiteServer)" -ForegroundColor Yellow
            Write-Host "Valid SkipCertificateCheck: $($script:TestConnectData.Valid.SkipCertificateCheck)" -ForegroundColor Yellow
            Write-Host "Invalid SiteServer: $($script:TestConnectData.Invalid.SiteServer)" -ForegroundColor Yellow
            Write-Host "============================================================`n" -ForegroundColor Cyan

            # This test always passes, it's just for output
            $true | Should -Be $true
        }
    }

    Context "Successful Connection with Real MECM Server" {

        It "Should create CIM session with valid credentials" {
            # Arrange
            $siteServer = $script:TestConnectData.Valid.SiteServer
            $credential = $script:TestConnectData.Valid.Credential
            $skipCert = $script:TestConnectData.Valid.SkipCertificateCheck

            # Act
            $result = Invoke-CM7Connection -SiteServer $siteServer -Credential $credential -SkipCertificateCheck:$skipCert

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.CimSession | Should -Not -BeNullOrEmpty
            $result.SiteCode | Should -Not -BeNullOrEmpty
            $result.ProviderMachineName | Should -Not -BeNullOrEmpty

            # Cleanup
            if ($result.CimSession) {
                Remove-CimSession -CimSession $result.CimSession -ErrorAction SilentlyContinue
            }
        }

        It "Should return PSCustomObject with correct properties" {
            # Arrange
            $siteServer = $script:TestConnectData.Valid.SiteServer
            $credential = $script:TestConnectData.Valid.Credential
            $skipCert = $script:TestConnectData.Valid.SkipCertificateCheck

            # Act
            $result = Invoke-CM7Connection -SiteServer $siteServer -Credential $credential -SkipCertificateCheck:$skipCert

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.PSObject.Properties.Name | Should -Contain 'CimSession'
            $result.PSObject.Properties.Name | Should -Contain 'SiteCode'
            $result.PSObject.Properties.Name | Should -Contain 'ProviderMachineName'

            # Cleanup
            if ($result.CimSession) {
                Remove-CimSession -CimSession $result.CimSession -ErrorAction SilentlyContinue
            }
        }

        It "Should return valid SiteCode (3 character format)" {
            # Arrange
            $siteServer = $script:TestConnectData.Valid.SiteServer
            $credential = $script:TestConnectData.Valid.Credential
            $skipCert = $script:TestConnectData.Valid.SkipCertificateCheck

            # Act
            $result = Invoke-CM7Connection -SiteServer $siteServer -Credential $credential -SkipCertificateCheck:$skipCert

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.SiteCode | Should -Not -BeNullOrEmpty
            $result.SiteCode | Should -Match "^[A-Z0-9]{3}$"

            Write-Host "Connected to Site Code: $($result.SiteCode)" -ForegroundColor Green

            # Cleanup
            if ($result.CimSession) {
                Remove-CimSession -CimSession $result.CimSession -ErrorAction SilentlyContinue
            }
        }

        It "Should return valid ProviderMachineName" {
            # Arrange
            $siteServer = $script:TestConnectData.Valid.SiteServer
            $credential = $script:TestConnectData.Valid.Credential
            $skipCert = $script:TestConnectData.Valid.SkipCertificateCheck

            # Act
            $result = Invoke-CM7Connection -SiteServer $siteServer -Credential $credential -SkipCertificateCheck:$skipCert

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.ProviderMachineName | Should -Not -BeNullOrEmpty
            $result.ProviderMachineName | Should -BeOfType [string]

            Write-Host "SMS Provider Machine: $($result.ProviderMachineName)" -ForegroundColor Green

            # Cleanup
            if ($result.CimSession) {
                Remove-CimSession -CimSession $result.CimSession -ErrorAction SilentlyContinue
            }
        }
    }

    Context "CimSession Validation" {

        It "Should return valid CimSession object that can query WMI" {
            # Arrange
            $siteServer = $script:TestConnectData.Valid.SiteServer
            $credential = $script:TestConnectData.Valid.Credential
            $skipCert = $script:TestConnectData.Valid.SkipCertificateCheck

            # Act
            $result = Invoke-CM7Connection -SiteServer $siteServer -Credential $credential -SkipCertificateCheck:$skipCert

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.CimSession | Should -Not -BeNullOrEmpty
            $result.CimSession.Id | Should -Not -BeNullOrEmpty
            $result.CimSession.ComputerName | Should -Not -BeNullOrEmpty

            # Verify CimSession can query SMS Provider Location
            $testQuery = Get-CimInstance -CimSession $result.CimSession -Namespace "root\SMS" -ClassName "SMS_ProviderLocation" -ErrorAction SilentlyContinue
            $testQuery | Should -Not -BeNullOrEmpty

            # Cleanup
            if ($result.CimSession) {
                Remove-CimSession -CimSession $result.CimSession -ErrorAction SilentlyContinue
            }
        }

        It "Should create unique CimSession on each call" {
            # Arrange
            $siteServer = $script:TestConnectData.Valid.SiteServer
            $credential = $script:TestConnectData.Valid.Credential
            $skipCert = $script:TestConnectData.Valid.SkipCertificateCheck

            # Act
            $result1 = Invoke-CM7Connection -SiteServer $siteServer -Credential $credential -SkipCertificateCheck:$skipCert
            $result2 = Invoke-CM7Connection -SiteServer $siteServer -Credential $credential -SkipCertificateCheck:$skipCert

            # Assert
            $result1 | Should -Not -BeNullOrEmpty
            $result2 | Should -Not -BeNullOrEmpty
            $result1.CimSession.Id | Should -Not -Be $result2.CimSession.Id

            Write-Host "Created two unique sessions: $($result1.CimSession.Id) and $($result2.CimSession.Id)" -ForegroundColor Green

            # Cleanup
            if ($result1.CimSession) {
                Remove-CimSession -CimSession $result1.CimSession -ErrorAction SilentlyContinue
            }
            if ($result2.CimSession) {
                Remove-CimSession -CimSession $result2.CimSession -ErrorAction SilentlyContinue
            }
        }
    }

    Context "SSL and Certificate Options" {

        It "Should accept SkipCertificateCheck parameter" {
            # Arrange
            $siteServer = $script:TestConnectData.Valid.SiteServer
            $credential = $script:TestConnectData.Valid.Credential
            $skipCert = $script:TestConnectData.Valid.SkipCertificateCheck

            # Act
            $result = Invoke-CM7Connection -SiteServer $siteServer -Credential $credential -SkipCertificateCheck:$skipCert

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.CimSession | Should -Not -BeNullOrEmpty

            # Cleanup
            if ($result.CimSession) {
                Remove-CimSession -CimSession $result.CimSession -ErrorAction SilentlyContinue
            }
        }

        It "Should accept UseSsl parameter" -Skip {
            # Arrange
            $siteServer = $script:TestConnectData.Valid.SiteServer
            $credential = $script:TestConnectData.Valid.Credential
            $skipCert = $script:TestConnectData.Valid.SkipCertificateCheck

            # Act
            $result = Invoke-CM7Connection -SiteServer $siteServer -Credential $credential -UseSsl -SkipCertificateCheck:$skipCert

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.CimSession | Should -Not -BeNullOrEmpty

            # Cleanup
            if ($result.CimSession) {
                Remove-CimSession -CimSession $result.CimSession -ErrorAction SilentlyContinue
            }
        }
    }

    Context "Error Handling" {

        It "Should throw error when connecting to invalid server" {
            # Arrange
            $invalidServer = $script:TestConnectData.Invalid.SiteServer

            # Act & Assert
            { Invoke-CM7Connection -SiteServer $invalidServer -ErrorAction Stop } | Should -Throw
        }

        It "Should throw error with invalid server name in message" {
            # Arrange
            $invalidServer = $script:TestConnectData.Invalid.SiteServer

            # Act & Assert
            { Invoke-CM7Connection -SiteServer $invalidServer -ErrorAction Stop } | Should -Throw "*Failed to create CIM session*"
        }
    }

    Context "Parameter Validation" {

        It "Should require SiteServer parameter" {
            # Verify parameter is mandatory
            $command = Get-Command Invoke-CM7Connection
            $siteServerParam = $command.Parameters['SiteServer']
            $siteServerParam.Attributes | Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] } | ForEach-Object {
                $_.Mandatory | Should -Be $true
            }
        }

        It "Should accept optional Credential parameter" {
            # Verify parameter exists and is optional
            $command = Get-Command Invoke-CM7Connection
            $command.Parameters.Keys | Should -Contain 'Credential'
            $credParam = $command.Parameters['Credential']
            $credParam.Attributes | Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] } | ForEach-Object {
                $_.Mandatory | Should -Be $false
            }
        }

        It "Should accept optional UseSsl switch" {
            # Verify parameter exists
            $command = Get-Command Invoke-CM7Connection
            $command.Parameters.Keys | Should -Contain 'UseSsl'
        }

        It "Should accept optional SkipCertificateCheck switch" {
            # Verify parameter exists
            $command = Get-Command Invoke-CM7Connection
            $command.Parameters.Keys | Should -Contain 'SkipCertificateCheck'
        }
    }

    Context "Function Documentation" {

        It "Should have help documentation" {
            # Arrange & Act
            $help = Get-Help Invoke-CM7Connection -ErrorAction SilentlyContinue

            # Assert
            $help.Synopsis | Should -Not -BeNullOrEmpty
        }

        It "Should document parameters in help" {
            # Arrange & Act
            $help = Get-Help Invoke-CM7Connection -Full -ErrorAction SilentlyContinue

            # Assert
            $help.Parameters | Should -Not -BeNullOrEmpty
        }
    }
}

AfterAll {
    # Clean up any remaining CIM sessions from this test run
    $sessions = Get-CimSession -ErrorAction SilentlyContinue
    if ($sessions) {
        $sessions | Remove-CimSession -ErrorAction SilentlyContinue
    }
}
