# Functional Tests for Get-CM7User
# Tests the Get-CM7User function behavior and return values

BeforeAll {
    # Load test declarations
    . (Join-Path $PSScriptRoot "declarations.ps1")

    # Load all functions
    $CodePath = Join-Path (Get-Item $PSScriptRoot).Parent.FullName "Code"
    Get-ChildItem -Path (Join-Path $CodePath "Private") -Filter "*.ps1" | ForEach-Object { . $_.FullName }
    Get-ChildItem -Path (Join-Path $CodePath "Public") -Filter "*.ps1" | ForEach-Object { . $_.FullName }

    # Get test data for this function
    $script:TestUserData = $script:TestData['Get-CM7User']
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
Describe 'Get-CM7User' {
	Context "Test Data Validation" {

        It "Should have test data defined in declarations.ps1" {
            # Assert
            $script:TestUserData | Should -Not -BeNullOrEmpty
            $script:TestData.ContainsKey('Get-CM7User') | Should -Be $true
        }

        It "Should have required test data parameter sets" {
            # Assert
            $script:TestUserData.ContainsKey('ByName') | Should -Be $true
            $script:TestUserData.ContainsKey('ByResourceId') | Should -Be $true
            $script:TestUserData.ContainsKey('NonExistent') | Should -Be $true
        }

        It "Should output test data for verification" {
            # Output test data
            Write-Host "`n=== Test Data for Get-CM7User ===" -ForegroundColor Cyan
            Write-Host "ByName:" -ForegroundColor Yellow
            Write-Host "  Name: $($script:TestUserData.ByName.Name)" -ForegroundColor White
            Write-Host "  ExpectedCount: $($script:TestUserData.ByName.ExpectedCount)" -ForegroundColor White

            Write-Host "ByResourceId:" -ForegroundColor Yellow
            Write-Host "  ResourceId: $($script:TestUserData.ByResourceId.ResourceId)" -ForegroundColor White
            Write-Host "  ExpectedCount: $($script:TestUserData.ByResourceId.ExpectedCount)" -ForegroundColor White

            Write-Host "NonExistent:" -ForegroundColor Yellow
            Write-Host "  Name: $($script:TestUserData.NonExistent.Name)" -ForegroundColor White
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
            { Get-CM7User -Name $script:TestUserData.ByName.Name } | Should -Throw

            # Restore connection
            $script:CMConnection = $backupConnection
        }
    }

	Context 'ByName' {
		It 'Returns user by name' {
			$result = Get-CM7User -Name $script:TestUserData.ByName.Name
			$result | Should -Not -BeNullOrEmpty
			$result.Count | Should -Be $script:TestUserData.ByName.ExpectedCount
		}
	}

	Context 'ByName and WildCard' {
		It 'Returns user by name' {
			$result = Get-CM7User -Name $script:TestUserData.ByName.Name -AllowWildcards
			$result | Should -Not -BeNullOrEmpty
			$result.Count | Should -Be $script:TestUserData.ByName.ExpectedCount
		}
	}

	Context 'ByResourceId' {
		It 'Returns user by ResourceId' {
			$result = Get-CM7User -ResourceId $script:TestUserData.ByResourceId.ResourceId
			$result | Should -Not -BeNullOrEmpty
			$result.ResourceId | Should -Contain $script:TestUserData.ByResourceId.ResourceId
		}
	}

	Context 'All' {
		It 'Returns all users (minimum count)' {
			$result = Get-CM7User
			($result.Count -ge $script:TestUserData.All.ExpectedMinCount) | Should -BeTrue
		}
	}

	Context 'NonExistent' {
		It 'Returns no user for non-existent name' {
			$result = Get-CM7User -Name $script:TestUserData.NonExistent.Name
			$result | Should -BeNullOrEmpty
		}
		It 'Returns no user for non-existent ResourceId' {
			$result = Get-CM7User -ResourceId $script:TestUserData.NonExistent.ResourceId
			$result | Should -BeNullOrEmpty
		}
	}
}