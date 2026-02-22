# Test Avatar Factory GPU Worker Setup (setup.ps1)
# Validates installation components. Run after setup.ps1 or on existing install.
# Full tests require Windows; macOS runs subset.

$ErrorActionPreference = "Stop"
$RootDir = Split-Path $PSScriptRoot -Parent
$null = Set-Location $RootDir

# Try to load common.ps1 (Windows-specific, may fail on macOS)
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
Write-Host "  Setup Test Suite (test-install.ps1)" -ForegroundColor Blue
Write-Host "  Root: $RootDir" -ForegroundColor Gray
Write-Host "  Platform: $(if ($IsWin) { 'Windows' } else { 'Non-Windows' })" -ForegroundColor Gray
Write-Host "========================================" -ForegroundColor Blue

# Test 1: Prerequisites check (check-system.ps1)
Test-Case "Prerequisites check" {
    $checkScript = Join-Path $RootDir "check-system.ps1"
    if (-not (Test-Path $checkScript)) { return $false }
    $proc = Start-Process powershell -ArgumentList "-ExecutionPolicy Bypass -NoProfile -File `"$checkScript`"" -WorkingDirectory $RootDir -Wait -PassThru -NoNewWindow
    return $proc.ExitCode -eq 0
} -WindowsOnly

# Test 2: Python installation detection
Test-Case "Python installation detection" {
    if (Get-Command python -ErrorAction SilentlyContinue) {
        $v = python --version 2>&1
        if ($v -match "Python (\d+)\.(\d+)") {
            $major = [int]$Matches[1]; $minor = [int]$Matches[2]
            return ($major -eq 3 -and $minor -ge 10)
        }
    }
    return $false
}

# Test 3: Venv creation
Test-Case "Venv creation" {
    $venvPath = Join-Path $RootDir "venv"
    $venvPython = if ($IsWin) { Join-Path $venvPath "Scripts" "python.exe" } else { Join-Path $venvPath "bin" "python" }
    if (Test-Path $venvPython) {
        $ver = & $venvPython --version 2>&1
        Write-Host "  $ver" -ForegroundColor Gray
        return $true
    }
    # If no venv, try creating one in temp
    $tmpDir = if ($env:TEMP) { $env:TEMP } else { [System.IO.Path]::GetTempPath() }
    $tmpVenv = Join-Path $tmpDir "af-gpu-test-venv-$(Get-Random)"
    try {
        python -m venv $tmpVenv 2>&1 | Out-Null
        $tmpPy = if ($IsWin) { Join-Path $tmpVenv "Scripts" "python.exe" } else { Join-Path $tmpVenv "bin" "python" }
        $ok = Test-Path $tmpPy
        if (Test-Path $tmpVenv) { Remove-Item $tmpVenv -Recurse -Force -ErrorAction SilentlyContinue }
        return $ok
    }
    catch { return $false }
}

# Test 4: PyTorch installation (requires venv)
Test-Case "PyTorch installation" {
    $venvPath = Join-Path $RootDir "venv"
    $venvPython = if ($IsWin) { Join-Path $venvPath "Scripts" "python.exe" } else { Join-Path $venvPath "bin" "python" }
    if (-not (Test-Path $venvPython)) {
        Write-Host "  (no venv - run setup.ps1 first)" -ForegroundColor Gray
        return $false
    }
    $ver = & $venvPython -c "import torch; print(torch.__version__)" 2>&1
    return $LASTEXITCODE -eq 0 -and $ver
}

# Test 5: Dependencies installation
Test-Case "Dependencies installation" {
    $venvPython = if ($IsWin) { Join-Path $RootDir "venv" "Scripts" "python.exe" } else { Join-Path $RootDir "venv" "bin" "python" }
    if (-not (Test-Path $venvPython)) { return $false }
    $r = & $venvPython -c "import fastapi; import uvicorn; print('OK')" 2>&1
    return $LASTEXITCODE -eq 0 -and $r -match "OK"
}

# Test 6: .env generation
Test-Case ".env generation" {
    $envFile = Join-Path $RootDir ".env"
    if (-not (Test-Path $envFile)) { return $false }
    $content = Get-Content $envFile -Raw
    return $content -match "GPU_API_KEY" -and $content -match "PORT"
}

# Test 7: Logs created
Test-Case "Logs created" {
    $logDir = Join-Path $RootDir "logs"
    $logFile = Join-Path $logDir "install.log"
    return (Test-Path $logDir) -or (Test-Path $logFile)
}

# Test 8: setup.ps1 exists and is valid
Test-Case "setup.ps1 script" {
    $setup = Join-Path $RootDir "setup.ps1"
    if (-not (Test-Path $setup)) { return $false }
    $content = Get-Content $setup -Raw
    return $content -match "param\s*\(" -and $content -match "SkipModels|NoService|Silent"
}

# Summary
Write-Host ""
Write-Host "========================================" -ForegroundColor Blue
$total = $script:Passed + $script:Failed + $script:Skipped
Write-Host "  Passed: $($script:Passed) | Failed: $($script:Failed) | Skipped: $($script:Skipped)" -ForegroundColor $(if ($script:Failed -eq 0) { "Green" } else { "Yellow" })
Write-Host "========================================" -ForegroundColor Blue

if ($script:Failed -gt 0) {
    Write-Host ""
    Write-Host "Run setup.ps1 first: .\setup.ps1 -Silent -SkipModels -NoService" -ForegroundColor Yellow
    exit 1
}
exit 0
