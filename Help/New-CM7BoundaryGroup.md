# New-CM7BoundaryGroup

## SYNOPSIS

Creates a new boundary group in MECM using CIM.

## DESCRIPTION

Creates a new boundary group (SMS_BoundaryGroup) in Microsoft Endpoint Configuration Manager
(MECM) using CIM. Supports setting a name, description, default site code for automatic site
assignment, and optionally associating site system servers.
Requires an active connection via Connect-CM7.

This is the CIM-based equivalent of the New-CMBoundaryGroup cmdlet from the
ConfigurationManager PowerShell module, but uses direct CIM queries over WinRM.

## PARAMETERS

### Name

The name of the new boundary group. Must be unique within the MECM environment. (Mandatory)

- Type: String
- Required: true
- Accept pipeline input: false
- Accept wildcard characters: false

### Description

An optional description for the new boundary group.

- Type: String
- Required: false
- Accept pipeline input: false
- Accept wildcard characters: false

### DefaultSiteCode

The default site code to use for automatic site assignment for clients in this boundary group.

- Type: String
- Required: false
- Accept pipeline input: false
- Accept wildcard characters: false

### AddSiteSystemServerName

One or more site system server fully qualified domain names (FQDNs) to associate with the
new boundary group. These servers will be added as site system references for the group.
Alias: AddSiteSystemServerNames

- Type: String[]
- Required: false
- Accept pipeline input: false
- Accept wildcard characters: false

### DisableWildcardHandling

Treats wildcard characters as literal character values.
Cannot be combined with ForceWildcardHandling.

- Type: SwitchParameter
- Required: false
- Default value: False
- Accept pipeline input: false
- Accept wildcard characters: false

### ForceWildcardHandling

Forces wildcard character processing even in contexts where it is not normally supported.
May lead to unexpected behavior (not recommended).
Cannot be combined with DisableWildcardHandling.

- Type: SwitchParameter
- Required: false
- Default value: False
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

Prompts you for confirmation before running the cmdlet.

- Type: SwitchParameter
- Required: false
- Accept pipeline input: false
- Accept wildcard characters: false

## EXAMPLES

### Example 1

```powershell
New-CM7BoundaryGroup -Name "Test"
            Creates a new boundary group named "Test".
```

### Example 2

```powershell
New-CM7BoundaryGroup -Name "BGroup05" -Description "My boundary group" -DefaultSiteCode "PS1"
            Creates a new boundary group with a description and default site code.
```

### Example 3

```powershell
New-CM7BoundaryGroup -Name "BGroup06" -AddSiteSystemServerName "server01.contoso.com" -Force
            Creates a boundary group and associates a site system server without prompting for confirmation.
```

## NOTES

Requires an active connection established via Connect-CM7.
The SMS_BoundaryGroup WMI class is used to represent boundary groups in MECM.
Site system server associations are stored in the SMS_BoundaryGroupSiteSystems WMI class.
For more information on return object properties, see SMS_BoundaryGroup server WMI class:
https://learn.microsoft.com/en-us/mem/configmgr/develop/reference/core/servers/configure/sms_boundarygroup-server-wmi-class
