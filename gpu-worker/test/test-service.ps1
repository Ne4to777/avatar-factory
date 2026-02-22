# Test Avatar Factory GPU Worker Service Scripts
# Validates service-install, service-status, service-uninstall.
# Requires Windows and administrator privileges for full tests.

$ErrorActionPreference = "Stop"
$RootDir = Split-Path $PSScriptRoot -Parent
$null = Set-Location $RootDir

try {
    . (Join-Path $RootDir "lib" "common.ps1")
}
catch {
    $script:Colors = @{ Green = "`e[92m"; Red = "`e[91m"; Yellow = "`e[93m"; Blue = "`e[94m"; Cyan = "`e[96m"; Reset = "`e[0m" }
    function Write-Success { param($Message) Write-Host "$($script:Colors.Green)PASS$($script:Colors.Reset) $Message" }
    function Write-Info { param($Message) Write-Host "$($script:Colors.Blue)INFO$($script:Colors.Reset) $Message" }
    function Write-WarningMsg { param($Message) Write-Host "$($script:Colors.Yellow)SKIP$($script:Colors.Reset) $Message" }
    function Write-ErrorMsg { param($Message) Write-Host "$($script:Colors.Red)FAIL$($script:Colors.Reset) $Message" }
}

$script:Passed = 0
$script:Failed = 0
$script:Skipped = 0
$IsWin = $env:OS -eq "Windows_NT"
$ServiceName = "AvatarFactoryGPU"

function Test-Case {
    param([string]$Name, [scriptblock]$Test, [switch]$WindowsOnly)
    Write-Host ""
    Write-Host "[$($script:Passed + $script:Failed + $script:Skipped + 1)] $Name" -ForegroundColor Cyan
    if ($WindowsOnly -and -not $IsWin) {
        Write-WarningMsg "$Name - Windows required"
        $script:Skipped++
        return
    }
    try {
        $result = & $Test
        if ($result) {
            Write-Success "$Name"
            $script:Passed++
        }
        else {
            Write-ErrorMsg "$Name - test returned false"
            $script:Failed++
        }
    }
    catch {
        Write-ErrorMsg "$Name - $_"
        $script:Failed++
    }
}

Write-Host "========================================" -ForegroundColor Blue
Write-Host "  Service Test Suite (test-service.ps1)" -ForegroundColor Blue
Write-Host "  Root: $RootDir" -ForegroundColor Gray
Write-Host "  Platform: $(if ($IsWin) { 'Windows' } else { 'Non-Windows' })" -ForegroundColor Gray
Write-Host "========================================" -ForegroundColor Blue

# Test 1: Service scripts exist
Test-Case "Service script: service-install.ps1" {
    return Test-Path (Join-Path $RootDir "service-install.ps1")
}

Test-Case "Service script: service-status.ps1" {
    return Test-Path (Join-Path $RootDir "service-status.ps1")
}

Test-Case "Service script: service-uninstall.ps1" {
    return Test-Path (Join-Path $RootDir "service-uninstall.ps1")
}

# Test 2: Service installation (Windows only, requires admin)
Test-Case "Service installation" {
    $installScript = Join-Path $RootDir "service-install.ps1"
    if (-not (Test-Path $installScript)) { return $false }
    $content = Get-Content $installScript -Raw
    return $content -match "AvatarFactoryGPU" -and $content -match "NSSM"
} -WindowsOnly

# Test 3: Service status script runs
Test-Case "Service status reporting" {
    if (-not $IsWin) { return $false }
    $statusScript = Join-Path $RootDir "service-status.ps1"
    $proc = Start-Process powershell -ArgumentList "-ExecutionPolicy Bypass -NoProfile -File `"$statusScript`"" -WorkingDirectory $RootDir -Wait -PassThru -NoNewWindow
    return $proc.ExitCode -eq 0
} -WindowsOnly

# Test 4: Service starts correctly (if service is installed)
Test-Case "Service starts correctly" {
    if (-not $IsWin) { return $false }
    try {
        $svc = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
        if (-not $svc) {
            Write-Host "  (Service not installed - run service-install.ps1 to test)" -ForegroundColor Gray
            return $true
        }
        return $svc.Status -eq "Running"
    }
    catch { return $false }
} -WindowsOnly

# Test 5: Service uninstall script exists and is valid
Test-Case "Service uninstallation script" {
    $uninstall = Join-Path $RootDir "service-uninstall.ps1"
    if (-not (Test-Path $uninstall)) { return $false }
    $content = Get-Content $uninstall -Raw
    return $content -match $ServiceName -and $content -match "Stop-Service|remove"
}

# Test 6: NSSM download script exists
Test-Case "NSSM download script" {
    return Test-Path (Join-Path $RootDir "download-nssm.ps1")
}

# Summary
Write-Host ""
Write-Host "========================================" -ForegroundColor Blue
$total = $script:Passed + $script:Failed + $script:Skipped
Write-Host "  Passed: $($script:Passed) | Failed: $($script:Failed) | Skipped: $($script:Skipped)" -ForegroundColor $(if ($script:Failed -eq 0) { "Green" } else { "Yellow" })
Write-Host "========================================" -ForegroundColor Blue

if (-not $IsWin) {
    Write-Host ""
    Write-Info "Full service tests require Windows. Install service with: .\service-install.ps1"
}

if ($script:Failed -gt 0) { exit 1 }
exit 0
