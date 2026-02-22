# Functional Tests for Set-CM7TaskSequenceDeployment
# Tests the Set-CM7TaskSequenceDeployment function behavior and return values

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

    function New-TestDeploymentForSet {
        param(
            [string]$NamePrefix = "Test-SetTSD",
            [string]$CollectionName = $script:TestSetTSDData.TestDeployment.CollectionName,
            [string]$TaskSequencePackageId = $script:TestSetTSDData.TestDeployment.TaskSequencePackageId,
            [ValidateSet('Available','Required')]
            [string]$DeployPurpose = 'Available'
        )

        $uniqueName = "$NamePrefix-$(Get-Date -Format 'yyyyMMdd_HHmmss_fff')-$([guid]::NewGuid().ToString().Substring(0, 8))"
        $result = New-CM7TaskSequenceDeployment `
            -TaskSequencePackageId $TaskSequencePackageId `
            -CollectionName $CollectionName `
            -DeploymentName $uniqueName `
            -DeployPurpose $DeployPurpose `
            -Force

        if ($result) {
            $script:CreatedAdvertisementIds += $result.AdvertisementID
        }

        return $result
    }
}

Describe "Set-CM7TaskSequenceDeployment Function Tests" -Tag "Integration", "TaskSequenceDeployment", "Set" {
    Context "Test Data Validation" {
        It "Should have test data defined in declarations.ps1" {
            $script:TestSetTSDData | Should -Not -BeNullOrEmpty
            $script:TestData.ContainsKey('Set-CM7TaskSequenceDeployment') | Should -Be $true
        }

        It "Should have required test data parameter sets" {
            $script:TestSetTSDData.ContainsKey('TestDeployment') | Should -Be $true
            $script:TestSetTSDData.ContainsKey('NonExistent') | Should -Be $true
        }
    }

    Context "Connection Requirement" {
        It "Should fail if not connected to MECM" {
            $backupConnection = $script:CMConnection.Clone()
            $script:CMConnection.CimSession = $null

            { Set-CM7TaskSequenceDeployment -TaskSequenceDeploymentId "SD120BD2" -Comment "Test" } | Should -Throw "*not connected*"

            $script:CMConnection = $backupConnection
        }
    }

    Context "Update by Deployment ID" {
        It "Should update comment and progress flag by TaskSequenceDeploymentId" {
            $testDeployment = New-TestDeploymentForSet -NamePrefix "Test-SetTSD-ByID"
            $testDeployment | Should -Not -BeNullOrEmpty

            $advId = $testDeployment.AdvertisementID
            $newComment = "Updated by Set-CM7TaskSequenceDeployment $(Get-Date -Format 's')"

            $result = Set-CM7TaskSequenceDeployment `
                -TaskSequenceDeploymentId $advId `
                -Comment $newComment `
                -ShowTaskSequenceProgress $true `
                -PassThru `
                -Force

            $result | Should -Not -BeNullOrEmpty
            $result.AdvertisementID | Should -Be $advId
            $result.Comment | Should -Be $newComment
            ($result.AdvertFlags -band 0x02000000) | Should -Be 0x02000000
            ($result.RemoteClientFlags -band 0x00004000) | Should -Be 0x00004000
        }
    }

    Context "Update by InputObject" {
        It "Should update options using InputObject pipeline" {
            $testDeployment = New-TestDeploymentForSet -NamePrefix "Test-SetTSD-InputObj"
            $testDeployment | Should -Not -BeNullOrEmpty

            $advId = $testDeployment.AdvertisementID
            $deploymentObject = Get-CM7TaskSequenceDeployment -AdvertisementID $advId
            $deploymentObject | Should -Not -BeNullOrEmpty

            $result = $deploymentObject | Set-CM7TaskSequenceDeployment `
                -AllowFallback $true `
                -DeploymentOption RunFromDistributionPoint `
                -UseMeteredNetwork $false `
                -PassThru `
                -Force

            $result | Should -Not -BeNullOrEmpty
            $result.AdvertisementID | Should -Be $advId
            ($result.AdvertFlags -band 0x00080000) | Should -Be 0
            ($result.RemoteClientFlags -band 0x00000004) | Should -Be 0x00000004
            ($result.RemoteClientFlags -band 0x00008000) | Should -Be 0
        }

        It "Should throw when InputObject has no AdvertisementID property" {
            $badObj = [PSCustomObject]@{ Name = "InvalidObject" }
            { Set-CM7TaskSequenceDeployment -InputObject $badObj -Comment "x" -Force } | Should -Throw "*AdvertisementID*"
        }
    }

    Context "Update by Task Sequence selectors" {
        It "Should update deployment using TaskSequenceName and CollectionName" {
            $testDeployment = New-TestDeploymentForSet -NamePrefix "Test-SetTSD-ByTSName"
            $testDeployment | Should -Not -BeNullOrEmpty

            $tsName = $script:TestSetTSDData.TestDeployment.TaskSequenceName
            $collectionName = $script:TestSetTSDData.TestDeployment.CollectionName
            $newComment = "Updated-By-TSName-$(Get-Date -Format 'yyyyMMddHHmmss')"

            $result = Set-CM7TaskSequenceDeployment `
                -TaskSequenceName $tsName `
                -CollectionName $collectionName `
                -Comment $newComment `
                -PassThru `
                -Force | Where-Object { $_.AdvertisementID -eq $testDeployment.AdvertisementID }

            $result | Should -Not -BeNullOrEmpty
            $result.Comment | Should -Be $newComment
        }

        It "Should update deployment using TaskSequencePackageId and CollectionName" {
            $testDeployment = New-TestDeploymentForSet -NamePrefix "Test-SetTSD-ByPkg"
            $testDeployment | Should -Not -BeNullOrEmpty

            $tsPkg = $script:TestSetTSDData.TestDeployment.TaskSequencePackageId
            $collectionName = $script:TestSetTSDData.TestDeployment.CollectionName

            $result = Set-CM7TaskSequenceDeployment `
                -TaskSequencePackageId $tsPkg `
                -CollectionName $collectionName `
                -AllowSharedContent $false `
                -PassThru `
                -Force | Where-Object { $_.AdvertisementID -eq $testDeployment.AdvertisementID }

            $result | Should -Not -BeNullOrEmpty
            ($result.RemoteClientFlags -band 0x00000010) | Should -Be 0
        }
    }

    Context "Flag mapping and schedule-event handling" {
        It "Should apply MakeAvailableTo MediaAndPxeHidden" {
            $testDeployment = New-TestDeploymentForSet -NamePrefix "Test-SetTSD-MediaPxeHidden"
            $testDeployment | Should -Not -BeNullOrEmpty

            $result = Set-CM7TaskSequenceDeployment `
                -TaskSequenceDeploymentId $testDeployment.AdvertisementID `
                -MakeAvailableTo MediaAndPxeHidden `
                -PassThru `
                -Force

            $result | Should -Not -BeNullOrEmpty
            ($result.AdvertFlags -band 0x00002000) | Should -Be 0x00002000
            ($result.AdvertFlags -band 0x00008000) | Should -Be 0x00008000
        }

        It "Should set, add, remove and clear schedule events" {
            # ScheduleEvent bits (ADVERT_IMMEDIATE 0x20, ADVERT_ONUSERLOGON 0x200, ADVERT_ONUSERLOGOFF 0x400)
            # are only valid for Required deployments. The MECM WMI provider rejects ModifyInstance
            # with HRESULT 0x80041001 when any of these bits are written on an Available deployment.
            # This test explicitly creates a Required deployment to avoid that constraint.
            $testDeployment = New-TestDeploymentForSet -NamePrefix "Test-SetTSD-ScheduleEvents" -DeployPurpose Required
            $testDeployment | Should -Not -BeNullOrEmpty

            $advId = $testDeployment.AdvertisementID

            # Step 1: set ScheduleEvent to LogOn only
            $setResult = Set-CM7TaskSequenceDeployment -TaskSequenceDeploymentId $advId -ScheduleEvent LogOn -PassThru -Force
            ($setResult.AdvertFlags -band 0x00000200) | Should -Be 0x00000200

            # Step 2: add LogOff
            $addResult = Set-CM7TaskSequenceDeployment -TaskSequenceDeploymentId $advId -AddScheduleEvent LogOff -PassThru -Force
            ($addResult.AdvertFlags -band 0x00000200) | Should -Be 0x00000200
            ($addResult.AdvertFlags -band 0x00000400) | Should -Be 0x00000400

            # Step 3: remove LogOn
            $removeResult = Set-CM7TaskSequenceDeployment -TaskSequenceDeploymentId $advId -RemoveScheduleEvent LogOn -PassThru -Force
            ($removeResult.AdvertFlags -band 0x00000200) | Should -Be 0
            ($removeResult.AdvertFlags -band 0x00000400) | Should -Be 0x00000400

                # Step 4: clear all schedule events — LogOff (0x400) and LogOn (0x200) must be cleared
                # For Required deployments, clearing all schedule events is not allowed and should throw.
                { Set-CM7TaskSequenceDeployment -TaskSequenceDeploymentId $advId -ClearScheduleEvent -PassThru -Force } | Should -Throw
        }

        It "Should clear multiple remote/advert flags when set to false" {
            $testDeployment = New-TestDeploymentForSet -NamePrefix "Test-SetTSD-DisableFlags"
            $testDeployment | Should -Not -BeNullOrEmpty

            $result = Set-CM7TaskSequenceDeployment `
                -TaskSequenceDeploymentId $testDeployment.AdvertisementID `
                -AllowFallback $false `
                -SoftwareInstallation $false `
                -SystemRestart $false `
                -SendWakeupPacket $false `
                -ShowTaskSequenceProgress $false `
                -PersistOnWriteFilterDevice $false `
                -InternetOption $false `
                -UseMeteredNetwork $false `
                -RerunBehavior NeverRerunDeployedProgram `
                -DeploymentOption DownloadAllContentLocallyBeforeStartingTaskSequence `
                -PassThru `
                -Force

            $result | Should -Not -BeNullOrEmpty
            ($result.AdvertFlags -band 0x00080000) | Should -Be 0x00080000
            ($result.AdvertFlags -band 0x00010000) | Should -Be 0
            ($result.AdvertFlags -band 0x00020000) | Should -Be 0
            ($result.AdvertFlags -band 0x00040000) | Should -Be 0
            ($result.AdvertFlags -band 0x02000000) | Should -Be 0
            ($result.RemoteClientFlags -band 0x00004000) | Should -Be 0
            ($result.RemoteClientFlags -band 0x00000400) | Should -Be 0
            ($result.RemoteClientFlags -band 0x00000800) | Should -Be 0
            ($result.RemoteClientFlags -band 0x00008000) | Should -Be 0
            ($result.RemoteClientFlags -band 0x00000020) | Should -Be 0
            ($result.RemoteClientFlags -band 0x00000040) | Should -Be 0
            ($result.RemoteClientFlags -band 0x00000080) | Should -Be 0
            ($result.RemoteClientFlags -band 0x00000004) | Should -Be 0
            ($result.RemoteClientFlags -band 0x00000002) | Should -Be 0
        }
    }

    Context "Collection target resolution" {
        It "Should update target collection using collection object" {
            $testDeployment = New-TestDeploymentForSet -NamePrefix "Test-SetTSD-CollectionObj"
            $testDeployment | Should -Not -BeNullOrEmpty

            $targetCollectionName = $script:TestSetTSDData.TestDeployment.AlternateCollections[0]
            $collectionObject = Get-CM7Collection -Name $targetCollectionName
            $collectionObject | Should -Not -BeNullOrEmpty

            $result = Set-CM7TaskSequenceDeployment `
                -TaskSequenceDeploymentId $testDeployment.AdvertisementID `
                -Collection $collectionObject `
                -PassThru `
                -Force

            $result | Should -Not -BeNullOrEmpty
            $result.CollectionName | Should -Be $targetCollectionName
        }

        It "Should throw when wildcard collection name resolves to multiple collections" {
            $testDeployment = New-TestDeploymentForSet -NamePrefix "Test-SetTSD-MultiCollection"
            $testDeployment | Should -Not -BeNullOrEmpty

            {
                Set-CM7TaskSequenceDeployment `
                    -TaskSequenceDeploymentId $testDeployment.AdvertisementID `
                    -CollectionName "Test-Collection-*" `
                    -Comment "Should fail on multiple collections" `
                    -Force
            } | Should -Throw "*multiple collections*"
        }
    }

    Context "WhatIf Support" {
        It "Should support -WhatIf parameter" {
            $testDeployment = New-TestDeploymentForSet -NamePrefix "Test-SetTSD-WhatIf"
            $testDeployment | Should -Not -BeNullOrEmpty

            $advId = $testDeployment.AdvertisementID
            $commentBefore = (Get-CM7TaskSequenceDeployment -AdvertisementID $advId).Comment

            { Set-CM7TaskSequenceDeployment -TaskSequenceDeploymentId $advId -Comment "ShouldNotApply" -WhatIf } | Should -Not -Throw

            $commentAfter = (Get-CM7TaskSequenceDeployment -AdvertisementID $advId).Comment
            $commentAfter | Should -Be $commentBefore
        }
    }

    Context "Error Handling" {
        It "Should throw for non-existent deployment" {
            $nonExistentId = $script:TestSetTSDData.NonExistent.TaskSequenceDeploymentId
            { Set-CM7TaskSequenceDeployment -TaskSequenceDeploymentId $nonExistentId -Comment "x" -Force } | Should -Throw "*not found*"
        }

        It "Should throw for unsupported schedule token parameters" {
            $testDeployment = New-TestDeploymentForSet -NamePrefix "Test-SetTSD-UnsupportedSchedule"
            $testDeployment | Should -Not -BeNullOrEmpty

            { Set-CM7TaskSequenceDeployment -TaskSequenceDeploymentId $testDeployment.AdvertisementID -ClearSchedule -Force } | Should -Throw "*currently not supported*"
            { Set-CM7TaskSequenceDeployment -TaskSequenceDeploymentId $testDeployment.AdvertisementID -Schedule @([PSCustomObject]@{}) -Force } | Should -Throw "*currently not supported*"
            { Set-CM7TaskSequenceDeployment -TaskSequenceDeploymentId $testDeployment.AdvertisementID -AddSchedule @([PSCustomObject]@{}) -Force } | Should -Throw "*currently not supported*"
            { Set-CM7TaskSequenceDeployment -TaskSequenceDeploymentId $testDeployment.AdvertisementID -RemoveSchedule @([PSCustomObject]@{}) -Force } | Should -Throw "*currently not supported*"
        }

        It "Should throw for non-existent task sequence name" {
            { Set-CM7TaskSequenceDeployment -TaskSequenceName "NonExistent-TaskSequence-999" -Comment "x" -Force } | Should -Throw "*not found*"
        }

        It "Should throw for non-existent task sequence package" {
            { Set-CM7TaskSequenceDeployment -TaskSequencePackageId "XXX99999" -Comment "x" -Force } | Should -Throw "*not found*"
        }

        It "Should throw for non-existent collection name when supplied" {
            { Set-CM7TaskSequenceDeployment -TaskSequenceDeploymentId $script:TestSetTSDData.NonExistent.TaskSequenceDeploymentId -CollectionName $script:TestSetTSDData.NonExistent.CollectionName -Comment "x" -Force } | Should -Throw "*not found*"
        }

        It "Should throw when wildcard handling switches are both set" {
            $testDeployment = New-TestDeploymentForSet -NamePrefix "Test-SetTSD-WildcardErr"
            $testDeployment | Should -Not -BeNullOrEmpty

            { Set-CM7TaskSequenceDeployment -TaskSequenceDeploymentId $testDeployment.AdvertisementID -DisableWildcardHandling -ForceWildcardHandling -Force } | Should -Throw "*cannot be used together*"
        }
    }
}

AfterAll {
    if ($script:CMConnection.CimSession -and $script:CreatedAdvertisementIds.Count -gt 0) {
        foreach ($advId in ($script:CreatedAdvertisementIds | Select-Object -Unique)) {
            try {
                Remove-CM7TaskSequenceDeployment -AdvertisementID $advId -Force -ErrorAction SilentlyContinue | Out-Null
            }
            catch { }
        }
    }
}
