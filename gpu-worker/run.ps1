# Start Avatar Factory GPU Worker
# Usage: powershell -ExecutionPolicy Bypass -File run.ps1

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host " Avatar Factory GPU Worker" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# Check venv exists
if (-not (Test-Path "venv\Scripts\python.exe")) {
    Write-Host "[ERROR] venv not found!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Run installation first:"
    Write-Host "  install.bat"
    Write-Host ""
    Read-Host "Press Enter to exit"
    exit 1
}

# Kill existing process on port 8001
Write-Host "Checking for existing server on port 8001..." -ForegroundColor Yellow
$port = 8001
$connections = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue

if ($connections) {
    foreach ($conn in $connections) {
        $pid = $conn.OwningProcess
        $process = Get-Process -Id $pid -ErrorAction SilentlyContinue
        
        if ($process) {
            Write-Host "Found process: $($process.ProcessName) (PID: $pid)" -ForegroundColor Yellow
            Write-Host "Killing process $pid..." -ForegroundColor Yellow
            
            try {
                Stop-Process -Id $pid -Force
                Write-Host "Process $pid killed successfully" -ForegroundColor Green
                Start-Sleep -Milliseconds 500  # Wait for port to be released
            } catch {
                Write-Host "[WARNING] Could not kill process $pid : $_" -ForegroundColor Red
            }
        }
    }
} else {
    Write-Host "No existing server found on port $port" -ForegroundColor Green
}

# Clean Python cache
Write-Host "Cleaning Python cache..." -ForegroundColor Yellow
Get-ChildItem -Path . -Filter "__pycache__" -Recurse -Directory -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
Get-ChildItem -Path . -Filter "*.pyc" -Recurse -File -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
Write-Host "Cache cleaned" -ForegroundColor Green

Write-Host ""
Write-Host "Starting server on http://localhost:8001" -ForegroundColor Green
Write-Host "Press Ctrl+C to stop" -ForegroundColor Yellow
Write-Host ""

# Start server
& "venv\Scripts\python.exe" server.py

# Pause on exit (only if not Ctrl+C)
if ($LASTEXITCODE -ne 0) {
    Read-Host "Press Enter to exit"
}
