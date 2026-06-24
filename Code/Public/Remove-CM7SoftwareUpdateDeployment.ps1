
function Remove-CM7SoftwareUpdateDeployment {
    <#
        .SYNOPSIS
            Removes a software update deployment from a collection using CIM connectivity.

        .DESCRIPTION
            Removes a deployment of a software update group from a device collection in MECM, using CIM. This is the CIM-based equivalent of Remove-CMSoftwareUpdateDeployment from the ConfigurationManager module.

        .PARAMETER InputObject
            A software update deployment CIM instance (SMS_UpdateGroupAssignment) to remove. Can be piped from Get-CM7SoftwareUpdateDeployment.

        .PARAMETER DeploymentID
            The unique ID (AssignmentUniqueID) of the software update deployment to remove.

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

        .EXAMPLE
            Remove-CM7SoftwareUpdateDeployment -DeploymentID "{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}" -Force

        .EXAMPLE
            Get-CM7SoftwareUpdateDeployment -SoftwareUpdateGroupName "Test-SUG" | Remove-CM7SoftwareUpdateDeployment -Force

        .NOTES
            Requires an active connection established via Connect-CM7.
    #>
    [CmdletBinding(DefaultParameterSetName='SUGNameCollectionName',SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param(
        [Parameter(ParameterSetName='InputObject', Mandatory=$true, ValueFromPipeline=$true)]
        [PSTypeName('MECM7.SoftwareUpdateDeployment')]
        [PSObject]$InputObject,

        [Parameter(ParameterSetName='DeploymentID', Mandatory=$true)]
        [string]$DeploymentID,

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
            $deployments = @()
            $targetDescription = ''

            switch ($PSCmdlet.ParameterSetName) {
                'InputObject' {
                    $deploymentQuery = "SELECT * FROM SMS_UpdatesAssignment WHERE AssignmentID = $($InputObject.AssignmentID)"
                    Write-Verbose "Finding deployment by InputObject AssignmentID $($InputObject.AssignmentID): $deploymentQuery"
                    $deployments = @(Get-CimInstance @cimParams -Query $deploymentQuery)
                    if (-not $deployments) {
                        throw "Deployment with AssignmentID '$($InputObject.AssignmentID)' not found."
                    }
                    $targetDescription = "deployment '$($InputObject.AssignmentName)' (AssignmentID: $($InputObject.AssignmentID))"
                }
                'DeploymentID' {
                    $deploymentQuery = "SELECT * FROM SMS_UpdateGroupAssignment WHERE AssignmentUniqueID = '$DeploymentID'"
                    Write-Verbose "Finding deployment by DeploymentID: $deploymentQuery"
                    $deployments = @(Get-CimInstance @cimParams -Query $deploymentQuery)
                    if (-not $deployments) {
                        throw "Deployment with DeploymentID '$DeploymentID' not found."
                    }
                    $targetDescription = "deployment '$DeploymentID'"
                }
                default {
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
                    $resolvedCollectionID = $resolvedCollection.CollectionID
                    $CollectionName = $resolvedCollection.Name

                    # Find deployment
                    $deploymentQuery = "SELECT * FROM SMS_UpdateGroupAssignment WHERE AssignedUpdateGroup = '${groupCIID}' AND TargetCollectionID = '${resolvedCollectionID}'"
                    Write-Verbose "Finding deployment: $deploymentQuery"
                    $deployments = @(Get-CimInstance @cimParams -Query $deploymentQuery)
                    if (-not $deployments) {
                        throw "Deployment for SUG '$SoftwareUpdateGroupName' and collection '$CollectionName' not found."
                    }
                    $targetDescription = "deployment for SUG '$SoftwareUpdateGroupName' in collection '$CollectionName'"
                }
            }

            if ($PSCmdlet.ShouldProcess($targetDescription, "Remove")) {
                foreach ($deployment in $deployments) {
                    Write-Verbose "Removing deployment with AssignmentID: $($deployment.AssignmentID)"
                    Remove-CimInstance -CimSession $script:CMConnection.CimSession -InputObject $deployment
                }
                Write-Host "Removed $targetDescription"
            }
        } catch {
            Write-Error $_
            throw $_
        }
    }
}
