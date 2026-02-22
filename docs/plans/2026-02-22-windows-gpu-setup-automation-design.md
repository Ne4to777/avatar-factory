# Windows GPU Worker - Automated Setup Design

**Date:** 2026-02-22  
**Status:** Approved  
**Author:** AI Assistant

## Overview

Automated one-command installation system for Avatar Factory GPU Worker on Windows 10/11. The goal is to reduce manual setup from 30+ minutes with multiple manual steps to a single command that handles all prerequisites, dependencies, and configuration automatically.

## Problem Statement

Current installation process requires:
- Manual Python installation
- Manual CUDA Toolkit installation
- Manual Git installation
- Manual virtual environment setup
- Manual PyTorch installation with CUDA
- Manual model downloads
- Manual firewall configuration
- Manual service setup for auto-start

Users need to follow 10+ manual steps in README, which is error-prone and time-consuming.

## Goals

1. **One-command install:** User runs `install.bat` and everything is configured
2. **Automatic prerequisites:** Install Python, Git if missing
3. **Automatic service setup:** GPU server starts on Windows boot
4. **Firewall configuration:** Automatically open port 8001
5. **Error handling:** Clear messages with recovery instructions
6. **Idempotent:** Can be run multiple times safely
7. **Unattended option:** Support for silent installation

## Solution Architecture

### Component Overview

```
gpu-worker/
├── setup.ps1                 # Main PowerShell installer
├── install.bat               # Wrapper for double-click execution
├── start.bat                 # Manual server start (improved)
├── stop.bat                  # Server stop script
├── service-install.ps1       # Windows Service installer
├── service-remove.ps1        # Windows Service uninstaller
├── service-restart.ps1       # Service restart utility
├── check-system.ps1          # System requirements checker
├── download-nssm.ps1         # NSSM auto-downloader
├── configure-firewall.ps1    # Firewall automation
├── logs/                     # Installation and service logs
│   ├── install.log
│   ├── service.log
│   └── service-error.log
└── tools/                    # Downloaded tools (NSSM)
    └── nssm.exe
```

### Design Decision: PowerShell + NSSM

**Chosen Approach:** PowerShell-based automation with NSSM service manager

**Why:**
- Native to Windows (no extra runtime needed)
- Can elevate privileges when needed
- Good error handling capabilities
- Scriptable and maintainable
- NSSM is lightweight (350KB) and reliable

**Alternatives Considered:**
1. **Docker-based:** Rejected - nvidia-docker unstable on Windows, adds complexity
2. **EXE installer:** Rejected - 5GB+ size, hard to maintain, requires code signing

## Detailed Design

### 1. Installation Flow (setup.ps1)

```powershell
┌─────────────────────────────────────────┐
│ 1. Check Execution Policy & Admin      │
│    - Warn if restricted                 │
│    - Offer to re-run with elevation     │
└─────────────────────────────────────────┘
                  ↓
┌─────────────────────────────────────────┐
│ 2. System Requirements Check            │
│    ✓ Windows 10/11                      │
│    ✓ 30GB free space                    │
│    ✓ 16GB+ RAM                          │
│    ✓ NVIDIA GPU present                 │
└─────────────────────────────────────────┘
                  ↓
┌─────────────────────────────────────────┐
│ 3. Install Missing Prerequisites        │
│    - Python 3.10+ via winget            │
│    - Git via winget                     │
│    - Prompt for CUDA if missing         │
└─────────────────────────────────────────┘
                  ↓
┌─────────────────────────────────────────┐
│ 4. Python Environment Setup             │
│    - Create venv                        │
│    - Upgrade pip, setuptools, wheel     │
└─────────────────────────────────────────┘
                  ↓
┌─────────────────────────────────────────┐
│ 5. Install PyTorch with CUDA            │
│    - Detect CUDA version                │
│    - Install matching PyTorch           │
│    - Progress indicator                 │
└─────────────────────────────────────────┘
                  ↓
┌─────────────────────────────────────────┐
│ 6. Install Python Dependencies          │
│    - Install from requirements.txt      │
│    - Clone SadTalker repo               │
│    - Install SadTalker deps             │
└─────────────────────────────────────────┘
                  ↓
┌─────────────────────────────────────────┐
│ 7. Download AI Models (~10GB)           │
│    - Show progress bars                 │
│    - Allow skip (download later)        │
│    - Verify downloads                   │
└─────────────────────────────────────────┘
                  ↓
┌─────────────────────────────────────────┐
│ 8. Environment Configuration            │
│    - Generate secure API key            │
│    - Auto-detect local IP               │
│    - Create .env file                   │
└─────────────────────────────────────────┘
                  ↓
┌─────────────────────────────────────────┐
│ 9. Firewall Configuration               │
│    - Open TCP port 8001                 │
│    - Create inbound rule                │
│    - Requires admin                     │
└─────────────────────────────────────────┘
                  ↓
┌─────────────────────────────────────────┐
│ 10. Test Installation                   │
│    - Import torch, check CUDA           │
│    - Import fastapi                     │
│    - Test server start                  │
└─────────────────────────────────────────┘
                  ↓
┌─────────────────────────────────────────┐
│ 11. Optional: Install Windows Service   │
│    - Download NSSM if needed            │
│    - Register service                   │
│    - Set to auto-start                  │
│    - Start service                      │
└─────────────────────────────────────────┘
                  ↓
┌─────────────────────────────────────────┐
│ 12. Display Setup Summary               │
│    - Server URL (with IP)               │
│    - API Key                            │
│    - Next steps                         │
│    - How to test                        │
└─────────────────────────────────────────┘
```

### 2. Command-Line Parameters

**setup.ps1 parameters:**

```powershell
# Basic usage
.\setup.ps1

# Skip model downloads
.\setup.ps1 -SkipModels

# Don't install Windows Service
.\setup.ps1 -NoService

# Silent mode (minimal output)
.\setup.ps1 -Silent

# Force reinstall everything
.\setup.ps1 -Force

# Only admin tasks (firewall, service)
.\setup.ps1 -AdminOnly

# Repair broken installation
.\setup.ps1 -Repair

# Full uninstall
.\setup.ps1 -Uninstall
```

### 3. Windows Service Configuration

**NSSM Configuration:**

```powershell
Service Name:    AvatarFactoryGPU
Display Name:    Avatar Factory GPU Server
Description:     AI-powered video generation GPU worker
Startup Type:    Automatic
Application:     <venv-path>\Scripts\python.exe
Arguments:       server.py
Working Dir:     <gpu-worker-path>
Stdout Log:      logs\service.log
Stderr Log:      logs\service-error.log
Restart:         On failure (3 attempts, 60s delay)
```

**Service Management Scripts:**

- `service-install.ps1` - Install and start service
- `service-remove.ps1` - Stop and remove service
- `service-restart.ps1` - Restart running service
- Native Windows: `services.msc` for GUI management

### 4. User Experience

**For Basic Users:**
```batch
# Just double-click install.bat
install.bat
# Follow on-screen prompts (Y/N questions)
# Wait 15-30 minutes (depending on internet)
# Done! Service runs automatically
```

**For Advanced Users:**
```powershell
# Full control with parameters
.\setup.ps1 -SkipModels -NoService -Silent
# Later, install service separately
.\service-install.ps1
```

**Visual Enhancements:**
- Colored output (Green=success, Yellow=warning, Red=error)
- ASCII art banner on start
- Progress bars for downloads (with %)
- Step counters (Step 3/12)
- Estimated time remaining
- Final summary with all important info

### 5. Error Handling & Recovery

**Error Categories:**

1. **Prerequisites Missing:**
   - Clear message: "Python 3.10+ required"
   - Offer auto-install via winget
   - Provide manual download link

2. **Network Failures:**
   - Retry logic (3 attempts)
   - Resume partial downloads
   - Offline mode if models exist

3. **Permission Errors:**
   - Detect need for admin
   - Offer to re-launch elevated
   - Skip optional admin tasks

4. **Installation Failures:**
   - Rollback changes
   - Keep detailed logs
   - Suggest repair command

**Logging:**
- All output to `logs/install.log`
- Timestamps on every line
- Error stack traces included
- Upload-friendly format for support

**Recovery Commands:**
```powershell
# Repair broken installation
.\setup.ps1 -Repair

# Clean reinstall
.\setup.ps1 -Force

# Complete removal
.\setup.ps1 -Uninstall
```

### 6. Security Considerations

**API Key Generation:**
```powershell
# Use cryptographically secure random
[System.Security.Cryptography.RandomNumberGenerator]::Create()
# Base64 encode for readability
# 32 bytes = 256-bit security
```

**Firewall Rules:**
```powershell
# Only open port 8001
# Only TCP protocol
# Only inbound direction
# Named rule for easy removal
New-NetFirewallRule -DisplayName "Avatar Factory GPU" `
    -Direction Inbound -Protocol TCP -LocalPort 8001 `
    -Action Allow
```

**File Permissions:**
- venv/ - Current user only
- .env - Hidden + read-only after creation
- logs/ - Current user only

**Downloaded Files:**
- NSSM: Verify SHA256 checksum
- Models: Use official HuggingFace checksums
- Reject corrupted downloads

### 7. Compatibility Matrix

| OS Version | Status | Notes |
|------------|--------|-------|
| Windows 10 1809+ | ✅ Full support | PowerShell 5.1+ |
| Windows 11 | ✅ Full support | Native winget |
| Windows Server 2019+ | ✅ Supported | May need GUI features |
| Windows 10 <1809 | ⚠️ Limited | Manual winget install |
| Windows 7/8 | ❌ Not supported | EOL OS |

**PowerShell Requirements:**
- PowerShell 5.1+ (built into Windows 10/11)
- ExecutionPolicy: RemoteSigned or Bypass
- Optional: Windows Terminal for better colors

### 8. Testing Strategy

**Test Scenarios:**

1. **Clean Install:**
   - Fresh Windows 10 VM
   - No Python, no Git
   - Run `install.bat`
   - Verify all components installed

2. **Partial Install:**
   - Python already installed
   - Run setup
   - Verify reuses existing Python

3. **Reinstall:**
   - Run setup twice
   - Verify idempotent behavior
   - No errors on second run

4. **Offline Mode:**
   - Pre-download models
   - Disconnect network
   - Run setup
   - Verify uses cached files

5. **Non-Admin User:**
   - Standard user account
   - Run setup
   - Verify graceful degradation
   - Skip firewall/service if no admin

6. **Service Functionality:**
   - Install service
   - Reboot Windows
   - Verify auto-start
   - Check server responds

**Success Criteria:**
- ✅ Installation completes in <30 min
- ✅ Zero manual file editing required
- ✅ Service starts on boot
- ✅ Server accessible from network
- ✅ All tests pass in test_server.py

## Implementation Notes

### File Structure Changes

**New Files:**
```
gpu-worker/
├── setup.ps1                 # 500-800 lines
├── install.bat               # 10 lines (wrapper)
├── stop.bat                  # 20 lines
├── service-install.ps1       # 100 lines
├── service-remove.ps1        # 50 lines
├── service-restart.ps1       # 30 lines
├── check-system.ps1          # 150 lines
├── download-nssm.ps1         # 80 lines
├── configure-firewall.ps1    # 60 lines
└── README-WINDOWS.md         # New comprehensive guide
```

**Modified Files:**
```
gpu-worker/
├── README.md                 # Update with new install method
├── start.bat                 # Improve with better checks
└── .gitignore                # Add logs/, tools/
```

### Dependencies

**System Prerequisites:**
- Windows 10 1809+ or Windows 11
- 30GB free disk space
- 16GB+ RAM
- NVIDIA GPU with 8GB+ VRAM
- Internet connection (initial setup)

**Auto-Installable via winget:**
- Python 3.10+
- Git

**Manual Installation Required:**
- NVIDIA GPU drivers
- CUDA Toolkit 11.8+

**Downloaded During Setup:**
- NSSM 2.24 (~350KB)
- PyTorch with CUDA (~2GB)
- Python packages (~1GB)
- AI models (~10GB)

### Rollout Plan

**Phase 1: Core Setup Script**
- Implement setup.ps1 with all checks
- Test on clean Windows 10 VM
- Add logging and error handling

**Phase 2: Service Integration**
- Implement NSSM download
- Create service management scripts
- Test service auto-start

**Phase 3: Polish & Documentation**
- Add progress bars and colors
- Write comprehensive README-WINDOWS.md
- Create troubleshooting guide

**Phase 4: Testing & Validation**
- Test on multiple Windows versions
- Test with/without admin rights
- Test offline scenarios
- Get user feedback

## Success Metrics

**Installation Time:**
- Target: <30 minutes (from clone to running server)
- Current: ~60 minutes with manual steps

**User Actions Required:**
- Target: 1 (run install.bat)
- Current: 15+ manual steps

**Error Rate:**
- Target: <5% failure rate on supported systems
- Recovery: Clear error messages with solutions

**Adoption:**
- Measure through GitHub issues/discussions
- Track "installation help" issues (should decrease)

## Future Enhancements

**Possible Improvements:**

1. **Auto-Update Mechanism:**
   - Check for new versions
   - One-command update: `.\update.ps1`

2. **Web-Based Setup UI:**
   - Electron app for GUI setup
   - Visual progress indicators

3. **Pre-Built Installer:**
   - InnoSetup installer with embedded Python
   - Trade-off: Large size vs convenience

4. **Cloud Model Cache:**
   - Pre-download models to CDN
   - Faster downloads than HuggingFace

5. **Multiple GPU Support:**
   - Detect multiple GPUs
   - Configure load balancing

## Appendix

### NSSM Command Reference

```powershell
# Install service
nssm install AvatarFactoryGPU "C:\path\python.exe" "C:\path\server.py"

# Start service
nssm start AvatarFactoryGPU

# Stop service
nssm stop AvatarFactoryGPU

# Remove service
nssm remove AvatarFactoryGPU confirm

# Edit service
nssm edit AvatarFactoryGPU
```

### Firewall Command Reference

```powershell
# Add rule
New-NetFirewallRule -DisplayName "Avatar Factory GPU" `
    -Direction Inbound -Protocol TCP -LocalPort 8001 -Action Allow

# Remove rule
Remove-NetFirewallRule -DisplayName "Avatar Factory GPU"

# Check if rule exists
Get-NetFirewallRule -DisplayName "Avatar Factory GPU"
```

### Useful PowerShell Snippets

```powershell
# Check if running as admin
([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")

# Get GPU info
nvidia-smi --query-gpu=name,memory.total --format=csv

# Get local IP address
(Get-NetIPAddress -AddressFamily IPv4 -InterfaceAlias "Ethernet*" | Select-Object -First 1).IPAddress

# Generate secure random string
$bytes = New-Object byte[] 32
[Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
[Convert]::ToBase64String($bytes)
```

---

**Design Status:** ✅ Approved for Implementation  
**Next Step:** Create implementation plan with writing-plans skill
