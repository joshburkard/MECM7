function New-CM7SoftwareUpdateDeploymentPackage {
    <#
        .SYNOPSIS
            Creates a new software update deployment package in MECM using CIM connectivity.

        .DESCRIPTION
            Creates a new software update deployment package (SMS_SoftwareUpdatePackage) in Microsoft Endpoint Configuration Manager (MECM) using CIM. This is the CIM-based equivalent of New-CMSoftwareUpdateDeploymentPackage from the ConfigurationManager module, but uses direct CIM queries.

            The function performs the following actions:
            1. Validates an active connection (Connect-CM7)
            2. Resolves the software update group by name
            3. Creates a new SMS_SoftwareUpdatePackage instance via CIM with the specified parameters
            4. Returns the created package as a formatted MECM7.SoftwareUpdateDeploymentPackage object

        .PARAMETER SoftwareUpdateGroupName
            The name of the software update group to package.

        .PARAMETER DeploymentPackageName
            The name for the new deployment package.

        .PARAMETER PackageSourcePath
            The UNC path for the package source (e.g., \\server\share\path).

        .PARAMETER Description
            An optional description for the deployment package.

        .EXAMPLE
            New-CM7SoftwareUpdateDeploymentPackage -SoftwareUpdateGroupName "Test-SUG" -DeploymentPackageName "Test-DeploymentPackage" -PackageSourcePath "\\sd.dika.be\data\SCCM\Patches\Servers-SecurityPatches\test" -Description "Test deployment package created by automated tests"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name,
        [Parameter(Mandatory)]
        [string]$Path,
        [Parameter()]
        [string]$Description
    )

    # Validate connection
    if (-not $script:CMConnection.CimSession) {
        throw "No active MECM7 connection. Run Connect-CM7 first."
    }

    # Check for existing package with the same name
    Get-CM7SoftwareUpdateDeploymentPackage -Name $Name -ErrorAction Ignore | ForEach-Object {
        throw "A deployment package with the name '$Name' already exists."
    }

    # check if the unc path exists
    # Test-Path does not support UNC paths, so we will use Get-Item and check for exceptions
    if (-not ( [System.IO.Directory]::Exists($Path) )) {
        throw "The specified package source path '$Path' does not exist or is not accessible."
    }

    $namespace = "root/SMS/site_$($script:CMConnection.SiteCode)"
    $cimSession = $script:CMConnection.CimSession
    $packageProps = @{
        Name = $Name
        Description = $Description
        PkgSourcePath = $Path
        PkgSourceFlag = 2 # UNC source
    }
    $newPackage = New-CimInstance -CimSession $cimSession -Namespace $namespace -ClassName "SMS_SoftwareUpdatesPackage" -Property $packageProps

    # Return object
    $newPackage
}
