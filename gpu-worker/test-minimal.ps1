# Minimal test for GPU worker - 480p, short audio
# Run: powershell -ExecutionPolicy Bypass -File test-minimal.ps1

$ErrorActionPreference = "Continue"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
Add-Type -AssemblyName System.Web

$API_KEY = "your-secret-gpu-key-change-this"
$HOST = "http://localhost:8001"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "GPU Server Minimal Test (480p)" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Test 1: Health check
Write-Host "[1/3] Health check..." -ForegroundColor Yellow
try {
    $health = Invoke-RestMethod -Uri "$HOST/health" -Method GET -Headers @{"x-api-key"=$API_KEY}
    Write-Host "✓ Server healthy" -ForegroundColor Green
    Write-Host "  Models: MuseTalk=$($health.models.musetalk), SD=$($health.models.stable_diffusion), TTS=$($health.models.silero_tts)" -ForegroundColor Gray
} catch {
    Write-Host "✗ Health check failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
Write-Host ""

# Test 2: Generate short TTS (2 words)
Write-Host "[2/3] Generating TTS..." -ForegroundColor Yellow
try {
    # Use simple Russian text (URL-encoded manually to avoid encoding issues)
    $text = "%D0%9F%D1%80%D0%B8%D0%B2%D0%B5%D1%82"  # "Privet" in Russian
    $uri = "$HOST/api/tts?text=$text&speaker=xenia"
    
    $audioFile = "test-minimal-audio.wav"
    Invoke-RestMethod -Uri $uri -Method POST -Headers @{"x-api-key"=$API_KEY} -OutFile $audioFile
    
    $size = (Get-Item $audioFile).Length
    Write-Host "✓ TTS generated: $audioFile ($size bytes)" -ForegroundColor Green
} catch {
    Write-Host "✗ TTS failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
Write-Host ""

# Test 3: Generate small background (480p)
Write-Host "[3/3] Generating background (480x480)..." -ForegroundColor Yellow
try {
    $uri = "$HOST/api/generate-background?prompt=simple+white+background&negative_prompt=complex&width=480&height=480"
    
    $bgFile = "test-minimal-bg.png"
    Invoke-RestMethod -Uri $uri -Method POST -Headers @{"x-api-key"=$API_KEY} -OutFile $bgFile
    
    $size = (Get-Item $bgFile).Length
    Write-Host "✓ Background generated: $bgFile ($size bytes)" -ForegroundColor Green
} catch {
    Write-Host "✗ Background generation failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
Write-Host ""

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "✓ All tests passed!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Generated files:" -ForegroundColor Yellow
Get-ChildItem test-minimal-*.* | Format-Table Name, Length, LastWriteTime
Write-Host ""
Write-Host "You can test these files manually:" -ForegroundColor Yellow
Write-Host "  1. Play audio: test-minimal-audio.wav" -ForegroundColor Gray
Write-Host "  2. View image: test-minimal-bg.png" -ForegroundColor Gray
