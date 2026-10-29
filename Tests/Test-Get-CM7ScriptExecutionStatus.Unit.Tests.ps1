BeforeAll {
    . (Join-Path (Split-Path $PSScriptRoot -Parent) 'Code/Public/Get-CM7ScriptExecutionStatus.ps1')
    $script:CMConnection = @{
        CimSession = 'test-session'
        SiteCode   = 'ABC'
    }
}

Describe 'Get-CM7ScriptExecutionStatus lazy CIM properties' -Tag 'Unit', 'Script' {
    BeforeEach {
        $script:fullScriptOutput = '{"Data":"' + ('x' * 16000) + '"}'
        $script:taskStatus = [PSCustomObject]@{
            ClientOperationId   = 123
            ScriptName          = 'Service query'
            ScriptVersion       = '1'
            ScriptGuid          = '00000000-0000-0000-0000-000000000001'
            CollectionId        = ''
            CollectionName      = ''
            CompletedClients    = 1
            TotalClients        = 1
            FailedClients       = 0
            OfflineClients      = 0
            NotApplicableClients = 0
            UnknownClients      = 0
            LastUpdateTime      = [datetime]::UtcNow
        }
        $script:partialClientStatus = New-CimInstance -ClassName Win32_Process -ClientOnly -Property @{
            ProcessId = 1
        }
        $script:fullClientStatus = [PSCustomObject]@{
            ResourceId           = 1
            DeviceName           = 'DEVICE01'
            ScriptExecutionState  = 3
            ScriptExitCode        = 0
            ScriptOutput          = $script:fullScriptOutput
        }

        Mock Get-CimInstance {
            param($CimSession, $Namespace, $Query, $InputObject)

            if ($Query -like 'SELECT * FROM SMS_ScriptsExecutionTask*') {
                return $script:taskStatus
            }
            if ($Query -like 'SELECT * FROM SMS_ScriptsExecutionStatus*') {
                return $script:partialClientStatus
            }
            if ($InputObject) {
                return $script:fullClientStatus
            }
        }
    }

    It 'refreshes the status instance before returning its full ScriptOutput' {
        $result = Get-CM7ScriptExecutionStatus -ClientOperationId 123

        $result.Results[0].ScriptOutput.Length | Should -Be $script:fullScriptOutput.Length
        $result.Results[0].OutputObject.Data.Length | Should -Be 16000
        Should -Invoke Get-CimInstance -Times 1 -Exactly -ParameterFilter {
            $null -ne $InputObject
        }
    }
}