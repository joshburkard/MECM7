# ============================================================================
# Test Declarations - Structured Approach
# ============================================================================
# Copy this file to 'declarations.ps1' and fill in your actual test values
# The 'declarations.ps1' file should be added to .gitignore to avoid committing sensitive data

#region Global Connection Settings
# MECM7 Connection
$UserName = ""  # Optional: specify username for credential prompt
$Password = ""  # Optional: specify password for credential prompt

$script:CM7Connection = @{
    SiteServer              = "mecm.yourdomain.local"  # Your MECM site server hostname
    SiteCode                = "CM1"
    Credential              = New-Object System.Management.Automation.PSCredential ( $UserName, ( ConvertTo-SecureString -String $Password -AsPlainText -Force ) )                    # Will be set below if needed
    SkipCertificateCheck    = $true                   # Set to $true if using self-signed certificates
    UseSsl                  = $false                  # Set to $true to use HTTPS for WinRM
}

# this array is used by the test framework to automatically redact sensitive values from test output and logs
$SensitiveValues = @(
    $UserName,
    $Password,
    $script:CM7Connection.Credential,
    $script:CM7Connection.SiteServer,
    $script:CM7Connection.SiteCode
)

# Credential options:
# Option 1: Use current user credentials (no prompt) - leave Credential as $null above
# Option 2: Prompt for credentials (uncomment below)
if(-not $Global:TestCredentialCached){
    # Uncomment the line below to enable credential prompting
    # $Global:TestCredentialCached = Get-Credential -Message "Enter credentials for connecting to the test MECM environment"
}
$script:CM7Connection.Credential = $Global:TestCredentialCached

#endregion

#region Test Execution Control
# Set to $true to run all functional tests during build
# Set to $false (default) to only run tests for functions that changed since last git commit
# This prevents accidentally triggering script executions or other actions in SCCM during routine builds
$script:RunAllFunctionalTests = $false

# Timeout Settings
$script:TestTimeout = 300  # Timeout in seconds for script execution tests
$script:TestPollingInterval = 5  # Polling interval in seconds for status checks
#endregion

#region Test Data by Function
# Organized hashtable structure: Function -> ParameterSet -> Parameters -> Values
# This makes it easy to add new functions and parameter sets

$script:TestData = @{

    # ========================================================================
    # Connect-CM7
    # ========================================================================
    'Connect-CM7' = @{
        Valid = @{
            SiteServer = $script:CM7Connection.SiteServer
            Credential = $script:CM7Connection.Credential
            SkipCertificateCheck = $script:CM7Connection.SkipCertificateCheck
            UseSsl = $script:CM7Connection.UseSsl
        }
        Invalid = @{
            SiteServer = "invalid-server.invalid.local"
        }
    }

    # ========================================================================
    # Get-CM7Device
    # ========================================================================
    'Get-CM7Device' = @{
        ByName = @{
            Name = "TEST-DEVICE-001"  # Replace with an existing device name
            ExpectedCount = 1
        }
        ByResourceId = @{
            ResourceId = 16777220  # Replace with an existing device ResourceID
            ExpectedCount = 1
        }
        ByWildcard = @{
            Name = "TEST-*"  # Wildcard pattern
            ExpectedMinCount = 1
        }
        ByCollectionName = @{
            CollectionName = "All Systems"
            ExpectedMinCount = 1
        }
        ByCollectionId = @{
            CollectionId = "SMS00001"  # "All Systems" collection
            ExpectedMinCount = 1
        }
        Fast = @{
            Name = "TEST-DEVICE-001"
            ExpectedCount = 1
        }
        NonExistent = @{
            Name = "NONEXISTENT-DEVICE-999"
            ExpectedCount = 0
        }
        All = @{
            ExpectedMinCount = 1  # At least 1 device should exist
        }
    }

    # ========================================================================
    # Get-CM7Collection
    # ========================================================================
    'Get-CM7Collection' = @{
        ByName = @{
            Name = "All Systems"
            ExpectedCount = 1
        }
        ByCollectionID = @{
            CollectionID = "SMS00001"  # "All Systems" collection
            ExpectedCount = 1
        }
        NonExistent = @{
            Name = "NonExistent Collection 999"
            CollectionID = "XXX99999"
            ExpectedCount = 0
        }
        All = @{
            ExpectedMinCount = 1  # At least 1 collection should exist
        }
    }

    # ========================================================================
    # Get-CM7DeviceCollection
    # ========================================================================
    'Get-CM7DeviceCollection' = @{
        ByName = @{
            Name = "All Systems"
            ExpectedCount = 1
        }
        ByCollectionID = @{
            CollectionID = "SMS00001"  # "All Systems" device collection
            ExpectedCount = 1
        }
        NonExistent = @{
            Name = "NonExistent Device Collection 999"
            CollectionID = "XXX99999"
            ExpectedCount = 0
        }
        All = @{
            ExpectedMinCount = 1  # At least 1 device collection should exist
        }
    }

    # ========================================================================
    # Get-CM7UserCollection
    # ========================================================================
    'Get-CM7UserCollection' = @{
        ByName = @{
            Name = "All Users"
            ExpectedCount = 1
        }
        ByCollectionID = @{
            CollectionID = "SMS00002"  # "All Users" user collection
            ExpectedCount = 1
        }
        NonExistent = @{
            Name = "NonExistent User Collection 999"
            CollectionID = "XXX99999"
            ExpectedCount = 0
        }
        All = @{
            ExpectedMinCount = 1  # At least 1 user collection should exist
        }
    }

    # ========================================================================
    # Get-CM7CollectionDirectMembershipRule
    # ========================================================================
    'Get-CMASCollectionDirectMembershipRule' = @{
        ByCollectionName = @{
            CollectionName = "All Systems"
            # May return empty if no direct membership rules exist
        }
        ByCollectionId = @{
            CollectionId = "SMS00001"
            # May return empty if no direct membership rules exist
        }
        ByCollectionNameAndResourceName = @{
            CollectionName = "All Systems"
            ResourceName = "TEST-DEVICE-001"  # Replace with device that's directly added
        }
        ByCollectionIdAndResourceId = @{
            CollectionId = "SMS00001"
            ResourceId = 16777220  # Replace with ResourceID directly added
        }
        WithWildcard = @{
            CollectionName = "All Systems"
            ResourceName = "TEST-*"
        }
        NonExistent = @{
            CollectionName = "NonExistent Collection 999"
            CollectionId = "XXX99999"
        }
    }

    # ========================================================================
    # Get-CM7CollectionExcludeMembershipRule
    # ========================================================================
    'Get-CM7CollectionExcludeMembershipRule' = @{
        ByCollectionName = @{
            CollectionName = "All Systems"
            # May return empty if no exclude rules exist
        }
        ByCollectionId = @{
            CollectionId = "SMS00001"
            # May return empty if no exclude rules exist
        }
        ByCollectionNameAndExcludeName = @{
            CollectionName = "All Systems"
            ExcludeCollectionName = "Test Exclude Collection"  # Replace with actual excluded collection
        }
        ByCollectionIdAndExcludeId = @{
            CollectionId = "SMS00001"
            ExcludeCollectionId = "SMS00002"  # Replace with actual excluded collection ID
        }
        WithWildcard = @{
            CollectionName = "All Systems"
            ExcludeCollectionName = "TEST-*"
        }
        NonExistent = @{
            CollectionName = "NonExistent Collection 999"
            CollectionId = "XXX99999"
        }
    }

    # ========================================================================
    # Get-CM7CollectionIncludeMembershipRule
    # ========================================================================
    'Get-CM7CollectionIncludeMembershipRule' = @{
        ByCollectionName = @{
            CollectionName = "Test-Collection-Include"  # Replace with collection that has include rules
            # May return empty if no include rules exist
        }
        ByCollectionId = @{
            CollectionId = "SMS00101"  # Replace with actual collection ID
            # May return empty if no include rules exist
        }
        ByCollectionNameAndIncludeName = @{
            CollectionName = "Test-Collection-Include"
            IncludeCollectionName = "Test-Collection-Direct"  # Replace with actual included collection
        }
        ByCollectionIdAndIncludeId = @{
            CollectionId = "SMS00101"
            IncludeCollectionId = "SMS00100"  # Replace with actual included collection ID
        }
        WithWildcard = @{
            CollectionName = "Test-Collection-Include"
            IncludeCollectionName = "TEST-*"
        }
        NonExistent = @{
            CollectionName = "NonExistent Collection 999"
            CollectionId = "XXX99999"
        }
    }

    # ========================================================================
    # Get-CM7CollectionQueryMembershipRule
    # ========================================================================
    'Get-CM7CollectionQueryMembershipRule' = @{
        ByCollectionName = @{
            CollectionName = "Test-Collection-Query"  # Replace with collection that has query rules
            # May return empty if no query rules exist
        }
        ByCollectionId = @{
            CollectionId = "SMS00102"  # Replace with actual collection ID
            # May return empty if no query rules exist
        }
        ByCollectionNameAndRuleName = @{
            CollectionName = "Test-Collection-Query"
            RuleName = "Test-Servers"  # Replace with actual query rule name
        }
        ByCollectionIdAndRuleName = @{
            CollectionId = "SMS00102"
            RuleName = "Test-Servers"  # Replace with actual query rule name
        }
        WithWildcard = @{
            CollectionName = "Test-Collection-Query"
            RuleName = "*Server*"
        }
        NonExistent = @{
            CollectionName = "NonExistent Collection 999"
            CollectionId = "XXX99999"
        }
    }

    # ========================================================================
    # Get-CM7CollectionMember
    # ========================================================================
    'Get-CM7CollectionMember' = @{
        ByCollectionName = @{
            CollectionName = "Test-Collection-Query"
            ExpectedMinCount = 1
        }
        ByCollectionId = @{
            CollectionId = "SMS00102"  # Replace with actual collection ID
            ExpectedMinCount = 1
        }
        ByCollectionNameAndResourceName = @{
            CollectionName = "Test-Collection-Query"
            ResourceName = "TEST-*"
        }
        ByCollectionIdAndResourceId = @{
            CollectionId = "SMS00102"  # Replace with actual collection ID
            ResourceId = 16777220  # Replace with a ResourceID that is a member
        }
        NonExistent = @{
            CollectionName = "NonExistent Collection 999"
            CollectionId = "XXX99999"
            ResourceName = "NONEXISTENT-DEVICE-999"
            ResourceId = 99999999
            ExpectedCount = 0
        }
    }

    # ========================================================================
    # Get-CM7CollectionDirectMembership
    # ========================================================================
    'Get-CM7CollectionDirectMembership' = @{
        ByCollectionName = @{
            CollectionName = "All Systems"
            ExpectedMinCount = 1  # All Systems should have at least some direct members
        }
        ByCollectionId = @{
            CollectionId = "SMS00001"  # All Systems
            ExpectedMinCount = 1
        }
        ByCollectionNameAndResourceName = @{
            CollectionName = "All Systems"
            ResourceName = "TEST-DEVICE-001"  # Replace with device that's directly added
        }
        ByCollectionIdAndResourceId = @{
            CollectionId = "SMS00001"
            ResourceId = 16777220  # Replace with ResourceID directly added
        }
        WithWildcard = @{
            CollectionName = "All Systems"
            ResourceName = "TEST-*"
        }
        Fast = @{
            CollectionName = "All Systems"
        }
        NonExistent = @{
            CollectionName = "NonExistent Collection 999"
            CollectionId = "XXX99999"
            ResourceName = "NONEXISTENT-DEVICE-999"
            ResourceId = 99999999
            ExpectedCount = 0
        }
    }

    # ========================================================================
    # Add-CM7CollectionMembershipRule
    # ========================================================================
    'Add-CM7CollectionMembershipRule' = @{
        TestCollection = @{
            CollectionName = "Test-Collection-Rules"  # Replace with test collection name
            CollectionId = "SMS00104"  # Replace with test collection ID
        }
        DirectByCollectionNameAndResourceId = @{
            CollectionName = "Test-Collection-Rules"
            ResourceId = 16777220  # Replace with actual ResourceID to add
            ResourceIdArray = @(16777220, 16777221)  # Optional: Array for multi-add tests
        }
        DirectByCollectionIdAndResourceName = @{
            CollectionId = "SMS00104"
            ResourceName = "TEST-DEVICE-001"  # Replace with actual device name
        }
        QueryByCollectionName = @{
            CollectionName = "Test-Collection-Rules"
            RuleName = "Test-Query-Rule"  # Replace with unique rule name
            QueryExpression = "select SMS_R_SYSTEM.ResourceID from SMS_R_System where SMS_R_System.Name like 'TEST-%'"
        }
        IncludeByCollectionName = @{
            CollectionName = "Test-Collection-Rules"
            CollectionId = "SMS00104"  # Optional: for testing by ID
            IncludeCollectionName = "Test-Collection-Query"  # Replace with collection to include
            IncludeCollectionId = "SMS00102"  # Optional: for testing by ID
        }
        ExcludeByCollectionName = @{
            CollectionName = "Test-Collection-Rules"
            CollectionId = "SMS00104"  # Optional: for testing by ID
            ExcludeCollectionName = "Test-Collection-Direct"  # Replace with collection to exclude
            ExcludeCollectionId = "SMS00100"  # Optional: for testing by ID
        }
    }

    # ========================================================================
    # Get-CM7MaintenanceWindow
    # ========================================================================
    'Get-CM7MaintenanceWindow' = @{
        ByCollectionName = @{
            CollectionName = "Test-Collection-Direct"
            # May return empty if no maintenance windows are configured
        }
        ByCollectionID = @{
            CollectionID = "SMS00001"  # All Systems
            # May return empty if no maintenance windows are configured
        }
        NonExistent = @{
            CollectionName = "NonExistent-Collection-999"
            CollectionID = "XXX99999"
        }
        All = @{
            # Retrieves all maintenance windows in the environment
            ExpectedMinCount = 0  # May have no maintenance windows configured
        }
    }

    # ========================================================================
    # New-CM7MaintenanceWindow
    # ========================================================================
    'New-CM7MaintenanceWindow' = @{
        ByCollectionName = @{
            CollectionName = "Test-Collection-Direct"
            Name = "Test-MainWin-Daily"
            StartTime = (Get-Date).AddDays(1).Date.AddHours(22)  # Tomorrow at 10 PM
            DurationMinutes = 60  # 1 hour
            IsEnabled = $true
            RecurrenceType = "Daily"
            DayOfWeek = "Monday"
            ApplyTo = "Any"
            IsUtc = $false
        }
        ByCollectionID = @{
            CollectionID = "SMS00001"  # Replace with your test collection ID
            Name = "Test-MainWin-Weekly"
            StartTime = (Get-Date).AddDays(1).Date.AddHours(22)  # Tomorrow at 10 PM
            DurationMinutes = 120  # 2 hours
            IsEnabled = $true
            RecurrenceType = "Weekly"
            DayOfWeek = "Friday"
            ApplyTo = "SoftwareUpdatesOnly"
            IsUtc = $false
        }
        WithSpecificTime = @{
            CollectionName = "Test-Collection-Direct"
            Name = "Test-MainWin-Specific"
            StartTime = (Get-Date).AddDays(7).Date.AddHours(2)  # 7 days from now at 2 AM
            DurationMinutes = 30  # 30 minutes
            IsEnabled = $true
            RecurrenceType = "None"
            ApplyTo = "TaskSequencesOnly"
            IsUtc = $false
        }
        DisabledWindow = @{
            CollectionName = "Test-Collection-Direct"
            Name = "Test-MainWin-Disabled"
            StartTime = (Get-Date).AddDays(1).Date.AddHours(22)
            DurationMinutes = 60  # 1 hour
            IsEnabled = $false
            RecurrenceType = "Daily"
            ApplyTo = "Any"
            IsUtc = $false
        }
        MonthlyByWeekday = @{
            CollectionName = "Test-Collection-Direct"
            Name = "Test-MainWin-MonthlyByWeekday"
            StartTime = (Get-Date).AddDays(1).Date.AddHours(1)  # Tomorrow at 1 AM
            DurationMinutes = 180  # 3 hours
            IsEnabled = $true
            RecurrenceType = "MonthlyByWeekday"
            DayOfWeek = "Tuesday"
            WeekOrder = "Second"
            ForNumberOfMonths = 1
            ApplyTo = "SoftwareUpdatesOnly"
            IsUtc = $false
        }
        MonthlyByDate = @{
            CollectionName = "Test-Collection-Direct"
            Name = "Test-MainWin-MonthlyByDate"
            StartTime = (Get-Date).AddDays(1).Date.AddHours(3)  # Tomorrow at 3 AM
            DurationMinutes = 120  # 2 hours
            IsEnabled = $true
            RecurrenceType = "MonthlyByDate"
            MonthDay = 15
            ForNumberOfMonths = 1
            ApplyTo = "Any"
            IsUtc = $false
        }
        NonExistentCollection = @{
            CollectionName = "NonExistent-Collection-999"
            Name = "Test-MainWin"
            StartTime = (Get-Date).AddDays(1).Date.AddHours(22)
            DurationMinutes = 60  # 1 hour
            ApplyTo = "Any"
            IsUtc = $false
        }
        UTCTimeZone = @{
            CollectionName = "Test-Collection-Direct"
            Name = "Test-MainWin-UTC"
            StartTime = (Get-Date).AddDays(1).Date.AddHours(22)
            DurationMinutes = 60  # 1 hour
            IsEnabled = $true
            RecurrenceType = "None"
            ApplyTo = "Any"
            IsUtc = $true
        }
    }

    # ========================================================================
    # Add-CMASCollectionMembershipRule
    # ========================================================================
    'Add-CMASCollectionMembershipRule' = @{
        TestCollection = @{
            CollectionName = "Test-Collection-Rules"  # Replace with test collection name
            CollectionId = "SMS00104"  # Replace with test collection ID
        }
        DirectByCollectionNameAndResourceId = @{
            CollectionName = "Test-Collection-Rules"
            ResourceId = 16777220  # Replace with actual ResourceID to add
            ResourceIdArray = @(16777220, 16777221)  # Optional: Array for multi-add tests
        }
        DirectByCollectionIdAndResourceName = @{
            CollectionId = "SMS00104"
            ResourceName = "TEST-DEVICE-001"  # Replace with actual device name
        }
        QueryByCollectionName = @{
            CollectionName = "Test-Collection-Rules"
            RuleName = "Test-Query-Rule"  # Replace with unique rule name
            QueryExpression = "select SMS_R_SYSTEM.ResourceID from SMS_R_System where SMS_R_System.Name like 'TEST-%'"
        }
        IncludeByCollectionName = @{
            CollectionName = "Test-Collection-Rules"
            CollectionId = "SMS00104"  # Optional: for testing by ID
            IncludeCollectionName = "Test-Collection-Query"  # Replace with collection to include
            IncludeCollectionId = "SMS00102"  # Optional: for testing by ID
        }
        ExcludeByCollectionName = @{
            CollectionName = "Test-Collection-Rules"
            CollectionId = "SMS00104"  # Optional: for testing by ID
            ExcludeCollectionName = "Test-Collection-Direct"  # Replace with collection to exclude
            ExcludeCollectionId = "SMS00100"  # Optional: for testing by ID
        }
    }

    # ========================================================================
    # Remove-CM7CollectionMembershipRule
    # ========================================================================
    'Remove-CM7CollectionMembershipRule' = @{
        TestCollection = @{
            CollectionName = "Test-Collection-Rules"  # Replace with test collection name
            CollectionId = "SMS00104"  # Replace with test collection ID
        }
        DirectByCollectionNameAndResourceId = @{
            CollectionName = "Test-Collection-Rules"
            ResourceId = 16777220  # Replace with actual ResourceID to remove
            ResourceIdArray = @(16777220, 16777221)  # Optional: Array for multi-remove tests
        }
        DirectByCollectionIdAndResourceName = @{
            CollectionId = "SMS00104"
            ResourceName = "TEST-DEVICE-001"  # Replace with actual device name
        }
        DirectByWildcard = @{
            CollectionName = "Test-Collection-Rules"
            ResourceName = "TEST-*"  # Wildcard pattern for batch removal
        }
        QueryByCollectionName = @{
            CollectionName = "Test-Collection-Rules"
            RuleName = "Test-Query-Rule"  # Replace with query rule name
        }
        QueryByWildcard = @{
            CollectionName = "Test-Collection-Rules"
            RuleName = "*Query*"  # Wildcard pattern for batch removal
        }
        IncludeByCollectionName = @{
            CollectionName = "Test-Collection-Rules"
            CollectionId = "SMS00104"  # Optional: for testing by ID
            IncludeCollectionName = "Test-Collection-Query"  # Replace with collection to remove
            IncludeCollectionId = "SMS00102"  # Optional: for testing by ID
        }
        ExcludeByCollectionName = @{
            CollectionName = "Test-Collection-Rules"
            CollectionId = "SMS00104"  # Optional: for testing by ID
            ExcludeCollectionName = "Test-Collection-Direct"  # Replace with collection to remove
            ExcludeCollectionId = "SMS00100"  # Optional: for testing by ID
        }
    }

    # ========================================================================
    # Get-CM7CollectionVariable
    # ========================================================================
    'Get-CM7CollectionVariable' = @{
        ByCollectionName = @{
            CollectionName = "Test-Collection-WithVariables"  # Replace with collection that has variables
            ExpectedMinCount = 1  # Should have at least 1 variable
        }
        ByCollectionId = @{
            CollectionId = "SMS00100"  # Replace with CollectionID of collection with variables
            ExpectedMinCount = 1
        }
        ByCollectionNameAndVariableName = @{
            CollectionName = "Test-Collection-WithVariables"
            VariableName = "TestVar"  # Replace with existing variable name
        }
        ByCollectionIdAndVariableName = @{
            CollectionId = "SMS00100"
            VariableName = "TestMaskedVar"  # Replace with existing masked variable name
        }
        ByWildcard = @{
            CollectionName = "Test-Collection-WithVariables"
            VariableName = "Test*"  # Wildcard pattern to match test variables
        }
        NonExistentCollection = @{
            CollectionName = "NONEXISTENT-COLLECTION-999"
            ExpectedCount = 0
        }
        NonExistentVariable = @{
            CollectionName = "Test-Collection-WithVariables"
            VariableName = "NonExistentVar999"
            ExpectedCount = 0
        }
        CollectionWithoutVariables = @{
            # If you have a collection without variables, specify it here
            # Otherwise this test will be skipped
            CollectionName = "All Systems"  # All Systems typically has no variables
            CollectionId = "SMS00001"
        }
    }

    # ========================================================================
    # Get-CM7Script
    # ========================================================================
    'Get-CM7Script' = @{
        ByName = @{
            ScriptName = "Test-Script"  # Replace with an existing script name
            ExpectedCount = 1
        }
        ByGuid = @{
            ScriptGuid = "00000000-0000-0000-0000-000000000000"  # Replace with actual script GUID
            ExpectedCount = 1
        }
        NonExistent = @{
            ScriptName = "NonExistent-Script-999"
            ExpectedCount = 0
        }
        All = @{
            ExpectedMinCount = 0  # May have no scripts
        }
    }

    # ========================================================================
    # Invoke-CM7Script
    # ========================================================================
    'Invoke-CM7Script' = @{
        ByScriptNameAndDeviceName = @{
            ScriptName = "Test-Script"  # Replace with an existing approved script name
            DeviceName = "TEST-DEVICE-001"  # Replace with an existing device name
            ScriptParameters = @{
                ComputerName = "localhost"  # Replace with actual script parameters
            }
        }
        ByScriptGuidAndResourceId = @{
            ScriptGuid = "00000000-0000-0000-0000-000000000000"  # Replace with actual script GUID
            ResourceId = 16777220  # Replace with actual ResourceID
            ScriptParameters = @{
                ComputerName = "localhost"
            }
        }
        ByScriptNameAndCollectionId = @{
            ScriptName = "Test-Script"  # Replace with an existing approved script name
            CollectionId = "SMS00001"  # Replace with target collection ID
            ScriptParameters = @{}
        }
        NonExistent = @{
            ScriptName = "NonExistent-Script-999"
            DeviceName = "TEST-DEVICE-001"
        }
    }

    # ========================================================================
    # Get-CMASScript (Legacy)
    # ========================================================================
    'Get-CMASScript' = @{
        ByName = @{
            ScriptName = "Test-Script"  # Replace with an existing script name
            ExpectedCount = 1
        }
        ByGuid = @{
            ScriptGuid = "00000000-0000-0000-0000-000000000000"  # Replace with actual script GUID
            ExpectedCount = 1
        }
        NonExistent = @{
            ScriptName = "NonExistent-Script-999"
            ExpectedCount = 0
        }
        All = @{
            ExpectedMinCount = 0  # May have no scripts
        }
    }

    # ========================================================================
    # Invoke-CMASScript (Legacy)
    # ========================================================================
    'Invoke-CMASScript' = @{
        ByScriptNameAndDeviceName = @{
            ScriptName = "Test-Script"
            DeviceName = "TEST-DEVICE-001"
            ScriptParameters = @{
                ComputerName = "localhost"
            }
        }
        ByScriptGuidAndResourceId = @{
            ScriptGuid = "00000000-0000-0000-0000-000000000000"
            ResourceId = 16777220
            ScriptParameters = @{
                ComputerName = "localhost"
            }
        }
        ByScriptNameAndCollectionId = @{
            ScriptName = "Test-Script"
            CollectionId = "SMS00001"
            ScriptParameters = @{}
        }
    }

    # ========================================================================
    # Get-CM7ScriptExecutionStatus
    # ========================================================================
    'Get-CM7ScriptExecutionStatus' = @{
        ByClientOperationId = @{
            ClientOperationId = 16777220  # Replace with actual operation ID from a script execution
        }
        ByScriptGuidAndResourceId = @{
            ScriptGuid = "00000000-0000-0000-0000-000000000000"
            TargetResourceId = 16777220
        }
        NonExistent = @{
            ClientOperationId = 999999999
        }
    }

    # ========================================================================
    # Get-CM7Deployment
    # ========================================================================
    'Get-CM7Deployment' = @{
        ByCollectionName = @{
            CollectionName = "Test-Collection-Direct"  # Replace with a collection that has a deployment
            ExpectedMinCount = 1
        }
        ByDeploymentId = @{
            DeploymentId = ""  # Replace with an actual deployment ID from your environment
        }
        BySoftwareName = @{
            SoftwareName = "*"  # Replace with actual software name or wildcard
            ExpectedMinCount = 1
        }
        ByFeatureType = @{
            FeatureType = "Application"  # Replace with the type matching your test deployment
            ExpectedMinCount = 0
        }
        ByCollectionNameWildcard = @{
            CollectionName = "Test-Collection-*"
            ExpectedMinCount = 1
        }
        NonExistent = @{
            CollectionName = "NonExistent-Collection-999"
            DeploymentId = "{00000000-0000-0000-0000-000000000000}"
            ExpectedCount = 0
        }
        All = @{
            ExpectedMinCount = 1  # At least 1 deployment should exist
        }
    }

    # ========================================================================
    # Get-CMASScriptExecutionStatus (Legacy)
    # ========================================================================
    'Get-CMASScriptExecutionStatus' = @{
        ByClientOperationId = @{
            ClientOperationId = 16777220  # Replace with actual operation ID from a script execution
        }
        ByScriptGuidAndResourceId = @{
            ScriptGuid = "00000000-0000-0000-0000-000000000000"
            TargetResourceId = 16777220
        }
        NonExistent = @{
            ClientOperationId = 999999999
        }
    }

    # ========================================================================
    # New-CMASCollection
    # ========================================================================
    'New-CMASCollection' = @{
        DeviceCollectionByLimitingId = @{
            Name = "Test-DeviceCollection-ByID"
            LimitingCollectionId = "SMS00001"  # All Systems
        }
        DeviceCollectionByLimitingName = @{
            Name = "Test-DeviceCollection-ByName"
            LimitingCollectionName = "All Systems"
        }
        UserCollection = @{
            Name = "Test-UserCollection"
            CollectionType = "User"
            LimitingCollectionId = "SMS00002"  # All Users - Replace with your limiting collection for users
            LimitingCollectionName = "All Users"
        }
        WithComment = @{
            Name = "Test-Collection-WithComment"
            LimitingCollectionId = "SMS00001"
            Comment = "This is a test collection created by automated tests"
        }
        WithPeriodicRefresh = @{
            Name = "Test-Collection-PeriodicRefresh"
            LimitingCollectionId = "SMS00001"
            RefreshType = "Periodic"
        }
        WithContinuousRefresh = @{
            Name = "Test-Collection-ContinuousRefresh"
            LimitingCollectionId = "SMS00001"
            RefreshType = "Continuous"
        }
        WithBothRefresh = @{
            Name = "Test-Collection-BothRefresh"
            LimitingCollectionId = "SMS00001"
            RefreshType = "Both"
        }
        WithFolderPath = @{
            Name = "Test-Collection-WithFolderPath"
            LimitingCollectionId = "SMS00001"
            FolderPath = "XXX:\DeviceCollection\YourFolder"  # Replace with actual folder path
        }
        DuplicateName = @{
            Name = "All Systems"  # This should already exist
            LimitingCollectionId = "SMS00001"
        }
        NonExistentLimiting = @{
            Name = "Test-Collection-NoLimiting"
            LimitingCollectionId = "XXX99999"  # Non-existent limiting collection
            LimitingCollectionName = "NonExistent-Limiting-999"
        }
    }

    # ========================================================================
    # Remove-CMASCollection
    # ========================================================================
    'Remove-CMASCollection' = @{
        ByName = @{
            # Note: Test collections will be created dynamically during tests
            # This ensures we don't accidentally delete real collections
            CollectionNamePattern = "Test-Remove-Collection-*"
        }
        ById = @{
            # Note: Test collections will be created dynamically during tests
            # CollectionId will be determined at test runtime
        }
        WithMembers = @{
            # Note: Test collection with members will be created dynamically
            # to test warning messages about member count
            CreateWithMembers = $true
        }
        Protected = @{
            # These collections should never be deletable
            ProtectedCollections = @("SMS00001", "SMS00002", "SMS00003", "SMS00004")
        }
    }

    # ========================================================================
    # Remove-CM7Collection
    # ========================================================================
    'Remove-CM7Collection' = @{
        ByName = @{
            # Note: Test collections will be created dynamically during tests
            # This ensures we don't accidentally delete real collections
            CollectionNamePattern = "Test-Remove-Collection-*"
            LimitingCollectionId = "SMS00001"  # All Systems - used when creating test collections
        }
        ById = @{
            # Note: Test collections will be created dynamically during tests
            # CollectionId will be determined at test runtime
            LimitingCollectionId = "SMS00001"
        }
        WithMembers = @{
            # Note: Test collection with members will be created dynamically
            # to test warning messages about member count
            CreateWithMembers = $true
            LimitingCollectionId = "SMS00001"
        }
        Protected = @{
            # These collections should never be deletable
            ProtectedCollections = @("SMS00001", "SMS00002", "SMS00003", "SMS00004")
        }
        FolderPath = "XXX:\DeviceCollection\YourFolder"  # Replace with folder path for test collections
    }

    # ========================================================================
    # Set-CMASCollection
    # ========================================================================
    'Set-CMASCollection' = @{
        UpdateName = @{
            # Note: Test collection will be created dynamically during tests
            OriginalName = "Test-Set-Collection-Original"
            NewName = "Test-Set-Collection-Updated"
        }
        UpdateComment = @{
            # Note: Test collection will be created dynamically during tests
            CollectionName = "Test-Set-Collection-Comment"
            Comment = "Updated comment via automated tests"
        }
        UpdateRefreshType = @{
            # Note: Test collection will be created dynamically during tests
            CollectionName = "Test-Set-Collection-RefreshType"
            OriginalRefreshType = "Manual"
            NewRefreshType = "Continuous"
        }
        UpdateRefreshSchedule = @{
            # Note: Test collection will be created dynamically during tests
            CollectionName = "Test-Set-Collection-Schedule"
            RefreshType = "Periodic"
            RefreshSchedule = @{
                DaySpan = 1
                StartTime = "2025-02-14T00:00:00Z"
            }
        }
        UpdateMultipleProperties = @{
            # Note: Test collection will be created dynamically during tests
            CollectionName = "Test-Set-Collection-Multiple"
            NewName = "Test-Set-Collection-Multiple-Updated"
            Comment = "Multiple properties updated"
            RefreshType = "Both"
        }
        ByCollectionId = @{
            # Note: Test collection will be created dynamically during tests
            # CollectionId will be determined at test runtime
        }
        ByInputObject = @{
            # Note: Test collection will be created dynamically during tests
            # Collection object will be retrieved at test runtime
        }
    }

    # ========================================================================
    # Set-CMASCollectionSchedule
    # ========================================================================
    'Set-CMASCollectionSchedule' = @{
        DailySchedule = @{
            CollectionName = "Test-Schedule-Daily"
            RecurInterval = "Days"
            RecurCount = 1
        }
        HourlySchedule = @{
            CollectionName = "Test-Schedule-Hourly"
            RecurInterval = "Hours"
            RecurCount = 4
        }
        MinuteSchedule = @{
            CollectionName = "Test-Schedule-Minute"
            RecurInterval = "Minutes"
            RecurCount = 30
        }
    }

    # ========================================================================
    # Invoke-CMASCollectionUpdate
    # ========================================================================
    'Invoke-CMASCollectionUpdate' = @{
        ByCollectionName = @{
            CollectionName = "All Systems"
            ExpectedSuccess = $true
        }
        ByCollectionId = @{
            CollectionId = "SMS00001"  # All Systems
            ExpectedSuccess = $true
        }
        NonExistent = @{
            CollectionName = "NonExistent-Collection-XYZ999"
            CollectionId = "XXX99999"
            ExpectedSuccess = $false
        }
    }

    # ========================================================================
    # Get-CMASCollectionVariable
    # ========================================================================
    'Get-CMASCollectionVariable' = @{
        ByCollectionName = @{
            CollectionName = "Test-Collection-WithVariables"  # Collection with variables
            ExpectedMinCount = 1  # Should have at least 1 variable
        }
        ByCollectionId = @{
            CollectionId = "SMS00100"  # Replace with CollectionID of collection with variables
            ExpectedMinCount = 1
        }
        ByCollectionNameAndVariableName = @{
            CollectionName = "Test-Collection-WithVariables"
            VariableName = "TestVar"  # Replace with existing variable
        }
        ByCollectionIdAndVariableName = @{
            CollectionId = "SMS00100"
            VariableName = "TestMaskedVar"  # Replace with existing masked variable
        }
        ByWildcard = @{
            CollectionName = "Test-Collection-WithVariables"
            VariableName = "Test*"  # Wildcard pattern to match test variables
        }
        NonExistentCollection = @{
            CollectionName = "NONEXISTENT-COLLECTION-999"
            ExpectedCount = 0
        }
        NonExistentVariable = @{
            CollectionName = "Test-Collection-WithVariables"
            VariableName = "NonExistentVar999"
            ExpectedCount = 0
        }
        CollectionWithoutVariables = @{
            # If you have a collection without variables, specify it here
            # Otherwise this test will be skipped
            CollectionName = "All Systems"  # All Systems typically has no variables
            CollectionId = "SMS00001"
        }
    }

    # ========================================================================
    # New-CMASCollectionVariable
    # ========================================================================
    'New-CMASCollectionVariable' = @{
        ByCollectionName = @{
            CollectionName = "Test-Collection-WithVariables"  # Existing test collection
            VariableName = "TestCollVar"  # Will be made unique with timestamp in tests
            VariableValue = "TestCollValue123"
        }
        ByCollectionId = @{
            CollectionId = "SMS00100"  # Replace with test collection ID
            VariableName = "TestCollVar_CollID"  # Will be made unique with timestamp in tests
            VariableValue = "TestValueByCollID"
        }
        WithSpecialChars = @{
            CollectionName = "Test-Collection-WithVariables"
            VariableName = "TestCollVar_Special"  # Will be made unique with timestamp in tests
            VariableValue = "C:\\Windows\\System32;D:\\Apps"
        }
        MaskedVariable = @{
            CollectionName = "Test-Collection-WithVariables"
            VariableName = "TestCollVar_Masked"  # Will be made unique with timestamp in tests
            VariableValue = "SecretCollValue123"
            IsMasked = $true
        }
        EmptyValue = @{
            CollectionName = "Test-Collection-WithVariables"
            VariableName = "TestCollVar_Empty"  # Will be made unique with timestamp in tests
            VariableValue = ""
        }
        NonExistentCollection = @{
            CollectionName = "NONEXISTENT-COLLECTION-999"
            VariableName = "TestCollVar_NoCollection"
            VariableValue = "ShouldFail"
        }
        InvalidVariableName = @{
            CollectionName = "Test-Collection-WithVariables"
            VariableName = "Test Coll Var Invalid"  # Spaces not allowed - should fail validation
            VariableValue = "ShouldFail"
        }
    }

    # ========================================================================
    # New-CM7DeviceCollectionVariable
    # ========================================================================
    'New-CM7DeviceCollectionVariable' = @{
        ByCollectionName = @{
            CollectionName = "Test-Collection-WithVariables"  # Existing test collection
            VariableName = "TestDCVar"  # Will be made unique with timestamp in tests
            VariableValue = "TestDCValue123"
        }
        ByCollectionId = @{
            CollectionId = "SMS00100"  # Replace with test collection ID
            VariableName = "TestDCVar_CollID"  # Will be made unique with timestamp in tests
            VariableValue = "TestDCValueByCollID"
        }
        WithSpecialChars = @{
            CollectionName = "Test-Collection-WithVariables"
            VariableName = "TestDCVar_Special"  # Will be made unique with timestamp in tests
            VariableValue = "C:\\Windows\\System32;D:\\Apps"
        }
        MaskedVariable = @{
            CollectionName = "Test-Collection-WithVariables"
            VariableName = "TestDCVar_Masked"  # Will be made unique with timestamp in tests
            VariableValue = "SecretDCValue123"
            IsMasked = $true
        }
        EmptyValue = @{
            CollectionName = "Test-Collection-WithVariables"
            VariableName = "TestDCVar_Empty"  # Will be made unique with timestamp in tests
            VariableValue = ""
        }
        NonExistentCollection = @{
            CollectionName = "NONEXISTENT-COLLECTION-999"
            VariableName = "TestDCVar_NoCollection"
            VariableValue = "ShouldFail"
        }
        InvalidVariableName = @{
            CollectionName = "Test-Collection-WithVariables"
            VariableName = "Test DC Var Invalid"  # Spaces not allowed - should fail validation
            VariableValue = "ShouldFail"
        }
    }

    # ========================================================================
    # Remove-CM7DeviceCollectionVariable
    # ========================================================================
    'Remove-CM7DeviceCollectionVariable' = @{
        ByCollectionName = @{
            CollectionName = "Test-Collection-WithVariables"  # Replace with test collection name
            VariableName = "TestDCVar_Remove"  # Will be made unique with timestamp in tests
        }
        ByCollectionId = @{
            CollectionId = "SMS00100"  # Replace with test collection ID
            VariableName = "TestDCVar_RemoveByID"  # Will be made unique with timestamp in tests
        }
        ByWildcard = @{
            CollectionName = "Test-Collection-WithVariables"
            VariableNamePattern = "TestDCVar_RemoveWildcard_*"  # Pattern for batch removal
        }
        NonExistentCollection = @{
            CollectionName = "NONEXISTENT-COLLECTION-999"
            VariableName = "TestDCVar"
        }
        NonExistentVariable = @{
            CollectionName = "Test-Collection-WithVariables"
            VariableName = "NonExistentDCVar999"
        }
    }

    # ========================================================================
    # Remove-CMASCollectionVariable
    # ========================================================================
    'Remove-CMASCollectionVariable' = @{
        ByCollectionName = @{
            CollectionName = "Test-Collection-Direct"  # Replace with test collection name
            VariableName = "TestCollVar_Remove"  # Will be made unique with timestamp in tests
        }
        ByCollectionId = @{
            CollectionId = "SMS00100"  # Replace with test collection ID
            VariableName = "TestCollVar_RemoveByID"  # Will be made unique with timestamp in tests
        }
        ByWildcard = @{
            CollectionName = "Test-Collection-Direct"
            VariableNamePattern = "TestCollVar_RemoveWildcard_*"  # Pattern for batch removal
        }
        NonExistentCollection = @{
            CollectionName = "NONEXISTENT-COLLECTION-999"
            VariableName = "TestCollVar"
        }
        NonExistentVariable = @{
            CollectionName = "Test-Collection-Direct"
            VariableName = "NonExistentCollVar999"
        }
    }

    # ========================================================================
    # Set-CMASCollectionVariable
    # ========================================================================
    'Set-CMASCollectionVariable' = @{
        ByCollectionName = @{
            CollectionName = "Test-Collection-Direct"
            VariableName = "TestCollVar_Set"  # Will be made unique with timestamp in tests
            OriginalValue = "OriginalValue"
            NewValue = "ModifiedValue123"
        }
        ByCollectionId = @{
            CollectionId = "CM101C00"  # Replace with test collection ID
            VariableName = "TestCollVar_SetByID"  # Will be made unique with timestamp in tests
            OriginalValue = "OriginalValueByID"
            NewValue = "ModifiedValueByID"
        }
        ChangeMaskedState = @{
            CollectionName = "Test-Collection-Direct"
            VariableName = "TestCollVar_Mask"  # Will be made unique with timestamp in tests
            OriginalValue = "ValueToMask"
            NewValue = "ValueToMask"  # Keep value same, just change masked state
            IsMasked = $true
        }
        UnmaskVariable = @{
            CollectionName = "Test-Collection-Direct"
            VariableName = "TestCollVar_Unmask"  # Will be made unique with timestamp in tests
            OriginalValue = "MaskedValue"
            NewValue = "UnmaskedValue"
            IsNotMasked = $true
        }
        EmptyValue = @{
            CollectionName = "Test-Collection-Direct"
            VariableName = "TestCollVar_SetEmpty"  # Will be made unique with timestamp in tests
            OriginalValue = "SomeValue"
            NewValue = ""
        }
        NonExistentCollection = @{
            CollectionName = "NONEXISTENT-COLLECTION-999"
            VariableName = "TestVar"
            NewValue = "ShouldFail"
        }
        NonExistentVariable = @{
            CollectionName = "Test-Collection-Direct"
            VariableName = "NonExistentCollVar999"
            NewValue = "ShouldFail"
        }
    }

    # ========================================================================
    # New-CM7DeviceVariable
    # ========================================================================
    'New-CM7DeviceVariable' = @{
        ByDeviceName = @{
            DeviceName = "TEST-DEVICE-001"  # Existing test device
            VariableName = "TestVar"  # Will be made unique with timestamp in tests
            VariableValue = "TestValue123"
        }
        ByResourceId = @{
            ResourceId = 16777220  # Replace with actual ResourceID
            VariableName = "TestVar_ResID"  # Will be made unique with timestamp in tests
            VariableValue = "TestValueByResID"
        }
        WithSpecialChars = @{
            DeviceName = "TEST-DEVICE-001"
            VariableName = "TestVar_Special"  # Will be made unique with timestamp in tests
            VariableValue = "C:\\Windows\\System32;D:\\Apps"
        }
        MaskedVariable = @{
            DeviceName = "TEST-DEVICE-001"
            VariableName = "TestVar_Masked"  # Will be made unique with timestamp in tests
            VariableValue = "SecretValue123"
            IsMasked = $true
        }
        EmptyValue = @{
            DeviceName = "TEST-DEVICE-001"
            VariableName = "TestVar_Empty"  # Will be made unique with timestamp in tests
            VariableValue = ""
        }
        NonExistentDevice = @{
            DeviceName = "NONEXISTENT-DEVICE-999"
            VariableName = "TestVar_NoDevice"
            VariableValue = "ShouldFail"
        }
        InvalidVariableName = @{
            DeviceName = "TEST-DEVICE-001"
            VariableName = "Test Var Invalid"  # Spaces not allowed - should fail validation
            VariableValue = "ShouldFail"
        }
    }

    # ========================================================================
    # Get-CM7DeviceVariable
    # ========================================================================
    'Get-CM7DeviceVariable' = @{
        ByDeviceName = @{
            DeviceName = "TEST-DEVICE-001"  # Device with variables
            ExpectedMinCount = 1  # Should have at least 1 variable from tests
        }
        ByResourceId = @{
            ResourceId = 16777220  # Replace with actual ResourceID
            ExpectedMinCount = 1
        }
        ByDeviceNameAndVariableName = @{
            DeviceName = "TEST-DEVICE-001"
            VariableName = "TestVar*"  # Wildcard pattern to match test variables
        }
        ByResourceIdAndVariableName = @{
            ResourceId = 16777220
            VariableName = "TestVar_ResID*"  # Specific test variable pattern
        }
        NonExistentDevice = @{
            DeviceName = "NONEXISTENT-DEVICE-999"
            ExpectedCount = 0
        }
        NonExistentVariable = @{
            DeviceName = "TEST-DEVICE-001"
            VariableName = "NonExistentVar999"
            ExpectedCount = 0
        }
        DeviceWithoutVariables = @{
            # If you have a device without variables, specify it here
            # Otherwise this test will be skipped
            DeviceName = $null  # Set to actual device name or leave null
            ResourceId = $null  # Set to actual ResourceID or leave null
        }
    }

    # ========================================================================
    # Remove-CM7DeviceVariable
    # ========================================================================
    'Remove-CM7DeviceVariable' = @{
        ByDeviceName = @{
            DeviceName = "TEST-DEVICE-001"
            VariableName = "TestVar_Remove"  # Will be made unique with timestamp in tests
        }
        ByResourceId = @{
            ResourceId = 16777220  # Replace with actual ResourceID
            VariableName = "TestVar_RemoveByID"  # Will be made unique with timestamp in tests
        }
        ByWildcard = @{
            DeviceName = "TEST-DEVICE-001"
            VariableNamePattern = "TestVar_RemoveWildcard_*"  # Pattern for batch removal
        }
        NonExistentDevice = @{
            DeviceName = "NONEXISTENT-DEVICE-999"
            VariableName = "TestVar"
        }
        NonExistentVariable = @{
            DeviceName = "TEST-DEVICE-001"
            VariableName = "NonExistentVar999"
        }
    }

    # ========================================================================
    # Set-CMASDeviceVariable
    # ========================================================================
    'Set-CMASDeviceVariable' = @{
        ByDeviceName = @{
            DeviceName = "TEST-DEVICE-001"
            VariableName = "TestVar_Set"  # Will be made unique with timestamp in tests
            OriginalValue = "OriginalValue"
            NewValue = "ModifiedValue123"
        }
        ByResourceId = @{
            ResourceId = 16777220  # Replace with actual ResourceID
            VariableName = "TestVar_SetByResID"  # Will be made unique with timestamp in tests
            OriginalValue = "OriginalValueByID"
            NewValue = "ModifiedValueByID"
        }
        ChangeMaskedState = @{
            DeviceName = "TEST-DEVICE-001"
            VariableName = "TestVar_Mask"  # Will be made unique with timestamp in tests
            OriginalValue = "ValueToMask"
            NewValue = "ValueToMask"  # Keep value same, just change masked state
            IsMasked = $true
        }
        UnmaskVariable = @{
            DeviceName = "TEST-DEVICE-001"
            VariableName = "TestVar_Unmask"  # Will be made unique with timestamp in tests
            OriginalValue = "MaskedValue"
            NewValue = "UnmaskedValue"
            IsNotMasked = $true
        }
        EmptyValue = @{
            DeviceName = "TEST-DEVICE-001"
            VariableName = "TestVar_SetEmpty"  # Will be made unique with timestamp in tests
            OriginalValue = "SomeValue"
            NewValue = ""
        }
        NonExistentDevice = @{
            DeviceName = "NONEXISTENT-DEVICE-999"
            VariableName = "TestVar"
            NewValue = "ShouldFail"
        }
        NonExistentVariable = @{
            DeviceName = "TEST-DEVICE-001"
            VariableName = "NonExistentVar999"
            NewValue = "ShouldFail"
        }
    }

    # ========================================================================
    # Remove-CM7MaintenanceWindow
    # ========================================================================
    'Remove-CM7MaintenanceWindow' = @{
        ByCollectionName = @{
            CollectionName = "Test-Collection-Direct"  # Replace with your test collection name
            MaintenanceWindowName = "Test-RemoveMW"  # Will be made unique with timestamp in tests
        }
        ByCollectionID = @{
            CollectionID = "SMS00001"  # Replace with your test collection ID
            MaintenanceWindowName = "Test-RemoveMW-ByID"  # Will be made unique with timestamp in tests
        }
        ByServiceWindowID = @{
            CollectionName = "Test-Collection-Direct"  # Replace with your test collection name
            # ServiceWindowID will be determined at test runtime after creating a test MW
        }
        ByWildcard = @{
            CollectionName = "Test-Collection-Direct"  # Replace with your test collection name
            MaintenanceWindowNamePattern = "Test-RemoveMW-Wildcard_*"  # Pattern for batch removal
        }
        NonExistentCollection = @{
            CollectionName = "NONEXISTENT-COLLECTION-999"
            MaintenanceWindowName = "Test-RemoveMW"
        }
        NonExistentMaintenanceWindow = @{
            CollectionName = "Test-Collection-Direct"  # Replace with your test collection name
            MaintenanceWindowName = "NonExistentMW999"
        }
    }

    # ========================================================================
    # Get-CM7SoftwareUpdate
    # ========================================================================
    'Get-CM7SoftwareUpdate' = @{
        ByArticleId = @{
            ArticleId = "4038779"  # Replace with an existing KB article ID in your environment
            ExpectedCount = 1
        }
        ByName = @{
            Name = "*4038779*"  # Replace with a name wildcard matching a known update
            ExpectedMinCount = 1
        }
        ByNameExact = @{
            Name = ""  # Replace with the exact localized display name of a known update
            ExpectedCount = 1
        }
        BySeverity = @{
            Severity = "Critical"
            ExpectedMinCount = 0  # May vary per environment
        }
        IsDeployed = @{
            IsDeployed = $true
            ExpectedMinCount = 0  # May vary per environment
        }
        IsNotSuperseded = @{
            IsSuperseded = $false
            ExpectedMinCount = 0  # May vary per environment
        }
        NonExistent = @{
            ArticleId = "0000000"
            Name = "NonExistent-SoftwareUpdate-999"
            BulletinId = "NONEXISTENT-999"
            ExpectedCount = 0
        }
        All = @{
            ExpectedMinCount = 1  # At least 1 software update should exist
        }
    }

    # ========================================================================
    # Get-CM7SoftwareUpdateDeployment
    # ========================================================================
    'Get-CM7SoftwareUpdateDeployment' = @{
        ByCollectionName = @{
            CollectionName = "Your-Collection-With-SUDeployment"  # Replace with a collection that has a software update deployment
            ExpectedMinCount = 1
        }
        ByAssignmentId = @{
            AssignmentId = 0  # Replace with an actual assignment ID (integer) from your environment
        }
        ByName = @{
            Name = "*"  # Replace with actual deployment name or wildcard
            ExpectedMinCount = 1
        }
        ByCollectionNameWildcard = @{
            CollectionName = "Your-Collection-*"
            ExpectedMinCount = 1
        }
        NonExistent = @{
            CollectionName = "NonExistent-Collection-999"
            AssignmentId = 999999999
            Name = "NonExistent-SoftwareUpdateDeployment-999"
            ExpectedCount = 0
        }
        All = @{
            ExpectedMinCount = 1  # At least 1 software update deployment should exist
        }
    }

    # ========================================================================
    # Move-CM7Object
    # ========================================================================
    'Move-CM7Object' = @{
        DeviceCollectionToFolder = @{
            ObjectId = "SMS00001"  # Replace with an existing device collection ID
            ObjectType = "DeviceCollection"
            FolderId = 1  # Replace with an existing folder ID
        }
        DeviceCollectionToRoot = @{
            ObjectId = "SMS00001"  # Replace with an existing device collection ID
            ObjectType = "DeviceCollection"
            FolderId = 0  # Root folder
        }
        DeviceCollectionByFolderPath = @{
            ObjectId = "SMS00001"  # Replace with an existing device collection ID
            FolderPath = "XXX:\DeviceCollection\YourFolder\SubFolder"  # Replace with actual folder path
        }
        DeviceCollectionByFolderPathToRoot = @{
            ObjectId = "SMS00001"  # Replace with an existing device collection ID
            FolderPath = "XXX:\DeviceCollection"  # Root of DeviceCollection category
        }
        MultipleObjects = @{
            ObjectIds = @("SMS00001", "SMS00002")  # Replace with existing collection IDs
            ObjectType = "DeviceCollection"
            FolderId = 1  # Replace with an existing folder ID
        }
        MultipleObjectsByFolderPath = @{
            ObjectIds = @("SMS00001", "SMS00002")  # Replace with existing collection IDs
            FolderPath = "XXX:\DeviceCollection\YourFolder"  # Replace with actual folder path
        }
        NonExistentObject = @{
            ObjectId = "XXX99999"
            ObjectType = "DeviceCollection"
            FolderId = 0
        }
        NonExistentFolder = @{
            ObjectId = "SMS00001"  # Replace with an existing device collection ID
            ObjectType = "DeviceCollection"
            FolderId = 999999  # Non-existent folder
        }
        NonExistentFolderPath = @{
            ObjectId = "SMS00001"  # Replace with an existing device collection ID
            FolderPath = "XXX:\DeviceCollection\NonExistent\Folder999"  # Non-existent folder path
        }
        InvalidCategoryPath = @{
            ObjectId = "SMS00001"
            FolderPath = "XXX:\InvalidCategory\SomeFolder"  # Invalid category
        }
        TestFolder = @{
            # Folder used for move tests - replace with an actual folder in your environment
            FolderName = "YourFolder"
            FolderPath = "XXX:\DeviceCollection\YourFolder"
            FolderId = 1  # Replace with actual folder ID
            ObjectType = "DeviceCollection"
        }
        RestoreFolderPath = "XXX:\DeviceCollection\YourFolder\SubFolder"  # Folder to move test collections back to after tests
    }

    # ========================================================================
    # Get-CM7SoftwareUpdateGroup
    # ========================================================================
    'Get-CM7SoftwareUpdateGroup' = @{
        ByName = @{
            Name = "Your-SU-Group-Name"  # Replace with an existing software update group name
            ExpectedCount = 1
        }
        ById = @{
            Id = 0  # Replace with actual CI_ID of the above group (integer)
            ExpectedName = "Your-SU-Group-Name"  # Expected name when querying by ID
        }
        ByNameWildcard = @{
            Name = "Your-SU-*"  # Replace with wildcard pattern matching one or more groups
            ExpectedMinCount = 1
        }
        NonExistent = @{
            Id = 999999999
            Name = "NonExistent-SoftwareUpdateGroup-999"
            ExpectedCount = 0
        }
        All = @{
            ExpectedMinCount = 1  # At least 1 software update group should exist
        }
    }

    # ========================================================================
    # Get-CM7SoftwareUpdateDeploymentPackage
    # ========================================================================
    'Get-CM7SoftwareUpdateDeploymentPackage' = @{
        ByName = @{
            Name = "Your-SU-Deployment-Package-Name"  # Replace with an existing software update deployment package name
            ExpectedCount = 1
        }
        ById = @{
            Id = "XXX00001"  # Replace with actual package ID
            ExpectedName = "Your-SU-Deployment-Package-Name"  # Expected name when querying by ID
        }
        ByNameWildcard = @{
            Name = "Your-SU-*"  # Replace with wildcard pattern matching one or more packages
            ExpectedMinCount = 1
        }
        NonExistent = @{
            Id = "ZZZZZZZZ"
            Name = "NonExistent-SoftwareUpdateDeploymentPackage-999"
            ExpectedCount = 0
        }
        All = @{
            ExpectedMinCount = 1  # At least 1 software update deployment package should exist
        }
    }

    # ========================================================================
    # New-CM7SoftwareUpdateGroup
    # ========================================================================
    'New-CM7SoftwareUpdateGroup' = @{
        BasicGroup = @{
            Name = "Test-SUG-Basic"
            Description = "Test software update group created by automated tests"
        }
        WithUpdates = @{
            Name = "Test-SUG-WithUpdates"
            Description = "Test SUG with updates"
            # Replace with actual CI_IDs of existing software updates in your environment
            UpdateIds = @()  # Will be populated dynamically in tests if needed
        }
        WithArticleIds = @{
            Name = "Test-SUG-WithArticles"
            Description = "Test SUG with article IDs"
            # Replace with actual Article IDs (KB numbers) of existing software updates
            ArticleIds = @()  # Will be populated dynamically in tests if needed
        }
        DuplicateName = @{
            Name = "Your-Existing-SU-Group-Name"  # Replace with an existing software update group name
        }
        NonExistentArticle = @{
            Name = "Test-SUG-BadArticle"
            ArticleIds = @("0000000")  # Non-existent Article ID
        }
        ExistingGroup = @{
            Name = "Your-Existing-SU-Group-Name"  # Replace with an existing software update group for duplicate check testing
        }
    }

    # ========================================================================
    # Add-CM7SoftwareUpdateToGroup
    # ========================================================================
    'Add-CM7SoftwareUpdateToGroup' = @{
        TestGroup = @{
            SoftwareUpdateGroupName = "Your-Test-SUG-Name"  # Replace with an existing software update group for testing
        }
        ByGroupNameAndUpdateId = @{
            SoftwareUpdateGroupName = "Your-Test-SUG-Name"  # Replace with your test software update group name
            # UpdateId will be resolved dynamically in tests from ArticleId
        }
        ByGroupNameAndArticleId = @{
            SoftwareUpdateGroupName = "Your-Test-SUG-Name"  # Replace with your test software update group name
            ArticleId = @("4038779")  # Replace with an existing software update Article ID (KB number)
        }
        ByGroupNameAndSoftwareUpdate = @{
            SoftwareUpdateGroupName = "Your-Test-SUG-Name"  # Replace with your test software update group name
            ArticleId = "4038779"  # Replace with Article ID used to retrieve the software update object in tests
        }
        ByGroupNameAndSoftwareUpdateName = @{
            SoftwareUpdateGroupName = "Your-Test-SUG-Name"  # Replace with your test software update group name
            SoftwareUpdateName = "*4038779*"  # Replace with wildcard pattern to match the update by name
        }
        ByGroupId = @{
            # SoftwareUpdateGroupId will be resolved dynamically in tests
            ArticleId = @("4038779")  # Replace with an existing software update Article ID
        }
        ByGroupObject = @{
            SoftwareUpdateGroupName = "Your-Test-SUG-Name"  # Replace with your test software update group name
            ArticleId = @("4038779")  # Replace with an existing software update Article ID
        }
        DuplicateUpdate = @{
            SoftwareUpdateGroupName = "Your-Test-SUG-Name"  # Replace with your test software update group name
            ArticleId = @("4038779")  # Replace with Article ID - will be added first, then attempted again
        }
        NonExistentGroup = @{
            SoftwareUpdateGroupName = "NonExistent-SoftwareUpdateGroup-999"
            ArticleId = @("4038779")  # Replace with an existing Article ID
        }
        NonExistentGroupId = @{
            SoftwareUpdateGroupId = 999999999
            ArticleId = @("4038779")  # Replace with an existing Article ID
        }
        NonExistentArticle = @{
            SoftwareUpdateGroupName = "Your-Test-SUG-Name"  # Replace with your test software update group name
            ArticleId = @("0000000")  # Non-existent Article ID
        }
    }

    # ========================================================================
    # New-CM7SoftwareUpdateDeployment
    # ========================================================================
    'New-CM7SoftwareUpdateDeployment' = @{
        BasicDeployment = @{
            SoftwareUpdateGroupName = "Your-Existing-SU-Group-Name"  # Replace with an existing software update group name
            CollectionName = "Your-Test-Collection"  # Replace with an existing collection name
            DeploymentType = "Required"
        }
        AvailableDeployment = @{
            SoftwareUpdateGroupName = "Your-Existing-SU-Group-Name"  # Replace with an existing software update group name
            CollectionName = "Your-Test-Collection"  # Replace with an existing collection name
            DeploymentType = "Available"
        }
        WithDeadline = @{
            SoftwareUpdateGroupName = "Your-Existing-SU-Group-Name"  # Replace with an existing software update group name
            CollectionName = "Your-Test-Collection"  # Replace with an existing collection name
            DeploymentType = "Required"
            DeadlineDays = 7  # Deadline in days from now
        }
        WithDescription = @{
            SoftwareUpdateGroupName = "Your-Existing-SU-Group-Name"  # Replace with an existing software update group name
            CollectionName = "Your-Test-Collection"  # Replace with an existing collection name
            Description = "Test deployment created by automated tests"
        }
        NonExistentGroup = @{
            SoftwareUpdateGroupName = "NonExistent-SoftwareUpdateGroup-999"
            CollectionName = "Your-Test-Collection"  # Replace with an existing collection name
        }
        NonExistentCollection = @{
            SoftwareUpdateGroupName = "Your-Existing-SU-Group-Name"  # Replace with an existing software update group name
            CollectionName = "NonExistent-Collection-999"
        }
    }

}
#endregion

#region Helper Functions for Tests
# Helper function to get test data for a specific function and parameter set
function Get-TestData {
    param(
        [string]$FunctionName,
        [string]$ParameterSet
    )

    if ($script:TestData.ContainsKey($FunctionName)) {
        if ($script:TestData[$FunctionName].ContainsKey($ParameterSet)) {
            return $script:TestData[$FunctionName][$ParameterSet]
        }
    }
    return $null
}

# Helper function to check if test data exists for a function
function Test-HasTestData {
    param(
        [string]$FunctionName,
        [string]$ParameterSet = $null
    )

    if ($script:TestData.ContainsKey($FunctionName)) {
        if ($null -eq $ParameterSet) {
            return $true
        }
        return $script:TestData[$FunctionName].ContainsKey($ParameterSet)
    }
    return $false
}
#endregion

#region Backward Compatibility (Optional - for existing tests)
# Keep old variable names for backward compatibility with existing tests
# Remove this section once all tests are migrated to use $script:TestData

$script:TestSiteServer = $script:CMASConnection.SiteServer
$script:TestCredential = $script:CMASConnection.Credential
$script:TestSkipCertificateCheck = $script:CMASConnection.SkipCertificateCheck

$script:TestDeviceName = $script:TestData['Get-CMASDevice'].ByName.Name
$script:TestDeviceResourceID = $script:TestData['Get-CMASDevice'].ByResourceId.ResourceId
$script:TestNonExistentDeviceName = $script:TestData['Get-CMASDevice'].NonExistent.Name

$script:TestCollectionID = $script:TestData['Get-CM7Collection'].ByCollectionID.CollectionID
$script:TestCollectionName = $script:TestData['Get-CM7Collection'].ByName.Name
$script:TestNonExistentCollectionID = $script:TestData['Get-CM7Collection'].NonExistent.CollectionID
$script:TestNonExistentCollectionName = $script:TestData['Get-CM7Collection'].NonExistent.Name

$script:TestScriptGuid = $script:TestData['Get-CM7Script'].ByGuid.ScriptGuid
$script:TestScriptName = $script:TestData['Get-CM7Script'].ByName.ScriptName

$script:TestClientOperationID = $script:TestData['Get-CM7ScriptExecutionStatus'].ByClientOperationId.ClientOperationId
$script:TestTargetResourceID = $script:TestData['Invoke-CM7Script'].ByScriptGuidAndResourceId.ResourceId

$script:ExpectedDeviceCount = $script:TestData['Get-CM7Device'].ByName.ExpectedCount
$script:ExpectedCollectionCount = $script:TestData['Get-CM7Collection'].ByName.ExpectedCount

$script:TestScriptParameterName = "ComputerName"
$script:TestScriptParameterValue = "localhost"
#endregion
