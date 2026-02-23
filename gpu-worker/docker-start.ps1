# Avatar Factory GPU Worker - Docker Start (PowerShell)
# Builds and starts GPU worker in Docker container

param(
    [switch]$NoGpu,
    [switch]$Rebuild
)

$ErrorActionPreference = "Stop"

function Write-ColorOutput {
    param([string]$Message, [string]$Color = "White")
    Write-Host $Message -ForegroundColor $Color
}

function Write-Step {
    param([string]$Message)
    Write-ColorOutput "`n[INFO] $Message" "Cyan"
}

function Write-Success {
    param([string]$Message)
    Write-ColorOutput "[OK] $Message" "Green"
}

function Write-Warning {
    param([string]$Message)
    Write-ColorOutput "[WARN] $Message" "Yellow"
}

function Write-Error {
    param([string]$Message)
    Write-ColorOutput "[ERROR] $Message" "Red"
}

Clear-Host
Write-ColorOutput "`n========================================" "Blue"
Write-ColorOutput " Avatar Factory GPU Worker - Docker" "Blue"
Write-ColorOutput "========================================`n" "Blue"

Set-Location $PSScriptRoot

# 1. Check Docker
Write-Step "Checking Docker..."
try {
    $dockerVersion = docker version --format "{{.Server.Version}}" 2>$null
    if ($LASTEXITCODE -ne 0) {
        throw "Docker not running"
    }
    Write-Success "Docker $dockerVersion is running"
}
catch {
    Write-Error "Docker is not running"
    Write-Host "`nPlease install and start Docker Desktop:"
    Write-Host "https://docs.docker.com/desktop/install/windows-install/`n"
    Read-Host "Press Enter to exit"
    exit 1
}

# 2. Check GPU support
if (-not $NoGpu) {
    Write-Step "Checking NVIDIA GPU support..."
    try {
        $null = docker run --rm --gpus all nvidia/cuda:11.8.0-base-ubuntu22.04 nvidia-smi 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Success "NVIDIA GPU support detected"
            $gpuArgs = "--gpus all"
        }
        else {
            throw "GPU not detected"
        }
    }
    catch {
        Write-Warning "NVIDIA Container Toolkit not detected"
        Write-Host "`nTo use GPU in Docker, install NVIDIA Container Toolkit:"
        Write-Host "https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html`n"
        
        $continue = Read-Host "Continue without GPU? (y/N)"
        if ($continue -ne "y") {
            exit 1
        }
        $gpuArgs = ""
    }
}
else {
    Write-Warning "Skipping GPU check (--NoGpu flag)"
    $gpuArgs = ""
}

# 3. Check .env
Write-Step "Checking configuration..."
if (-not (Test-Path ".env")) {
    Write-Warning ".env not found, creating default..."
    $apiKey = -join ((65..90) + (97..122) + (48..57) | Get-Random -Count 32 | ForEach-Object {[char]$_})
    @"
GPU_API_KEY=$apiKey
HOST=0.0.0.0
PORT=8001
CUDA_VISIBLE_DEVICES=0
"@ | Out-File -FilePath ".env" -Encoding UTF8
    Write-Success "Created .env"
}
else {
    Write-Success ".env exists"
}

# 4. Build image
Write-Step "Building Docker image..."
Write-ColorOutput "  This may take 10-20 minutes on first build" "Blue"
Write-ColorOutput "  (downloads ~5GB of dependencies)`n" "Blue"

$buildArgs = @("build", "-t", "avatar-gpu-worker:latest")
if ($Rebuild) {
    $buildArgs += "--no-cache"
}
$buildArgs += "."

& docker @buildArgs

if ($LASTEXITCODE -ne 0) {
    Write-Error "Docker build failed"
    Write-Host "`nCommon issues:"
    Write-Host "  - Network connection problems"
    Write-Host "  - Insufficient disk space"
    Write-Host "  - CUDA/Python dependency conflicts`n"
    Read-Host "Press Enter to exit"
    exit 1
}
Write-Success "Build successful"

# 5. Start container
Write-Step "Starting GPU worker container..."

# Stop existing container
docker stop avatar-gpu-worker 2>$null
docker rm avatar-gpu-worker 2>$null

# Start new container
$runArgs = @(
    "run", "-d",
    "--name", "avatar-gpu-worker",
    "-p", "8001:8001",
    "--env-file", ".env",
    "--restart", "unless-stopped",
    "-v", "${PWD}/checkpoints:/app/checkpoints",
    "-v", "${PWD}/models:/app/models"
)

if ($gpuArgs) {
    $runArgs += $gpuArgs.Split(" ")
}

$runArgs += "avatar-gpu-worker:latest"

& docker @runArgs

if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to start container"
    Write-Host "`nTry without GPU:"
    Write-Host "  docker-start.ps1 -NoGpu`n"
    Read-Host "Press Enter to exit"
    exit 1
}

Write-Success "Container started"

# Wait for startup
Write-Step "Waiting for server to start..."
Start-Sleep -Seconds 10

# Check health
Write-Step "Testing server health..."
try {
    $response = Invoke-RestMethod -Uri "http://localhost:8001/health" -ErrorAction Stop
    Write-Success "Server is healthy!"
    
    Write-ColorOutput "`n========================================" "Green"
    Write-ColorOutput " GPU Worker is running!" "Green"
    Write-ColorOutput "========================================`n" "Green"
    
    Write-Host "Server URL: http://localhost:8001"
    Write-Host "API Key: (check .env file)`n"
    Write-Host "Commands:"
    Write-Host "  View logs:   docker logs -f avatar-gpu-worker"
    Write-Host "  Stop server: .\docker-stop.ps1"
    Write-Host "  Restart:     .\docker-restart.ps1"
}
catch {
    Write-Warning "Server is starting... (may take 1-2 minutes)"
    Write-Host "`nView startup logs:"
    Write-Host "  docker logs -f avatar-gpu-worker`n"
    Write-Host "Check health when ready:"
    Write-Host "  curl http://localhost:8001/health"
}

Write-Host ""
Read-Host "Press Enter to exit"
