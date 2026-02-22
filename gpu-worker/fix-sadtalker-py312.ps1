# Fix SadTalker requirements.txt for Python 3.12 compatibility
# Run this from gpu-worker directory

if (-not (Test-Path "SadTalker\requirements.txt")) {
    Write-Host "ERROR: SadTalker not found. Run setup.ps1 first." -ForegroundColor Red
    exit 1
}

Write-Host "Fixing SadTalker requirements.txt for Python 3.12..." -ForegroundColor Cyan

# Backup original
Copy-Item "SadTalker\requirements.txt" "SadTalker\requirements.txt.backup"

# Read and fix requirements
$requirements = Get-Content "SadTalker\requirements.txt"
$fixed = $requirements | ForEach-Object {
    $line = $_
    
    # Skip problematic packages or fix versions
    if ($line -match "^numpy") {
        "numpy>=1.23.0,<2.0.0"
    }
    elseif ($line -match "^setuptools") {
        "setuptools>=68.0.0"
    }
    elseif ($line -match "^scikit-image") {
        "scikit-image>=0.21.0"
    }
    else {
        $line
    }
}

$fixed | Set-Content "SadTalker\requirements.txt"

Write-Host ""
Write-Host "Fixed! Now install SadTalker dependencies:" -ForegroundColor Green
Write-Host "  cd SadTalker" -ForegroundColor Yellow
Write-Host "  ..\venv\Scripts\python.exe -m pip install -r requirements.txt" -ForegroundColor Yellow
Write-Host ""
Write-Host "Original saved as requirements.txt.backup" -ForegroundColor Gray
