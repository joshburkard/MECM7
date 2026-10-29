BeforeAll {
    . (Join-Path (Split-Path $PSScriptRoot -Parent) 'Code/Public/Invoke-CM7Query.ps1')
}

Describe 'Invoke-CM7Query' -Tag 'Unit', 'Query' {
    BeforeEach {
        $script:CMConnection = [PSCustomObject]@{
            CimSession = 'test-session'
            SiteCode   = 'ABC'
        }
        $script:queryObject = [PSCustomObject]@{
            Name                = 'Hardware query'
            QueryID             = 'ABC00001'
            Expression          = 'SELECT * FROM SMS_R_System'
            LimitToCollectionID = ''
        }
        $script:queryResult = [PSCustomObject]@{ Name = 'DEVICE01'; ResourceID = 1 }

        Mock Get-CimInstance {
            param($CimSession, $Namespace, $Query)

            if ($Query -like 'SELECT * FROM SMS_Query*') {
                return $script:queryObject
            }

            return $script:queryResult
        }
    }

    It 'resolves a saved query by name and returns its CIM results' {
        $result = Invoke-CM7Query -Name 'Hardware query'

        $result | Should -Be $script:queryResult
        Should -Invoke Get-CimInstance -Times 2 -Exactly -ParameterFilter {
            $Namespace -eq 'root/SMS/site_ABC'
        }
    }

    It 'resolves a saved query by ID' {
        $result = Invoke-CM7Query -Id 'ABC00001'

        $result | Should -Be $script:queryResult
        Should -Invoke Get-CimInstance -Times 1 -Exactly -ParameterFilter {
            $Query -eq "SELECT * FROM SMS_Query WHERE QueryID = 'ABC00001'"
        }
    }

    It 'executes a saved query object from the pipeline without resolving it again' {
        $result = $script:queryObject | Invoke-CM7Query

        $result | Should -Be $script:queryResult
        Should -Invoke Get-CimInstance -Times 1 -Exactly -ParameterFilter {
            $Query -eq 'SELECT * FROM SMS_R_System'
        }
    }

    It 'rejects collection-limited queries rather than returning unfiltered results' {
        $script:queryObject.LimitToCollectionID = '<Prompt>'

        { Invoke-CM7Query -InputObject $script:queryObject } | Should -Throw '*Collection-limited queries cannot be executed through direct CIM*'
        Should -Invoke Get-CimInstance -Times 0 -Exactly
    }

    It 'requires an active MECM connection' {
        $script:CMConnection.CimSession = $null

        { Invoke-CM7Query -Id 'ABC00001' } | Should -Throw '*not connected*'
    }

    It 'honors WhatIf without executing the query expression' {
        Invoke-CM7Query -Name 'Hardware query' -WhatIf

        Should -Invoke Get-CimInstance -Times 1 -Exactly -ParameterFilter {
            $Query -like 'SELECT * FROM SMS_Query*'
        }
    }
}