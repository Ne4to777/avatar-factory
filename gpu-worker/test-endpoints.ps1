# GPU Server API Tests
# Run: powershell -ExecutionPolicy Bypass -File test-endpoints.ps1

$ErrorActionPreference = "Continue"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# Load URL encoding utility
Add-Type -AssemblyName System.Web

$API_KEY = "your-secret-gpu-key-change-this"
$HOST = "http://localhost:8001"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "GPU Server API Tests" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Test 1: Health
Write-Host "[1/4] Testing Health Endpoint..." -ForegroundColor Yellow
try {
    $response = Invoke-RestMethod -Uri "$HOST/health" -Method GET -Headers @{"x-api-key"=$API_KEY}
    Write-Host ($response | ConvertTo-Json -Depth 5) -ForegroundColor Green
} catch {
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
}
Write-Host ""

# Test 2: TTS with Russian text (aidar)
Write-Host "[2/4] Testing TTS with speaker aidar..." -ForegroundColor Yellow
try {
    $text = [System.Web.HttpUtility]::UrlEncode("Привет, это тестовое сообщение.")
    $uri = "$HOST/api/tts?text=$text&speaker=aidar"
    Invoke-RestMethod -Uri $uri -Method POST -Headers @{"x-api-key"=$API_KEY} -OutFile "test-tts-aidar.wav"
    $size = (Get-Item "test-tts-aidar.wav").Length
    Write-Host "✓ Generated: test-tts-aidar.wav ($size bytes)" -ForegroundColor Green
} catch {
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    if (Test-Path "test-tts-aidar.wav") {
        Write-Host "Response content: $(Get-Content 'test-tts-aidar.wav' -Raw)" -ForegroundColor Red
    }
}
Write-Host ""

# Test 3: TTS with Russian text (xenia)
Write-Host "[3/4] Testing TTS with speaker xenia..." -ForegroundColor Yellow
try {
    $text = [System.Web.HttpUtility]::UrlEncode("Добро пожаловать в систему создания видео.")
    $uri = "$HOST/api/tts?text=$text&speaker=xenia"
    Invoke-RestMethod -Uri $uri -Method POST -Headers @{"x-api-key"=$API_KEY} -OutFile "test-tts-xenia.wav"
    $size = (Get-Item "test-tts-xenia.wav").Length
    Write-Host "✓ Generated: test-tts-xenia.wav ($size bytes)" -ForegroundColor Green
} catch {
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    if (Test-Path "test-tts-xenia.wav") {
        Write-Host "Response content: $(Get-Content 'test-tts-xenia.wav' -Raw)" -ForegroundColor Red
    }
}
Write-Host ""

# Test 4: Background Generation
Write-Host "[4/4] Testing Background Generation..." -ForegroundColor Yellow
try {
    $uri = "$HOST/api/generate-background?prompt=modern+office&negative_prompt=blurry&width=512&height=512"
    Invoke-RestMethod -Uri $uri -Method POST -Headers @{"x-api-key"=$API_KEY} -OutFile "test-bg.png"
    $size = (Get-Item "test-bg.png").Length
    Write-Host "✓ Generated: test-bg.png ($size bytes)" -ForegroundColor Green
} catch {
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    if (Test-Path "test-bg.png") {
        $content = Get-Content 'test-bg.png' -Raw -Encoding UTF8
        if ($content.Length -lt 1000) {
            Write-Host "Response content: $content" -ForegroundColor Red
        }
    }
}
Write-Host ""

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Tests Complete!" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Generated files:"
Get-ChildItem test-tts-*.wav, test-bg.png -ErrorAction SilentlyContinue | Format-Table Name, Length
