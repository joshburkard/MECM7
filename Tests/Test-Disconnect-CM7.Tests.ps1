# Functional Tests for Disconnect-CM7
# Tests the Disconnect-CM7 function behavior and return values

BeforeAll {
    # Load test declarations
    . (Join-Path $PSScriptRoot "declarations.ps1")

    # Load all functions
    $CodePath = Join-Path (Get-Item $PSScriptRoot).Parent.FullName "Code"
    Get-ChildItem -Path (Join-Path $CodePath "Private") -Filter "*.ps1" | ForEach-Object { . $_.FullName }
    Get-ChildItem -Path (Join-Path $CodePath "Public") -Filter "*.ps1" | ForEach-Object { . $_.FullName }

    # Get test data for Connect-CM7 (needed to establish a connection before disconnecting)
    $script:TestConnectData = $script:TestData['Connect-CM7']
}

Describe "Disconnect-CM7 Function Tests" -Tag "Integration", "Connection" {

    Context "Disconnection Behavior" {

        BeforeEach {
            # Establish a connection before each test that needs one
            Connect-CM7 -SiteServer $script:TestConnectData.Valid.SiteServer `
                        -Credential $script:TestConnectData.Valid.Credential `
                        -SkipCertificateCheck:$script:TestConnectData.Valid.SkipCertificateCheck
        }

        It "Should disconnect successfully when a connection exists" {
            # Act & Assert
            { Disconnect-CM7 } | Should -Not -Throw
        }

        It "Should clear SiteServer from script connection variable" {
            # Act
            Disconnect-CM7

            # Assert
            $script:CMConnection.SiteServer | Should -BeNullOrEmpty
        }

        It "Should clear CimSession from script connection variable" {
            # Act
            Disconnect-CM7

            # Assert
            $script:CMConnection.CimSession | Should -BeNullOrEmpty
        }

        It "Should clear SiteCode from script connection variable" {
            # Act
            Disconnect-CM7

            # Assert
            $script:CMConnection.SiteCode | Should -BeNullOrEmpty
        }

        It "Should clear ProviderMachineName from script connection variable" {
            # Act
            Disconnect-CM7

            # Assert
            $script:CMConnection.ProviderMachineName | Should -BeNullOrEmpty
        }

        It "Should clear Credential from script connection variable" {
            # Act
            Disconnect-CM7

            # Assert
            $script:CMConnection.Credential | Should -BeNullOrEmpty
        }

        It "Should reset SkipCertificateCheck to false" {
            # Act
            Disconnect-CM7

            # Assert
            $script:CMConnection.SkipCertificateCheck | Should -Be $false
        }

        It "Should reset UseSsl to false" {
            # Act
            Disconnect-CM7

            # Assert
            $script:CMConnection.UseSsl | Should -Be $false
        }

        It "Should reset AddToTrustedHosts to false" {
            # Act
            Disconnect-CM7

            # Assert
            $script:CMConnection.AddToTrustedHosts | Should -Be $false
        }

        It "Should output a success message containing the server name" {
            # Arrange
            $serverName = $script:CMConnection.SiteServer

            # Act
            $output = Disconnect-CM7

            # Assert
            $output | Should -Match $serverName
        }
    }

    Context "Disconnection Without Active Connection" {

        BeforeEach {
            # Ensure no active connection
            $script:CMConnection = @{
                SiteServer           = $null
                CimSession           = $null
                SiteCode             = $null
                ProviderMachineName  = $null
                Credential           = $null
                SkipCertificateCheck = $false
                UseSsl               = $false
                AddToTrustedHosts    = $false
            }
        }

        It "Should not throw when no active connection exists" {
            # Act & Assert
            { Disconnect-CM7 } | Should -Not -Throw
        }

        It "Should write a warning when no active connection exists" {
            # Act & Assert
            Disconnect-CM7 3>&1 | Should -Match "No active CM7 connection"
        }
    }
}

Describe "Disconnect-CM7 Parameter Validation" -Tag "Unit" {

    Context "Parameter Metadata" {

        It "Should have no mandatory parameters" {
            # Get the command metadata
            $command = Get-Command Disconnect-CM7
            $mandatoryParams = $command.Parameters.Values | Where-Object {
                $_.Attributes | Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] -and $_.Mandatory }
            }

            # Assert
            $mandatoryParams | Should -BeNullOrEmpty
        }

        It "Should support CmdletBinding" {
            # Get the command metadata
            $command = Get-Command Disconnect-CM7

            # Assert
            $command | Should -Not -BeNullOrEmpty
            $command.CmdletBinding | Should -Be $true
        }
    }
}
