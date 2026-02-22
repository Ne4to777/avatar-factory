# Show Avatar Factory GPU Worker Windows Service status and logs
# No administrator privileges required

. "$PSScriptRoot\lib\common.ps1"

$ServiceName = "AvatarFactoryGPU"
$STDOUT_LOG = Join-Path $PSScriptRoot "logs\service.log"
$STDERR_LOG = Join-Path $PSScriptRoot "logs\service-error.log"

Write-Banner "Service Status"

# Check if service exists
$service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue

if (-not $service) {
    Write-WarningMsg "Service '$ServiceName' not found"
    Write-Info "Install with: .\service-install.ps1"
    exit 0
}

# Get service details
$statusColor = switch ($service.Status) {
    "Running"   { $Colors.Green }
    "Stopped"   { $Colors.Yellow }
    "Starting"  { $Colors.Cyan }
    "Stopping"  { $Colors.Cyan }
    default     { $Colors.Yellow }
}

Write-Host "Service:     $($Colors.Cyan)$ServiceName$($Colors.Reset)"
Write-Host "Display:     Avatar Factory GPU Worker"
Write-Host "Status:      $($statusColor)$($service.Status)$($Colors.Reset)"
Write-Host "Start Type:  $($service.StartType)"
if ($service.Status -eq "Running") {
    try {
        $proc = Get-CimInstance Win32_Service -Filter "Name='$ServiceName'" | Select-Object -ExpandProperty ProcessId
        if ($proc -gt 0) {
            Write-Host "Process ID:  $proc"
        }
    }
    catch { }
}
Write-Host ""

# Show last 10 lines of logs
if (Test-Path $STDOUT_LOG) {
    Write-Host "Last 10 lines of service.log:" -ForegroundColor Blue
    Write-Host "----------------------------------------------------------------" -ForegroundColor DarkGray
    try {
        Get-Content $STDOUT_LOG -Tail 10 -ErrorAction SilentlyContinue
    }
    catch {
        Write-WarningMsg "Could not read log: $_"
    }
    Write-Host "----------------------------------------------------------------" -ForegroundColor DarkGray
}
else {
    Write-Info "No service.log found (service may not have started yet)"
}

if (Test-Path $STDERR_LOG) {
    $errLines = Get-Content $STDERR_LOG -Tail 5 -ErrorAction SilentlyContinue
    if ($errLines) {
        Write-Host ""
        Write-Host "Recent errors (service-error.log):" -ForegroundColor Yellow
        Write-Host "----------------------------------------------------------------" -ForegroundColor DarkGray
        $errLines | ForEach-Object { Write-Host $_ }
        Write-Host "----------------------------------------------------------------" -ForegroundColor DarkGray
    }
}
Write-Host ""

# Service management commands
Write-Host "Commands:" -ForegroundColor Blue
Write-Host "  Start:      $($Colors.Cyan)Start-Service $ServiceName$($Colors.Reset)"
Write-Host "  Stop:       $($Colors.Cyan)Stop-Service $ServiceName$($Colors.Reset)"
Write-Host "  Restart:    $($Colors.Cyan)Restart-Service $ServiceName$($Colors.Reset)"
Write-Host "  Uninstall:  $($Colors.Cyan).\service-uninstall.ps1$($Colors.Reset)"
Write-Host "  Services:   $($Colors.Cyan)services.msc$($Colors.Reset)"
Write-Host ""

# Offer to open full logs (skip in IDE terminals)
if (-not ($env:TERM_PROGRAM -eq "vscode" -or $env:TERM_PROGRAM -eq "Cursor")) {
    $openLogs = Read-Host "Open full logs in default editor? (y/N)"
    if ($openLogs -match "^[Yy]$") {
        if (Test-Path $STDOUT_LOG) {
            Start-Process $STDOUT_LOG
        }
        if (Test-Path $STDERR_LOG) {
            Start-Process $STDERR_LOG
        }
    }
}

exit 0
