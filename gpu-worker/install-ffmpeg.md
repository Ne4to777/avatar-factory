# Installing FFmpeg on Windows

FFmpeg is required for video processing with MuseTalk.

## Option 1: Using Chocolatey (Recommended)

If you have Chocolatey installed:

```powershell
choco install ffmpeg
```

## Option 2: Manual Installation

1. Download ffmpeg from: https://ffmpeg.org/download.html#build-windows
   - Or direct link: https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip

2. Extract the zip file to `C:\ffmpeg`

3. Add to PATH:
   - Open System Properties → Environment Variables
   - Edit "Path" system variable
   - Add: `C:\ffmpeg\bin`
   - Click OK

4. Restart command prompt and verify:
   ```cmd
   ffmpeg -version
   ```

## Option 3: Using Scoop

```powershell
scoop install ffmpeg
```

## Verify Installation

After installation, run:

```cmd
ffmpeg -version
```

You should see ffmpeg version information.

## Troubleshooting

If `ffmpeg -version` doesn't work after installation:
1. Restart all command prompts/terminals
2. Verify PATH includes ffmpeg bin directory
3. Log out and log back in to Windows
