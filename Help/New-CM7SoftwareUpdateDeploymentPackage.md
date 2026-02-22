# New-CM7SoftwareUpdateDeploymentPackage

## SYNOPSIS
Creates a new software update deployment package in MECM using CIM connectivity.

## DESCRIPTION
Creates a new software update deployment package (SMS_SoftwareUpdatePackage) in Microsoft Endpoint Configuration Manager (MECM) using CIM. This is the CIM-based equivalent of New-CMSoftwareUpdateDeploymentPackage from the ConfigurationManager module, but uses direct CIM queries.

## PARAMETERS
- **SoftwareUpdateGroupName**: The name of the software update group to package.
- **DeploymentPackageName**: The name for the new deployment package.
- **PackageSourcePath**: The UNC path for the package source (e.g., \\server\share\path).
- **Description**: An optional description for the deployment package.

## EXAMPLES
```
New-CM7SoftwareUpdateDeploymentPackage -SoftwareUpdateGroupName "Test-SUG" -DeploymentPackageName "Test-DeploymentPackage" -PackageSourcePath "\\mecm.yourdomain.local\Patches\Test" -Description "Test deployment package created by automated tests"
```

## NOTES
- Requires an active connection via Connect-CM7.
- Uses CIM connectivity for all operations.
