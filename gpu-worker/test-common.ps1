# Simple test for common.ps1
# Note: Full test requires Windows. On macOS/Linux, only print and utility functions are tested.
. "$PSScriptRoot\lib\common.ps1"

Write-Banner "Testing Common Library"

Write-Info "Testing print functions..."
Write-Success "Success message works"
Write-Warning "Warning message works"
Write-Error "Error message works"
Write-Step -Current 1 -Total 3 -Message "Step message works"

if ($env:OS -eq 'Windows_NT') {
    Write-Info "Testing system checks..."
    Write-Host "Administrator: $(Test-Administrator)"
    Write-Host "Windows: $((Get-WindowsVersion).Caption)"
    Write-Host "Free space: $(Get-FreeDiskSpace) GB"
    Write-Host "RAM: $(Get-TotalMemory) GB"
    Write-Host "IP: $(Get-LocalIPAddress)"
    Write-Host "Internet: $(Test-InternetConnection)"
}
else {
    Write-Warning "Skipping Windows-specific system checks (run on Windows for full test)"
}

Write-Info "Testing utilities..."
$randomString = New-SecureRandomString -Length 16
Write-Host "Random string: $randomString"

Write-Success "All tests passed!"
