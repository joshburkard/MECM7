# Test Coverage Report

This file tracks the test coverage status for all functions in the MECMAdminService module.

**Last Updated:** 2026-02-20 10:12:54

| Function | Status | Passed | Failed | Skipped | Coverage % | Duration |
|----------|--------|--------|--------|---------|------------|----------|
| Get-CM7ScriptExecutionStatus | Test-Get-CM7ScriptExecutionStatus.Tests.ps1 | 🟢 Passed | 20 | 0 | 0 | 93.75% | 21.15s |
| Get-CM7DeviceCollection | Test-Get-CM7DeviceCollection.Tests.ps1 | 🟢 Passed | 18 | 0 | 0 | 100% | 56.2s |
| Get-CM7UserCollection | Test-Get-CM7UserCollection.Tests.ps1 | 🟢 Passed | 18 | 0 | 0 | 100% | 7.06s |
| Get-CM7Deployment | Test-Get-CM7Deployment.Tests.ps1 | 🟢 Passed | 18 | 0 | 0 | 97.3% | 16.2s |
| Get-CM7SoftwareUpdateDeployment | Test-Get-CM7SoftwareUpdateDeployment.Tests.ps1 | 🟢 Passed | 20 | 0 | 0 | 96.08% | 143.74s |
| Get-CM7SoftwareUpdate | Test-Get-CM7SoftwareUpdate.Tests.ps1 | 🟢 Passed | 21 | 0 | 0 | 61.24% | 49.78s |
| Get-CM7SoftwareUpdateDeploymentPackage | Test-Get-CM7SoftwareUpdateDeploymentPackage.Tests.ps1 | 🟢 Passed | 18 | 0 | 0 | 91.36% | 5.12s |
| Get-CM7SoftwareUpdateGroup | Test-Get-CM7SoftwareUpdateGroup.Tests.ps1 | 🟢 Passed | 18 | 0 | 0 | 94.64% | 32.05s |
| New-CM7SoftwareUpdateGroup | Test-New-CM7SoftwareUpdateGroup.Tests.ps1 | 🟢 Passed | 14 | 0 | 0 | 82.02% | 25.62s |
| New-CM7SoftwareUpdateDeployment | Test-New-CM7SoftwareUpdateDeployment.Tests.ps1 | 🟢 Passed | 18 | 0 | 0 | 92.51% | 29.7s |
| Add-CM7SoftwareUpdateToGroup | Test-Add-CM7SoftwareUpdateToGroup.Tests.ps1 | 🟡 Partial | 16 | 0 | 2 | 94.52% | 14.5s |
| Invoke-CM7ClientNotification | Test-Invoke-CM7ClientNotification.Tests.ps1 | 🟢 Passed | 24 | 0 | 0 | 91.4% | 5.1s |
| Invoke-CM7CollectionUpdate | Test-Invoke-CM7CollectionUpdate.Tests.ps1 | 🟢 Passed | 20 | 0 | 0 | 87.27% | 6.92s |
| Get-CM7TaskSequence | Test-Get-CM7TaskSequence.Tests.ps1 | 🟢 Passed | 18 | 0 | 0 | 89.89% | 230.3s |
| New-CM7Schedule | Test-New-CM7Schedule.Tests.ps1 | 🟢 Passed | 39 | 0 | 0 | 97.14% | 5.23s |
| Add-CM7CollectionMembershipRule | 🟢 Passed | 31 | 0 | 0 | 92.86% | 62.19s |
| Connect-CM7 | 🟡 Partial | 25 | 0 | 2 | 100% | 8.9s |
| Get-CM7Collection | 🟢 Passed | 18 | 0 | 0 | 96.88% | 23.39s |
| Get-CM7CollectionDirectMembershipRule | 🟢 Passed | 19 | 0 | 0 | 83.33% | 4.84s |
| Get-CM7CollectionExcludeMembershipRule | 🟢 Passed | 17 | 0 | 0 | 90.74% | 5.01s |
| Get-CM7CollectionIncludeMembershipRule | 🟢 Passed | 17 | 0 | 0 | 90.74% | 6.21s |
| Get-CM7CollectionMember | 🟢 Passed | 20 | 0 | 0 | 93.33% | 4.11s |
| Get-CM7CollectionQueryMembershipRule | 🟢 Passed | 16 | 0 | 0 | 90.2% | 4.16s |
| Get-CM7CollectionVariable | 🟢 Passed | 20 | 0 | 0 | 56.36% | 6.61s |
| Get-CM7Device | 🟢 Passed | 19 | 0 | 0 | 93.33% | 18.43s |
| Get-CM7DeviceVariable | 🟡 Partial | 18 | 0 | 2 | 87.72% | 7.36s |
| Get-CM7MaintenanceWindow | Test-Get-CM7MaintenanceWindow.Tests.ps1 | 🟢 Passed | 19 | 0 | 0 | 90.36% | 6.26s |
| Invoke-CM7Connection | 🟡 Partial | 18 | 0 | 1 | 81.58% | 5.53s |
| Invoke-CM7Script | Test-Invoke-CM7Script.Tests.ps1 | 🟢 Passed | 16 | 0 | 0 | 81.34% | 6.08s |
| Move-CM7Object | 🟢 Passed | 20 | 0 | 0 | 78.28% | 8.37s |
| New-CM7DeviceCollectionVariable | 🟢 Passed | 19 | 0 | 0 | 85.15% | 9.7s |
| New-CM7DeviceVariable | Test-New-CM7DeviceVariable.Tests.ps1 | 🟢 Passed | 19 | 0 | 0 | 83.17% | 14.88s |
| Remove-CM7Collection | 🟢 Passed | 15 | 0 | 0 | 91.14% | 17.95s |
| Remove-CM7CollectionMembershipRule | 🟢 Passed | 36 | 0 | 0 | 83.62% | 240.13s |
| Remove-CM7DeviceCollectionVariable | 🟢 Passed | 16 | 0 | 0 | 93.07% | 23.6s |
| Remove-CM7DeviceVariable | Test-Remove-CM7DeviceVariable.Tests.ps1 | 🟢 Passed | 16 | 0 | 0 | 92.93% | 13.38s |
| Remove-CM7MaintenanceWindow | Test-Remove-CM7MaintenanceWindow.Tests.ps1 | 🟢 Passed | 24 | 0 | 0 | 93.88% | 18.78s |

## Legend

- 🟢 **Passed** - All tests passed
- 🟡 **Partial** - Some tests passed, some skipped
- 🔴 **Failed** - One or more tests failed
- ⏳ **Not Run** - Tests have not been executed yet
































































