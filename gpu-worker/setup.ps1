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
$script:TotalSteps = 13
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
        # Display full error details
        Write-Host ""
        Write-ErrorMsg "Step failed with error:"
        Write-Host "$($Colors.Red)$_$($Colors.Reset)"
        
        # Show exception details if available
        if ($_.Exception) {
            Write-Host ""
            Write-Host "$($Colors.Yellow)Exception Type:$($Colors.Reset) $($_.Exception.GetType().FullName)"
            if ($_.Exception.Message -ne $_) {
                Write-Host "$($Colors.Yellow)Exception Message:$($Colors.Reset) $($_.Exception.Message)"
            }
        }
        
        # Show script stack trace
        if ($_.ScriptStackTrace) {
            Write-Host ""
            Write-Host "$($Colors.Yellow)Stack Trace:$($Colors.Reset)"
            Write-Host "$($_.ScriptStackTrace)"
        }
        
        Write-Host ""
        
        # Log full error
        Write-Log "Step failed: $_" -LogPath $LOG_FILE
        Write-Log "Exception: $($_.Exception.GetType().FullName) - $($_.Exception.Message)" -LogPath $LOG_FILE
        Write-Log "Stack: $($_.ScriptStackTrace)" -LogPath $LOG_FILE
        
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

    # Upgrade pip using venv's python explicitly
    Write-Info "Upgrading pip..."
    $venvPython = Join-Path $VENV_PATH "Scripts\python.exe"
    $pipUpgradeArgs = @("-m", "pip", "install", "--upgrade", "pip", "setuptools", "wheel")
    if ($Silent) { $pipUpgradeArgs += "--quiet" }
    & $venvPython @pipUpgradeArgs

    if ($LASTEXITCODE -eq 0) {
        Write-Success "pip upgraded"
    }

    $script:InstallationState.VenvCreated = $true
}
if (-not $step5) { exit 1 }

# === STEP 6: Install PyTorch with CUDA ===
$step6 = Invoke-Step "PyTorch Installation" {
    Write-Info "Checking PyTorch installation..."
    
    $venvPython = Join-Path $VENV_PATH "Scripts\python.exe"
    
    # Quick check if torch is already installed
    $torchInstalled = & $venvPython -c "import torch; print(torch.__version__)" 2>$null
    
    if ($torchInstalled -and -not $Force) {
        Write-Success "PyTorch already installed: $torchInstalled"
        Write-Info "CUDA support will be verified in tests (Step 12)"
        $script:InstallationState.TorchInstalled = $true
        return
    }
    
    # Install PyTorch with CUDA 11.8
    Write-Info "Installing PyTorch with CUDA support..."
    if (-not $Silent) {
        Write-Host "  This may take 5-10 minutes depending on your internet speed..."
        Write-Host ""
    }
    
    $pipArgs = @(
        "-m", "pip",
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
    
    # Capture output and errors
    $output = & $venvPython @pipArgs 2>&1
    $exitCode = $LASTEXITCODE
    
    # Show output in non-silent mode
    if (-not $Silent) {
        $output | ForEach-Object { Write-Host $_ }
    }
    
    if ($exitCode -ne 0) {
        Write-Host ""
        Write-ErrorMsg "PyTorch installation failed with exit code: $exitCode"
        Write-Host ""
        Write-Host "$($Colors.Yellow)Last 20 lines of output:$($Colors.Reset)"
        $output | Select-Object -Last 20 | ForEach-Object { Write-Host "  $_" }
        Write-Host ""
        throw "Failed to install PyTorch (exit code: $exitCode)"
    }
    
    # Quick verify (just check it imports)
    $torchVersion = & $venvPython -c "import torch; print(torch.__version__)" 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Success "PyTorch installed: $torchVersion"
        $script:InstallationState.TorchInstalled = $true
    }
    else {
        throw "PyTorch installation verification failed"
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

    $venvPython = Join-Path $VENV_PATH "Scripts\python.exe"
    $pipArgs = @(
        "-m", "pip",
        "install",
        "-r",
        "requirements.txt"
    )

    if ($Silent) {
        $pipArgs += "--quiet"
    }

    # Capture output and errors
    $output = & $venvPython @pipArgs 2>&1
    $exitCode = $LASTEXITCODE

    # Show output in non-silent mode
    if (-not $Silent) {
        $output | ForEach-Object { Write-Host $_ }
    }

    if ($exitCode -ne 0) {
        Write-Host ""
        Write-ErrorMsg "Dependencies installation failed with exit code: $exitCode"
        Write-Host ""
        Write-Host "$($Colors.Yellow)Last 30 lines of output:$($Colors.Reset)"
        $output | Select-Object -Last 30 | ForEach-Object { Write-Host "  $_" }
        Write-Host ""
        throw "Failed to install Python dependencies (exit code: $exitCode)"
    }

    Write-Success "Python dependencies installed"

    # Verify key packages (non-critical - will be tested properly in Step 12)
    Write-Info "Quick verification of key packages..."

    $packages = @("fastapi", "uvicorn", "diffusers", "transformers")
    
    foreach ($package in $packages) {
        try {
            # Capture both stdout and stderr
            $output = & $venvPython -c "import $package; print('OK')" 2>&1
            $exitCode = $LASTEXITCODE
            
            if ($exitCode -eq 0 -and $output -match "OK") {
                Write-Host "  $($Colors.Green)[OK]$($Colors.Reset) $package"
            }
            else {
                Write-Host "  $($Colors.Yellow)[WARN]$($Colors.Reset) $package (will retry in tests)"
                
                # Log error details but don't fail
                if ($output) {
                    Write-Log "Package $package import failed: $output" -LogPath $LOG_FILE
                }
            }
        }
        catch {
            Write-Host "  $($Colors.Yellow)[WARN]$($Colors.Reset) $package (will retry in tests)"
            Write-Log "Package $package check failed: $_" -LogPath $LOG_FILE
        }
    }

    Write-Info "Full package verification will happen in Step 12"
    $script:InstallationState.DepsInstalled = $true
}
if (-not $step7) { exit 1 }

# === STEP 7.5: Install xformers (requires PyTorch) ===
$step7_5 = Invoke-Step "xformers Installation" {
    Write-Info "Installing xformers (memory-efficient attention)..."
    Write-Info "This requires PyTorch and may take a few minutes..."

    $venvPython = Join-Path $VENV_PATH "Scripts\python.exe"
    
    # Try to install xformers (flexible version for compatibility)
    $xformersArgs = @(
        "-m", "pip",
        "install",
        "xformers",
        "--index-url",
        "https://download.pytorch.org/whl/cu118"
    )
    
    if ($Silent) {
        $xformersArgs += "--quiet"
    }
    
    # Capture output and errors
    $output = & $venvPython @xformersArgs 2>&1
    $exitCode = $LASTEXITCODE
    
    # Show output in non-silent mode
    if (-not $Silent) {
        $output | ForEach-Object { Write-Host $_ }
    }
    
    if ($exitCode -eq 0) {
        $installedVersion = & $venvPython -c "import xformers; print(xformers.__version__)" 2>$null
        Write-Success "xformers installed: $installedVersion"
    }
    else {
        Write-WarningMsg "xformers installation failed (this is optional)"
        Write-Info "Diffusers will work without xformers, but slower"
        
        if (-not $Silent) {
            Write-Host ""
            Write-Host "$($Colors.Yellow)Error details (last 10 lines):$($Colors.Reset)"
            $output | Select-Object -Last 10 | ForEach-Object { Write-Host "  $_" }
            Write-Host ""
        }
    }
}
# xformers is optional, don't fail if it doesn't install
# if (-not $step7_5) { exit 1 }

# === STEP 8: Clone and Setup SadTalker ===
$step8 = Invoke-Step "SadTalker Setup" {
    Write-Info "Setting up SadTalker..."

    $needsClone = $false
    
    if (Test-Path "SadTalker") {
        if ($Force) {
            Write-WarningMsg "Removing existing SadTalker..."
            Remove-Item -Path "SadTalker" -Recurse -Force
            $needsClone = $true
        }
        else {
            Write-Success "SadTalker directory already exists"
        }
    }
    else {
        $needsClone = $true
    }

    if ($needsClone) {
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
    }

    # Install/Update SadTalker dependencies (always run, even if already cloned)
    Write-Info "Installing SadTalker dependencies..."
    
    # Get full path to venv python before changing directory
    $venvPythonPath = Resolve-Path (Join-Path $VENV_PATH "Scripts\python.exe")

    Push-Location "SadTalker"
    try {
        if (Test-Path "requirements.txt") {
            # Capture output for better error reporting
            $sadPipArgs = @("-m", "pip", "install", "-r", "requirements.txt")
            if ($Silent) { $sadPipArgs += "--quiet" }
            
            $output = & $venvPythonPath @sadPipArgs 2>&1
            $exitCode = $LASTEXITCODE
            
            if (-not $Silent) {
                $output | ForEach-Object { Write-Host $_ }
            }

            if ($exitCode -eq 0) {
                Write-Success "SadTalker dependencies installed"
            }
            else {
                Write-Host ""
                Write-ErrorMsg "SadTalker dependencies installation failed"
                Write-Host ""
                Write-Host "$($Colors.Yellow)Last 20 lines of output:$($Colors.Reset)"
                $output | Select-Object -Last 20 | ForEach-Object { Write-Host "  $_" }
                Write-Host ""
                throw "Failed to install SadTalker dependencies (exit code: $exitCode)"
            }
        }
        else {
            Write-WarningMsg "SadTalker requirements.txt not found"
        }
    }
    finally {
        Pop-Location
    }
}
if (-not $step8) { exit 1 }

# === STEP 9: Download AI Models ===
if (-not $SkipModels) {
    Invoke-Step "AI Models Download" {
        Write-Info "Downloading AI models..."

        if ($Silent) {
            Write-WarningMsg "Silent mode: skipping model download"
            Write-Info "You can download models later by running: python download_models.py"
            return
        }

        Write-Host ""
        Write-Host "  $($Colors.Yellow)This will download approximately 10GB of data$($Colors.Reset)"
        Write-Host "  $($Colors.Yellow)and may take 15-30 minutes depending on your internet speed$($Colors.Reset)"
        Write-Host ""

        $proceed = Read-Host "  Download models now? (Y/n)"
        if ($proceed -match "^[Nn]$") {
            Write-WarningMsg "Skipping model download"
            Write-Info "You can download models later by running: python download_models.py"
            return
        }

        if (-not (Test-Path "download_models.py")) {
            Write-WarningMsg "download_models.py not found, skipping automatic download"
            Write-Info "You may need to download models manually"
            return
        }

        Write-Info "Starting model download..."
        python download_models.py

        if ($LASTEXITCODE -eq 0) {
            Write-Success "Models downloaded successfully"
            $script:InstallationState.ModelsDownloaded = $true
        }
        else {
            Write-WarningMsg "Model download had errors"
            Write-Info "You can retry later: python download_models.py"
        }
    }
}

# === STEP 10: Environment Configuration ===
Invoke-Step "Environment Configuration" {
    Write-Info "Configuring environment..."

    $envFile = ".env"
    $envExists = Test-Path $envFile

    if ($envExists -and -not $Force) {
        Write-Success ".env file already exists"

        $existingConfig = Get-Content $envFile | Out-String

        if ($existingConfig -match "GPU_API_KEY=(.+)") {
            $apiKey = $Matches[1].Trim()
            $displayKey = $apiKey.Substring(0, [Math]::Min(8, $apiKey.Length))
            Write-Info "Using existing API key: ${displayKey}..."
        }

        $script:InstallationState.EnvConfigured = $true
        return
    }

    Write-Info "Creating .env file..."

    $apiKey = New-SecureRandomString -Length 32
    $localIP = Get-LocalIPAddress

    $envContent = @"
# Avatar Factory GPU Worker Configuration
# Generated: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

# Security
GPU_API_KEY=$apiKey

# Server
HOST=0.0.0.0
PORT=8001

# GPU Settings
CUDA_VISIBLE_DEVICES=0

# Logging
LOG_LEVEL=INFO
"@

    Set-Content -Path $envFile -Value $envContent -Encoding UTF8

    # Make file hidden (not read-only - user may need to edit)
    $file = Get-Item $envFile
    $file.Attributes = $file.Attributes -bor [System.IO.FileAttributes]::Hidden

    Write-Success ".env file created"
    Write-Host ""
    Write-Host "  $($Colors.Yellow)===============================================================$($Colors.Reset)"
    Write-Host "  $($Colors.Yellow)IMPORTANT: Save these values for laptop configuration$($Colors.Reset)"
    Write-Host ""
    Write-Host "  GPU Server URL:  $($Colors.Green)http://${localIP}:8001$($Colors.Reset)"
    Write-Host "  API Key:         $($Colors.Green)$apiKey$($Colors.Reset)"
    Write-Host ""
    Write-Host "  Add to laptop's .env file:"
    Write-Host "  $($Colors.Cyan)GPU_SERVER_URL=http://${localIP}:8001$($Colors.Reset)"
    Write-Host "  $($Colors.Cyan)GPU_API_KEY=$apiKey$($Colors.Reset)"
    Write-Host "  $($Colors.Yellow)===============================================================$($Colors.Reset)"
    Write-Host ""

    Write-Log "Environment configured - IP: $localIP, API Key: $($apiKey.Substring(0,8))..." -LogPath $LOG_FILE

    $script:InstallationState.EnvConfigured = $true
}

# === STEP 11: Firewall Configuration ===
Invoke-Step "Firewall Configuration" {
    if ($AdminOnly -or (Test-Administrator)) {
        Write-Info "Configuring Windows Firewall..."

        & "$PSScriptRoot\configure-firewall.ps1" -Action Add

        if ($LASTEXITCODE -eq 0) {
            Write-Success "Firewall configured"
            $script:InstallationState.FirewallConfigured = $true
        }
        else {
            Write-WarningMsg "Firewall configuration failed"
        }
    }
    else {
        Write-WarningMsg "Firewall configuration requires administrator privileges"
        Write-Info "Run this command as administrator later:"
        Write-Host "  powershell -ExecutionPolicy Bypass -File configure-firewall.ps1 -Action Add" -ForegroundColor Cyan
    }
}

# === STEP 12: Test Installation ===
Invoke-Step "Installation Test" {
    Write-Info "Testing installation..."

    Write-Info "Testing Python imports..."

    $tests = @(
        @{ Name = "PyTorch"; Command = 'import torch; print(torch.__version__)' }
        @{ Name = "CUDA"; Command = 'import torch; print(torch.cuda.is_available())' }
        @{ Name = "FastAPI"; Command = 'import fastapi; print(fastapi.__version__)' }
        @{ Name = "Diffusers"; Command = 'import diffusers; print(diffusers.__version__)' }
    )

    $allPassed = $true
    $venvPython = Join-Path $VENV_PATH "Scripts\python.exe"

    foreach ($test in $tests) {
        $result = & $venvPython -c $test.Command 2>&1

        if ($LASTEXITCODE -eq 0) {
            Write-Host "  $($Colors.Green)[OK]$($Colors.Reset) $($test.Name): $result"
        }
        else {
            Write-Host "  $($Colors.Red)[FAIL]$($Colors.Reset) $($test.Name): FAILED"
            $allPassed = $false
        }
    }

    if (-not $allPassed) {
        Write-WarningMsg "Some tests failed"
    }
    else {
        Write-Success "All tests passed"
    }

    if (Test-Path "server.py") {
        Write-Info "Testing server start..."

        $workDir = $PSScriptRoot
        $venvPython = Join-Path $workDir "venv\Scripts\python.exe"

        if (Test-Path $venvPython) {
            $serverJob = Start-Job -ScriptBlock {
                param($workDir, $venvPython)
                Set-Location $workDir
                & $venvPython server.py
            } -ArgumentList $workDir, $venvPython

            Start-Sleep -Seconds 5

            try {
                $response = Invoke-WebRequest -Uri "http://localhost:8001/health" -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
                Write-Success "Server started successfully"
            }
            catch {
                Write-WarningMsg "Server test failed (may need manual verification)"
            }
            finally {
                Stop-Job $serverJob -ErrorAction SilentlyContinue
                Remove-Job $serverJob -ErrorAction SilentlyContinue

                # Kill any python server process we started on port 8001
                $serverProc = Get-NetTCPConnection -LocalPort 8001 -ErrorAction SilentlyContinue |
                    Select-Object -First 1 -ExpandProperty OwningProcess
                if ($serverProc) {
                    Stop-Process -Id $serverProc -Force -ErrorAction SilentlyContinue
                }
            }
        }
        else {
            Write-WarningMsg "Virtual environment Python not found, skipping server test"
        }
    }
}

# === Installation Complete ===
Write-Host ""
Write-Host "===============================================================" -ForegroundColor Green
Write-Host "$($Colors.Green)[OK] Installation Complete!$($Colors.Reset)" -ForegroundColor Green
Write-Host "===============================================================" -ForegroundColor Green
Write-Host ""

Write-Host "$($Colors.Blue)Installation Summary:$($Colors.Reset)"
Write-Host ""

foreach ($key in $script:InstallationState.Keys) {
    $status = if ($script:InstallationState[$key]) { "$($Colors.Green)[OK]$($Colors.Reset)" } else { "$($Colors.Yellow)[--]$($Colors.Reset)" }
    $label = $key -replace "([A-Z])", ' $1'
    Write-Host "  $status $label"
}

Write-Host ""
Write-Host "$($Colors.Blue)Next Steps:$($Colors.Reset)"
Write-Host ""
Write-Host "  $($Colors.Yellow)Note: .env is hidden$($Colors.Reset) (view/edit: Get-Content .env)"
Write-Host ""
Write-Host "  1. Find your PC's IP address:"
Write-Host "     $($Colors.Cyan)ipconfig$($Colors.Reset) (look for IPv4 Address)"
Write-Host ""
Write-Host "  2. Start the GPU server:"
Write-Host "     $($Colors.Cyan).\start.bat$($Colors.Reset)"
Write-Host ""
Write-Host "  3. Test the server:"
Write-Host "     $($Colors.Cyan)curl http://localhost:8001/health$($Colors.Reset)"
Write-Host ""

if (-not $NoService) {
    Write-Host "  4. Optional: Install Windows Service for auto-start"
    Write-Host "     $($Colors.Cyan).\service-install.ps1$($Colors.Reset)"
    Write-Host ""

    if (-not $Silent) {
        $installService = Read-Host "  Install Windows Service now? (y/N)"

        if ($installService -match "^[Yy]$") {
            Write-Host ""
            if (Test-Path "$PSScriptRoot\service-install.ps1") {
                & "$PSScriptRoot\service-install.ps1"
            }
            else {
                Write-WarningMsg "service-install.ps1 not found (created in Task 8)"
            }
        }
    }
}

Write-Host ""
Write-Host "$($Colors.Green)Documentation:$($Colors.Reset) README.md"
Write-Host "$($Colors.Green)Logs:$($Colors.Reset) $LOG_FILE"
Write-Host ""

Write-Log "=== Installation Completed Successfully ===" -LogPath $LOG_FILE

exit 0
