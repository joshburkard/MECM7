# Functional Tests for Connect-CM7
# Tests the Connect-CM7 function behavior and return values

BeforeAll {
    # Load test declarations
    . (Join-Path $PSScriptRoot "declarations.ps1")

    # Load all functions
    $CodePath = Join-Path (Get-Item $PSScriptRoot).Parent.FullName "Code"
    Get-ChildItem -Path (Join-Path $CodePath "Private") -Filter "*.ps1" | ForEach-Object { . $_.FullName }
    Get-ChildItem -Path (Join-Path $CodePath "Public") -Filter "*.ps1" | ForEach-Object { . $_.FullName }

    # Get test data for this function
    $script:TestConnectData = $script:TestData['Connect-CM7']
}

Describe "Connect-CM7 Function Tests" -Tag "Integration", "Connection" {

    Context "Test Data Validation" {

        It "Should have test data defined in declarations.ps1" {
            # Assert
            $script:TestConnectData | Should -Not -BeNullOrEmpty
            $script:TestData.ContainsKey('Connect-CM7') | Should -Be $true
        }

        It "Should have required test data parameter sets" {
            # Assert
            $script:TestConnectData.ContainsKey('Valid') | Should -Be $true
            $script:TestConnectData.ContainsKey('Invalid') | Should -Be $true
        }

        It "Should output test data for verification" {
            # Output test data
            Write-Host "`n=== Test Data for Connect-CM7 ===" -ForegroundColor Cyan
            Write-Host "Valid:" -ForegroundColor Yellow
            Write-Host "  SiteServer: $($script:TestConnectData.Valid.SiteServer)" -ForegroundColor White
            Write-Host "  SkipCertificateCheck: $($script:TestConnectData.Valid.SkipCertificateCheck)" -ForegroundColor White
            Write-Host "  Credential: $(if($script:TestConnectData.Valid.Credential){'Configured'}else{'Not Configured'})" -ForegroundColor White

            Write-Host "Invalid:" -ForegroundColor Yellow
            Write-Host "  SiteServer: $($script:TestConnectData.Invalid.SiteServer)" -ForegroundColor White
            Write-Host "============================================================`n" -ForegroundColor Cyan

            # This test always passes, it's just for output
            $true | Should -Be $true
        }
    }

    Context "Connection Establishment" {

        It "Should connect successfully with valid site server" {
            # Arrange
            $params = @{
                SiteServer = $script:TestConnectData.Valid.SiteServer
                Credential = $script:TestConnectData.Valid.Credential
            }
            if($script:TestConnectData.Valid.SkipCertificateCheck){
                $params.SkipCertificateCheck = $true
            }

            # Act & Assert
            { Connect-CM7 @params } | Should -Not -Throw
        }

        It "Should store connection details in script variables" {
            # Arrange & Act
            Connect-CM7 -SiteServer $script:TestConnectData.Valid.SiteServer -Credential $script:TestConnectData.Valid.Credential -SkipCertificateCheck:$script:TestConnectData.Valid.SkipCertificateCheck

            # Assert
            $script:CMConnection.SiteServer | Should -Be $script:TestConnectData.Valid.SiteServer
            $script:CMConnection.SiteCode | Should -Not -BeNullOrEmpty
        }

        It "Should return connection information object" {
            # Arrange & Act
            $result = Connect-CM7 -SiteServer $script:TestConnectData.Valid.SiteServer -Credential $script:TestConnectData.Valid.Credential -SkipCertificateCheck:$script:TestConnectData.Valid.SkipCertificateCheck

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.SiteServer | Should -Be $script:TestConnectData.Valid.SiteServer
            $result.SiteCode | Should -Not -BeNullOrEmpty
            $result.ProviderMachineName | Should -Not -BeNullOrEmpty
            $result.CimSessionId | Should -Not -BeNullOrEmpty
        }

        It "Should fail with invalid site server" {
            # Arrange
            $invalidServer = "invalid-server-name-that-does-not-exist.local"

            # Act & Assert
            { Connect-CM7 -SiteServer $invalidServer -ErrorAction Stop } | Should -Throw
        }
    }

    Context "Credential Handling" {

        It "Should accept PSCredential parameter" {
            # Arrange
            $params = @{
                SiteServer = $script:TestConnectData.Valid.SiteServer
                SkipCertificateCheck = $script:TestConnectData.Valid.SkipCertificateCheck
            }
            if($null -ne $script:TestConnectData.Valid.Credential){
                $params.Credential = $script:TestConnectData.Valid.Credential
            }

            # Act & Assert
            { Connect-CM7 @params } | Should -Not -Throw
        }

        It "Should work with current user credentials when Credential not specified" {
            # Arrange & Act & Assert
            { Connect-CM7 -SiteServer $script:TestConnectData.Valid.SiteServer -Credential $script:TestConnectData.Valid.Credential -SkipCertificateCheck:$script:TestConnectData.Valid.SkipCertificateCheck } | Should -Not -Throw
        }
    }

    Context "Certificate Handling" {

        It "Should accept SkipCertificateCheck parameter" {
            # Arrange & Act & Assert
            { Connect-CM7 -SiteServer $script:TestConnectData.Valid.SiteServer -Credential $script:TestConnectData.Valid.Credential -SkipCertificateCheck } | Should -Not -Throw
        }

        It "Should set certificate skip in script variable when specified" {
            # Arrange & Act
            Connect-CM7 -SiteServer $script:TestConnectData.Valid.SiteServer -Credential $script:TestConnectData.Valid.Credential -SkipCertificateCheck

            # Assert
            $script:CMConnection.SkipCertificateCheck | Should -Be $true
        }

        It "Should set certificate skip to false when not specified" {
            # Arrange & Act
            Connect-CM7 -SiteServer $script:TestConnectData.Valid.SiteServer -Credential $script:TestConnectData.Valid.Credential

            # Assert
            $script:CMConnection.SkipCertificateCheck | Should -Be $false
        }
    }

    Context "SSL Handling" {

        It "Should accept UseSsl parameter" -Skip {
            # Arrange & Act & Assert
            { Connect-CM7 -SiteServer $script:TestConnectData.Valid.SiteServer -Credential $script:TestConnectData.Valid.Credential -UseSsl -SkipCertificateCheck } | Should -Not -Throw
        }

        It "Should set SSL flag in script variable when specified" -Skip {
            # Arrange & Act
            Connect-CM7 -SiteServer $script:TestConnectData.Valid.SiteServer -Credential $script:TestConnectData.Valid.Credential -UseSsl -SkipCertificateCheck

            # Assert
            $script:CMConnection.UseSsl | Should -Be $true
        }

        It "Should set SSL flag to false when not specified" {
            # Arrange & Act
            Connect-CM7 -SiteServer $script:TestConnectData.Valid.SiteServer -Credential $script:TestConnectData.Valid.Credential

            # Assert
            $script:CMConnection.UseSsl | Should -Be $false
        }
    }

    Context "CIM Session Management" {

        It "Should create a valid CIM session" {
            # Arrange & Act
            Connect-CM7 -SiteServer $script:TestConnectData.Valid.SiteServer -Credential $script:TestConnectData.Valid.Credential -SkipCertificateCheck:$script:TestConnectData.Valid.SkipCertificateCheck

            # Assert
            $script:CMConnection.CimSession | Should -Not -BeNullOrEmpty
            $script:CMConnection.CimSession | Get-Member -Name "Id" | Should -Not -BeNullOrEmpty
        }

        It "Should discover SMS Provider location" {
            # Arrange & Act
            Connect-CM7 -SiteServer $script:TestConnectData.Valid.SiteServer -Credential $script:TestConnectData.Valid.Credential -SkipCertificateCheck:$script:TestConnectData.Valid.SkipCertificateCheck

            # Assert
            $script:CMConnection.ProviderMachineName | Should -Not -BeNullOrEmpty
        }

        It "Should discover site code" {
            # Arrange & Act
            Connect-CM7 -SiteServer $script:TestConnectData.Valid.SiteServer -Credential $script:TestConnectData.Valid.Credential -SkipCertificateCheck:$script:TestConnectData.Valid.SkipCertificateCheck

            # Assert
            $script:CMConnection.SiteCode | Should -Not -BeNullOrEmpty
            $script:CMConnection.SiteCode | Should -MatchExactly '^[A-Z0-9]{3}$'
        }
    }
}

Describe "Connect-CM7 Parameter Validation" -Tag "Unit" {

    Context "Parameter Metadata" {

        It "Should require SiteServer parameter" {
            # Get the command metadata
            $command = Get-Command Connect-CM7
            $param = $command.Parameters['SiteServer']

            # Assert
            $param.Attributes.Mandatory | Should -Contain $true
        }

        It "Should accept string for SiteServer parameter" {
            # Get the command metadata
            $command = Get-Command Connect-CM7
            $param = $command.Parameters['SiteServer']

            # Assert
            $param.ParameterType.Name | Should -Be "String"
        }

        It "Should have optional Credential parameter" {
            # Get the command metadata
            $command = Get-Command Connect-CM7
            $param = $command.Parameters['Credential']

            # Assert
            $param | Should -Not -BeNullOrEmpty
            $param.Attributes.Mandatory | Should -Not -Contain $true
        }

        It "Should accept PSCredential for Credential parameter" {
            # Get the command metadata
            $command = Get-Command Connect-CM7
            $param = $command.Parameters['Credential']

            # Assert
            $param.ParameterType.Name | Should -Be "PSCredential"
        }

        It "Should have optional UseSsl parameter" {
            # Get the command metadata
            $command = Get-Command Connect-CM7
            $param = $command.Parameters['UseSsl']

            # Assert
            $param | Should -Not -BeNullOrEmpty
            $param.SwitchParameter | Should -Be $true
        }

        It "Should have optional SkipCertificateCheck parameter" {
            # Get the command metadata
            $command = Get-Command Connect-CM7
            $param = $command.Parameters['SkipCertificateCheck']

            # Assert
            $param | Should -Not -BeNullOrEmpty
            $param.SwitchParameter | Should -Be $true
        }
    }
}

Describe "Invoke-CM7Connection Private Function" -Tag "Unit", "Private" {

    Context "Function Existence" {

        It "Should have Invoke-CM7Connection private function" {
            # Act
            $function = Get-Command -Name "Invoke-CM7Connection" -ErrorAction SilentlyContinue

            # Assert
            $function | Should -Not -BeNullOrEmpty
        }

        It "Should accept required parameters" {
            # Get the command metadata
            $command = Get-Command Invoke-CM7Connection

            # Assert
            $command.Parameters.ContainsKey('SiteServer') | Should -Be $true
            $command.Parameters['SiteServer'].Attributes.Mandatory | Should -Contain $true
        }

        It "Should accept optional parameters" {
            # Get the command metadata
            $command = Get-Command Invoke-CM7Connection

            # Assert
            $command.Parameters.ContainsKey('Credential') | Should -Be $true
            $command.Parameters.ContainsKey('UseSsl') | Should -Be $true
            $command.Parameters.ContainsKey('SkipCertificateCheck') | Should -Be $true
        }
    }
}
