# get all files in the Tests directory that match Test-*.Tests.ps1
$testFiles = Get-ChildItem -Path .\Tests\Test-*.Tests.ps1

foreach ($testFile in $testFiles) {
    Write-Host "Running tests in file: $($testFile.FullName)" -ForegroundColor Green
    $FunctionName = ($testFile.BaseName -replace '^Test-(.+)\.Tests$', '$1')
    . .\Tests\Invoke-Test.ps1 -FunctionName $FunctionName -IncludeStructuralTests
    # . $testFile.FullName
}
