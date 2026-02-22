# Avatar Factory GPU Worker - Common PowerShell Utilities
# Windows 10/11 only - uses Windows-specific cmdlets (Get-CimInstance, Get-NetIPAddress, etc.)
# Dot-source with: . "$PSScriptRoot\lib\common.ps1"

# Enable strict mode
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ANSI color codes for Windows 10+ (PowerShell 5.1 compatible)
$script:ESC = [char]27
$script:Colors = @{
    Red    = "$($script:ESC)[91m"
    Green  = "$($script:ESC)[92m"
    Yellow = "$($script:ESC)[93m"
    Blue   = "$($script:ESC)[94m"
    Cyan   = "$($script:ESC)[96m"
    Reset  = "$($script:ESC)[0m"
}

# Enable ANSI colors in Windows Console
function Enable-AnsiColors {
    if ($PSVersionTable.PSVersion.Major -ge 5) {
        try {
            $null = [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
        }
        catch { }
        if (($Host.Name -eq 'ConsoleHost') -and ($env:OS -eq 'Windows_NT')) {
            $null = reg add HKCU\Console /v VirtualTerminalLevel /t REG_DWORD /d 1 /f 2>$null
        }
    }
}

# Print functions
function Write-Success {
    param([string]$Message)
    Write-Host "$($Colors.Green)[OK]$($Colors.Reset) $Message"
}

function Write-Info {
    param([string]$Message)
    Write-Host "$($Colors.Blue)[i]$($Colors.Reset) $Message"
}

function Write-WarningMsg {
    param([string]$Message)
    Write-Host "$($Colors.Yellow)[!]$($Colors.Reset) $Message"
}

function Write-ErrorMsg {
    param([string]$Message)
    Write-Host "$($Colors.Red)[X]$($Colors.Reset) $Message"
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
    param(
        [string[]]$Arguments,
        [string]$ScriptPath = $MyInvocation.PSCommandPath
    )

    if (-not (Test-Administrator)) {
        Write-WarningMsg "This operation requires administrator privileges"
        Write-Info "Restarting with elevation..."

        Start-Process powershell.exe -ArgumentList "-ExecutionPolicy Bypass -File `"$ScriptPath`" $($Arguments -join ' ')" -Verb RunAs
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
            $percent = if ($e.TotalBytesToReceive -gt 0) {
                [math]::Round(($e.BytesReceived / $e.TotalBytesToReceive) * 100, 2)
            } else { 0 }
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
        [string]$LogPath = 'logs\install.log'
    )

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $logMessage = '[{0}] {1}' -f $timestamp, $Message

    # Ensure log directory exists
    $logDir = Split-Path $LogPath -Parent
    if (-not (Test-Path $logDir)) {
        $null = New-Item -ItemType Directory -Path $logDir -Force
    }

    Add-Content -Path $LogPath -Value $logMessage -Encoding UTF8
}
