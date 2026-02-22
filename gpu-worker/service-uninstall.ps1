# Uninstall Avatar Factory GPU Worker Windows Service

param(
    [switch]$Silent
)

. "$PSScriptRoot\lib\common.ps1"

# Build arguments for restart (if we need to re-elevate)
$scriptArgs = @()
if ($Silent) { $scriptArgs += "-Silent" }

# Check admin privileges
if (-not (Test-Administrator)) {
    Write-WarningMsg "Service removal requires administrator privileges"
    Restart-AsAdministrator -Arguments $scriptArgs -ScriptPath $MyInvocation.PSCommandPath
    exit
}

Write-Banner "Windows Service Uninstallation"

$ServiceName = "AvatarFactoryGPU"
$NSSM_PATH = Join-Path $PSScriptRoot "tools\nssm.exe"

# Check if service exists
$service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue

if (-not $service) {
    Write-ErrorMsg "Service '$ServiceName' not found"
    Write-Info "Nothing to uninstall."
    exit 1
}

# Confirm removal (unless -Silent)
if (-not $Silent) {
    $confirm = Read-Host "Remove service '$ServiceName'? (y/N)"
    if (-not ($confirm -match "^[Yy]$")) {
        Write-Info "Cancelled."
        exit 0
    }
    Write-Host ""
}

# Stop service if running
if ($service.Status -eq "Running") {
    Write-Info "Stopping service..."
    try {
        Stop-Service -Name $ServiceName -Force -ErrorAction Stop
        Start-Sleep -Seconds 2
        Write-Success "Service stopped"
    }
    catch {
        Write-WarningMsg "Could not stop service: $_"
        Write-Info "Attempting removal anyway..."
    }
}

# Remove service with NSSM
Write-Info "Removing service..."

if (Test-Path $NSSM_PATH) {
    & $NSSM_PATH remove $ServiceName confirm
    $exitCode = $LASTEXITCODE
}
else {
    Write-WarningMsg "NSSM not found, using sc.exe..."
    sc.exe delete $ServiceName
    $exitCode = $LASTEXITCODE
}

if ($exitCode -eq 0) {
    Write-Success "Service removed successfully"
}
else {
    Write-ErrorMsg "Failed to remove service"
    exit 1
}

# Verify removal
Start-Sleep -Seconds 1
$verify = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
if ($verify) {
    Write-WarningMsg "Service may still be present. Try again or use services.msc"
    exit 1
}

Write-Host ""
Write-Success "Service '$ServiceName' has been uninstalled"
Write-Host ""

exit 0
