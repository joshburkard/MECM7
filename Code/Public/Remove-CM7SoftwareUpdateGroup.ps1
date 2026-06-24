function Remove-CM7SoftwareUpdateGroup {
    <#
        .SYNOPSIS
            Removes a software update group from MECM using CIM connectivity.

        .DESCRIPTION
            Removes a software update group (SMS_AuthorizationList) from Microsoft Endpoint Configuration Manager (MECM) using CIM. This is the CIM-based equivalent of Remove-CMSoftwareUpdateGroup from the ConfigurationManager module, but works via CIM.

        .PARAMETER Name
            The name of the software update group to remove.

        .PARAMETER CI_ID
            The CI_ID of the software update group to remove.

        .PARAMETER Force
            Suppresses confirmation prompts.

        .PARAMETER WhatIf
            Shows what would happen if the cmdlet runs. The cmdlet is not run.

        .EXAMPLE
            Remove-CM7SoftwareUpdateGroup -Name "Test-SUG-Creation" -Force

        .EXAMPLE
            Remove-CM7SoftwareUpdateGroup -CI_ID 12345678 -Force

        .NOTES
            Requires an active connection established via Connect-CM7.
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param(
        [Parameter(ParameterSetName='ByName', Mandatory=$true)]
        [string]$Name,

        [Parameter(ParameterSetName='ById', Mandatory=$true)]
        [int]$CI_ID,

        [Parameter()]
        [switch]$Force
    )

    begin {
        $function = $($MyInvocation.MyCommand.Name)
        Write-Verbose "Running $function"

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
            # Resolve Software Update Group
            if ($CI_ID) {
                $groupQuery = "SELECT CI_ID, LocalizedDisplayName FROM SMS_AuthorizationList WHERE CI_ID = $CI_ID"
            } else {
                $groupQuery = "SELECT CI_ID, LocalizedDisplayName FROM SMS_AuthorizationList WHERE LocalizedDisplayName = '$Name'"
            }
            Write-Verbose "Resolving software update group: $groupQuery"
            $resolvedGroup = Get-CimInstance @cimParams -Query $groupQuery
            if (-not $resolvedGroup) {
                throw "Software update group '$Name' not found."
            }
            $groupCIID = [int]$resolvedGroup.CI_ID
            $groupName = $resolvedGroup.LocalizedDisplayName

            if ($PSCmdlet.ShouldProcess("Software update group '$groupName' (CI_ID: $groupCIID)", "Remove")) {
                if ($WhatIf) {
                    Write-Host "WhatIf: Would remove software update group '$groupName' (CI_ID: $groupCIID)"
                    return
                }
                Remove-CimInstance -CimSession $script:CMConnection.CimSession -InputObject $resolvedGroup
                Write-Host "Removed software update group '$groupName' (CI_ID: $groupCIID)"
                return [PSCustomObject]@{
                    CI_ID = $groupCIID
                    Name = $groupName
                    Status = 'Removed'
                }
            }
        } catch {
            Write-Error $_
            throw $_
        }
    }
}
