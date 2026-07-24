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

        .PARAMETER Name
            The name for the new deployment package.

        .PARAMETER Path
            The UNC path for the package source (e.g., \\server\share\path).

        .PARAMETER Description
            An optional description for the deployment package.

        .EXAMPLE
            New-CM7SoftwareUpdateDeploymentPackage -Name "Test-DeploymentPackage" -Path "\\<FQDN>\Data\SCCM\Security-Patches\Test" -Description "Test deployment package created by automated tests"
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
    $existingPkg = Get-CM7SoftwareUpdateDeploymentPackage -Name $Name -ErrorAction Ignore
    if ($existingPkg) {
        throw "A deployment package with the name '$Name' already exists."
    }

    # Check for existing package with the same source path
    $existingPath = Get-CM7SoftwareUpdateDeploymentPackage -ErrorAction Ignore | Where-Object { $_.PkgSourcePath -eq $Path }
    if ($existingPath) {
        throw "A deployment package with the source path '$Path' already exists (PackageID: $($existingPath.PackageID), Name: $($existingPath.Name))."
    }

    if (-not (Test-CM7RemotePath -Path $Path)) {
        $parentPath = Split-Path -Path $Path -Parent
        if (-not (Test-CM7RemotePath -Path $parentPath)) {
            throw "The specified package source path '$Path' does not exist or is not accessible from the MECM server. Additionally, the parent path '$parentPath' is also inaccessible."
        }
        else {
            # The parent path exists, but the specified path does not. Create the directory on the MECM server.

            New-CM7RemotePath -Path $Path -ErrorAction Stop
            Write-Verbose "Created directory '$Path' on the MECM server."
        }
    }

    $namespace = "root/SMS/site_$($script:CMConnection.SiteCode)"
    $cimSession = $script:CMConnection.CimSession

    # PkgSourceFlag is computed by the SMS Provider when PkgSourcePath is set — do not pass it explicitly
    $packageProps = @{
        Name          = $Name
        PkgSourcePath = $Path
        PkgSourceFlag = 2
    }
    if ($Description) { $packageProps['Description'] = $Description }

    $newPackage = New-CimInstance -CimSession $cimSession -Namespace $namespace -ClassName "SMS_SoftwareUpdatesPackage" -Property $packageProps -ErrorAction Stop

    if (-not $newPackage) {
        throw "Failed to create deployment package '$Name'. New-CimInstance returned null."
    }

    # Return object
    $newPackage
}
