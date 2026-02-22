# Avatar Factory GPU Worker - Main Setup Script
# One-command installation for Windows 10/11

param(
    [switch]$SkipModels,
    [switch]$NoService,
    [switch]$Silent,
    [switch]$Force,
    [switch]$AdminOnly,
    [switch]$Repair,
    [switch]$Uninstall
)

# Ensure we run from script directory for consistent paths
$null = Set-Location $PSScriptRoot

# Import common utilities
. "$PSScriptRoot\lib\common.ps1"

# Configuration
$LOG_FILE = Join-Path $PSScriptRoot "logs\install.log"
$VENV_PATH = "venv"
$PYTHON_VERSION_MIN = "3.10"
$CUDA_VERSION_RECOMMENDED = "11.8"

# Initialize logging
$logDir = Split-Path $LOG_FILE -Parent
if (-not (Test-Path $logDir)) {
    $null = New-Item -ItemType Directory -Path $logDir -Force
}
Write-Log "=== Avatar Factory GPU Worker Setup Started ===" -LogPath $LOG_FILE
Write-Log "Parameters: SkipModels=$SkipModels NoService=$NoService Silent=$Silent Force=$Force" -LogPath $LOG_FILE

# Display banner
if (-not $Silent) {
    Write-Banner "Avatar Factory GPU Worker Setup"
}

# Track installation state
$script:InstallationState = @{
    SystemChecked = $false
    PythonReady = $false
    VenvCreated = $false
    TorchInstalled = $false
    DepsInstalled = $false
    ModelsDownloaded = $false
    EnvConfigured = $false
    FirewallConfigured = $false
    ServiceInstalled = $false
}

# Handle special modes
if ($Uninstall) {
    Write-Log "Uninstall mode requested" -LogPath $LOG_FILE
    if (Test-Path "$PSScriptRoot\uninstall.ps1") {
        & "$PSScriptRoot\uninstall.ps1"
        exit $LASTEXITCODE
    }
    else {
        Write-ErrorMsg "Uninstall script not found. Run full setup first."
        exit 1
    }
}

if ($Repair) {
    Write-Log "Repair mode requested" -LogPath $LOG_FILE
    $Force = $true
}

# Step counter
$script:CurrentStep = 0
$script:TotalSteps = 12
if ($SkipModels) { $script:TotalSteps-- }
if ($NoService) { $script:TotalSteps-- }

function Invoke-Step {
    param(
        [string]$Name,
        [scriptblock]$Action
    )

    $script:CurrentStep++

    if (-not $Silent) {
        Write-Step -Current $script:CurrentStep -Total $script:TotalSteps -Message $Name
    }

    Write-Log "Step $($script:CurrentStep)/$($script:TotalSteps): $Name" -LogPath $LOG_FILE

    try {
        & $Action
        Write-Log "Step completed successfully" -LogPath $LOG_FILE
        return $true
    }
    catch {
        Write-ErrorMsg "Step failed: $_"
        Write-Log "Step failed: $_" -LogPath $LOG_FILE
        return $false
    }
}

# === STEP 1: System Requirements Check ===
$step1 = Invoke-Step "System Requirements Check" {
    Write-Info "Checking system requirements..."

    # Run system checker in subprocess (it uses exit, which would otherwise terminate our script)
    $checkScript = Join-Path $PSScriptRoot "check-system.ps1"
    $process = Start-Process powershell -ArgumentList "-ExecutionPolicy Bypass -NoProfile -File `"$checkScript`"" -WorkingDirectory $PSScriptRoot -Wait -PassThru -NoNewWindow

    if ($process.ExitCode -ne 0) {
        throw "System requirements not met. Please address the issues and try again."
    }

    $script:InstallationState.SystemChecked = $true
    Write-Success "System requirements met"
}
if (-not $step1) { exit 1 }

# === STEP 2: Check/Install Python ===
$step2 = Invoke-Step "Python Installation" {
    Write-Info "Checking Python installation..."

    if (Test-Command python) {
        $version = python --version 2>&1
        if ($version -match "Python (\d+)\.(\d+)") {
            $major = [int]$Matches[1]
            $minor = [int]$Matches[2]

            if ($major -eq 3 -and $minor -ge 10) {
                Write-Success "Python $major.$minor found"
                $script:InstallationState.PythonReady = $true
                return
            }
        }
    }

    Write-WarningMsg "Python 3.10+ not found"

    # Try to install via winget
    if (Test-Command winget) {
        Write-Info "Installing Python via winget..."

        $null = winget install -e --id Python.Python.3.11 --silent --accept-package-agreements --accept-source-agreements

        if ($LASTEXITCODE -eq 0) {
            Write-Success "Python installed successfully"

            # Refresh PATH
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

            $script:InstallationState.PythonReady = $true
        }
        else {
            throw "Failed to install Python via winget. Please install manually from https://www.python.org/downloads/"
        }
    }
    else {
        throw "winget not available. Please install Python 3.10+ manually from https://www.python.org/downloads/"
    }
}
if (-not $step2) { exit 1 }

# === STEP 3: Check/Install Git ===
Invoke-Step "Git Installation" {
    Write-Info "Checking Git installation..."

    if (Test-Command git) {
        $version = git --version
        Write-Success "Git found: $version"
        return
    }

    Write-WarningMsg "Git not found"

    # Try to install via winget
    if (Test-Command winget) {
        Write-Info "Installing Git via winget..."

        $null = winget install -e --id Git.Git --silent --accept-package-agreements --accept-source-agreements

        if ($LASTEXITCODE -eq 0) {
            Write-Success "Git installed successfully"

            # Refresh PATH
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
        }
        else {
            Write-WarningMsg "Failed to install Git via winget"
            Write-Info "Git is optional but recommended. Install from https://git-scm.com/downloads"
        }
    }
    else {
        Write-WarningMsg "winget not available"
        Write-Info "Git is optional but recommended. Install from https://git-scm.com/downloads"
    }
}

# === STEP 4: Check CUDA ===
$step4 = Invoke-Step "CUDA Check" {
    Write-Info "Checking CUDA installation..."

    if (Test-Command nvidia-smi) {
        $gpuInfo = nvidia-smi --query-gpu=name,memory.total --format=csv,noheader 2>$null
        Write-Success "NVIDIA GPU detected: $gpuInfo"
    }
    else {
        Write-WarningMsg "NVIDIA GPU not detected"
        Write-Info "Make sure NVIDIA drivers are installed"
    }

    if (Test-Command nvcc) {
        $cudaVersion = nvcc --version 2>&1 | Select-String "release" | Out-String
        Write-Success "CUDA Toolkit found: $($cudaVersion.Trim())"
    }
    else {
        Write-WarningMsg "CUDA Toolkit not found"
        Write-Host ""
        Write-Host "  $($Colors.Yellow)CUDA Toolkit 11.8 is required for GPU acceleration$($Colors.Reset)"
        Write-Host "  Download from: $($Colors.Cyan)https://developer.nvidia.com/cuda-11-8-0-download-archive$($Colors.Reset)"
        Write-Host ""

        if ($Silent) {
            Write-WarningMsg "CUDA not found - continuing (Silent mode)"
        }
        else {
            $continue = Read-Host "Continue without CUDA? (y/N)"
            if ($continue -notmatch "^[Yy]$") {
                throw "CUDA Toolkit required. Please install and run setup again."
            }
        }
    }
}
if (-not $step4) { exit 1 }

# More steps will be added in next task...

Write-Success "Setup completed!"
exit 0
