function Remove-CM7SoftwareUpdateDeploymentPackage {
    <#
        .SYNOPSIS
            Removes a software update deployment package from MECM using CIM.

        .DESCRIPTION
            Removes (deletes) a software update deployment package (SMS_SoftwareUpdatesPackage)
            from Microsoft Endpoint Configuration Manager (MECM) using CIM.

            This is the CIM-based equivalent of Remove-CMSoftwareUpdateDeploymentPackage from the
            ConfigurationManager PowerShell module, but uses direct CIM queries over WinRM.

            The function performs the following actions:
            1. Validates an active connection exists (established via Connect-CM7)
            2. Resolves the package by name or package ID
            3. Removes the SMS_SoftwareUpdatesPackage instance via CIM (with confirmation by default)

            Key features:
            - Remove by Name or PackageID
            - Wildcard Support for Name
            - Pipeline Support (future)
            - Force Parameter: Bypass confirmation prompts for scripted scenarios
            - WhatIf/Confirm: Full ShouldProcess support for safe operations

        .PARAMETER Name
            The name of the software update deployment package to remove. Supports wildcards.

        .PARAMETER Id
            The PackageID of the software update deployment package to remove.

        .PARAMETER InputObject
            A software update deployment package object (from Get-CM7SoftwareUpdateDeploymentPackage) to remove.

        .PARAMETER Force
            Suppresses confirmation prompts and removes the package without asking.

        .PARAMETER WhatIf
            Shows what would happen if the cmdlet runs. The cmdlet is not run.

        .PARAMETER Confirm
            Prompts you for confirmation before running the cmdlet.

        .EXAMPLE
            Remove-CM7SoftwareUpdateDeploymentPackage -Name "Test-SUG" -Force

        .EXAMPLE
            Remove-CM7SoftwareUpdateDeploymentPackage -Id "XXX00001" -Force

        .EXAMPLE
            $pkg = Get-CM7SoftwareUpdateDeploymentPackage -Name "Test-SUG"
            Remove-CM7SoftwareUpdateDeploymentPackage -InputObject $pkg -Force

        .NOTES
            Requires an active connection established via Connect-CM7.
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High', DefaultParameterSetName = 'ByName')]
    param(
        [Parameter(ParameterSetName = 'ByName', Mandatory = $true)]
        [SupportsWildcards()]
        [string]$Name,

        [Parameter(ParameterSetName = 'ById', Mandatory = $true)]
        [string]$Id,

        [Parameter(ParameterSetName = 'ByInputObject', Mandatory = $true, ValueFromPipeline = $true)]
        [PSObject]$InputObject,

        [Parameter()]
        [switch]$Force
    )

    begin {
        $function = $($MyInvocation.MyCommand.Name)
        Write-Verbose "Running $function"

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
            $pkgsToRemove = @()
            switch ($PSCmdlet.ParameterSetName) {
                'ByName' {
                    $wqlName = $Name.Replace('*', '%').Replace('?', '_')
                    $query = if ($wqlName -like '*%*' -or $wqlName -like '*_*') {
                        "SELECT * FROM SMS_SoftwareUpdatesPackage WHERE Name LIKE '$wqlName'"
                    } else {
                        "SELECT * FROM SMS_SoftwareUpdatesPackage WHERE Name = '$Name'"
                    }
                    Write-Verbose "Querying for package(s) by name: $query"
                    $pkgs = @(Get-CimInstance @cimParams -Query $query)
                    if (-not $pkgs -or $pkgs.Count -eq 0) {
                        throw "No software update deployment package(s) found matching name '$Name'."
                    }
                    $pkgsToRemove = $pkgs
                }
                'ById' {
                    $query = "SELECT * FROM SMS_SoftwareUpdatesPackage WHERE PackageID = '$Id'"
                    Write-Verbose "Querying for package by ID: $query"
                    $pkg = Get-CimInstance @cimParams -Query $query
                    if (-not $pkg) {
                        throw "No software update deployment package found with PackageID '$Id'."
                    }
                    $pkgsToRemove = @($pkg)
                }
                'ByInputObject' {
                    $pkgId = $InputObject.PackageID
                    if (-not $pkgId) {
                        throw "InputObject does not have a PackageID property."
                    }
                    $query = "SELECT * FROM SMS_SoftwareUpdatesPackage WHERE PackageID = '$pkgId'"
                    Write-Verbose "Querying for package by InputObject: $query"
                    $pkg = Get-CimInstance @cimParams -Query $query
                    if (-not $pkg) {
                        throw "No software update deployment package found with PackageID '$pkgId' from InputObject."
                    }
                    $pkgsToRemove = @($pkg)
                }
            }

            foreach ($pkg in $pkgsToRemove) {
                $displayName = "$($pkg.Name) ($($pkg.PackageID))"
                $actionDescription = "Remove software update deployment package '$($pkg.Name)' ($($pkg.PackageID))"
                if ($Force -or $PSCmdlet.ShouldProcess($displayName, $actionDescription)) {
                    Write-Verbose "Removing package: $actionDescription"
                    Remove-CimInstance -CimSession $script:CMConnection.CimSession -InputObject $pkg
                    Write-Verbose "Software update deployment package '$($pkg.Name)' ($($pkg.PackageID)) removed successfully."
                    [PSCustomObject]@{
                        PSTypeName   = 'MECM7.RemovedSoftwareUpdateDeploymentPackage'
                        PackageID    = $pkg.PackageID
                        Name         = $pkg.Name
                        Status       = 'Removed'
                    }
                }
            }
        } catch {
            throw $_
        }
    }
}
