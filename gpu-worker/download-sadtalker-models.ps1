# SadTalker Models Downloader for Windows
# Downloads all required checkpoints (~2.5GB total)

$ErrorActionPreference = "Stop"

Write-Host "============================================================"
Write-Host "[>] SadTalker Checkpoints Downloader"
Write-Host "============================================================"
Write-Host ""

# Create checkpoints directory
$checkpointsDir = "SadTalker\checkpoints"
if (-not (Test-Path $checkpointsDir)) {
    Write-Host "[i] Creating checkpoints directory..."
    New-Item -ItemType Directory -Path $checkpointsDir -Force | Out-Null
}

# Model URLs from SadTalker repository
$models = @(
    @{
        Name = "SadTalker V0.0.2 (Main Model)"
        Url = "https://github.com/OpenTalker/SadTalker/releases/download/v0.0.2-rc/mapping_00229-model.pth.tar"
        Path = "$checkpointsDir\mapping_00229-model.pth.tar"
        Size = "~350MB"
    },
    @{
        Name = "SadTalker V0.0.2 (Face Renderer)"
        Url = "https://github.com/OpenTalker/SadTalker/releases/download/v0.0.2-rc/facevid2vid_00189-model.pth.tar"
        Path = "$checkpointsDir\facevid2vid_00189-model.pth.tar"
        Size = "~1.5GB"
    },
    @{
        Name = "SadTalker V0.0.2 (Audio2Pose)"
        Url = "https://github.com/OpenTalker/SadTalker/releases/download/v0.0.2-rc/audio2pose_00140-model.pth"
        Path = "$checkpointsDir\audio2pose_00140-model.pth"
        Size = "~50MB"
    },
    @{
        Name = "SadTalker V0.0.2 (Audio2Exp)"
        Url = "https://github.com/OpenTalker/SadTalker/releases/download/v0.0.2-rc/audio2exp_00300-model.pth"
        Path = "$checkpointsDir\audio2exp_00300-model.pth"
        Size = "~17MB"
    },
    @{
        Name = "Face Detection (shape_predictor)"
        Url = "https://github.com/OpenTalker/SadTalker/releases/download/v0.0.2-rc/shape_predictor_68_face_landmarks.dat"
        Path = "$checkpointsDir\shape_predictor_68_face_landmarks.dat"
        Size = "~100MB"
    },
    @{
        Name = "Face Analysis"
        Url = "https://github.com/OpenTalker/SadTalker/releases/download/v0.0.2-rc/BFM_Fitting.zip"
        Path = "$checkpointsDir\BFM_Fitting.zip"
        Size = "~50MB"
    },
    @{
        Name = "Expression Coefficients"
        Url = "https://github.com/OpenTalker/SadTalker/releases/download/v0.0.2-rc/epoch_20.pth"
        Path = "$checkpointsDir\epoch_20.pth"
        Size = "~100MB"
    }
)

Write-Host "[i] Total download size: ~2.5GB"
Write-Host "[i] This will take 10-20 minutes depending on your connection"
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
    
    try {
        # Use .NET WebClient for progress (Invoke-WebRequest is slow)
        $webClient = New-Object System.Net.WebClient
        
        # Download with progress
        Register-ObjectEvent -InputObject $webClient -EventName DownloadProgressChanged -Action {
            $percent = $EventArgs.ProgressPercentage
            Write-Progress -Activity "Downloading" -Status "$percent% Complete" -PercentComplete $percent
        } | Out-Null
        
        $webClient.DownloadFile($model.Url, $model.Path)
        $webClient.Dispose()
        
        Write-Progress -Activity "Downloading" -Completed
        
        if (Test-Path $model.Path) {
            $size = (Get-Item $model.Path).Length / 1MB
            Write-Host "    [OK] Downloaded ($([math]::Round($size, 1))MB)"
            $downloaded++
        } else {
            Write-Host "    [ERROR] Download failed"
            $failed++
        }
    }
    catch {
        Write-Host "    [ERROR] $($_.Exception.Message)"
        $failed++
    }
    
    Write-Host ""
}

# Extract BFM_Fitting.zip if needed
$bfmZip = "$checkpointsDir\BFM_Fitting.zip"
$bfmDir = "$checkpointsDir\BFM_Fitting"

if ((Test-Path $bfmZip) -and -not (Test-Path $bfmDir)) {
    Write-Host "[i] Extracting BFM_Fitting.zip..."
    try {
        Expand-Archive -Path $bfmZip -DestinationPath $checkpointsDir -Force
        Write-Host "[OK] Extracted successfully"
        Remove-Item $bfmZip -Force
        Write-Host "[i] Removed zip file"
    }
    catch {
        Write-Host "[ERROR] Failed to extract: $($_.Exception.Message)"
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
    Write-Host "https://github.com/OpenTalker/SadTalker/releases/tag/v0.0.2-rc"
}

Write-Host ""
Write-Host "Press any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
