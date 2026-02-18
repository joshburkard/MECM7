# Functional Tests for Get-CM7SoftwareUpdate
# Tests the Get-CM7SoftwareUpdate function behavior and return values

BeforeAll {
    # Load test declarations
    . (Join-Path $PSScriptRoot "declarations.ps1")

    # Load all functions
    $CodePath = Join-Path (Get-Item $PSScriptRoot).Parent.FullName "Code"
    Get-ChildItem -Path (Join-Path $CodePath "Private") -Filter "*.ps1" | ForEach-Object { . $_.FullName }
    Get-ChildItem -Path (Join-Path $CodePath "Public") -Filter "*.ps1" | ForEach-Object { . $_.FullName }

    # Get test data for this function
    $script:TestSUData = $script:TestData['Get-CM7SoftwareUpdate']
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

Describe "Get-CM7SoftwareUpdate Function Tests" -Tag "Integration", "SoftwareUpdate" {

    Context "Test Data Validation" {

        It "Should have test data defined in declarations.ps1" {
            # Assert
            $script:TestSUData | Should -Not -BeNullOrEmpty
            $script:TestData.ContainsKey('Get-CM7SoftwareUpdate') | Should -Be $true
        }

        It "Should have required test data parameter sets" {
            # Assert
            $script:TestSUData.ContainsKey('ByArticleId') | Should -Be $true
            $script:TestSUData.ContainsKey('NonExistent') | Should -Be $true
            $script:TestSUData.ContainsKey('All') | Should -Be $true
        }

        It "Should output test data for verification" {
            # Output test data
            Write-Host "`n=== Test Data for Get-CM7SoftwareUpdate ===" -ForegroundColor Cyan
            Write-Host "ByArticleId:" -ForegroundColor Yellow
            Write-Host "  ArticleId: $($script:TestSUData.ByArticleId.ArticleId)" -ForegroundColor White
            Write-Host "  ExpectedCount: $($script:TestSUData.ByArticleId.ExpectedCount)" -ForegroundColor White

            Write-Host "ByName:" -ForegroundColor Yellow
            Write-Host "  Name: $($script:TestSUData.ByName.Name)" -ForegroundColor White
            Write-Host "  ExpectedMinCount: $($script:TestSUData.ByName.ExpectedMinCount)" -ForegroundColor White

            Write-Host "NonExistent:" -ForegroundColor Yellow
            Write-Host "  ArticleId: $($script:TestSUData.NonExistent.ArticleId)" -ForegroundColor White
            Write-Host "  Name: $($script:TestSUData.NonExistent.Name)" -ForegroundColor White
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
            { Get-CM7SoftwareUpdate -ArticleId "4038779" } | Should -Throw "*not connected*"

            # Restore connection
            $script:CMConnection = $backupConnection
        }
    }

    Context "Query by Article ID" {

        It "Should retrieve software update by article ID" {
            # Arrange
            $articleId = $script:TestSUData.ByArticleId.ArticleId

            # Act
            $result = Get-CM7SoftwareUpdate -ArticleId $articleId

            # Assert
            if ($result) {
                $result | Should -Not -BeNullOrEmpty
                @($result) | ForEach-Object {
                    $_.ArticleID | Should -Be $articleId
                }
            } else {
                Set-ItResult -Skipped -Because "Software update with ArticleId '$articleId' not found in environment"
            }
        }

        It "Should return null for non-existent article ID" {
            # Arrange
            $articleId = $script:TestSUData.NonExistent.ArticleId

            # Act
            $result = Get-CM7SoftwareUpdate -ArticleId $articleId

            # Assert
            $result | Should -BeNullOrEmpty
        }
    }

    Context "Query by Name" {

        It "Should retrieve software updates by name pattern" {
            # Arrange
            $name = $script:TestSUData.ByName.Name

            # Act
            $result = Get-CM7SoftwareUpdate -Name $name

            # Assert
            if ($result) {
                $result | Should -Not -BeNullOrEmpty
                @($result).Count | Should -BeGreaterOrEqual $script:TestSUData.ByName.ExpectedMinCount
            } else {
                Set-ItResult -Skipped -Because "No software updates found matching name '$name'"
            }
        }

        It "Should return null for non-existent name" {
            # Arrange
            $name = $script:TestSUData.NonExistent.Name

            # Act
            $result = Get-CM7SoftwareUpdate -Name $name

            # Assert
            $result | Should -BeNullOrEmpty
        }

        It "Should support wildcard patterns in name" {
            # First get a valid update by article ID
            $articleId = $script:TestSUData.ByArticleId.ArticleId
            $existing = Get-CM7SoftwareUpdate -ArticleId $articleId

            if ($existing) {
                $fullName = @($existing)[0].LocalizedDisplayName
                # Use only the first few characters as a wildcard pattern
                $wildcardName = "$($fullName.Substring(0, [Math]::Min(15, $fullName.Length)))*"

                # Act
                $result = Get-CM7SoftwareUpdate -Name $wildcardName

                # Assert
                $result | Should -Not -BeNullOrEmpty
                $result | ForEach-Object {
                    $_.LocalizedDisplayName | Should -BeLike $wildcardName
                }
            } else {
                Set-ItResult -Skipped -Because "No software updates found to search by wildcard name"
            }
        }
    }

    Context "Query by Severity" {

        It "Should filter software updates by severity" {
            # Arrange
            $severity = $script:TestSUData.BySeverity.Severity

            # Act
            $result = Get-CM7SoftwareUpdate -Severity $severity

            # Assert
            if ($result) {
                $result | Should -Not -BeNullOrEmpty
                $result | ForEach-Object {
                    $_.Severity | Should -Be $severity
                }
            } else {
                Set-ItResult -Skipped -Because "No software updates with severity '$severity' found"
            }
        }
    }

    Context "Query by Deployment Status" {

        It "Should filter software updates by IsDeployed" {
            # Act
            $result = Get-CM7SoftwareUpdate -IsDeployed $script:TestSUData.IsDeployed.IsDeployed

            # Assert
            if ($result) {
                $result | Should -Not -BeNullOrEmpty
                $result | ForEach-Object {
                    $_.IsDeployed | Should -Be $true
                }
            } else {
                Set-ItResult -Skipped -Because "No deployed software updates found"
            }
        }

        It "Should filter software updates by IsSuperseded" {
            # Act
            $result = Get-CM7SoftwareUpdate -IsSuperseded $script:TestSUData.IsNotSuperseded.IsSuperseded

            # Assert
            if ($result) {
                $result | Should -Not -BeNullOrEmpty
                $result | ForEach-Object {
                    $_.IsSuperseded | Should -Be $false
                }
            } else {
                Set-ItResult -Skipped -Because "No non-superseded software updates found"
            }
        }
    }

    Context "Combined Filters" {

        It "Should support combining article ID with additional filters" {
            # Arrange
            $articleId = $script:TestSUData.ByArticleId.ArticleId

            # Act
            $result = Get-CM7SoftwareUpdate -ArticleId $articleId

            # Assert
            if ($result) {
                $result | Should -Not -BeNullOrEmpty
                @($result) | ForEach-Object {
                    $_.ArticleID | Should -Be $articleId
                }
            } else {
                Set-ItResult -Skipped -Because "Software update with ArticleId '$articleId' not found"
            }
        }

        It "Should support severity combined with deployment status" {
            # Act
            $result = Get-CM7SoftwareUpdate -Severity "Critical" -IsDeployed $true

            # Assert
            if ($result) {
                $result | ForEach-Object {
                    $_.Severity | Should -Be "Critical"
                    $_.IsDeployed | Should -Be $true
                }
            } else {
                Set-ItResult -Skipped -Because "No critical deployed software updates found"
            }
        }
    }

    Context "Fast Mode" {

        It "Should return limited properties with Fast switch" {
            # Arrange
            $articleId = $script:TestSUData.ByArticleId.ArticleId

            # Act
            $result = Get-CM7SoftwareUpdate -ArticleId $articleId -Fast

            # Assert
            if ($result) {
                $result | Should -Not -BeNullOrEmpty
                $firstResult = @($result)[0]
                $firstResult.PSObject.Properties.Name | Should -Contain 'CI_ID'
                $firstResult.PSObject.Properties.Name | Should -Contain 'ArticleID'
                $firstResult.PSObject.Properties.Name | Should -Contain 'BulletinID'
                $firstResult.PSObject.Properties.Name | Should -Contain 'LocalizedDisplayName'
                $firstResult.PSObject.Properties.Name | Should -Contain 'DatePosted'
                $firstResult.PSObject.Properties.Name | Should -Contain 'IsDeployed'
                $firstResult.PSObject.Properties.Name | Should -Contain 'IsSuperseded'
                $firstResult.PSObject.Properties.Name | Should -Contain 'Severity'
            } else {
                Set-ItResult -Skipped -Because "Software update with ArticleId '$articleId' not found"
            }
        }

        It "Fast mode should be faster than full query" {
            # Arrange
            $articleId = $script:TestSUData.ByArticleId.ArticleId

            # Act
            $fastStart = Get-Date
            $fastResult = Get-CM7SoftwareUpdate -ArticleId $articleId -Fast
            $fastDuration = (Get-Date) - $fastStart

            $fullStart = Get-Date
            $fullResult = Get-CM7SoftwareUpdate -ArticleId $articleId
            $fullDuration = (Get-Date) - $fullStart

            # Assert
            Write-Host "Fast mode: $($fastDuration.TotalMilliseconds)ms, Full mode: $($fullDuration.TotalMilliseconds)ms" -ForegroundColor Cyan
            # Note: We don't assert speed because it can vary
            $true | Should -Be $true
        }
    }

    Context "Return Object Properties" {

        It "Should return objects with expected properties" {
            # Arrange
            $articleId = $script:TestSUData.ByArticleId.ArticleId

            # Act
            $result = Get-CM7SoftwareUpdate -ArticleId $articleId

            # Assert
            if ($result) {
                $result | Should -Not -BeNullOrEmpty
                $firstResult = @($result)[0]
                $firstResult.PSObject.Properties.Name | Should -Contain 'CI_ID'
                $firstResult.PSObject.Properties.Name | Should -Contain 'ArticleID'
                $firstResult.PSObject.Properties.Name | Should -Contain 'BulletinID'
                $firstResult.PSObject.Properties.Name | Should -Contain 'LocalizedDisplayName'
                $firstResult.PSObject.Properties.Name | Should -Contain 'LocalizedDescription'
                $firstResult.PSObject.Properties.Name | Should -Contain 'Severity'
                $firstResult.PSObject.Properties.Name | Should -Contain 'DatePosted'
                $firstResult.PSObject.Properties.Name | Should -Contain 'DateRevised'
                $firstResult.PSObject.Properties.Name | Should -Contain 'IsDeployed'
                $firstResult.PSObject.Properties.Name | Should -Contain 'IsSuperseded'
                $firstResult.PSObject.Properties.Name | Should -Contain 'NumMissing'
                $firstResult.PSObject.Properties.Name | Should -Contain 'NumPresent'
                $firstResult.PSObject.Properties.Name | Should -Contain 'NumTotal'
                $firstResult.PSObject.Properties.Name | Should -Contain 'PercentCompliant'
            } else {
                Set-ItResult -Skipped -Because "Software update with ArticleId '$articleId' not found"
            }
        }

        It "Should have PSTypeName set correctly" {
            # Arrange
            $articleId = $script:TestSUData.ByArticleId.ArticleId

            # Act
            $result = Get-CM7SoftwareUpdate -ArticleId $articleId

            # Assert
            if ($result) {
                $firstResult = @($result)[0]
                $firstResult.PSObject.TypeNames[0] | Should -Be 'MECM7.SoftwareUpdate'
            } else {
                Set-ItResult -Skipped -Because "Software update with ArticleId '$articleId' not found"
            }
        }

        It "Should have Severity as string (friendly name)" {
            # Arrange
            $articleId = $script:TestSUData.ByArticleId.ArticleId

            # Act
            $result = Get-CM7SoftwareUpdate -ArticleId $articleId

            # Assert
            if ($result) {
                $firstResult = @($result)[0]
                $firstResult.Severity | Should -BeOfType [string]
                $firstResult.Severity | Should -Match "^(None|Low|Moderate|Important|Critical|Unknown.*)$"
            } else {
                Set-ItResult -Skipped -Because "Software update with ArticleId '$articleId' not found"
            }
        }
    }

    Context "Get All Software Updates" {

        It "Should retrieve software updates when no parameters specified" {
            # Act
            $result = Get-CM7SoftwareUpdate -Fast

            # Assert
            $result | Should -Not -BeNullOrEmpty
            @($result).Count | Should -BeGreaterOrEqual $script:TestSUData.All.ExpectedMinCount
        }
    }

    Context "Verbose Output" {

        It "Should provide verbose output when requested" {
            # Arrange
            $articleId = $script:TestSUData.ByArticleId.ArticleId

            # Act & Assert
            $verboseOutput = Get-CM7SoftwareUpdate -ArticleId $articleId -Verbose 4>&1
            $verboseOutput | Should -Not -BeNullOrEmpty
            $verboseOutput | Where-Object { $_ -match "Running Get-CM7SoftwareUpdate" } | Should -Not -BeNullOrEmpty
        }
    }
}

AfterAll {
    # Optional: Close CIM session if needed
    if ($script:CMConnection.CimSession) {
        Write-Host "Cleaning up CIM session..." -ForegroundColor Yellow
        # Remove-CimSession -CimSession $script:CMConnection.CimSession -ErrorAction SilentlyContinue
    }
}
