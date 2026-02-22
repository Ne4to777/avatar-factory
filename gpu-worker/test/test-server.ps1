# Test Avatar Factory GPU Worker Server
# Validates server.py: start, health, CUDA, models, API endpoints.
# Server must be running or will be started for tests.

$ErrorActionPreference = "Stop"
$RootDir = Split-Path $PSScriptRoot -Parent
$null = Set-Location $RootDir

try {
    . (Join-Path $RootDir "lib" "common.ps1")
}
catch {
    $script:ESC = [char]27
    $script:Colors = @{ Green = "$($script:ESC)[92m"; Red = "$($script:ESC)[91m"; Yellow = "$($script:ESC)[93m"; Blue = "$($script:ESC)[94m"; Cyan = "$($script:ESC)[96m"; Reset = "$($script:ESC)[0m" }
    function Write-Success { param($Message) Write-Host "$($script:Colors.Green)PASS$($script:Colors.Reset) $Message" }
    function Write-Info { param($Message) Write-Host "$($script:Colors.Blue)INFO$($script:Colors.Reset) $Message" }
    function Write-WarningMsg { param($Message) Write-Host "$($script:Colors.Yellow)SKIP$($script:Colors.Reset) $Message" }
    function Write-ErrorMsg { param($Message) Write-Host "$($script:Colors.Red)FAIL$($script:Colors.Reset) $Message" }
}

$script:Passed = 0
$script:Failed = 0
$script:Skipped = 0
$BaseUrl = "http://localhost:8001"
$ServerJob = $null

function Test-Case {
    param([string]$Name, [scriptblock]$Test)
    Write-Host ""
    Write-Host "[$($script:Passed + $script:Failed + $script:Skipped + 1)] $Name" -ForegroundColor Cyan
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
Write-Host "  Server Test Suite (test-server.ps1)" -ForegroundColor Blue
Write-Host "  Root: $RootDir" -ForegroundColor Gray
Write-Host "  Base URL: $BaseUrl" -ForegroundColor Gray
Write-Host "========================================" -ForegroundColor Blue

# Test 1: Server script exists
Test-Case "Server script" {
    return Test-Path (Join-Path $RootDir "server.py")
}

# Test 2: Server starts (or is already running)
Test-Case "Server starts" {
    try {
        $r = Invoke-WebRequest -Uri "$BaseUrl/" -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
        Write-Host "  Status: $($r.StatusCode)" -ForegroundColor Gray
        return $r.StatusCode -eq 200
    }
    catch {
        Write-Host "  Attempting to start server..." -ForegroundColor Gray
        $venvPy = if ($env:OS -eq "Windows_NT") { Join-Path $RootDir "venv" "Scripts" "python.exe" } else { Join-Path $RootDir "venv" "bin" "python" }
        if (-not (Test-Path $venvPy)) {
            Write-Host "  Venv not found - run setup.ps1 first" -ForegroundColor Gray
            return $false
        }
        $script:ServerJob = Start-Job -ScriptBlock {
            param($root, $py)
            Set-Location $root
            & $py server.py 2>&1
        } -ArgumentList $RootDir, $venvPy
        Start-Sleep -Seconds 8
        try {
            $r = Invoke-WebRequest -Uri "$BaseUrl/" -UseBasicParsing -TimeoutSec 5
            return $r.StatusCode -eq 200
        }
        catch { return $false }
    }
}

# Test 3: Health endpoint responds
Test-Case "Health endpoint responds" {
    try {
        $r = Invoke-WebRequest -Uri "$BaseUrl/health" -UseBasicParsing -TimeoutSec 5
        $j = $r.Content | ConvertFrom-Json
        Write-Host "  Status: $($j.status)" -ForegroundColor Gray
        return $r.StatusCode -eq 200 -and $j.status -eq "healthy"
    }
    catch { return $false }
}

# Test 4: CUDA available (from health response)
Test-Case "CUDA available" {
    try {
        $r = Invoke-WebRequest -Uri "$BaseUrl/health" -UseBasicParsing -TimeoutSec 5
        $j = $r.Content | ConvertFrom-Json
        return $null -ne $j.gpu -and $j.gpu.name
    }
    catch { return $false }
}

# Test 5: Models loaded
Test-Case "Models loaded" {
    try {
        $r = Invoke-WebRequest -Uri "$BaseUrl/health" -UseBasicParsing -TimeoutSec 5
        $j = $r.Content | ConvertFrom-Json
        return $null -ne $j.models
    }
    catch { return $false }
}

# Test 6: API root returns JSON
Test-Case "API root endpoint" {
    try {
        $r = Invoke-WebRequest -Uri "$BaseUrl/" -UseBasicParsing -TimeoutSec 5
        $j = $r.Content | ConvertFrom-Json
        return $j.status -eq "ok"
    }
    catch { return $false }
}

# Cleanup: stop server if we started it
if ($script:ServerJob) {
    Write-Host ""
    Write-Info "Stopping test server..."
    Stop-Job $script:ServerJob -ErrorAction SilentlyContinue
    Remove-Job $script:ServerJob -ErrorAction SilentlyContinue
}

# Summary
Write-Host ""
Write-Host "========================================" -ForegroundColor Blue
$total = $script:Passed + $script:Failed
Write-Host "  Passed: $($script:Passed) | Failed: $($script:Failed)" -ForegroundColor $(if ($script:Failed -eq 0) { "Green" } else { "Yellow" })
Write-Host "========================================" -ForegroundColor Blue

if ($script:Failed -gt 0) {
    Write-Host ""
    Write-Info "Ensure server is running: .\start.bat or python server.py"
    exit 1
}
exit 0
