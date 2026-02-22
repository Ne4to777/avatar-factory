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
                Write-ErrorMsg $FailureMessage
                $script:AllChecksPassed = $false
            }
            else {
                Write-WarningMsg $FailureMessage
                $script:Warnings += $FailureMessage
            }
            return $false
        }
    }
    catch {
        if ($Required) {
            Write-ErrorMsg "$FailureMessage (Error: $_)"
            $script:AllChecksPassed = $false
        }
        else {
            Write-WarningMsg "$FailureMessage (Error: $_)"
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
        return ($version.Major -ge 6) -or ($version.Major -eq 5 -and $version.Minor -ge 1)
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
$null = Test-Requirement `
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
$null = Test-Requirement `
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
$null = Test-Requirement `
    -Name "NVIDIA GPU" `
    -Test {
        if (Test-Command nvidia-smi) {
            $gpuInfo = nvidia-smi --query-gpu=name,memory.total --format=csv,noheader 2>$null
            if ($gpuInfo -and $Detailed) {
                Write-Host "  GPU: $gpuInfo"
            }
            return ($null -ne $gpuInfo) -and ($gpuInfo.ToString().Trim() -ne '')
        }
        return $false
    } `
    -SuccessMessage "NVIDIA GPU detected" `
    -FailureMessage "NVIDIA GPU not detected (drivers may not be installed)" `
    -Required $false

# Check 8: CUDA
$null = Test-Requirement `
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
$null = Test-Requirement `
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
        Write-WarningMsg "Optional components to install:"
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
    Write-ErrorMsg "Some critical requirements are not met"
    Write-Host ""
    Write-Info "Please address the errors above and run this check again"

    exit 1
}
