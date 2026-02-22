# SadTalker Models Downloader for Windows
# Downloads all required checkpoints (~2.5GB total)

$ErrorActionPreference = "Stop"

Write-Host "============================================================"
Write-Host "[>] SadTalker Checkpoints Downloader"
Write-Host "============================================================"
Write-Host ""

# Create required directories
$checkpointsDir = "SadTalker\checkpoints"
$gfpganDir = "SadTalker\gfpgan\weights"

if (-not (Test-Path $checkpointsDir)) {
    Write-Host "[i] Creating checkpoints directory..."
    New-Item -ItemType Directory -Path $checkpointsDir -Force | Out-Null
}

if (-not (Test-Path $gfpganDir)) {
    Write-Host "[i] Creating GFPGAN weights directory..."
    New-Item -ItemType Directory -Path $gfpganDir -Force | Out-Null
}

# Helper function to download with retry
function Download-WithRetry {
    param(
        [string]$Url,
        [string]$Path,
        [int]$MaxRetries = 3
    )
    
    for ($i = 1; $i -le $MaxRetries; $i++) {
        try {
            Write-Host "    Attempt $i/$MaxRetries..."
            
            # Use Invoke-WebRequest with Resume support
            $ProgressPreference = 'SilentlyContinue'
            Invoke-WebRequest -Uri $Url -OutFile $Path -UseBasicParsing -TimeoutSec 600
            $ProgressPreference = 'Continue'
            
            if (Test-Path $Path) {
                return $true
            }
        }
        catch {
            $errorMsg = $_.Exception.Message
            Write-Host "    [ERROR] $errorMsg"
            
            # Don't retry on HTTP errors (404, 403, etc) - file doesn't exist
            if ($errorMsg -match "\(404\)|\(403\)|\(401\)|\(400\)") {
                Write-Host "    [SKIP] HTTP error - file not available, no retry"
                return $false
            }
            
            # Retry only on network errors (timeouts, connection drops)
            if ($i -lt $MaxRetries) {
                Write-Host "    [RETRY] Network error - retrying in 5 seconds..."
                Start-Sleep -Seconds 5
                
                # Remove partial download
                if (Test-Path $Path) {
                    Remove-Item $Path -Force -ErrorAction SilentlyContinue
                }
            }
        }
    }
    
    return $false
}

# Model URLs from HuggingFace mirror (more reliable than GitHub releases)
# Source: https://huggingface.co/camenduru/SadTalker/tree/main/new/checkpoints
$models = @(
    @{
        Name = "SadTalker V0.0.2 256px (SafeTensors)"
        Url = "https://huggingface.co/camenduru/SadTalker/resolve/main/new/checkpoints/SadTalker_V0.0.2_256.safetensors"
        Path = "$checkpointsDir\SadTalker_V0.0.2_256.safetensors"
        Size = "~156MB"
    },
    @{
        Name = "SadTalker V0.0.2 512px (SafeTensors)"
        Url = "https://huggingface.co/camenduru/SadTalker/resolve/main/new/checkpoints/SadTalker_V0.0.2_512.safetensors"
        Path = "$checkpointsDir\SadTalker_V0.0.2_512.safetensors"
        Size = "~725MB"
    },
    @{
        Name = "Mapping Model 109"
        Url = "https://huggingface.co/camenduru/SadTalker/resolve/main/new/checkpoints/mapping_00109-model.pth.tar"
        Path = "$checkpointsDir\mapping_00109-model.pth.tar"
        Size = "~148MB"
    },
    @{
        Name = "Mapping Model 229"
        Url = "https://huggingface.co/camenduru/SadTalker/resolve/main/new/checkpoints/mapping_00229-model.pth.tar"
        Path = "$checkpointsDir\mapping_00229-model.pth.tar"
        Size = "~148MB"
    },
    @{
        Name = "GFPGAN v1.3"
        Url = "https://huggingface.co/alexgenovese/facerestore/resolve/main/GFPGANv1.3.pth"
        Path = "SadTalker\gfpgan\weights\GFPGANv1.3.pth"
        Size = "~349MB"
    }
)

Write-Host "[i] Total download size: ~1.5GB"
Write-Host "[i] This will take 10-20 minutes depending on your connection"
Write-Host "[i] Using retry logic (3 attempts per file)"
Write-Host ""

$downloaded = 0
$failed = 0

foreach ($model in $models) {
    Write-Host "[$($downloaded + 1)/$($models.Count)] Downloading: $($model.Name) ($($model.Size))"
    
    if (Test-Path $model.Path) {
        Write-Host "    [SKIP] Already exists"
        $downloaded++
        continue
    }
    
    $success = Download-WithRetry -Url $model.Url -Path $model.Path -MaxRetries 3
    
    if ($success) {
        $size = (Get-Item $model.Path).Length / 1MB
        Write-Host "    [OK] Downloaded ($([math]::Round($size, 1))MB)"
        $downloaded++
    } else {
        Write-Host "    [ERROR] Download failed after retries"
        $failed++
    }
    
    Write-Host ""
}

Write-Host "============================================================"
Write-Host "[==] Download Summary"
Write-Host "============================================================"
Write-Host "[OK] Successfully downloaded: $downloaded/$($models.Count)"
if ($failed -gt 0) {
    Write-Host "[ERROR] Failed: $failed/$($models.Count)"
}
Write-Host ""

if ($failed -eq 0) {
    Write-Host "[OK] All SadTalker checkpoints downloaded!"
    Write-Host ""
    Write-Host "Next steps:"
    Write-Host "1. Install SadTalker dependencies:"
    Write-Host "   cd SadTalker"
    Write-Host "   ..\venv\Scripts\python.exe -m pip install setuptools wheel"
    Write-Host "   ..\venv\Scripts\python.exe -m pip install -r requirements.txt"
    Write-Host "   cd .."
    Write-Host ""
    Write-Host "2. Restart the server:"
    Write-Host "   .\start.bat"
} else {
    Write-Host "[!] Some downloads failed. Please try again or download manually from:"
    Write-Host "https://huggingface.co/camenduru/SadTalker/tree/main/new/checkpoints"
}

Write-Host ""
Write-Host "Press any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
