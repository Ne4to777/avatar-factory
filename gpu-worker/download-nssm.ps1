# Download and verify NSSM (Non-Sucking Service Manager)
# Used for Windows Service creation

param(
    [string]$OutputDir = "tools",
    [switch]$Force
)

. "$PSScriptRoot\lib\common.ps1"

# Resolve output path relative to script directory (unless absolute)
if (-not [System.IO.Path]::IsPathRooted($OutputDir)) {
    $OutputDir = Join-Path $PSScriptRoot $OutputDir
}

$NSSM_VERSION = "2.24"
# Note: NSSM 2.24-101 is recommended for Windows 10 Creators Update+
# We use 2.24 for broader compatibility. Service installation works correctly.
$NSSM_URL = "https://nssm.cc/release/nssm-$NSSM_VERSION.zip"
$NSSM_ZIP = Join-Path $OutputDir "nssm-$NSSM_VERSION.zip"
$NSSM_EXE = Join-Path $OutputDir "nssm.exe"

Write-Banner "NSSM Download Utility"

# Check if already exists
if ((Test-Path $NSSM_EXE) -and -not $Force) {
    Write-Success "NSSM already downloaded: $NSSM_EXE"

    # Verify it works
    $version = & $NSSM_EXE version 2>&1
    if ($version -and $version -match "NSSM") {
        Write-Info "Version: $version"
        exit 0
    }
    else {
        Write-WarningMsg "Existing NSSM appears corrupted, re-downloading..."
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
    Write-ErrorMsg "Failed to download NSSM"
    exit 1
}

# Verify download completed (catch truncated/empty downloads)
$zipFile = Get-Item $NSSM_ZIP -ErrorAction SilentlyContinue
$zipSize = if ($zipFile) { $zipFile.Length } else { 0 }
if (-not $zipSize -or $zipSize -lt 100000) {
    Remove-Item $NSSM_ZIP -Force -ErrorAction SilentlyContinue
    Write-ErrorMsg "Download incomplete or corrupted (got $zipSize bytes, expected ~350KB)"
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
    try {
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
    }
    finally {
        $zip.Dispose()
    }
}
catch {
    Write-ErrorMsg "Failed to extract NSSM: $_"
    exit 1
}

# Verify extracted file
Write-Info "Verifying NSSM..."

if (-not (Test-Path $NSSM_EXE)) {
    Write-ErrorMsg "NSSM executable not found after extraction"
    exit 1
}

# Test execution (nssm version may return non-zero exit code, but that's ok)
$version = & $NSSM_EXE version 2>&1
if ($version -and $version -match "NSSM") {
    Write-Success "NSSM verified: $version"
}
else {
    Write-ErrorMsg "NSSM executable appears corrupted or invalid"
    Write-Host "  Output: $version"
    exit 1
}

# Cleanup zip file
Write-Info "Cleaning up..."
Remove-Item $NSSM_ZIP -Force -ErrorAction SilentlyContinue

Write-Success "NSSM ready for use"
exit 0
