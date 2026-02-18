# Load test declarations
. (Join-Path $PSScriptRoot "Tests/declarations.ps1")

# Load all functions
$CodePath = Join-Path $PSScriptRoot "Code"
Get-ChildItem -Path (Join-Path $CodePath "Private") -Filter "*.ps1" | ForEach-Object { . $_.FullName }
Get-ChildItem -Path (Join-Path $CodePath "Public") -Filter "*.ps1" | ForEach-Object { . $_.FullName }

$TestData = $script:TestData['Get-CM7CollectionDirectMembershipRule']
$ConnectData = $script:TestData['Connect-CM7']

# Connect
Connect-CM7 -ComputerName $ConnectData.ComputerName -SiteCode $ConnectData.SiteCode -Credential (New-Object System.Management.Automation.PSCredential ($ConnectData.UserName, (ConvertTo-SecureString $ConnectData.Password -AsPlainText -Force)))

# Test 1: By Collection Name
Write-Host "Test 1: By Collection Name"
$collectionName = $TestData.ByCollectionName.CollectionName
Write-Host "  Collection Name: $collectionName"
try {
    $result = Get-CM7CollectionDirectMembershipRule -CollectionName $collectionName
    Write-Host "  Result: $result"
    Write-Host "  Result Count: $(if ($result) { @($result).Count } else { 0 })"
} catch {
    Write-Host "  ERROR: $_"
}

# Test 2: By Collection ID
Write-Host ""
Write-Host "Test 2: By Collection ID"
$collectionId = $TestData.ByCollectionId.CollectionId
Write-Host "  Collection ID: $collectionId"
try {
    $result = Get-CM7CollectionDirectMembershipRule -CollectionId $collectionId
    Write-Host "  Result: $result"
    Write-Host "  Result Count: $(if ($result) { @($result).Count } else { 0 })"
} catch {
    Write-Host "  ERROR: $_"
}
