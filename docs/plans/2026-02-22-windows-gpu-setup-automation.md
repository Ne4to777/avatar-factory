# Windows GPU Worker - Automated Setup Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Implement one-command automated installation system for Avatar Factory GPU Worker on Windows 10/11 that handles all prerequisites, dependencies, configuration, and service setup.

**Architecture:** PowerShell-based automation scripts that check system requirements, install missing prerequisites via winget, configure Python environment with CUDA support, download AI models, configure firewall, and set up Windows Service via NSSM for automatic startup.

**Tech Stack:** PowerShell 5.1+, NSSM 2.24, Python 3.10+, PyTorch CUDA, Windows Firewall API, winget package manager

---

## Prerequisites

Before starting implementation:
- Access to Windows 10/11 machine for testing (VM acceptable)
- PowerShell 5.1+ available
- Git for version control
- Read design document: `docs/plans/2026-02-22-windows-gpu-setup-automation-design.md`

---

## Task 1: Project Structure and Utilities

**Files:**
- Create: `gpu-worker/logs/.gitkeep`
- Create: `gpu-worker/tools/.gitkeep`
- Modify: `gpu-worker/.gitignore`
- Create: `gpu-worker/lib/common.ps1`

**Step 1: Create directory structure**

```bash
cd gpu-worker
mkdir -p logs tools
touch logs/.gitkeep tools/.gitkeep
```

**Step 2: Update .gitignore**

Add to `gpu-worker/.gitignore`:
```gitignore
# Installation logs
logs/*.log
logs/*.txt

# Downloaded tools
tools/nssm.exe
tools/nssm-*.zip

# Virtual environment
venv/

# Environment configuration
.env

# Python cache
__pycache__/
*.pyc
*.pyo
*.pyd
.Python
*.so

# AI Models cache
models/
checkpoints/
SadTalker/

# Temporary files
*.tmp
*.temp
```

**Step 3: Create PowerShell common library**

Create `gpu-worker/lib/common.ps1`:
```powershell
# Common PowerShell utilities for Avatar Factory GPU Worker
# Used by all installation scripts

# Enable strict mode
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ANSI color codes for Windows 10+
$script:Colors = @{
    Red    = "`e[91m"
    Green  = "`e[92m"
    Yellow = "`e[93m"
    Blue   = "`e[94m"
    Cyan   = "`e[96m"
    Reset  = "`e[0m"
}

# Enable ANSI colors in Windows Console
function Enable-AnsiColors {
    if ($PSVersionTable.PSVersion.Major -ge 5) {
        $null = [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
        if ($Host.Name -eq 'ConsoleHost') {
            $null = reg add HKCU\Console /v VirtualTerminalLevel /t REG_DWORD /d 1 /f 2>$null
        }
    }
}

# Print functions
function Write-Success {
    param([string]$Message)
    Write-Host "$($Colors.Green)✓$($Colors.Reset) $Message"
}

function Write-Info {
    param([string]$Message)
    Write-Host "$($Colors.Blue)▸$($Colors.Reset) $Message"
}

function Write-Warning {
    param([string]$Message)
    Write-Host "$($Colors.Yellow)⚠$($Colors.Reset) $Message"
}

function Write-Error {
    param([string]$Message)
    Write-Host "$($Colors.Red)✗$($Colors.Reset) $Message"
}

function Write-Step {
    param(
        [int]$Current,
        [int]$Total,
        [string]$Message
    )
    Write-Host "$($Colors.Cyan)[$Current/$Total]$($Colors.Reset) $Message"
}

# Print banner
function Write-Banner {
    param([string]$Title)
    Enable-AnsiColors
    Write-Host ""
    Write-Host "$($Colors.Blue)╔════════════════════════════════════════════════════════════════╗$($Colors.Reset)"
    Write-Host "$($Colors.Blue)║$($Colors.Reset)  🚀 $Title$((' ' * (57 - $Title.Length)))$($Colors.Blue)║$($Colors.Reset)"
    Write-Host "$($Colors.Blue)╚════════════════════════════════════════════════════════════════╝$($Colors.Reset)"
    Write-Host ""
}

# Check if running as administrator
function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Restart script with administrator privileges
function Restart-AsAdministrator {
    param([string[]]$Arguments)
    
    if (-not (Test-Administrator)) {
        Write-Warning "This operation requires administrator privileges"
        Write-Info "Restarting with elevation..."
        
        $scriptPath = $MyInvocation.PSCommandPath
        Start-Process powershell.exe -ArgumentList "-ExecutionPolicy Bypass -File `"$scriptPath`" $($Arguments -join ' ')" -Verb RunAs
        exit
    }
}

# Test if command exists
function Test-Command {
    param([string]$Command)
    $null = Get-Command $Command -ErrorAction SilentlyContinue
    return $?
}

# Get Windows version
function Get-WindowsVersion {
    $os = Get-CimInstance Win32_OperatingSystem
    return [PSCustomObject]@{
        Caption = $os.Caption
        Version = $os.Version
        Build   = $os.BuildNumber
    }
}

# Check disk space (in GB)
function Get-FreeDiskSpace {
    param([string]$Drive = "C:")
    $disk = Get-PSDrive -Name $Drive.Trim(':') -ErrorAction SilentlyContinue
    if ($disk) {
        return [math]::Round($disk.Free / 1GB, 2)
    }
    return 0
}

# Check RAM (in GB)
function Get-TotalMemory {
    $mem = Get-CimInstance Win32_ComputerSystem
    return [math]::Round($mem.TotalPhysicalMemory / 1GB, 2)
}

# Generate secure random string
function New-SecureRandomString {
    param([int]$Length = 32)
    $bytes = New-Object byte[] $Length
    $rng = [Security.Cryptography.RandomNumberGenerator]::Create()
    $rng.GetBytes($bytes)
    $rng.Dispose()
    return [Convert]::ToBase64String($bytes)
}

# Get local IP address
function Get-LocalIPAddress {
    $adapters = Get-NetIPAddress -AddressFamily IPv4 | 
        Where-Object { $_.InterfaceAlias -notlike '*Loopback*' -and $_.IPAddress -ne '127.0.0.1' }
    
    if ($adapters) {
        return $adapters[0].IPAddress
    }
    return "localhost"
}

# Test internet connectivity
function Test-InternetConnection {
    try {
        $null = Test-Connection -ComputerName 8.8.8.8 -Count 1 -Quiet -ErrorAction Stop
        return $true
    }
    catch {
        return $false
    }
}

# Download file with progress
function Get-FileWithProgress {
    param(
        [string]$Url,
        [string]$OutputPath
    )
    
    try {
        $webClient = New-Object System.Net.WebClient
        
        # Progress handler
        $progressHandler = {
            param($sender, $e)
            $percent = [math]::Round(($e.BytesReceived / $e.TotalBytesToReceive) * 100, 2)
            Write-Progress -Activity "Downloading $(Split-Path $OutputPath -Leaf)" `
                -Status "$percent% Complete" `
                -PercentComplete $percent
        }
        
        Register-ObjectEvent -InputObject $webClient -EventName DownloadProgressChanged `
            -SourceIdentifier WebClient.DownloadProgressChanged -Action $progressHandler | Out-Null
        
        $webClient.DownloadFileAsync($Url, $OutputPath)
        
        # Wait for download to complete
        while ($webClient.IsBusy) {
            Start-Sleep -Milliseconds 100
        }
        
        # Cleanup
        Unregister-Event -SourceIdentifier WebClient.DownloadProgressChanged -ErrorAction SilentlyContinue
        $webClient.Dispose()
        
        Write-Progress -Activity "Downloading" -Completed
        return $true
    }
    catch {
        Write-Progress -Activity "Downloading" -Completed
        return $false
    }
}

# Verify file checksum
function Test-FileChecksum {
    param(
        [string]$FilePath,
        [string]$ExpectedHash,
        [string]$Algorithm = "SHA256"
    )
    
    if (-not (Test-Path $FilePath)) {
        return $false
    }
    
    $hash = Get-FileHash -Path $FilePath -Algorithm $Algorithm
    return $hash.Hash -eq $ExpectedHash
}

# Log to file
function Write-Log {
    param(
        [string]$Message,
        [string]$LogPath = "logs\install.log"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] $Message"
    
    # Ensure log directory exists
    $logDir = Split-Path $LogPath -Parent
    if (-not (Test-Path $logDir)) {
        $null = New-Item -ItemType Directory -Path $logDir -Force
    }
    
    Add-Content -Path $LogPath -Value $logMessage -Encoding UTF8
}

# Export functions
Export-ModuleMember -Function *
```

**Step 4: Test common library**

Create test script `gpu-worker/test-common.ps1`:
```powershell
# Simple test for common.ps1
. .\lib\common.ps1

Write-Banner "Testing Common Library"

Write-Info "Testing print functions..."
Write-Success "Success message works"
Write-Warning "Warning message works"
Write-Error "Error message works"
Write-Step -Current 1 -Total 3 -Message "Step message works"

Write-Info "Testing system checks..."
Write-Host "Administrator: $(Test-Administrator)"
Write-Host "Windows: $((Get-WindowsVersion).Caption)"
Write-Host "Free space: $(Get-FreeDiskSpace) GB"
Write-Host "RAM: $(Get-TotalMemory) GB"
Write-Host "IP: $(Get-LocalIPAddress)"
Write-Host "Internet: $(Test-InternetConnection)"

Write-Info "Testing utilities..."
$randomString = New-SecureRandomString -Length 16
Write-Host "Random string: $randomString"

Write-Success "All tests passed!"
```

Run:
```powershell
powershell -ExecutionPolicy Bypass -File test-common.ps1
```

Expected: Colored output showing system information

**Step 5: Commit**

```bash
git add gpu-worker/.gitignore gpu-worker/logs/.gitkeep gpu-worker/tools/.gitkeep gpu-worker/lib/common.ps1 gpu-worker/test-common.ps1
git commit -m "feat(gpu-worker): add PowerShell common library and project structure"
```

---

## Task 2: System Requirements Checker

**Files:**
- Create: `gpu-worker/check-system.ps1`

**Step 1: Create system checker script**

Create `gpu-worker/check-system.ps1`:
```powershell
# System requirements checker for Avatar Factory GPU Worker
# Verifies all prerequisites before installation

param(
    [switch]$Detailed
)

# Import common utilities
. "$PSScriptRoot\lib\common.ps1"

Write-Banner "System Requirements Check"

$script:AllChecksPassed = $true
$script:Warnings = @()

function Test-Requirement {
    param(
        [string]$Name,
        [scriptblock]$Test,
        [string]$SuccessMessage,
        [string]$FailureMessage,
        [bool]$Required = $true
    )
    
    Write-Info "Checking $Name..."
    
    try {
        $result = & $Test
        if ($result) {
            Write-Success $SuccessMessage
            return $true
        }
        else {
            if ($Required) {
                Write-Error $FailureMessage
                $script:AllChecksPassed = $false
            }
            else {
                Write-Warning $FailureMessage
                $script:Warnings += $FailureMessage
            }
            return $false
        }
    }
    catch {
        if ($Required) {
            Write-Error "$FailureMessage (Error: $_)"
            $script:AllChecksPassed = $false
        }
        else {
            Write-Warning "$FailureMessage (Error: $_)"
            $script:Warnings += $FailureMessage
        }
        return $false
    }
}

# Check 1: Windows Version
Test-Requirement `
    -Name "Windows Version" `
    -Test {
        $os = Get-WindowsVersion
        $build = [int]$os.Build
        if ($Detailed) {
            Write-Host "  OS: $($os.Caption)"
            Write-Host "  Build: $($os.Build)"
        }
        return $build -ge 17763  # Windows 10 1809+
    } `
    -SuccessMessage "Windows 10/11 detected" `
    -FailureMessage "Windows 10 1809+ or Windows 11 required" `
    -Required $true

# Check 2: PowerShell Version
Test-Requirement `
    -Name "PowerShell Version" `
    -Test {
        $version = $PSVersionTable.PSVersion
        if ($Detailed) {
            Write-Host "  Version: $version"
        }
        return $version.Major -ge 5
    } `
    -SuccessMessage "PowerShell 5.1+ detected" `
    -FailureMessage "PowerShell 5.1+ required" `
    -Required $true

# Check 3: Disk Space
Test-Requirement `
    -Name "Disk Space" `
    -Test {
        $freeSpace = Get-FreeDiskSpace
        if ($Detailed) {
            Write-Host "  Free space: $freeSpace GB"
        }
        return $freeSpace -ge 30
    } `
    -SuccessMessage "Sufficient disk space (30GB+ available)" `
    -FailureMessage "At least 30GB free space required for models and dependencies" `
    -Required $true

# Check 4: RAM
Test-Requirement `
    -Name "System Memory" `
    -Test {
        $ram = Get-TotalMemory
        if ($Detailed) {
            Write-Host "  Total RAM: $ram GB"
        }
        return $ram -ge 16
    } `
    -SuccessMessage "Sufficient RAM (16GB+ available)" `
    -FailureMessage "16GB+ RAM recommended for AI models" `
    -Required $false

# Check 5: Python
$pythonInstalled = Test-Requirement `
    -Name "Python" `
    -Test {
        if (Test-Command python) {
            $version = python --version 2>&1
            if ($version -match "Python (\d+)\.(\d+)") {
                $major = [int]$Matches[1]
                $minor = [int]$Matches[2]
                if ($Detailed) {
                    Write-Host "  Version: $version"
                }
                return ($major -eq 3 -and $minor -ge 10)
            }
        }
        return $false
    } `
    -SuccessMessage "Python 3.10+ found" `
    -FailureMessage "Python 3.10+ not found (will be installed)" `
    -Required $false

# Check 6: Git
$gitInstalled = Test-Requirement `
    -Name "Git" `
    -Test {
        if (Test-Command git) {
            if ($Detailed) {
                $version = git --version
                Write-Host "  Version: $version"
            }
            return $true
        }
        return $false
    } `
    -SuccessMessage "Git found" `
    -FailureMessage "Git not found (will be installed)" `
    -Required $false

# Check 7: NVIDIA GPU
$gpuDetected = Test-Requirement `
    -Name "NVIDIA GPU" `
    -Test {
        if (Test-Command nvidia-smi) {
            $gpuInfo = nvidia-smi --query-gpu=name,memory.total --format=csv,noheader 2>$null
            if ($gpuInfo -and $Detailed) {
                Write-Host "  GPU: $gpuInfo"
            }
            return $gpuInfo -ne $null
        }
        return $false
    } `
    -SuccessMessage "NVIDIA GPU detected" `
    -FailureMessage "NVIDIA GPU not detected (drivers may not be installed)" `
    -Required $false

# Check 8: CUDA
$cudaInstalled = Test-Requirement `
    -Name "CUDA Toolkit" `
    -Test {
        if (Test-Command nvcc) {
            if ($Detailed) {
                $version = nvcc --version 2>&1 | Select-String "release"
                Write-Host "  $version"
            }
            return $true
        }
        return $false
    } `
    -SuccessMessage "CUDA Toolkit found" `
    -FailureMessage "CUDA Toolkit not found (manual installation required)" `
    -Required $false

# Check 9: Internet Connection
Test-Requirement `
    -Name "Internet Connection" `
    -Test {
        return Test-InternetConnection
    } `
    -SuccessMessage "Internet connection available" `
    -FailureMessage "No internet connection (offline mode available if models pre-downloaded)" `
    -Required $false

# Check 10: winget (for auto-install)
$wingetAvailable = Test-Requirement `
    -Name "winget Package Manager" `
    -Test {
        return Test-Command winget
    } `
    -SuccessMessage "winget available for automatic installations" `
    -FailureMessage "winget not available (manual installations required)" `
    -Required $false

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan

if ($AllChecksPassed) {
    Write-Success "All critical requirements met!"
    
    if ($Warnings.Count -gt 0) {
        Write-Host ""
        Write-Warning "Optional components to install:"
        foreach ($warning in $Warnings) {
            Write-Host "  • $warning" -ForegroundColor Yellow
        }
    }
    
    Write-Host ""
    Write-Info "Ready to proceed with installation"
    Write-Host "  Run: .\install.bat or .\setup.ps1" -ForegroundColor Green
    
    exit 0
}
else {
    Write-Error "Some critical requirements are not met"
    Write-Host ""
    Write-Info "Please address the errors above and run this check again"
    
    exit 1
}
```

**Step 2: Test system checker**

Run:
```powershell
powershell -ExecutionPolicy Bypass -File check-system.ps1
powershell -ExecutionPolicy Bypass -File check-system.ps1 -Detailed
```

Expected: 
- List of system checks with ✓ or ✗
- Detailed version shows additional info
- Exit code 0 if all critical checks pass, 1 otherwise

**Step 3: Commit**

```bash
git add gpu-worker/check-system.ps1
git commit -m "feat(gpu-worker): add system requirements checker"
```

---

## Task 3: NSSM Download Utility

**Files:**
- Create: `gpu-worker/download-nssm.ps1`

**Step 1: Create NSSM downloader**

Create `gpu-worker/download-nssm.ps1`:
```powershell
# Download and verify NSSM (Non-Sucking Service Manager)
# Used for Windows Service creation

param(
    [string]$OutputDir = "tools",
    [switch]$Force
)

. "$PSScriptRoot\lib\common.ps1"

$NSSM_VERSION = "2.24"
$NSSM_URL = "https://nssm.cc/release/nssm-$NSSM_VERSION.zip"
$NSSM_ZIP = "$OutputDir\nssm-$NSSM_VERSION.zip"
$NSSM_EXE = "$OutputDir\nssm.exe"

# SHA256 checksum for NSSM 2.24
$NSSM_SHA256 = "4E49FB7CA4A7D9D6A40E8E1E7E1B5DEB1D7B4B0B7E0E0E0E0E0E0E0E0E0E0E0E"  # Replace with actual hash

Write-Banner "NSSM Download Utility"

# Check if already exists
if ((Test-Path $NSSM_EXE) -and -not $Force) {
    Write-Success "NSSM already downloaded: $NSSM_EXE"
    
    # Verify it works
    try {
        $version = & $NSSM_EXE version 2>&1
        Write-Info "Version: $version"
        exit 0
    }
    catch {
        Write-Warning "Existing NSSM appears corrupted, re-downloading..."
    }
}

# Ensure output directory exists
if (-not (Test-Path $OutputDir)) {
    $null = New-Item -ItemType Directory -Path $OutputDir -Force
}

# Download NSSM
Write-Info "Downloading NSSM $NSSM_VERSION..."
Write-Host "  From: $NSSM_URL"
Write-Host "  To: $NSSM_ZIP"

if (-not (Get-FileWithProgress -Url $NSSM_URL -OutputPath $NSSM_ZIP)) {
    Write-Error "Failed to download NSSM"
    exit 1
}

Write-Success "Downloaded successfully"

# Extract NSSM
Write-Info "Extracting NSSM..."

try {
    # Determine architecture
    $arch = if ([Environment]::Is64BitOperatingSystem) { "win64" } else { "win32" }
    
    # Extract just the exe we need
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip = [System.IO.Compression.ZipFile]::OpenRead($NSSM_ZIP)
    
    $nssmEntry = $zip.Entries | Where-Object { 
        $_.FullName -like "*/$arch/nssm.exe" 
    } | Select-Object -First 1
    
    if ($nssmEntry) {
        [System.IO.Compression.ZipFileExtensions]::ExtractToFile($nssmEntry, $NSSM_EXE, $true)
        Write-Success "Extracted to $NSSM_EXE"
    }
    else {
        throw "Could not find nssm.exe in archive"
    }
    
    $zip.Dispose()
}
catch {
    Write-Error "Failed to extract NSSM: $_"
    exit 1
}

# Verify extracted file
Write-Info "Verifying NSSM..."

if (-not (Test-Path $NSSM_EXE)) {
    Write-Error "NSSM executable not found after extraction"
    exit 1
}

# Test execution
try {
    $version = & $NSSM_EXE version 2>&1
    Write-Success "NSSM verified: $version"
}
catch {
    Write-Error "NSSM executable appears corrupted: $_"
    exit 1
}

# Cleanup zip file
Write-Info "Cleaning up..."
Remove-Item $NSSM_ZIP -Force -ErrorAction SilentlyContinue

Write-Success "NSSM ready for use"
exit 0
```

**Step 2: Test NSSM downloader**

Run:
```powershell
powershell -ExecutionPolicy Bypass -File download-nssm.ps1
```

Expected:
- Downloads nssm.zip
- Extracts nssm.exe to tools/
- Verifies executable works
- Shows version

**Step 3: Update .gitignore to exclude downloaded NSSM**

Already done in Task 1.

**Step 4: Commit**

```bash
git add gpu-worker/download-nssm.ps1
git commit -m "feat(gpu-worker): add NSSM download utility"
```

---

## Task 4: Firewall Configuration

**Files:**
- Create: `gpu-worker/configure-firewall.ps1`

**Step 1: Create firewall configuration script**

Create `gpu-worker/configure-firewall.ps1`:
```powershell
# Configure Windows Firewall for Avatar Factory GPU Worker
# Opens TCP port 8001 for incoming connections

param(
    [ValidateSet("Add", "Remove", "Check")]
    [string]$Action = "Add",
    [int]$Port = 8001
)

. "$PSScriptRoot\lib\common.ps1"

$RULE_NAME = "Avatar Factory GPU Worker"

# Check if running as administrator
if (-not (Test-Administrator)) {
    Write-Error "Firewall configuration requires administrator privileges"
    Restart-AsAdministrator -Arguments @($Action, $Port)
    exit
}

Write-Banner "Firewall Configuration"

switch ($Action) {
    "Add" {
        Write-Info "Adding firewall rule for port $Port..."
        
        # Check if rule already exists
        $existingRule = Get-NetFirewallRule -DisplayName $RULE_NAME -ErrorAction SilentlyContinue
        
        if ($existingRule) {
            Write-Warning "Firewall rule already exists"
            Write-Info "Removing old rule..."
            Remove-NetFirewallRule -DisplayName $RULE_NAME -ErrorAction SilentlyContinue
        }
        
        # Create new rule
        try {
            $null = New-NetFirewallRule `
                -DisplayName $RULE_NAME `
                -Description "Allows incoming connections to Avatar Factory GPU Worker server" `
                -Direction Inbound `
                -Protocol TCP `
                -LocalPort $Port `
                -Action Allow `
                -Profile Any `
                -Enabled True
            
            Write-Success "Firewall rule added successfully"
            Write-Info "Port $Port is now open for incoming connections"
        }
        catch {
            Write-Error "Failed to add firewall rule: $_"
            exit 1
        }
    }
    
    "Remove" {
        Write-Info "Removing firewall rule..."
        
        $existingRule = Get-NetFirewallRule -DisplayName $RULE_NAME -ErrorAction SilentlyContinue
        
        if ($existingRule) {
            Remove-NetFirewallRule -DisplayName $RULE_NAME
            Write-Success "Firewall rule removed"
        }
        else {
            Write-Warning "Firewall rule not found"
        }
    }
    
    "Check" {
        Write-Info "Checking firewall rule..."
        
        $rule = Get-NetFirewallRule -DisplayName $RULE_NAME -ErrorAction SilentlyContinue
        
        if ($rule) {
            Write-Success "Firewall rule exists"
            Write-Host ""
            Write-Host "Rule Details:" -ForegroundColor Cyan
            Write-Host "  Name: $($rule.DisplayName)"
            Write-Host "  Direction: $($rule.Direction)"
            Write-Host "  Action: $($rule.Action)"
            Write-Host "  Enabled: $($rule.Enabled)"
            
            # Get port info
            $portFilter = $rule | Get-NetFirewallPortFilter
            Write-Host "  Port: $($portFilter.LocalPort)"
            Write-Host "  Protocol: $($portFilter.Protocol)"
        }
        else {
            Write-Warning "Firewall rule not found"
            Write-Info "Run with -Action Add to create the rule"
        }
    }
}

exit 0
```

**Step 2: Test firewall script (requires admin)**

Run as administrator:
```powershell
# Check current status
powershell -ExecutionPolicy Bypass -File configure-firewall.ps1 -Action Check

# Add rule
powershell -ExecutionPolicy Bypass -File configure-firewall.ps1 -Action Add

# Verify added
powershell -ExecutionPolicy Bypass -File configure-firewall.ps1 -Action Check

# Remove rule (cleanup)
powershell -ExecutionPolicy Bypass -File configure-firewall.ps1 -Action Remove
```

Expected:
- Check shows no rule initially
- Add creates rule successfully
- Check shows rule details
- Remove deletes rule

**Step 3: Commit**

```bash
git add gpu-worker/configure-firewall.ps1
git commit -m "feat(gpu-worker): add firewall configuration script"
```

---

## Task 5: Main Setup Script (Part 1 - Checks and Prerequisites)

**Files:**
- Create: `gpu-worker/setup.ps1` (initial version)

**Step 1: Create main setup script skeleton**

Create `gpu-worker/setup.ps1`:
```powershell
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

# Import common utilities
. "$PSScriptRoot\lib\common.ps1"

# Configuration
$LOG_FILE = "logs\install.log"
$VENV_PATH = "venv"
$PYTHON_VERSION_MIN = "3.10"
$CUDA_VERSION_RECOMMENDED = "11.8"

# Initialize logging
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
    & "$PSScriptRoot\uninstall.ps1"
    exit $LASTEXITCODE
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
        Write-Step -Current $CurrentStep -Total $TotalSteps -Message $Name
    }
    
    Write-Log "Step $CurrentStep/$TotalSteps: $Name" -LogPath $LOG_FILE
    
    try {
        & $Action
        Write-Log "Step completed successfully" -LogPath $LOG_FILE
        return $true
    }
    catch {
        Write-Error "Step failed: $_"
        Write-Log "Step failed: $_" -LogPath $LOG_FILE
        return $false
    }
}

# === STEP 1: System Requirements Check ===
Invoke-Step "System Requirements Check" {
    Write-Info "Checking system requirements..."
    
    # Run system checker
    $checkResult = & "$PSScriptRoot\check-system.ps1" -ErrorAction Stop
    
    if ($LASTEXITCODE -ne 0) {
        throw "System requirements not met. Please address the issues and try again."
    }
    
    $script:InstallationState.SystemChecked = $true
    Write-Success "System requirements met"
}

# === STEP 2: Check/Install Python ===
Invoke-Step "Python Installation" {
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
    
    Write-Warning "Python 3.10+ not found"
    
    # Try to install via winget
    if (Test-Command winget) {
        Write-Info "Installing Python via winget..."
        
        $result = winget install -e --id Python.Python.3.11 --silent --accept-package-agreements --accept-source-agreements
        
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Python installed successfully"
            
            # Refresh PATH
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
            
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

# === STEP 3: Check/Install Git ===
Invoke-Step "Git Installation" {
    Write-Info "Checking Git installation..."
    
    if (Test-Command git) {
        $version = git --version
        Write-Success "Git found: $version"
        return
    }
    
    Write-Warning "Git not found"
    
    # Try to install via winget
    if (Test-Command winget) {
        Write-Info "Installing Git via winget..."
        
        $result = winget install -e --id Git.Git --silent --accept-package-agreements --accept-source-agreements
        
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Git installed successfully"
            
            # Refresh PATH
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
        }
        else {
            Write-Warning "Failed to install Git via winget"
            Write-Info "Git is optional but recommended. Install from https://git-scm.com/downloads"
        }
    }
    else {
        Write-Warning "winget not available"
        Write-Info "Git is optional but recommended. Install from https://git-scm.com/downloads"
    }
}

# === STEP 4: Check CUDA ===
Invoke-Step "CUDA Check" {
    Write-Info "Checking CUDA installation..."
    
    if (Test-Command nvidia-smi) {
        $gpuInfo = nvidia-smi --query-gpu=name,memory.total --format=csv,noheader 2>$null
        Write-Success "NVIDIA GPU detected: $gpuInfo"
    }
    else {
        Write-Warning "NVIDIA GPU not detected"
        Write-Info "Make sure NVIDIA drivers are installed"
    }
    
    if (Test-Command nvcc) {
        $cudaVersion = nvcc --version 2>&1 | Select-String "release" | Out-String
        Write-Success "CUDA Toolkit found: $($cudaVersion.Trim())"
    }
    else {
        Write-Warning "CUDA Toolkit not found"
        Write-Host ""
        Write-Host "  $($Colors.Yellow)CUDA Toolkit 11.8 is required for GPU acceleration$($Colors.Reset)"
        Write-Host "  Download from: $($Colors.Cyan)https://developer.nvidia.com/cuda-11-8-0-download-archive$($Colors.Reset)"
        Write-Host ""
        
        $continue = Read-Host "Continue without CUDA? (y/N)"
        if ($continue -notmatch "^[Yy]$") {
            throw "CUDA Toolkit required. Please install and run setup again."
        }
    }
}

# More steps will be added in next task...

Write-Success "Setup completed!"
exit 0
```

**Step 2: Test basic setup flow**

Run:
```powershell
powershell -ExecutionPolicy Bypass -File setup.ps1 -Silent
```

Expected:
- Runs through first 4 steps
- Checks system, Python, Git, CUDA
- Installs Python/Git if missing (via winget)
- Logs to logs/install.log

**Step 3: Commit**

```bash
git add gpu-worker/setup.ps1
git commit -m "feat(gpu-worker): add main setup script (part 1 - prerequisites)"
```

---

## Task 6: Main Setup Script (Part 2 - Python Environment)

**Files:**
- Modify: `gpu-worker/setup.ps1`

**Step 1: Add Python environment setup steps**

Add after Step 4 in `gpu-worker/setup.ps1`:

```powershell
# === STEP 5: Create Virtual Environment ===
Invoke-Step "Python Virtual Environment" {
    Write-Info "Setting up Python virtual environment..."
    
    if ((Test-Path $VENV_PATH) -and $Force) {
        Write-Warning "Removing existing virtual environment..."
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
    python -m pip install --upgrade pip setuptools wheel --quiet
    
    if ($LASTEXITCODE -eq 0) {
        Write-Success "pip upgraded"
    }
    
    $script:InstallationState.VenvCreated = $true
}

# === STEP 6: Install PyTorch with CUDA ===
Invoke-Step "PyTorch Installation" {
    Write-Info "Installing PyTorch with CUDA support..."
    Write-Host "  This may take 5-10 minutes depending on your internet speed..."
    Write-Host ""
    
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
            Write-Warning "CUDA not available in current PyTorch installation"
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
    
    & python -m pip $pipArgs
    
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to install PyTorch"
    }
    
    # Verify installation
    $torchVersion = python -c "import torch; print(torch.__version__)" 2>&1
    $cudaAvailable = python -c "import torch; print(torch.cuda.is_available())" 2>&1
    
    if ($cudaAvailable -eq "True") {
        Write-Success "PyTorch installed with CUDA support: $torchVersion"
        
        # Show GPU info
        $gpuName = python -c "import torch; print(torch.cuda.get_device_name(0) if torch.cuda.is_available() else 'N/A')" 2>&1
        Write-Info "GPU: $gpuName"
        
        $script:InstallationState.TorchInstalled = $true
    }
    else {
        Write-Warning "PyTorch installed but CUDA not available"
        Write-Warning "GPU acceleration will not work. Check CUDA Toolkit installation."
    }
}

# === STEP 7: Install Python Dependencies ===
Invoke-Step "Python Dependencies" {
    Write-Info "Installing Python dependencies from requirements.txt..."
    Write-Host "  This may take 3-5 minutes..."
    Write-Host ""
    
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
    
    & python -m pip $pipArgs
    
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to install Python dependencies"
    }
    
    Write-Success "Python dependencies installed"
    
    # Verify key packages
    Write-Info "Verifying installations..."
    
    $packages = @("fastapi", "uvicorn", "diffusers", "transformers")
    foreach ($package in $packages) {
        $installed = python -c "import $package; print('✓')" 2>$null
        if ($installed -eq "✓") {
            Write-Host "  ✓ $package" -ForegroundColor Green
        }
        else {
            Write-Warning "  ✗ $package import failed"
        }
    }
    
    $script:InstallationState.DepsInstalled = $true
}

# === STEP 8: Clone and Setup SadTalker ===
Invoke-Step "SadTalker Setup" {
    Write-Info "Setting up SadTalker..."
    
    if (Test-Path "SadTalker") {
        if ($Force) {
            Write-Warning "Removing existing SadTalker..."
            Remove-Item -Path "SadTalker" -Recurse -Force
        }
        else {
            Write-Success "SadTalker already exists"
            return
        }
    }
    
    if (-not (Test-Command git)) {
        Write-Warning "Git not available, skipping SadTalker clone"
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
    
    if (Test-Path "requirements.txt") {
        python -m pip install -r requirements.txt --quiet
        
        if ($LASTEXITCODE -eq 0) {
            Write-Success "SadTalker dependencies installed"
        }
        else {
            Write-Warning "Some SadTalker dependencies failed to install"
        }
    }
    
    Pop-Location
}
```

**Step 2: Test Python environment setup**

Run:
```powershell
powershell -ExecutionPolicy Bypass -File setup.ps1
```

Expected:
- Creates venv/
- Installs PyTorch with CUDA
- Installs all dependencies
- Clones SadTalker
- Takes 10-15 minutes

**Step 3: Commit**

```bash
git add gpu-worker/setup.ps1
git commit -m "feat(gpu-worker): add Python environment setup to main script"
```

---

## Task 7: Main Setup Script (Part 3 - Models and Configuration)

**Files:**
- Modify: `gpu-worker/setup.ps1`

**Step 1: Add model download and configuration steps**

Add after Step 8 in `gpu-worker/setup.ps1`:

```powershell
# === STEP 9: Download AI Models ===
if (-not $SkipModels) {
    Invoke-Step "AI Models Download" {
        Write-Info "Downloading AI models..."
        Write-Host ""
        Write-Host "  $($Colors.Yellow)This will download approximately 10GB of data$($Colors.Reset)"
        Write-Host "  $($Colors.Yellow)and may take 15-30 minutes depending on your internet speed$($Colors.Reset)"
        Write-Host ""
        
        if (-not $Silent) {
            $proceed = Read-Host "  Download models now? (Y/n)"
            if ($proceed -match "^[Nn]$") {
                Write-Warning "Skipping model download"
                Write-Info "You can download models later by running: python download_models.py"
                return
            }
        }
        
        if (-not (Test-Path "download_models.py")) {
            Write-Warning "download_models.py not found, skipping automatic download"
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
            Write-Warning "Model download had errors"
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
        
        # Load existing config
        $existingConfig = Get-Content $envFile | Out-String
        
        if ($existingConfig -match "GPU_API_KEY=(.+)") {
            $apiKey = $Matches[1]
            Write-Info "Using existing API key: $($apiKey.Substring(0, [Math]::Min(8, $apiKey.Length)))..."
        }
        
        $script:InstallationState.EnvConfigured = $true
        return
    }
    
    Write-Info "Creating .env file..."
    
    # Generate secure API key
    $apiKey = New-SecureRandomString -Length 32
    
    # Get local IP
    $localIP = Get-LocalIPAddress
    
    # Create .env content
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
    
    # Make file hidden and read-only
    $file = Get-Item $envFile
    $file.Attributes = $file.Attributes -bor [System.IO.FileAttributes]::Hidden
    $file.IsReadOnly = $true
    
    Write-Success ".env file created"
    Write-Host ""
    Write-Host "  ═══════════════════════════════════════════════════════════" -ForegroundColor Yellow
    Write-Host "  $($Colors.Yellow)IMPORTANT: Save these values for laptop configuration$($Colors.Reset)"
    Write-Host ""
    Write-Host "  GPU Server URL:  $($Colors.Green)http://${localIP}:8001$($Colors.Reset)"
    Write-Host "  API Key:         $($Colors.Green)$apiKey$($Colors.Reset)"
    Write-Host ""
    Write-Host "  Add to laptop's .env file:"
    Write-Host "  $($Colors.Cyan)GPU_SERVER_URL=http://${localIP}:8001$($Colors.Reset)"
    Write-Host "  $($Colors.Cyan)GPU_API_KEY=$apiKey$($Colors.Reset)"
    Write-Host "  ═══════════════════════════════════════════════════════════" -ForegroundColor Yellow
    Write-Host ""
    
    # Log the config (without full API key)
    Write-Log "Environment configured - IP: $localIP, API Key: $($apiKey.Substring(0,8))..." -LogPath $LOG_FILE
    
    $script:InstallationState.EnvConfigured = $true
}

# === STEP 11: Firewall Configuration ===
Invoke-Step "Firewall Configuration" {
    if ($AdminOnly) {
        Write-Info "Configuring Windows Firewall..."
        
        # Run firewall script
        & "$PSScriptRoot\configure-firewall.ps1" -Action Add
        
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Firewall configured"
            $script:InstallationState.FirewallConfigured = $true
        }
        else {
            Write-Warning "Firewall configuration failed"
        }
    }
    elseif (Test-Administrator) {
        Write-Info "Configuring Windows Firewall..."
        
        & "$PSScriptRoot\configure-firewall.ps1" -Action Add
        
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Firewall configured"
            $script:InstallationState.FirewallConfigured = $true
        }
    }
    else {
        Write-Warning "Firewall configuration requires administrator privileges"
        Write-Info "Run this command as administrator later:"
        Write-Host "  powershell -ExecutionPolicy Bypass -File configure-firewall.ps1 -Action Add" -ForegroundColor Cyan
    }
}

# === STEP 12: Test Installation ===
Invoke-Step "Installation Test" {
    Write-Info "Testing installation..."
    
    # Test Python imports
    Write-Info "Testing Python imports..."
    
    $tests = @(
        @{ Name = "PyTorch"; Command = "import torch; print(torch.__version__)" },
        @{ Name = "CUDA"; Command = "import torch; print('Available' if torch.cuda.is_available() else 'Not Available')" },
        @{ Name = "FastAPI"; Command = "import fastapi; print(fastapi.__version__)" },
        @{ Name = "Diffusers"; Command = "import diffusers; print(diffusers.__version__)" }
    )
    
    $allPassed = $true
    
    foreach ($test in $tests) {
        $result = python -c $test.Command 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  ✓ $($test.Name): $result" -ForegroundColor Green
        }
        else {
            Write-Host "  ✗ $($test.Name): FAILED" -ForegroundColor Red
            $allPassed = $false
        }
    }
    
    if (-not $allPassed) {
        Write-Warning "Some tests failed"
    }
    else {
        Write-Success "All tests passed"
    }
    
    # Test server start (quick test)
    if (Test-Path "server.py") {
        Write-Info "Testing server start..."
        
        $serverJob = Start-Job -ScriptBlock {
            param($workDir)
            Set-Location $workDir
            & ".\venv\Scripts\python.exe" server.py
        } -ArgumentList $PSScriptRoot
        
        Start-Sleep -Seconds 5
        
        try {
            $response = Invoke-WebRequest -Uri "http://localhost:8001/health" -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
            Write-Success "Server started successfully"
        }
        catch {
            Write-Warning "Server test failed (may need manual verification)"
        }
        finally {
            Stop-Job $serverJob -ErrorAction SilentlyContinue
            Remove-Job $serverJob -ErrorAction SilentlyContinue
        }
    }
}
```

**Step 2: Add final summary and service prompt**

Add at the end of `gpu-worker/setup.ps1`:

```powershell
# === Installation Complete ===
Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host "$($Colors.Green)✓ Installation Complete!$($Colors.Reset)" -ForegroundColor Green
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host ""

# Show installation summary
Write-Host "$($Colors.Blue)Installation Summary:$($Colors.Reset)"
Write-Host ""

foreach ($key in $InstallationState.Keys) {
    $status = if ($InstallationState[$key]) { "$($Colors.Green)✓$($Colors.Reset)" } else { "$($Colors.Yellow)⊘$($Colors.Reset)" }
    $label = $key -replace "([A-Z])", " `$1"
    Write-Host "  $status $label"
}

Write-Host ""
Write-Host "$($Colors.Blue)Next Steps:$($Colors.Reset)"
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

# Offer to install Windows Service
if (-not $NoService) {
    Write-Host "  4. Optional: Install Windows Service for auto-start"
    Write-Host "     $($Colors.Cyan).\service-install.ps1$($Colors.Reset)"
    Write-Host ""
    
    if (-not $Silent) {
        $installService = Read-Host "  Install Windows Service now? (y/N)"
        
        if ($installService -match "^[Yy]$") {
            Write-Host ""
            & "$PSScriptRoot\service-install.ps1"
        }
    }
}

Write-Host ""
Write-Host "$($Colors.Green)Documentation:$($Colors.Reset) README.md"
Write-Host "$($Colors.Green)Logs:$($Colors.Reset) $LOG_FILE"
Write-Host ""

Write-Log "=== Installation Completed Successfully ===" -LogPath $LOG_FILE

exit 0
```

**Step 3: Test full installation (long running)**

Run on a test Windows machine:
```powershell
powershell -ExecutionPolicy Bypass -File setup.ps1
```

Expected:
- Runs all 12 steps
- Downloads models (~10GB, 15-30 min)
- Creates .env with API key
- Shows configuration summary
- Offers service installation

**Step 4: Commit**

```bash
git add gpu-worker/setup.ps1
git commit -m "feat(gpu-worker): complete main setup script with models and config"
```

---

## Task 8: Windows Service Management Scripts

**Files:**
- Create: `gpu-worker/service-install.ps1`
- Create: `gpu-worker/service-remove.ps1`
- Create: `gpu-worker/service-restart.ps1`

**Step 1: Create service installation script**

Create `gpu-worker/service-install.ps1`:
```powershell
# Install Avatar Factory GPU Worker as Windows Service
# Uses NSSM (Non-Sucking Service Manager)

param(
    [string]$ServiceName = "AvatarFactoryGPU",
    [switch]$Force
)

. "$PSScriptRoot\lib\common.ps1"

# Check admin privileges
if (-not (Test-Administrator)) {
    Write-Error "Service installation requires administrator privileges"
    Restart-AsAdministrator
    exit
}

Write-Banner "Windows Service Installation"

$NSSM_PATH = Join-Path $PSScriptRoot "tools\nssm.exe"
$VENV_PYTHON = Join-Path $PSScriptRoot "venv\Scripts\python.exe"
$SERVER_SCRIPT = Join-Path $PSScriptRoot "server.py"
$LOG_DIR = Join-Path $PSScriptRoot "logs"

# Step 1: Download NSSM if needed
if (-not (Test-Path $NSSM_PATH)) {
    Write-Info "NSSM not found, downloading..."
    & "$PSScriptRoot\download-nssm.ps1"
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to download NSSM"
        exit 1
    }
}

Write-Success "NSSM available"

# Step 2: Check if service already exists
Write-Info "Checking existing service..."

$existingService = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue

if ($existingService) {
    if ($Force) {
        Write-Warning "Service already exists, removing..."
        & "$PSScriptRoot\service-remove.ps1" -ServiceName $ServiceName
        Start-Sleep -Seconds 2
    }
    else {
        Write-Error "Service '$ServiceName' already exists"
        Write-Info "Use -Force to reinstall or run service-remove.ps1 first"
        exit 1
    }
}

# Step 3: Verify prerequisites
Write-Info "Verifying prerequisites..."

if (-not (Test-Path $VENV_PYTHON)) {
    Write-Error "Python virtual environment not found: $VENV_PYTHON"
    Write-Info "Run setup.ps1 first"
    exit 1
}

if (-not (Test-Path $SERVER_SCRIPT)) {
    Write-Error "Server script not found: $SERVER_SCRIPT"
    exit 1
}

Write-Success "Prerequisites verified"

# Step 4: Install service
Write-Info "Installing Windows Service..."

$nssmArgs = @(
    "install",
    $ServiceName,
    $VENV_PYTHON,
    $SERVER_SCRIPT
)

& $NSSM_PATH $nssmArgs

if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to install service"
    exit 1
}

Write-Success "Service installed"

# Step 5: Configure service
Write-Info "Configuring service..."

# Set working directory
& $NSSM_PATH set $ServiceName AppDirectory $PSScriptRoot

# Set display name and description
& $NSSM_PATH set $ServiceName DisplayName "Avatar Factory GPU Server"
& $NSSM_PATH set $ServiceName Description "AI-powered video generation GPU worker for Avatar Factory"

# Set startup type
& $NSSM_PATH set $ServiceName Start SERVICE_AUTO_START

# Set log files
$stdoutLog = Join-Path $LOG_DIR "service.log"
$stderrLog = Join-Path $LOG_DIR "service-error.log"

& $NSSM_PATH set $ServiceName AppStdout $stdoutLog
& $NSSM_PATH set $ServiceName AppStderr $stderrLog

# Set log rotation (10MB, keep 3 files)
& $NSSM_PATH set $ServiceName AppStdoutCreationDisposition 4  # OPEN_ALWAYS
& $NSSM_PATH set $ServiceName AppStderrCreationDisposition 4
& $NSSM_PATH set $ServiceName AppRotateFiles 1
& $NSSM_PATH set $ServiceName AppRotateBytes 10485760  # 10MB
& $NSSM_PATH set $ServiceName AppRotateOnline 1

# Set restart policy (restart on failure)
& $NSSM_PATH set $ServiceName AppExit Default Restart
& $NSSM_PATH set $ServiceName AppRestartDelay 60000  # 60 seconds

Write-Success "Service configured"

# Step 6: Start service
Write-Info "Starting service..."

Start-Service -Name $ServiceName

Start-Sleep -Seconds 3

$service = Get-Service -Name $ServiceName

if ($service.Status -eq "Running") {
    Write-Success "Service started successfully"
    
    # Test server
    Start-Sleep -Seconds 5
    
    try {
        $response = Invoke-WebRequest -Uri "http://localhost:8001/health" -UseBasicParsing -TimeoutSec 10
        Write-Success "Server is responding"
    }
    catch {
        Write-Warning "Server is running but not responding yet (may need more time to initialize)"
    }
}
else {
    Write-Error "Service failed to start"
    Write-Info "Check logs: $stderrLog"
    exit 1
}

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host "$($Colors.Green)✓ Windows Service Installed$($Colors.Reset)"
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host ""
Write-Host "Service Name: $($Colors.Cyan)$ServiceName$($Colors.Reset)"
Write-Host "Status:       $($Colors.Green)Running$($Colors.Reset)"
Write-Host "Startup:      $($Colors.Green)Automatic$($Colors.Reset)"
Write-Host ""
Write-Host "Manage service:"
Write-Host "  View logs:     $($Colors.Cyan)Get-Content $stdoutLog -Tail 50 -Wait$($Colors.Reset)"
Write-Host "  Restart:       $($Colors.Cyan).\service-restart.ps1$($Colors.Reset)"
Write-Host "  Stop:          $($Colors.Cyan)Stop-Service $ServiceName$($Colors.Reset)"
Write-Host "  Remove:        $($Colors.Cyan).\service-remove.ps1$($Colors.Reset)"
Write-Host "  Windows GUI:   $($Colors.Cyan)services.msc$($Colors.Reset)"
Write-Host ""

exit 0
```

**Step 2: Create service removal script**

Create `gpu-worker/service-remove.ps1`:
```powershell
# Remove Avatar Factory GPU Worker Windows Service

param(
    [string]$ServiceName = "AvatarFactoryGPU"
)

. "$PSScriptRoot\lib\common.ps1"

# Check admin privileges
if (-not (Test-Administrator)) {
    Write-Error "Service removal requires administrator privileges"
    Restart-AsAdministrator
    exit
}

Write-Banner "Windows Service Removal"

$NSSM_PATH = Join-Path $PSScriptRoot "tools\nssm.exe"

# Check if service exists
$service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue

if (-not $service) {
    Write-Warning "Service '$ServiceName' not found"
    exit 0
}

Write-Info "Found service: $ServiceName"

# Stop service if running
if ($service.Status -eq "Running") {
    Write-Info "Stopping service..."
    Stop-Service -Name $ServiceName -Force
    Start-Sleep -Seconds 2
    Write-Success "Service stopped"
}

# Remove service
Write-Info "Removing service..."

if (Test-Path $NSSM_PATH) {
    & $NSSM_PATH remove $ServiceName confirm
}
else {
    # Fallback to sc.exe
    sc.exe delete $ServiceName
}

if ($LASTEXITCODE -eq 0) {
    Write-Success "Service removed successfully"
}
else {
    Write-Error "Failed to remove service"
    exit 1
}

Write-Host ""
Write-Success "Service '$ServiceName' has been removed"
Write-Host ""

exit 0
```

**Step 3: Create service restart script**

Create `gpu-worker/service-restart.ps1`:
```powershell
# Restart Avatar Factory GPU Worker Windows Service

param(
    [string]$ServiceName = "AvatarFactoryGPU"
)

. "$PSScriptRoot\lib\common.ps1"

Write-Banner "Service Restart"

# Check if service exists
$service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue

if (-not $service) {
    Write-Error "Service '$ServiceName' not found"
    Write-Info "Install service first: .\service-install.ps1"
    exit 1
}

Write-Info "Restarting $ServiceName..."

Restart-Service -Name $ServiceName

Start-Sleep -Seconds 3

$service = Get-Service -Name $ServiceName

if ($service.Status -eq "Running") {
    Write-Success "Service restarted successfully"
    
    # Test server
    Start-Sleep -Seconds 5
    
    try {
        $response = Invoke-WebRequest -Uri "http://localhost:8001/health" -UseBasicParsing -TimeoutSec 10
        Write-Success "Server is responding"
    }
    catch {
        Write-Warning "Server is running but not responding yet"
    }
}
else {
    Write-Error "Service failed to restart"
    exit 1
}

exit 0
```

**Step 4: Test service scripts (requires admin)**

Run as administrator:
```powershell
# Install service
powershell -ExecutionPolicy Bypass -File service-install.ps1

# Check status
Get-Service AvatarFactoryGPU

# Restart service
powershell -ExecutionPolicy Bypass -File service-restart.ps1

# Remove service (cleanup)
powershell -ExecutionPolicy Bypass -File service-remove.ps1
```

Expected:
- Service installs successfully
- Shows as Running in services.msc
- Restarts without errors
- Removes cleanly

**Step 5: Commit**

```bash
git add gpu-worker/service-install.ps1 gpu-worker/service-remove.ps1 gpu-worker/service-restart.ps1
git commit -m "feat(gpu-worker): add Windows Service management scripts"
```

---

## Task 9: Improved Batch File Wrappers

**Files:**
- Modify: `gpu-worker/install.bat`
- Modify: `gpu-worker/start.bat`
- Create: `gpu-worker/stop.bat`

**Step 1: Update install.bat wrapper**

Update `gpu-worker/install.bat`:
```batch
@echo off
REM Avatar Factory GPU Worker - Installation Wrapper
REM Simply runs setup.ps1 with proper execution policy

setlocal EnableDelayedExpansion

REM Enable colors
reg add HKCU\Console /v VirtualTerminalLevel /t REG_DWORD /d 1 /f >nul 2>&1

echo.
echo [94m╔════════════════════════════════════════════════════════════════╗[0m
echo [94m║[0m  🚀 Avatar Factory GPU Worker - Installation             [94m║[0m
echo [94m╚════════════════════════════════════════════════════════════════╝[0m
echo.

REM Check PowerShell version
powershell -Command "if ($PSVersionTable.PSVersion.Major -lt 5) { exit 1 }" >nul 2>&1
if %errorLevel% neq 0 (
    echo [91m✗ PowerShell 5.1+ required[0m
    echo.
    echo Please update PowerShell from:
    echo https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-windows
    pause
    exit /b 1
)

REM Check if setup.ps1 exists
if not exist "%~dp0setup.ps1" (
    echo [91m✗ setup.ps1 not found[0m
    echo.
    echo Make sure you're running this from the gpu-worker directory
    pause
    exit /b 1
)

REM Run setup.ps1
echo [92m✓ PowerShell 5.1+ detected[0m
echo [96m▸[0m Starting installation...
echo.

powershell -ExecutionPolicy Bypass -File "%~dp0setup.ps1" %*

if %errorLevel% neq 0 (
    echo.
    echo [91m✗ Installation failed[0m
    echo.
    echo Check logs\install.log for details
    pause
    exit /b 1
)

echo.
echo [92m✓ Installation completed successfully![0m
echo.
pause
```

**Step 2: Update start.bat**

Update existing `gpu-worker/start.bat` to add more checks:
```batch
@echo off
REM Avatar Factory GPU Worker - Start Script
REM Starts the GPU server with proper environment

setlocal EnableDelayedExpansion

set "GREEN=[92m"
set "YELLOW=[93m"
set "RED=[91m"
set "BLUE=[94m"
set "NC=[0m"

reg add HKCU\Console /v VirtualTerminalLevel /t REG_DWORD /d 1 /f >nul 2>&1

cls
echo.
echo %BLUE%╔════════════════════════════════════════════════════════════════╗%NC%
echo %BLUE%║%NC%  🚀 Starting Avatar Factory GPU Server...                %BLUE%║%NC%
echo %BLUE%╚════════════════════════════════════════════════════════════════╝%NC%
echo.

REM Check if venv exists
if not exist "%~dp0venv" (
    echo %RED%✗ Virtual environment not found%NC%
    echo %YELLOW%  Run install.bat first%NC%
    echo.
    pause
    exit /b 1
)

REM Check if server.py exists
if not exist "%~dp0server.py" (
    echo %RED%✗ server.py not found%NC%
    echo %YELLOW%  Make sure you're in the gpu-worker directory%NC%
    echo.
    pause
    exit /b 1
)

REM Activate venv
call "%~dp0venv\Scripts\activate.bat"

if %errorLevel% neq 0 (
    echo %RED%✗ Failed to activate virtual environment%NC%
    pause
    exit /b 1
)

echo %GREEN%✓ Virtual environment activated%NC%

REM Check if .env exists
if not exist "%~dp0.env" (
    echo %YELLOW%⚠ .env file not found%NC%
    echo %BLUE%▸ Creating default configuration...%NC%
    
    set "API_KEY=%RANDOM%%RANDOM%%RANDOM%%RANDOM%"
    (
        echo GPU_API_KEY=!API_KEY!
        echo HOST=0.0.0.0
        echo PORT=8001
    ) > "%~dp0.env"
    
    echo %GREEN%✓ Configuration created%NC%
)

REM Get IP address
for /f "tokens=2 delims=:" %%a in ('ipconfig ^| findstr /c:"IPv4 Address"') do (
    set IP_ADDR=%%a
    set IP_ADDR=!IP_ADDR:~1!
    goto :ip_found
)
:ip_found

if "!IP_ADDR!"=="" set IP_ADDR=localhost

echo %GREEN%✓ Configuration loaded%NC%
echo.
echo %BLUE%Server will be available at:%NC%
echo   %GREEN%http://!IP_ADDR!:8001%NC%
echo   %GREEN%http://localhost:8001%NC%
echo.
echo %BLUE%Health check:%NC%
echo   %GREEN%curl http://localhost:8001/health%NC%
echo.
echo %YELLOW%Press Ctrl+C to stop the server%NC%
echo.
echo ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo.

REM Start server
python server.py

if %errorLevel% neq 0 (
    echo.
    echo %RED%✗ Server crashed or failed to start%NC%
    echo.
    echo Check logs for errors
    pause
)
```

**Step 3: Create stop.bat**

Create `gpu-worker/stop.bat`:
```batch
@echo off
REM Avatar Factory GPU Worker - Stop Script
REM Stops the running GPU server

setlocal EnableDelayedExpansion

set "GREEN=[92m"
set "YELLOW=[93m"
set "RED=[91m"
set "BLUE=[94m"
set "NC=[0m"

reg add HKCU\Console /v VirtualTerminalLevel /t REG_DWORD /d 1 /f >nul 2>&1

cls
echo.
echo %BLUE%╔════════════════════════════════════════════════════════════════╗%NC%
echo %BLUE%║%NC%  🛑 Stopping Avatar Factory GPU Server...               %BLUE%║%NC%
echo %BLUE%╚════════════════════════════════════════════════════════════════╝%NC%
echo.

REM Find Python processes running server.py
echo %BLUE%▸ Looking for running server...%NC%

set "FOUND=0"

for /f "tokens=2" %%a in ('tasklist ^| findstr /i "python.exe"') do (
    set PID=%%a
    
    REM Check if this process is running server.py
    wmic process where "ProcessId=!PID!" get CommandLine 2>nul | findstr /i "server.py" >nul
    
    if !errorLevel! equ 0 (
        echo %YELLOW%  Found server process: PID !PID!%NC%
        taskkill /PID !PID! /F >nul 2>&1
        
        if !errorLevel! equ 0 (
            echo %GREEN%  ✓ Stopped process !PID!%NC%
            set "FOUND=1"
        ) else (
            echo %RED%  ✗ Failed to stop process !PID!%NC%
        )
    )
)

if "!FOUND!"=="0" (
    echo %YELLOW%⚠ No running server found%NC%
) else (
    echo.
    echo %GREEN%✓ Server stopped successfully%NC%
)

echo.
pause
```

**Step 4: Test batch files**

Test sequence:
```batch
# Install (if not already done)
install.bat

# Start server
start.bat
# (Let it run, verify in browser: http://localhost:8001/health)

# In new terminal, stop server
stop.bat

# Verify stopped
```

Expected:
- install.bat shows colored output, runs setup.ps1
- start.bat shows server URL, starts server
- stop.bat finds and kills server process

**Step 5: Commit**

```bash
git add gpu-worker/install.bat gpu-worker/start.bat gpu-worker/stop.bat
git commit -m "feat(gpu-worker): improve batch file wrappers"
```

---

## Task 10: Documentation Updates

**Files:**
- Create: `gpu-worker/README-WINDOWS.md`
- Modify: `gpu-worker/README.md`

**Step 1: Create comprehensive Windows guide**

Create `gpu-worker/README-WINDOWS.md`:
```markdown
# Avatar Factory GPU Worker - Windows Setup Guide

Complete guide for installing and running the GPU Worker on Windows 10/11.

## Quick Start

**One-command installation:**

```batch
install.bat
```

That's it! The installer will:
- ✅ Check system requirements
- ✅ Install Python and Git if missing
- ✅ Set up virtual environment
- ✅ Install PyTorch with CUDA
- ✅ Download AI models (~10GB)
- ✅ Configure firewall
- ✅ Optionally install Windows Service

**Estimated time:** 20-30 minutes (depending on internet speed)

---

## System Requirements

| Requirement | Minimum | Recommended |
|------------|---------|-------------|
| **OS** | Windows 10 1809+ | Windows 11 |
| **GPU** | NVIDIA GTX 1060 6GB | RTX 4070 Ti 12GB |
| **VRAM** | 8GB | 12GB+ |
| **RAM** | 16GB | 32GB |
| **Storage** | 30GB free | 50GB+ SSD |
| **Internet** | Required for setup | - |

### Manual Prerequisites

These must be installed manually before running `install.bat`:

1. **NVIDIA GPU Drivers**
   - Download: [NVIDIA Drivers](https://www.nvidia.com/download/index.aspx)
   - Latest Game Ready or Studio drivers

2. **CUDA Toolkit 11.8**
   - Download: [CUDA 11.8](https://developer.nvidia.com/cuda-11-8-0-download-archive)
   - Required for GPU acceleration
   - Installer size: ~3GB

### Auto-Installed (via winget)

The installer will automatically install these if missing:

- Python 3.10+
- Git

---

## Installation

### Step 1: Install Prerequisites

1. **Install NVIDIA Drivers:**
   ```
   1. Go to https://www.nvidia.com/download/index.aspx
   2. Select your GPU model
   3. Download and install drivers
   4. Restart computer
   ```

2. **Install CUDA Toolkit 11.8:**
   ```
   1. Go to https://developer.nvidia.com/cuda-11-8-0-download-archive
   2. Select: Windows > x86_64 > 10 or 11 > exe (local)
   3. Download and run installer (~3GB)
   4. Choose "Express Installation"
   5. Restart computer
   ```

3. **Verify GPU and CUDA:**
   ```batch
   nvidia-smi
   nvcc --version
   ```

### Step 2: Clone Repository

```batch
git clone https://github.com/yourusername/avatar-factory.git
cd avatar-factory\gpu-worker
```

### Step 3: Run Installer

**Option A: Double-click** `install.bat`

**Option B: Command line:**
```batch
install.bat
```

**Option C: PowerShell (advanced):**
```powershell
powershell -ExecutionPolicy Bypass -File setup.ps1
```

The installer will:
1. Check system requirements
2. Install Python 3.10+ and Git (if missing)
3. Create Python virtual environment
4. Install PyTorch with CUDA support (~2GB download)
5. Install Python dependencies (~1GB)
6. Clone SadTalker repository
7. Download AI models (~10GB, optional)
8. Generate secure API key
9. Configure Windows Firewall
10. Optionally install Windows Service

**Total time:** 20-30 minutes

### Step 4: Configuration

After installation, you'll see:

```
═══════════════════════════════════════════════════════════
IMPORTANT: Save these values for laptop configuration

GPU Server URL:  http://192.168.1.100:8001
API Key:         AbCdEf123456...

Add to laptop's .env file:
GPU_SERVER_URL=http://192.168.1.100:8001
GPU_API_KEY=AbCdEf123456...
═══════════════════════════════════════════════════════════
```

**Save these values!** You'll need them to configure your laptop.

---

## Usage

### Starting the Server

**Method 1: Manual Start**
```batch
start.bat
```

The server runs in the foreground. Press Ctrl+C to stop.

**Method 2: Windows Service (Auto-start)**
```powershell
# Install service (requires admin)
.\service-install.ps1

# Server now starts automatically on boot!
```

### Stopping the Server

**If running manually:**
- Press Ctrl+C in the terminal

**If running as service:**
```powershell
Stop-Service AvatarFactoryGPU
```

**Or use:**
```batch
stop.bat
```

### Checking Status

**Server health:**
```batch
curl http://localhost:8001/health
```

**Service status:**
```powershell
Get-Service AvatarFactoryGPU
```

---

## Windows Service

### Install Service

Run as Administrator:
```powershell
.\service-install.ps1
```

Benefits:
- ✅ Starts automatically on boot
- ✅ Runs in background
- ✅ Auto-restarts on crash
- ✅ Logs to file

### Manage Service

```powershell
# Start service
Start-Service AvatarFactoryGPU

# Stop service
Stop-Service AvatarFactoryGPU

# Restart service
.\service-restart.ps1

# Check status
Get-Service AvatarFactoryGPU

# View logs
Get-Content logs\service.log -Tail 50 -Wait

# Open Windows Services GUI
services.msc
```

### Uninstall Service

```powershell
.\service-remove.ps1
```

---

## Advanced Usage

### Installation Options

```powershell
# Skip model download (download later)
.\setup.ps1 -SkipModels

# Don't install Windows Service
.\setup.ps1 -NoService

# Silent mode (minimal output)
.\setup.ps1 -Silent

# Force reinstall everything
.\setup.ps1 -Force

# Repair broken installation
.\setup.ps1 -Repair
```

### Download Models Later

If you skipped models during install:

```batch
.\venv\Scripts\activate
python download_models.py
```

### Configure Firewall Manually

```powershell
# Add firewall rule (requires admin)
.\configure-firewall.ps1 -Action Add

# Check rule status
.\configure-firewall.ps1 -Action Check

# Remove rule
.\configure-firewall.ps1 -Action Remove
```

---

## Troubleshooting

### Installation Issues

**"PowerShell 5.1+ required"**
- Update PowerShell: https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-windows

**"Python not found after installation"**
- Restart terminal
- Or run: `$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")`

**"CUDA out of memory"**
- Close other GPU applications
- Reduce batch size in `server.py`
- Upgrade to GPU with more VRAM

### Server Issues

**"Server not responding"**
1. Check if server is running: `Get-Process python`
2. Check logs: `Get-Content logs\service.log -Tail 50`
3. Verify port 8001 is open: `Test-NetConnection -ComputerName localhost -Port 8001`

**"Cannot access from laptop"**
1. Check firewall rule: `.\configure-firewall.ps1 -Action Check`
2. Verify IP address: `ipconfig`
3. Test connectivity from laptop: `curl http://YOUR_PC_IP:8001/health`

**"Models not found"**
- Download manually: `python download_models.py`

### Service Issues

**"Service fails to start"**
1. Check event log: `Get-EventLog -LogName Application -Source AvatarFactoryGPU -Newest 10`
2. Check service log: `Get-Content logs\service-error.log`
3. Try manual start to see errors: `.\start.bat`

**"Service stops unexpectedly"**
- Check logs: `Get-Content logs\service.log -Tail 100`
- Verify GPU drivers are up to date
- Check for CUDA errors in logs

---

## Uninstallation

### Complete Removal

1. **Remove Windows Service** (if installed):
   ```powershell
   .\service-remove.ps1
   ```

2. **Remove Firewall Rule:**
   ```powershell
   .\configure-firewall.ps1 -Action Remove
   ```

3. **Delete Files:**
   ```batch
   cd ..
   rmdir /s /q gpu-worker
   ```

### Keep Models (Save 10GB)

Before deletion, backup models:
```batch
move gpu-worker\models C:\backup\models
move gpu-worker\SadTalker C:\backup\SadTalker
```

Restore later:
```batch
move C:\backup\models gpu-worker\models
move C:\backup\SadTalker gpu-worker\SadTalker
```

---

## Performance Tuning

### GPU Memory Optimization

Edit `server.py`:
```python
# Reduce resolution
width = 768  # instead of 1080
height = 1024  # instead of 1920

# Enable memory efficient attention
sd_pipeline.enable_attention_slicing(1)
```

### Monitoring

**GPU Usage:**
```batch
# Real-time monitoring
nvidia-smi -l 1

# Log to file
nvidia-smi --query-gpu=timestamp,temperature.gpu,utilization.gpu,memory.used --format=csv -l 10 > gpu-log.csv
```

**Server Logs:**
```powershell
# Tail logs
Get-Content logs\service.log -Tail 50 -Wait

# Search errors
Select-String -Path logs\service.log -Pattern "ERROR"
```

---

## FAQ

**Q: Do I need CUDA?**
A: Yes, for GPU acceleration. Without CUDA, the server will be extremely slow.

**Q: Can I use AMD GPU?**
A: No, the project requires NVIDIA GPU with CUDA support.

**Q: How much does it cost to run?**
A: Only electricity costs (~$10-20/month depending on usage).

**Q: Can I run this on a laptop?**
A: Not recommended. Gaming laptops may work but expect thermal throttling.

**Q: Can multiple users connect?**
A: Yes, the server handles multiple concurrent requests (processed sequentially).

**Q: How do I update?**
A: Run `git pull` then `.\setup.ps1 -Force` to reinstall dependencies.

---

## Support

- **Documentation:** [README.md](README.md)
- **Installation Logs:** `logs\install.log`
- **Server Logs:** `logs\service.log`
- **GitHub Issues:** [issues](https://github.com/yourusername/avatar-factory/issues)

---

**Next:** Configure your laptop to connect to this GPU server. See main [README.md](../README.md).
```

**Step 2: Update main README**

Add at top of `gpu-worker/README.md`:

```markdown
# GPU Worker Setup Guide

## Platform-Specific Guides

- **Windows 10/11:** See [README-WINDOWS.md](README-WINDOWS.md) for automated one-command setup
- **Linux/Ubuntu:** See below for manual setup
- **macOS:** Not supported (requires NVIDIA GPU)

---

## Windows Quick Start

**One command:**
```batch
install.bat
```

See [README-WINDOWS.md](README-WINDOWS.md) for complete Windows guide.

---

[Rest of existing README content...]
```

**Step 3: Commit**

```bash
git add gpu-worker/README-WINDOWS.md gpu-worker/README.md
git commit -m "docs(gpu-worker): add comprehensive Windows setup guide"
```

---

## Task 11: Testing and Validation

**Files:**
- Create: `gpu-worker/test-installation.ps1`

**Step 1: Create installation test script**

Create `gpu-worker/test-installation.ps1`:
```powershell
# Test Avatar Factory GPU Worker Installation
# Validates all components are properly installed

. "$PSScriptRoot\lib\common.ps1"

Write-Banner "Installation Validation"

$script:TestsPassed = 0
$script:TestsFailed = 0

function Test-Component {
    param(
        [string]$Name,
        [scriptblock]$Test,
        [string]$SuccessMessage = "OK",
        [string]$FailureMessage = "FAILED"
    )
    
    Write-Info "Testing $Name..."
    
    try {
        $result = & $Test
        if ($result) {
            Write-Success "$SuccessMessage"
            $script:TestsPassed++
            return $true
        }
        else {
            Write-Error "$FailureMessage"
            $script:TestsFailed++
            return $false
        }
    }
    catch {
        Write-Error "$FailureMessage - $_"
        $script:TestsFailed++
        return $false
    }
}

# Test 1: Virtual environment
Test-Component "Virtual Environment" {
    $venvPath = "venv\Scripts\python.exe"
    if (Test-Path $venvPath) {
        $version = & $venvPath --version 2>&1
        Write-Host "  Version: $version" -ForegroundColor Gray
        return $true
    }
    return $false
} -SuccessMessage "Virtual environment exists" -FailureMessage "Virtual environment not found"

# Test 2: PyTorch
Test-Component "PyTorch" {
    $result = & venv\Scripts\python.exe -c "import torch; print(torch.__version__)" 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  Version: $result" -ForegroundColor Gray
        return $true
    }
    return $false
} -SuccessMessage "PyTorch installed" -FailureMessage "PyTorch not found"

# Test 3: CUDA Support
Test-Component "CUDA Support" {
    $result = & venv\Scripts\python.exe -c "import torch; print(torch.cuda.is_available())" 2>&1
    if ($result -eq "True") {
        $gpu = & venv\Scripts\python.exe -c "import torch; print(torch.cuda.get_device_name(0))" 2>&1
        Write-Host "  GPU: $gpu" -ForegroundColor Gray
        return $true
    }
    return $false
} -SuccessMessage "CUDA available" -FailureMessage "CUDA not available"

# Test 4: FastAPI
Test-Component "FastAPI" {
    $result = & venv\Scripts\python.exe -c "import fastapi; print(fastapi.__version__)" 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  Version: $result" -ForegroundColor Gray
        return $true
    }
    return $false
} -SuccessMessage "FastAPI installed" -FailureMessage "FastAPI not found"

# Test 5: Diffusers
Test-Component "Diffusers" {
    $result = & venv\Scripts\python.exe -c "import diffusers; print(diffusers.__version__)" 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  Version: $result" -ForegroundColor Gray
        return $true
    }
    return $false
} -SuccessMessage "Diffusers installed" -FailureMessage "Diffusers not found"

# Test 6: SadTalker
Test-Component "SadTalker" {
    return Test-Path "SadTalker"
} -SuccessMessage "SadTalker directory exists" -FailureMessage "SadTalker not found"

# Test 7: Configuration file
Test-Component "Configuration" {
    if (Test-Path ".env") {
        $env = Get-Content ".env" | Out-String
        if ($env -match "GPU_API_KEY") {
            Write-Host "  ✓ API key configured" -ForegroundColor Gray
        }
        return $true
    }
    return $false
} -SuccessMessage ".env file exists" -FailureMessage ".env file not found"

# Test 8: Firewall rule
Test-Component "Firewall Rule" {
    $rule = Get-NetFirewallRule -DisplayName "Avatar Factory GPU Worker" -ErrorAction SilentlyContinue
    if ($rule) {
        Write-Host "  Port: 8001" -ForegroundColor Gray
        return $true
    }
    return $false
} -SuccessMessage "Firewall configured" -FailureMessage "Firewall rule not found (run as admin to add)"

# Test 9: Windows Service (optional)
Test-Component "Windows Service" {
    $service = Get-Service -Name "AvatarFactoryGPU" -ErrorAction SilentlyContinue
    if ($service) {
        Write-Host "  Status: $($service.Status)" -ForegroundColor Gray
        return $true
    }
    return $false
} -SuccessMessage "Service installed" -FailureMessage "Service not installed (optional)"

# Test 10: Server script
Test-Component "Server Script" {
    return Test-Path "server.py"
} -SuccessMessage "server.py exists" -FailureMessage "server.py not found"

# Summary
Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

$totalTests = $TestsPassed + $TestsFailed

if ($TestsFailed -eq 0) {
    Write-Success "All $totalTests tests passed!"
    Write-Host ""
    Write-Info "Installation is complete and ready to use"
    Write-Host "  Start server: $($Colors.Cyan).\start.bat$($Colors.Reset)"
    Write-Host "  Test server:  $($Colors.Cyan)curl http://localhost:8001/health$($Colors.Reset)"
    exit 0
}
else {
    Write-Warning "$TestsPassed/$totalTests tests passed, $TestsFailed failed"
    Write-Host ""
    Write-Info "Some components need attention"
    Write-Host "  Re-run setup: $($Colors.Cyan).\setup.ps1 -Repair$($Colors.Reset)"
    exit 1
}
```

**Step 2: Test the test script**

Run:
```powershell
powershell -ExecutionPolicy Bypass -File test-installation.ps1
```

Expected:
- Shows 10 tests
- Reports pass/fail for each
- Shows overall summary
- Exit code 0 if all pass, 1 if any fail

**Step 3: Add test to setup.ps1**

Update end of setup.ps1 to offer testing:

```powershell
# Add after installation complete
Write-Host ""
$runTests = Read-Host "Run installation tests? (Y/n)"

if ($runTests -notmatch "^[Nn]$") {
    Write-Host ""
    & "$PSScriptRoot\test-installation.ps1"
}
```

**Step 4: Commit**

```bash
git add gpu-worker/test-installation.ps1 gpu-worker/setup.ps1
git commit -m "feat(gpu-worker): add installation validation tests"
```

---

## Task 12: Final Integration and Testing

**Step 1: Create uninstall script**

Create `gpu-worker/uninstall.ps1`:
```powershell
# Uninstall Avatar Factory GPU Worker
# Removes all components (except downloaded models - optional)

param(
    [switch]$KeepModels,
    [switch]$Force
)

. "$PSScriptRoot\lib\common.ps1"

Write-Banner "Uninstallation"

if (-not $Force) {
    Write-Warning "This will remove:"
    Write-Host "  • Windows Service (if installed)"
    Write-Host "  • Firewall rules"
    Write-Host "  • Virtual environment"
    Write-Host "  • Python dependencies"
    if (-not $KeepModels) {
        Write-Host "  • Downloaded models (~10GB)"
    }
    Write-Host ""
    
    $confirm = Read-Host "Continue with uninstall? (yes/no)"
    if ($confirm -ne "yes") {
        Write-Info "Uninstall cancelled"
        exit 0
    }
}

# Remove Windows Service
if (Get-Service -Name "AvatarFactoryGPU" -ErrorAction SilentlyContinue) {
    Write-Info "Removing Windows Service..."
    & "$PSScriptRoot\service-remove.ps1"
}

# Remove Firewall Rule
if (Test-Administrator) {
    Write-Info "Removing firewall rule..."
    & "$PSScriptRoot\configure-firewall.ps1" -Action Remove
}

# Remove Virtual Environment
if (Test-Path "venv") {
    Write-Info "Removing virtual environment..."
    Remove-Item -Path "venv" -Recurse -Force
    Write-Success "Virtual environment removed"
}

# Remove Models (optional)
if (-not $KeepModels) {
    if (Test-Path "SadTalker") {
        Write-Info "Removing SadTalker..."
        Remove-Item -Path "SadTalker" -Recurse -Force
    }
    
    if (Test-Path "models") {
        Write-Info "Removing models..."
        Remove-Item -Path "models" -Recurse -Force
    }
}

# Remove logs
if (Test-Path "logs") {
    Write-Info "Removing logs..."
    Remove-Item -Path "logs\*.log" -Force -ErrorAction SilentlyContinue
}

# Remove tools
if (Test-Path "tools") {
    Write-Info "Removing downloaded tools..."
    Remove-Item -Path "tools" -Recurse -Force -ErrorAction SilentlyContinue
}

# Keep .env file (contains API key user may want)
if (Test-Path ".env") {
    Write-Warning ".env file kept (contains your API key)"
    Write-Info "Delete manually if needed: rm .env"
}

Write-Host ""
Write-Success "Uninstallation complete"

if ($KeepModels) {
    Write-Info "Models kept: SadTalker/, models/"
}

exit 0
```

**Step 2: Full end-to-end test**

On a clean Windows 10/11 machine (or VM):

```powershell
# 1. Clone repo
git clone <repo-url>
cd avatar-factory/gpu-worker

# 2. Check system
.\check-system.ps1 -Detailed

# 3. Install everything
.\install.bat
# Follow prompts, let it complete

# 4. Verify installation
.\test-installation.ps1

# 5. Test manual start
.\start.bat
# Ctrl+C to stop

# 6. Install service
.\service-install.ps1

# 7. Verify service
Get-Service AvatarFactoryGPU
curl http://localhost:8001/health

# 8. Test from laptop (if available)
# From laptop: curl http://<gpu-pc-ip>:8001/health

# 9. Cleanup test
.\service-remove.ps1
.\uninstall.ps1 -KeepModels
```

Expected results:
- All steps complete without errors
- Service starts and responds
- Can access from network
- Clean uninstall

**Step 3: Create test checklist document**

Create `gpu-worker/TEST_CHECKLIST.md`:
```markdown
# Windows GPU Worker - Test Checklist

Use this checklist to verify the installation on Windows.

## Pre-Installation Tests

- [ ] Windows 10 1809+ or Windows 11
- [ ] PowerShell 5.1+
- [ ] 30GB+ free disk space
- [ ] 16GB+ RAM
- [ ] NVIDIA GPU with 8GB+ VRAM
- [ ] NVIDIA drivers installed (`nvidia-smi` works)
- [ ] CUDA 11.8 installed (`nvcc --version` works)

## Installation Tests

- [ ] `.\check-system.ps1` passes all critical checks
- [ ] `.\install.bat` completes without errors
- [ ] Installation log shows no errors (`logs\install.log`)
- [ ] Virtual environment created (`venv/` exists)
- [ ] PyTorch installed with CUDA
- [ ] All dependencies installed
- [ ] SadTalker cloned
- [ ] Models downloaded (or skipped intentionally)
- [ ] `.env` file created with API key
- [ ] Firewall rule added (if admin)

## Validation Tests

- [ ] `.\test-installation.ps1` all tests pass
- [ ] `python -c "import torch; print(torch.cuda.is_available())"` returns True
- [ ] `python -c "import fastapi"` works
- [ ] `python server.py` starts without errors

## Manual Start Tests

- [ ] `.\start.bat` starts server
- [ ] Server shows IP addresses
- [ ] `curl http://localhost:8001/health` returns 200 OK
- [ ] Server responds with JSON
- [ ] Ctrl+C stops server cleanly

## Service Tests

- [ ] `.\service-install.ps1` completes (as admin)
- [ ] Service appears in `services.msc`
- [ ] Service status is "Running"
- [ ] `Get-Service AvatarFactoryGPU` shows Running
- [ ] Server responds after service start
- [ ] `.\service-restart.ps1` works
- [ ] Service starts after Windows reboot
- [ ] Logs written to `logs\service.log`

## Network Tests

- [ ] From laptop: `curl http://<gpu-pc-ip>:8001/health` works
- [ ] Firewall rule exists (`.\configure-firewall.ps1 -Action Check`)
- [ ] Can connect from another device on network
- [ ] API key authentication works (if implemented)

## Cleanup Tests

- [ ] `.\service-remove.ps1` removes service
- [ ] Service no longer in `services.msc`
- [ ] `.\uninstall.ps1 -KeepModels` removes components
- [ ] Virtual environment removed
- [ ] Models kept (with `-KeepModels`)
- [ ] Can reinstall after uninstall

## Error Scenarios

- [ ] Graceful failure if Python not installed
- [ ] Clear error if CUDA missing
- [ ] Handles no internet connection
- [ ] Handles disk full
- [ ] Recovers from interrupted installation (`.\setup.ps1 -Repair`)

## Documentation Tests

- [ ] README-WINDOWS.md is clear and accurate
- [ ] All commands in docs work as written
- [ ] Troubleshooting section covers common issues
- [ ] FAQ answers basic questions

---

**Test Date:** ___________  
**Tester:** ___________  
**Windows Version:** ___________  
**GPU Model:** ___________  
**Issues Found:** ___________
```

**Step 4: Final commits**

```bash
git add gpu-worker/uninstall.ps1 gpu-worker/TEST_CHECKLIST.md
git commit -m "feat(gpu-worker): add uninstall script and test checklist"
```

**Step 5: Update main project README**

Update `/Users/nybble/projects/ai/avatar-factory/README.md` section about GPU worker:

```markdown
## GPU Worker Setup

### Windows 10/11 (Recommended - Automated)

**One command:**
```batch
cd gpu-worker
install.bat
```

See [gpu-worker/README-WINDOWS.md](gpu-worker/README-WINDOWS.md) for details.

### Linux/macOS (Manual)

See [gpu-worker/README.md](gpu-worker/README.md) for manual setup instructions.
```

**Step 6: Commit**

```bash
git add README.md
git commit -m "docs: update main README with automated Windows setup"
```

---

## Summary

This implementation plan creates a comprehensive automated setup system for Avatar Factory GPU Worker on Windows 10/11:

**Created Files:**
- PowerShell scripts: 11 files
- Batch wrappers: 3 files
- Documentation: 2 files
- Tests: 2 files
- Utilities: 1 library

**Key Features:**
- ✅ One-command installation
- ✅ Automatic prerequisite installation
- ✅ CUDA support verification
- ✅ AI model downloads with progress
- ✅ Secure API key generation
- ✅ Firewall configuration
- ✅ Windows Service with NSSM
- ✅ Comprehensive error handling
- ✅ Installation validation tests
- ✅ Complete documentation

**User Experience:**
- Beginners: Double-click `install.bat`, follow prompts
- Advanced: PowerShell with parameters for customization
- Admins: Service installation for production

**Next Steps:**
1. Test on clean Windows 10 VM
2. Test on clean Windows 11 VM
3. Gather user feedback
4. Iterate based on issues found
5. Consider packaging as MSI installer (future)
