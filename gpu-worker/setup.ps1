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

# === STEP 5: Create Virtual Environment ===
$step5 = Invoke-Step "Python Virtual Environment" {
    Write-Info "Setting up Python virtual environment..."

    if ((Test-Path $VENV_PATH) -and $Force) {
        Write-WarningMsg "Removing existing virtual environment..."
        Remove-Item -Path $VENV_PATH -Recurse -Force
    }

    if (-not (Test-Path $VENV_PATH)) {
        Write-Info "Creating virtual environment..."
        python -m venv $VENV_PATH

        if ($LASTEXITCODE -ne 0) {
            throw "Failed to create virtual environment"
        }

        Write-Success "Virtual environment created"
    }
    else {
        Write-Success "Virtual environment already exists"
    }

    # Activate venv
    Write-Info "Activating virtual environment..."
    $activateScript = Join-Path $VENV_PATH "Scripts\Activate.ps1"

    if (Test-Path $activateScript) {
        & $activateScript
        Write-Success "Virtual environment activated"
    }
    else {
        throw "Virtual environment activation script not found"
    }

    # Upgrade pip
    Write-Info "Upgrading pip..."
    $pipUpgradeArgs = @("install", "--upgrade", "pip", "setuptools", "wheel")
    if ($Silent) { $pipUpgradeArgs += "--quiet" }
    & python -m pip @pipUpgradeArgs

    if ($LASTEXITCODE -eq 0) {
        Write-Success "pip upgraded"
    }

    $script:InstallationState.VenvCreated = $true
}
if (-not $step5) { exit 1 }

# === STEP 6: Install PyTorch with CUDA ===
$step6 = Invoke-Step "PyTorch Installation" {
    Write-Info "Installing PyTorch with CUDA support..."
    if (-not $Silent) {
        Write-Host "  This may take 5-10 minutes depending on your internet speed..."
        Write-Host ""
    }

    # Check if already installed
    $torchInstalled = python -c "import torch; print(torch.__version__)" 2>$null

    if ($torchInstalled -and -not $Force) {
        Write-Success "PyTorch already installed: $torchInstalled"

        # Check CUDA availability
        $cudaAvailable = python -c "import torch; print(torch.cuda.is_available())" 2>$null

        if ($cudaAvailable -eq "True") {
            Write-Success "CUDA support confirmed"
            $script:InstallationState.TorchInstalled = $true
            return
        }
        else {
            Write-WarningMsg "CUDA not available in current PyTorch installation"
            Write-Info "Reinstalling PyTorch with CUDA..."
        }
    }

    # Install PyTorch with CUDA 11.8
    Write-Info "Installing from PyTorch CUDA index..."

    $pipArgs = @(
        "install",
        "torch",
        "torchvision",
        "torchaudio",
        "--index-url",
        "https://download.pytorch.org/whl/cu118"
    )

    if ($Silent) {
        $pipArgs += "--quiet"
    }

    & python -m pip @pipArgs

    if ($LASTEXITCODE -ne 0) {
        throw "Failed to install PyTorch"
    }

    # Verify installation
    $cudaAvailable = python -c "import torch; print(torch.cuda.is_available())" 2>&1

    if ($cudaAvailable -eq "True") {
        $torchVersion = python -c "import torch; print(torch.__version__)" 2>&1
        Write-Success "PyTorch installed with CUDA support: $torchVersion"

        # Show GPU info
        $gpuName = python -c "import torch; print(torch.cuda.get_device_name(0) if torch.cuda.is_available() else 'N/A')" 2>&1
        Write-Info "GPU: $gpuName"

        $script:InstallationState.TorchInstalled = $true
    }
    else {
        Write-WarningMsg "PyTorch installed but CUDA not available"
        Write-WarningMsg "GPU acceleration will not work. Check CUDA Toolkit installation."
    }
}
if (-not $step6) { exit 1 }

# === STEP 7: Install Python Dependencies ===
$step7 = Invoke-Step "Python Dependencies" {
    Write-Info "Installing Python dependencies from requirements.txt..."
    if (-not $Silent) {
        Write-Host "  This may take 3-5 minutes..."
        Write-Host ""
    }

    if (-not (Test-Path "requirements.txt")) {
        throw "requirements.txt not found"
    }

    $pipArgs = @(
        "install",
        "-r",
        "requirements.txt"
    )

    if ($Silent) {
        $pipArgs += "--quiet"
    }

    & python -m pip @pipArgs

    if ($LASTEXITCODE -ne 0) {
        throw "Failed to install Python dependencies"
    }

    Write-Success "Python dependencies installed"

    # Verify key packages
    Write-Info "Verifying installations..."

    $packages = @("fastapi", "uvicorn", "diffusers", "transformers")
    foreach ($package in $packages) {
        $installed = python -c "import $package; print('OK')" 2>$null
        if ($installed -eq "OK") {
            Write-Host "  $($Colors.Green)✓$($Colors.Reset) $package"
        }
        else {
            Write-WarningMsg "  $package import failed"
        }
    }

    $script:InstallationState.DepsInstalled = $true
}
if (-not $step7) { exit 1 }

# === STEP 8: Clone and Setup SadTalker ===
$step8 = Invoke-Step "SadTalker Setup" {
    Write-Info "Setting up SadTalker..."

    if (Test-Path "SadTalker") {
        if ($Force) {
            Write-WarningMsg "Removing existing SadTalker..."
            Remove-Item -Path "SadTalker" -Recurse -Force
        }
        else {
            Write-Success "SadTalker already exists"
            return
        }
    }

    if (-not (Test-Command git)) {
        Write-WarningMsg "Git not available, skipping SadTalker clone"
        Write-Info "You'll need to manually clone: git clone https://github.com/OpenTalker/SadTalker.git"
        return
    }

    Write-Info "Cloning SadTalker repository..."
    git clone https://github.com/OpenTalker/SadTalker.git

    if ($LASTEXITCODE -ne 0) {
        throw "Failed to clone SadTalker"
    }

    Write-Success "SadTalker cloned"

    # Install SadTalker dependencies
    Write-Info "Installing SadTalker dependencies..."

    Push-Location "SadTalker"
    try {
        if (Test-Path "requirements.txt") {
            $sadPipArgs = @("install", "-r", "requirements.txt")
            if ($Silent) { $sadPipArgs += "--quiet" }
            python -m pip @sadPipArgs

            if ($LASTEXITCODE -eq 0) {
                Write-Success "SadTalker dependencies installed"
            }
            else {
                Write-WarningMsg "Some SadTalker dependencies failed to install"
            }
        }
    }
    finally {
        Pop-Location
    }
}
if (-not $step8) { exit 1 }

# More steps will be added in next task...

Write-Success "Setup completed!"
exit 0
