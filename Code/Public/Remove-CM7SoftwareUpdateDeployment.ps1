
function Remove-CM7SoftwareUpdateDeployment {
    <#
        .SYNOPSIS
            Removes a software update deployment from a collection using CIM connectivity.

        .DESCRIPTION
            Removes a deployment of a software update group from a device collection in MECM, using CIM. This is the CIM-based equivalent of Remove-CMSoftwareUpdateDeployment from the ConfigurationManager module.

        .PARAMETER SoftwareUpdateGroupName
            The name of the software update group whose deployment should be removed.

        .PARAMETER SoftwareUpdateGroupID
            The CI_ID of the software update group whose deployment should be removed.

        .PARAMETER CollectionName
            The name of the collection from which to remove the deployment.

        .PARAMETER CollectionID
            The CollectionID of the collection from which to remove the deployment.

        .PARAMETER Force
            Suppresses confirmation prompts.

        .PARAMETER WhatIf
            Shows what would happen if the cmdlet runs. The cmdlet is not run.

        .EXAMPLE
            Remove-CM7SoftwareUpdateDeployment -SoftwareUpdateGroupName "Test-SUG" -CollectionName "Test-Collection-Direct" -Force

        .NOTES
            Requires an active connection established via Connect-CM7.
    #>
    [CmdletBinding(DefaultParameterSetName='SUGNameCollectionName',SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param(
        [Parameter(ParameterSetName='SUGNameCollectionName', Mandatory=$true)]
        [Parameter(ParameterSetName='SUGNameCollectionID', Mandatory=$true)]
        [string]$SoftwareUpdateGroupName,

        [Parameter(ParameterSetName='SUGIDCollectionName', Mandatory=$true)]
        [Parameter(ParameterSetName='SUGIDCollectionID', Mandatory=$true)]
        [string]$SoftwareUpdateGroupID,

        [Parameter(ParameterSetName='SUGNameCollectionName', Mandatory=$true)]
        [Parameter(ParameterSetName='SUGIDCollectionName', Mandatory=$true)]
        [string]$CollectionName,

        [Parameter(ParameterSetName='SUGNameCollectionID', Mandatory=$true)]
        [Parameter(ParameterSetName='SUGIDCollectionID', Mandatory=$true)]
        [string]$CollectionID,

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
            if ($SoftwareUpdateGroupID) {
                $groupQuery = "SELECT CI_ID, LocalizedDisplayName FROM SMS_AuthorizationList WHERE CI_ID = $SoftwareUpdateGroupID"
            } else {
                $groupQuery = "SELECT CI_ID, LocalizedDisplayName FROM SMS_AuthorizationList WHERE LocalizedDisplayName = '$SoftwareUpdateGroupName'"
            }
            Write-Verbose "Resolving software update group: $groupQuery"
            $resolvedGroup = Get-CimInstance @cimParams -Query $groupQuery
            if (-not $resolvedGroup) {
                throw "Software update group '$SoftwareUpdateGroupName' not found."
            }
            $groupCIID = [int]$resolvedGroup.CI_ID
            $SoftwareUpdateGroupName = $resolvedGroup.LocalizedDisplayName

            # Resolve Collection
            if ($CollectionID) {
                $collectionQuery = "SELECT CollectionID, Name FROM SMS_Collection WHERE CollectionID = '$CollectionID'"
            } else {
                $collectionQuery = "SELECT CollectionID, Name FROM SMS_Collection WHERE Name = '$CollectionName'"
            }
            Write-Verbose "Resolving collection: $collectionQuery"
            $resolvedCollection = Get-CimInstance @cimParams -Query $collectionQuery
            if (-not $resolvedCollection) {
                throw "Collection '$CollectionName' not found."
            }
            $collectionID = $resolvedCollection.CollectionID
            $CollectionName = $resolvedCollection.Name

            # Find deployment
            $deploymentQuery = "SELECT * FROM SMS_UpdateGroupAssignment WHERE AssignedUpdateGroup = '${groupCIID}' AND TargetCollectionID = '${collectionID}'"
            Write-Verbose "Finding deployment: $deploymentQuery"
            $deployments = Get-CimInstance @cimParams -Query $deploymentQuery
            if (-not $deployments) {
                throw "Deployment for SUG '$SoftwareUpdateGroupName' and collection '$CollectionName' not found."
            }

            if ($PSCmdlet.ShouldProcess("Deployment for SUG '$SoftwareUpdateGroupName' in collection '$CollectionName'", "Remove")) {
                if ($WhatIf) {
                    Write-Host "WhatIf: Would remove deployment for SUG '$SoftwareUpdateGroupName' from collection '$CollectionName'"
                    return
                }
                foreach ($deployment in $deployments) {
                    $assignmentID = $deployment.AssignmentID
                    Write-Verbose "Removing deployment with AssignmentID: $assignmentID"
                    Remove-CimInstance -CimSession $script:CMConnection.CimSession -InputObject $deployment
                }
                Write-Host "Removed deployment for SUG '$SoftwareUpdateGroupName' from collection '$CollectionName'"
            }
        } catch {
            Write-Error $_
            throw $_
        }
    }
}
