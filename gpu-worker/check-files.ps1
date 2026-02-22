# Diagnostic script to check if all required files exist

Write-Host "=== File Check Diagnostic ===" -ForegroundColor Cyan
Write-Host ""

$scriptRoot = $PSScriptRoot
Write-Host "Script root: $scriptRoot" -ForegroundColor Yellow

$requiredFiles = @(
    "lib\common.ps1",
    "setup.ps1",
    "check-system.ps1",
    "download-nssm.ps1",
    "configure-firewall.ps1",
    "service-install.ps1",
    "service-status.ps1",
    "service-uninstall.ps1"
)

$allExist = $true

foreach ($file in $requiredFiles) {
    $fullPath = Join-Path $scriptRoot $file
    $exists = Test-Path $fullPath
    
    if ($exists) {
        Write-Host "[OK]  $file" -ForegroundColor Green
    } else {
        Write-Host "[MISSING] $file" -ForegroundColor Red
        Write-Host "  Expected at: $fullPath" -ForegroundColor Yellow
        $allExist = $false
    }
}

Write-Host ""
if ($allExist) {
    Write-Host "All files present!" -ForegroundColor Green
} else {
    Write-Host "Some files are missing. Run 'git pull' to update." -ForegroundColor Red
}

Write-Host ""
Write-Host "Press any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
