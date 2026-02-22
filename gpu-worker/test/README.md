# GPU Worker Test Suite

Test suite for Avatar Factory GPU Worker automation scripts.

## Overview

| Script | Purpose |
|--------|---------|
| `test-install.ps1` | Tests setup.ps1: prerequisites, Python, venv, PyTorch, deps, .env, logs |
| `test-service.ps1` | Tests service-install, service-status, service-uninstall |
| `test-server.ps1` | Tests server.py: health, CUDA, models, API endpoints |

## Prerequisites

- **Windows**: Full test coverage. Run as regular user (admin for service tests).
- **macOS/Linux**: Partial coverage; Windows-specific tests are skipped.
- **PowerShell**: 5.1+ (Windows) or PowerShell Core (pwsh).
- **Setup**: Run `.\setup.ps1 -Silent -SkipModels -NoService` before install tests.

## Running Tests

From `gpu-worker` directory:

```powershell
cd gpu-worker/test
powershell -ExecutionPolicy Bypass -File test-install.ps1
powershell -ExecutionPolicy Bypass -File test-service.ps1
powershell -ExecutionPolicy Bypass -File test-server.ps1
```

Or run all:

```powershell
Get-ChildItem test\*.ps1 | ForEach-Object { & powershell -ExecutionPolicy Bypass -File $_.FullName }
```

## Interpreting Results

- **PASS**: Test succeeded
- **FAIL**: Test failed
- **SKIP**: Test skipped (e.g., Windows-only on non-Windows)
- Exit code 0 = all run tests passed; 1 = one or more failed

## CI Integration

Example GitHub Actions (Windows runner):

```yaml
- run: cd gpu-worker && .\setup.ps1 -Silent -SkipModels -NoService
- run: cd gpu-worker/test && powershell -ExecutionPolicy Bypass -File test-install.ps1
- run: cd gpu-worker/test && powershell -ExecutionPolicy Bypass -File test-server.ps1
```

Note: Service tests require admin; server tests require GPU for full pass.
