# Get-CM7UserCollectionDirectMembershipRule

## SYNOPSIS

Retrieves direct membership information for a MECM user collection using CIM.

## DESCRIPTION

Queries the SMS_FullCollectionMembership WMI class to retrieve direct membership information for a MECM user collection.
Direct members are resources that have been explicitly added to a user collection (as opposed to being added via
query rules, include collections, or exclude collections). Supports filtering by collection name, CollectionId,
resource name, or resource ID. Requires an active connection established via Connect-CM7.

## PARAMETERS

### CollectionName

Specifies the name of the user collection to retrieve direct members for.

- Type: String
- Required: false
- Accept pipeline input: true (ByPropertyName)
- Accept wildcard characters: false

### CollectionId

Specifies the CollectionID of the user collection to retrieve direct members for.

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
Get-CM7UserCollectionDirectMembershipRule -CollectionName "All Systems"
            Retrieves all resources that are direct members of the "All Systems" user collection.
```

### Example 2

```powershell
Get-CM7UserCollectionDirectMembershipRule -CollectionName "All Systems" -ResourceName "TEST-*"
            Retrieves all resources matching the pattern "TEST-*" that are direct members of the "All Systems" user collection.
```

### Example 3

```powershell
Get-CM7UserCollectionDirectMembershipRule -CollectionId "SMS00001" -ResourceId 16777220
            Retrieves direct membership information for resource 16777220 in the "SMS00001" user collection.
```

### Example 4

```powershell
Get-CM7UserCollectionDirectMembershipRule -CollectionName "All Systems" -Fast
            Retrieves direct members with limited properties for better performance.
```

## NOTES

This function queries WMI class SMS_FullCollectionMembership which contains direct membership relationships.
For all members (including members from rules, includes, and excludes), see Get-CM7UserCollectionMember.
