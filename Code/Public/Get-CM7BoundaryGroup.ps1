function Get-CM7BoundaryGroup {
    <#
        .SYNOPSIS
            Retrieves boundary group information from MECM using CIM.

        .DESCRIPTION
            Queries the SMS_BoundaryGroup WMI class to retrieve boundary group information from MECM.
            Supports filtering by Name and GroupID.
            Requires an active connection established via Connect-CM7.

            This function is the CIM-based equivalent of the Get-CMBoundaryGroup cmdlet
            from the ConfigurationManager PowerShell module, but uses direct CIM queries over WinRM.

        .PARAMETER Name
            The name of the boundary group to retrieve. Supports wildcard characters (* and ?).
            When no parameters are specified, all boundary groups are returned.

        .PARAMETER Id
            The GroupID(s) of one or more boundary groups to retrieve. Accepts an array of strings.
            Alias: GroupId

        .PARAMETER DisableWildcardHandling
            Treats wildcard characters as literal character values.
            Cannot be combined with ForceWildcardHandling.

        .PARAMETER ForceWildcardHandling
            Forces wildcard character processing even in contexts where it is not normally supported.
            May lead to unexpected behavior (not recommended).
            Cannot be combined with DisableWildcardHandling.

        .EXAMPLE
            Get-CM7BoundaryGroup
            Retrieves all boundary groups.

        .EXAMPLE
            Get-CM7BoundaryGroup -Name "Test Gino"
            Retrieves the boundary group named "Test Gino".

        .EXAMPLE
            Get-CM7BoundaryGroup -Name "Test*"
            Retrieves all boundary groups whose name starts with "Test".

        .EXAMPLE
            Get-CM7BoundaryGroup -Id "16777428"
            Retrieves the boundary group with GroupID 16777428.

        .EXAMPLE
            Get-CM7BoundaryGroup -Id "16777428", "16777429"
            Retrieves multiple boundary groups by their GroupIDs.

        .NOTES
            Requires an active connection established via Connect-CM7.
            The SMS_BoundaryGroup WMI class is used to represent boundary groups in MECM.
            For more information on return object properties, see SMS_BoundaryGroup server WMI class:
            https://learn.microsoft.com/en-us/mem/configmgr/develop/reference/core/servers/configure/sms_boundarygroup-server-wmi-class
    #>
    [CmdletBinding(DefaultParameterSetName = 'SearchByName')]
    param(
        [Parameter(ParameterSetName = 'SearchByName', Position = 0)]
        [SupportsWildcards()]
        [string]$Name,

        [Parameter(ParameterSetName = 'SearchByIdMandatory', Mandatory = $true)]
        [Alias('GroupId')]
        [string[]]$Id,

        [Parameter()]
        [switch]$DisableWildcardHandling,

        [Parameter()]
        [switch]$ForceWildcardHandling
    )

    begin {
        $function = $($MyInvocation.MyCommand.Name)
        Write-Verbose "Running $function"

        # Validate mutually exclusive wildcard parameters
        if ($DisableWildcardHandling -and $ForceWildcardHandling) {
            throw "DisableWildcardHandling and ForceWildcardHandling cannot be used together."
        }

        # Validate connection
        if (-not $script:CMConnection.CimSession) {
            throw "Not connected to MECM. Please run Connect-CM7 first."
        }

        $namespace = "root/SMS/site_$($script:CMConnection.SiteCode)"
        $cimParams = @{
            CimSession = $script:CMConnection.CimSession
            Namespace  = $namespace
        }
    }

    process {
        try {
            $query = $null

            switch ($PSCmdlet.ParameterSetName) {
                'SearchByName' {
                    if ($PSBoundParameters.ContainsKey('Name')) {
                        if ($DisableWildcardHandling) {
                            # Treat wildcard characters as literals
                            $escapedName = $Name -replace "'", "''"
                            $query = "SELECT * FROM SMS_BoundaryGroup WHERE Name = '$escapedName'"
                        } else {
                            # Convert PowerShell wildcard pattern to WQL LIKE pattern
                            $wqlPattern = $Name -replace "'", "''" -replace '\*', '%' -replace '\?', '_'
                            $query = "SELECT * FROM SMS_BoundaryGroup WHERE Name LIKE '$wqlPattern'"
                        }
                    } else {
                        $query = "SELECT * FROM SMS_BoundaryGroup"
                    }
                }
                'SearchByIdMandatory' {
                    if ($Id.Count -eq 1) {
                        $query = "SELECT * FROM SMS_BoundaryGroup WHERE GroupID = $($Id[0])"
                    } else {
                        $idInClause = $Id -join ', '
                        $query = "SELECT * FROM SMS_BoundaryGroup WHERE GroupID IN ($idInClause)"
                    }
                }
            }

            Write-Verbose "Executing WQL query: $query"
            $results = Get-CimInstance @cimParams -Query $query

            if ($results) {
                foreach ($result in $results) {
                    $output = [PSCustomObject]@{
                        PSTypeName      = 'MECM7.BoundaryGroup'
                        GroupID         = [int]$result.GroupID
                        Name            = $result.Name
                        Description     = $result.Description
                        DefaultSiteCode = $result.DefaultSiteCode
                        MemberCount     = $result.MemberCount
                        SiteSystemCount = $result.SiteSystemCount
                    }
                    $output.PSObject.TypeNames.Insert(0, 'MECM7.BoundaryGroup')

                    # Append any additional CIM properties not already mapped
                    $result.CimInstanceProperties | ForEach-Object {
                        if ($_.Name -notin $output.PSObject.Properties.Name) {
                            $output | Add-Member -MemberType NoteProperty -Name $_.Name -Value $_.Value -Force
                        }
                    }

                    Write-Output $output
                }
            }
        } catch {
            throw $_
        }
    }
}
