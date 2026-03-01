# Get-CM7DeviceCollectionDirectMembershipRule

## SYNOPSIS

Retrieves direct membership information for a MECM device collection using CIM.

## DESCRIPTION

Queries the SMS_FullCollectionMembership WMI class to retrieve direct membership information for a MECM device collection.
Direct members are resources that have been explicitly added to a collection (as opposed to being added via
query rules, include collections, or exclude collections). Supports filtering by collection name, CollectionId,
resource name, or resource ID. Requires an active connection established via Connect-CM7.

## PARAMETERS

### CollectionName

Specifies the name of the device collection to retrieve direct members for.

- Type: String
- Required: false
- Accept pipeline input: true (ByPropertyName)
- Accept wildcard characters: false

### CollectionId

Specifies the CollectionID of the device collection to retrieve direct members for.

- Type: String
- Required: false
- Accept pipeline input: true (ByPropertyName)
- Accept wildcard characters: false

### ResourceName

Specifies the name of the resource to retrieve direct membership information for. Supports wildcard characters (*).

- Type: String
- Required: false
- Accept pipeline input: false
- Accept wildcard characters: true

### ResourceId

Specifies the ResourceID of the resource to retrieve direct membership information for.

- Type: Int32
- Required: false
- Default value: -1
- Accept pipeline input: false
- Accept wildcard characters: false

### Fast

Returns limited properties for faster queries. Only returns essential properties like
ResourceID, Name, ResourceType.

- Type: SwitchParameter
- Required: false
- Default value: False
- Accept pipeline input: false
- Accept wildcard characters: false

## EXAMPLES

### Example 1

```powershell
Get-CMDeviceCollectionDirectMembershipRule -CollectionName "All Systems"
            Retrieves all resources that are direct members of the "All Systems" device collection.
```

### Example 2

```powershell
Get-CMDeviceCollectionDirectMembershipRule -CollectionName "All Systems" -ResourceName "TEST-*"
            Retrieves all resources matching the pattern "TEST-*" that are direct members of "All Systems".
```

### Example 3

```powershell
Get-CMDeviceCollectionDirectMembershipRule -CollectionId "SMS00001" -ResourceId 16777220
            Retrieves direct membership information for resource 16777220 in the device collection SMS00001.
```

### Example 4

```powershell
Get-CMDeviceCollectionDirectMembershipRule -CollectionName "All Systems" -Fast
            Retrieves direct members with limited properties for better performance.
```

## NOTES

This function queries WMI class SMS_FullCollectionMembership which contains direct membership relationships.
For all members (including members from rules, includes, and excludes), see Get-CM7CollectionMember.
