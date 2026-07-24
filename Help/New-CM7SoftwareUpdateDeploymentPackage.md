# New-CM7SoftwareUpdateDeploymentPackage

## SYNOPSIS

Creates a new software update deployment package in MECM using CIM connectivity.

## DESCRIPTION

Creates a new software update deployment package (SMS_SoftwareUpdatePackage) in Microsoft Endpoint Configuration Manager (MECM) using CIM. This is the CIM-based equivalent of New-CMSoftwareUpdateDeploymentPackage from the ConfigurationManager module, but uses direct CIM queries.

The function performs the following actions:
1. Validates an active connection (Connect-CM7)
2. Resolves the software update group by name
3. Creates a new SMS_SoftwareUpdatePackage instance via CIM with the specified parameters
4. Returns the created package as a formatted MECM7.SoftwareUpdateDeploymentPackage object

## PARAMETERS

### Name



- Type: String
- Required: true
- Accept pipeline input: false
- Accept wildcard characters: false

### Path



- Type: String
- Required: true
- Accept pipeline input: false
- Accept wildcard characters: false

### Description

An optional description for the deployment package.

- Type: String
- Required: false
- Accept pipeline input: false
- Accept wildcard characters: false

## EXAMPLES

### Example 1

```powershell
New-CM7SoftwareUpdateDeploymentPackage -SoftwareUpdateGroupName "Test-SUG" -DeploymentPackageName "Test-DeploymentPackage" -PackageSourcePath "\\mecm.yourdomain.local\Patches\Test" -Description "Test deployment package created by automated tests"
```
