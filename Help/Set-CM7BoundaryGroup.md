# Set-CM7BoundaryGroup

## SYNOPSIS

Modifies the properties of a boundary group in MECM using CIM.

## DESCRIPTION

Modifies properties of an existing boundary group (SMS_BoundaryGroup) in Microsoft Endpoint
Configuration Manager (MECM) using CIM.
Supports renaming, updating description, assigning a default site code, managing site system
server associations, and configuring peer download options.
Requires an active connection via Connect-CM7.

This is the CIM-based equivalent of the Set-CMBoundaryGroup cmdlet from the
ConfigurationManager PowerShell module, but uses direct CIM queries over WinRM.

The function supports identifying boundary groups by:
- Name:        looks up the boundary group by name
- Id (GroupID): looks up the boundary group by its integer GroupID
- InputObject:  accepts a boundary group object from the pipeline (e.g., from Get-CM7BoundaryGroup)

## PARAMETERS

### Name

The name of the boundary group to modify.

- Type: String
- Required: true
- Accept pipeline input: false
- Accept wildcard characters: false

### Id

The GroupID of the boundary group to modify.
Alias: GroupId

- Type: String
- Required: true
- Accept pipeline input: false
- Accept wildcard characters: false

### InputObject

A boundary group object (e.g., from Get-CM7BoundaryGroup) to modify.
Accepts pipeline input. Must have a GroupID property.

- Type: PSObject
- Required: true
- Accept pipeline input: true (ByValue)
- Accept wildcard characters: false

### NewName

A new name to rename the boundary group to.

- Type: String
- Required: false
- Accept pipeline input: false
- Accept wildcard characters: false

### Description

A new description for the boundary group.

- Type: String
- Required: false
- Accept pipeline input: false
- Accept wildcard characters: false

### DefaultSiteCode

The site code to set for automatic site assignment. Set to $null or empty string to disable
site assignment for this boundary group.

- Type: String
- Required: false
- Accept pipeline input: false
- Accept wildcard characters: false

### AddSiteSystemServerName

One or more site system server fully qualified domain names (FQDNs) to add to the
boundary group. Alias: AddSiteSystemServerNames

- Type: String[]
- Required: false
- Accept pipeline input: false
- Accept wildcard characters: false

### RemoveSiteSystemServerName

One or more site system server fully qualified domain names (FQDNs) to remove from the
boundary group. Alias: RemoveSiteSystemServerNames

- Type: String[]
- Required: false
- Accept pipeline input: false
- Accept wildcard characters: false

### ClearSiteSystemServer

Remove all site system server associations from the boundary group.
Alias: ClearSiteSystemServers

- Type: SwitchParameter
- Required: false
- Default value: False
- Accept pipeline input: false
- Accept wildcard characters: false

### AllowPeerDownload

Configure whether peer downloads are enabled in this boundary group.
Corresponds to bit 0x0002 in the Flags property of SMS_BoundaryGroup.

- Type: Boolean
- Required: false
- Default value: False
- Accept pipeline input: false
- Accept wildcard characters: false

### SubnetPeerDownloadOnly

Configure whether only peers within the same subnet are used for peer downloads.
Requires AllowPeerDownload to be enabled.
Corresponds to bit 0x0004 in the Flags property of SMS_BoundaryGroup.
Alias: PeerWithinSameSubnetOnly

- Type: Boolean
- Required: false
- Default value: False
- Accept pipeline input: false
- Accept wildcard characters: false

### PreferDPOverPeer

Configure whether distribution points are preferred over peers within the same subnet.
Requires AllowPeerDownload to be enabled.
Corresponds to bit 0x0008 in the Flags property of SMS_BoundaryGroup.
Alias: PreferDistributionPointOverPeerInSubnet

- Type: Boolean
- Required: false
- Default value: False
- Accept pipeline input: false
- Accept wildcard characters: false

### PreferCloudDPOverDP

Configure whether cloud-based sources are preferred over on-premises distribution points.
Corresponds to bit 0x0010 in the Flags property of SMS_BoundaryGroup.
Alias: PreferCloudDistributionPointOverDistributionPoint

- Type: Boolean
- Required: false
- Default value: False
- Accept pipeline input: false
- Accept wildcard characters: false

### PassThru

Returns the modified boundary group object. By default this cmdlet does not generate output.

- Type: SwitchParameter
- Required: false
- Default value: False
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
Set-CM7BoundaryGroup -Name "BGroup01" -NewName "BGroup00"
            Renames the boundary group "BGroup01" to "BGroup00".
```

### Example 2

```powershell
Set-CM7BoundaryGroup -Name "Test" -Description "Updated description" -DefaultSiteCode "PS1"
            Updates the description and default site code of the boundary group named "Test".
```

### Example 3

```powershell
Set-CM7BoundaryGroup -Name "Remote BG" -AddSiteSystemServerName "server01.contoso.com"
            Adds a site system server to the boundary group.
```

### Example 4

```powershell
Set-CM7BoundaryGroup -Name "Remote BG" -ClearSiteSystemServer
            Removes all site system server associations from the boundary group.
```

### Example 5

```powershell
Set-CM7BoundaryGroup -Name "Test" -AllowPeerDownload $true -SubnetPeerDownloadOnly $true
            Enables peer downloads and restricts them to same-subnet peers.
```

### Example 6

```powershell
Get-CM7BoundaryGroup -Name "BGroup01" | Set-CM7BoundaryGroup -NewName "BGroup00"
            Renames a boundary group using the pipeline.
```

### Example 7

```powershell
Set-CM7BoundaryGroup -Id "16777219" -Description "Updated via ID" -PassThru
            Updates the description of the boundary group with GroupID 16777219 and returns the modified object.
```

## NOTES

Requires an active connection established via Connect-CM7.
The SMS_BoundaryGroup WMI class is used to represent boundary groups in MECM.
Site system server associations are managed via the AddSiteSystem / RemoveSiteSystem CIM methods.
Peer download options are stored as bit flags in the Flags property of SMS_BoundaryGroup:
0x0002 = AllowPeerDownload
0x0004 = SubnetPeerDownloadOnly
0x0008 = PreferDPOverPeer
0x0010 = PreferCloudDPOverDP
For more information, see:
https://learn.microsoft.com/en-us/mem/configmgr/develop/reference/core/servers/configure/sms_boundarygroup-server-wmi-class
