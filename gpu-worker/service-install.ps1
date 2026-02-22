# Install Avatar Factory GPU Worker as Windows Service
# Uses NSSM (Non-Sucking Service Manager)

param(
    [switch]$Force,
    [switch]$Silent
)

. "$PSScriptRoot\lib\common.ps1"

# Build arguments for restart (if we need to re-elevate)
$scriptArgs = @()
if ($Force) { $scriptArgs += "-Force" }
if ($Silent) { $scriptArgs += "-Silent" }

# Check admin privileges
if (-not (Test-Administrator)) {
    Restart-AsAdministrator -Arguments $scriptArgs -ScriptPath $MyInvocation.PSCommandPath
    exit
}

Write-Banner "Windows Service Installation"

$ServiceName = "AvatarFactoryGPU"
$NSSM_PATH = Join-Path $PSScriptRoot "tools\nssm.exe"
$VENV_PYTHON = Join-Path $PSScriptRoot "venv\Scripts\python.exe"
$SERVER_SCRIPT = "server.py"
$LOG_DIR = Join-Path $PSScriptRoot "logs"
$STDOUT_LOG = Join-Path $LOG_DIR "service.log"
$STDERR_LOG = Join-Path $LOG_DIR "service-error.log"

# Step 1: Download NSSM if needed
if (-not (Test-Path $NSSM_PATH)) {
    Write-Info "NSSM not found, downloading..."
    & "$PSScriptRoot\download-nssm.ps1"

    if ($LASTEXITCODE -ne 0) {
        Write-ErrorMsg "Failed to download NSSM"
        exit 1
    }
}

Write-Success "NSSM available"

# Step 2: Check if service already exists
Write-Info "Checking existing service..."

$existingService = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue

if ($existingService) {
    if ($Force) {
        Write-WarningMsg "Service already exists, removing first..."
        & "$PSScriptRoot\service-uninstall.ps1" -Silent
        if ($LASTEXITCODE -ne 0) {
            Write-ErrorMsg "Failed to remove existing service"
            exit 1
        }
        Start-Sleep -Seconds 2
    }
    else {
        Write-ErrorMsg "Service '$ServiceName' already exists"
        Write-Info "Use -Force to reinstall or run .\service-uninstall.ps1 first"
        exit 1
    }
}

# Step 3: Verify prerequisites
Write-Info "Verifying prerequisites..."

if (-not (Test-Path $VENV_PYTHON)) {
    Write-ErrorMsg "Python virtual environment not found: $VENV_PYTHON"
    Write-Info "Run setup.ps1 first"
    exit 1
}

$serverPath = Join-Path $PSScriptRoot $SERVER_SCRIPT
if (-not (Test-Path $serverPath)) {
    Write-ErrorMsg "Server script not found: $serverPath"
    exit 1
}

# Ensure logs directory exists
if (-not (Test-Path $LOG_DIR)) {
    $null = New-Item -ItemType Directory -Path $LOG_DIR -Force
}

Write-Success "Prerequisites verified"

# Step 4: Install service with NSSM
Write-Info "Installing Windows Service..."

& $NSSM_PATH install $ServiceName $VENV_PYTHON $SERVER_SCRIPT

if ($LASTEXITCODE -ne 0) {
    Write-ErrorMsg "Failed to install service"
    exit 1
}

Write-Success "Service installed"

# Step 5: Configure service
Write-Info "Configuring service..."

# Working directory (gpu-worker folder)
& $NSSM_PATH set $ServiceName AppDirectory $PSScriptRoot

# Display name and description
& $NSSM_PATH set $ServiceName DisplayName "Avatar Factory GPU Worker"
& $NSSM_PATH set $ServiceName Description "AI-powered video generation GPU worker for Avatar Factory"

# Startup: Automatic (Delayed Start)
& $NSSM_PATH set $ServiceName Start SERVICE_DELAYED_AUTO_START

# Log files
& $NSSM_PATH set $ServiceName AppStdout $STDOUT_LOG
& $NSSM_PATH set $ServiceName AppStderr $STDERR_LOG

# Configure log rotation (10MB files)
& $NSSM_PATH set $ServiceName AppStdoutCreationDisposition 4  # OPEN_ALWAYS
& $NSSM_PATH set $ServiceName AppStderrCreationDisposition 4
& $NSSM_PATH set $ServiceName AppRotateFiles 1
& $NSSM_PATH set $ServiceName AppRotateBytes 10485760  # 10MB
& $NSSM_PATH set $ServiceName AppRotateOnline 1
Write-Info "Log rotation configured (10MB per file)"

# Environment variable
& $NSSM_PATH set $ServiceName AppEnvironmentExtra "CUDA_VISIBLE_DEVICES=0"

# Restart on crash
& $NSSM_PATH set $ServiceName AppExit Default Restart
& $NSSM_PATH set $ServiceName AppRestartDelay 60000

Write-Success "Service configured"

# Step 6: Start service
Write-Info "Starting service..."
try {
    Start-Service -Name $ServiceName -ErrorAction Stop
    Start-Sleep -Seconds 3

    $service = Get-Service -Name $ServiceName
    if ($service.Status -eq 'Running') {
        Write-Success "Service started successfully"
    }
    else {
        throw "Service status is $($service.Status)"
    }
}
catch {
    Write-ErrorMsg "Service failed to start: $_"
    Write-Info "Check logs: $STDERR_LOG"
    Write-Info "To debug: Get-Content `"$STDERR_LOG`""
    exit 1
}

# Step 8: Show status
Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host "$($Colors.Green)✓ Windows Service Installed$($Colors.Reset)"
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host ""
Write-Host "Service Name: $($Colors.Cyan)$ServiceName$($Colors.Reset)"
Write-Host "Status:       $($Colors.Green)Running$($Colors.Reset)"
Write-Host "Startup:      $($Colors.Green)Automatic (Delayed)$($Colors.Reset)"
Write-Host ""
Write-Host "Manage service:"
Write-Host "  Status:       $($Colors.Cyan).\service-status.ps1$($Colors.Reset)"
Write-Host "  View logs:    $($Colors.Cyan)Get-Content $STDOUT_LOG -Tail 50 -Wait$($Colors.Reset)"
Write-Host "  Stop:        $($Colors.Cyan)Stop-Service $ServiceName$($Colors.Reset)"
Write-Host "  Remove:      $($Colors.Cyan).\service-uninstall.ps1$($Colors.Reset)"
Write-Host "  Windows GUI: $($Colors.Cyan)services.msc$($Colors.Reset)"
Write-Host ""

exit 0
