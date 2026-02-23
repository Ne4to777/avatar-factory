# Docker Build Optimization

## Problem: Slow Rebuilds

**Before optimization:**
- Every code change triggers full rebuild
- PyTorch (~3-4GB) re-downloaded every time
- Build time: 15-20 minutes per rebuild

## Solution: Layer Caching Strategy

### Dockerfile Layer Order (optimized)

```dockerfile
# 1. Base image (never changes)
FROM nvidia/cuda:11.8.0-cudnn8-runtime-ubuntu22.04

# 2. System dependencies (rarely change)
RUN apt-get install ...

# 3. Miniconda (rarely changes)
RUN wget miniconda...

# 4. Create conda environment (rarely changes)
RUN conda create -n avatar python=3.11

# 5. Copy ONLY dependency files (rarely change)
COPY requirements.txt pyproject.toml ./

# 6. Install PyTorch ~3-4GB (CACHED if requirements unchanged!)
RUN conda install pytorch==2.7.0 ...

# 7. Install pip dependencies (CACHED if requirements unchanged!)
RUN pip install -r requirements.txt

# 8. Copy code LAST (changes frequently, doesn't break cache)
COPY . .
```

### Key Principle

**Copy files in order of change frequency:**
1. **Rarely change** → Copy first → Cache for longer
2. **Change often** → Copy last → Don't break cache

**Before:**
```dockerfile
RUN conda install pytorch  # 3GB download
COPY . .                   # Code changes → cache broken → re-download!
```

**After:**
```dockerfile
COPY requirements.txt .    # Rarely changes
RUN conda install pytorch  # 3GB download → CACHED
COPY . .                   # Code changes → cache still valid!
```

## Build Context Optimization

### Problem: 1GB+ Transfer
Docker was copying entire project including:
- `node_modules/` (676MB)
- Tests, docs, etc. (100MB+)

### Solution: `.dockerignore`

Created `.dockerignore` in project root:
```
node_modules/
**/__pycache__/
*.md
tests/
docs/
```

**Result:** Build context reduced from 1GB+ to **60KB**

## Build Cache Mounts (Optional)

Using Docker BuildKit cache mounts for even faster rebuilds:

```dockerfile
# Cache conda packages
RUN --mount=type=cache,target=/opt/conda/pkgs \
    conda install pytorch...

# Cache pip packages
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install -r requirements.txt
```

**Enable with:**
```bash
DOCKER_BUILDKIT=1 docker build ...
```

## Build Times

### First Build (no cache)
- Download base image: ~1 minute
- Install system deps: ~1 minute
- Install Miniconda: ~1 minute
- Install PyTorch: ~5-10 minutes
- Install pip deps: ~2-3 minutes
- **Total: 15-20 minutes**

### Cached Build (code changes only)
- Layers 1-7: **CACHED** (0 seconds)
- Copy code: <1 second
- Install project: <10 seconds
- **Total: 2-3 minutes**

### Cached Build (requirements change)
- Layers 1-5: **CACHED** (0 seconds)
- Install PyTorch: ~5-10 minutes (re-download)
- Install pip deps: ~2-3 minutes
- Copy code: <1 second
- **Total: 10-15 minutes**

## Best Practices

### 1. Build from Correct Directory

**❌ Wrong (copies 1GB):**
```bash
cd avatar-factory
docker build -f gpu-worker/Dockerfile -t avatar-gpu-worker:latest .
                                                                   ^ BAD!
```

**✅ Correct (copies 60KB):**
```bash
cd avatar-factory
docker build -f gpu-worker/Dockerfile -t avatar-gpu-worker:latest gpu-worker
                                                                   ^^^^^^^^^^
# Or use Makefile
make build-gpu
```

### 2. Keep requirements.txt Stable

**❌ Don't:**
- Change versions unnecessarily
- Add/remove packages frequently
- Use `>=` without upper bounds

**✅ Do:**
- Pin versions: `diffusers==0.30.0`
- Group changes together
- Test locally before rebuilding Docker

### 3. Use .dockerignore

Always exclude from build context:
- `node_modules/`
- `__pycache__/`
- `*.pyc`
- `.git/`
- Large model files
- Test files
- Documentation

### 4. Enable BuildKit

Add to your environment:
```bash
export DOCKER_BUILDKIT=1
```

Or in Makefile/scripts:
```bash
DOCKER_BUILDKIT=1 docker build ...
```

## Monitoring Build

### Check what's being copied
```bash
# See build context size
DOCKER_BUILDKIT=1 docker build --progress=plain -f gpu-worker/Dockerfile gpu-worker 2>&1 | grep "transferring context"

# Should show:
# => transferring context: 60KB
```

### Check layer caching
```bash
docker build --progress=plain ...

# Look for:
# => CACHED [stage-0 6/14] RUN conda install pytorch...  # ✅ Using cache
# => [stage-0 7/14] RUN pip install ...                   # ❌ Rebuilding
```

## Troubleshooting

### "Still downloading 5GB on every build"

**Cause:** Code copied BEFORE PyTorch installation
**Fix:** Reorder Dockerfile (see above)

### "transferring context: 1GB+"

**Cause:** Building from wrong directory or missing .dockerignore
**Fix:**
```bash
# Check build command
docker build -f gpu-worker/Dockerfile -t avatar-gpu-worker:latest gpu-worker
                                                                   ^^^^^^^^^^
# Not "."!

# Check .dockerignore exists
ls -la avatar-factory/.dockerignore
```

### "Cache not working after requirements.txt change"

**Expected behavior!** Changing requirements.txt invalidates:
- PyTorch installation (re-downloads ~3-4GB)
- Pip dependencies (re-downloads ~500MB)

**Minimize:** Batch requirements.txt changes together.

## Summary

| Optimization | Before | After | Savings |
|--------------|--------|-------|---------|
| Build context | 1GB+ | 60KB | ~99.9% |
| Code change rebuild | 15-20 min | 2-3 min | ~85% |
| Layer caching | None | Full | ~15 min |

**Result:** Fast, efficient Docker builds with minimal wait time for code changes.
