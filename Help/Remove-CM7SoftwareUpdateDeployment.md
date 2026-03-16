# Remove-CM7SoftwareUpdateDeployment

## SYNOPSIS

Removes a software update deployment from a collection using CIM connectivity.

## DESCRIPTION

Removes a deployment of a software update group from a device collection in MECM, using CIM. This is the CIM-based equivalent of Remove-CMSoftwareUpdateDeployment from the ConfigurationManager module.

## PARAMETERS

### InputObject

A software update deployment CIM instance (SMS_UpdateGroupAssignment) to remove. Can be piped from Get-CM7SoftwareUpdateDeployment.

- Type: PSObject
- Required: true
- Accept pipeline input: true (ByValue)
- Accept wildcard characters: false

### DeploymentID

The unique ID (AssignmentUniqueID) of the software update deployment to remove.

- Type: String
- Required: true
- Accept pipeline input: false
- Accept wildcard characters: false

### SoftwareUpdateGroupName

The name of the software update group whose deployment should be removed.

- Type: String
- Required: true
- Accept pipeline input: false
- Accept wildcard characters: false

### SoftwareUpdateGroupID

The CI_ID of the software update group whose deployment should be removed.

- Type: String
- Required: true
- Accept pipeline input: false
- Accept wildcard characters: false

### CollectionName

The name of the collection from which to remove the deployment.

- Type: String
- Required: true
- Accept pipeline input: false
- Accept wildcard characters: false

### CollectionID

The CollectionID of the collection from which to remove the deployment.

- Type: String
- Required: true
- Accept pipeline input: false
- Accept wildcard characters: false

### Force

Suppresses confirmation prompts.

- Type: SwitchParameter
- Required: false
- Default value: False
- Accept pipeline input: false
- Accept wildcard characters: false

### WhatIf

Shows what would happen if the cmdlet runs. The cmdlet is not run.

- Type: SwitchParameter
- Required: false
- Accept pipeline input: false
- Accept wildcard characters: false

### Confirm



- Type: SwitchParameter
- Required: false
- Accept pipeline input: false
- Accept wildcard characters: false

## EXAMPLES

### Example 1

```powershell
Remove-CM7SoftwareUpdateDeployment -SoftwareUpdateGroupName "Test-SUG" -CollectionName "Test-Collection-Direct" -Force
```

### Example 2

```powershell
Remove-CM7SoftwareUpdateDeployment -DeploymentID "{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}" -Force
```

### Example 3

```powershell
Get-CM7SoftwareUpdateDeployment -SoftwareUpdateGroupName "Test-SUG" | Remove-CM7SoftwareUpdateDeployment -Force
```

## NOTES

Requires an active connection established via Connect-CM7.
