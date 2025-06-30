# Android Build Scripts

This directory contains unified Android build scripts for the Go Socket Forwarder that support multiple architectures and use the NDK_PATH environment variable.

> **Note**: This build system was created with GitHub Copilot AI assistance.

## Prerequisites

1. **Android NDK**: Download and install the Android NDK
2. **Go**: Go 1.19 or later with Android support
3. **Environment Setup**: Set the NDK_PATH environment variable

## Setting up NDK_PATH

### Windows (PowerShell)
```powershell
# Set for current session
$env:NDK_PATH = "C:\Android\Sdk\ndk\25.2.9519653"

# Set permanently (requires restart)
[Environment]::SetEnvironmentVariable("NDK_PATH", "C:\Android\Sdk\ndk\25.2.9519653", "User")
```

### Linux/macOS (Bash)
```bash
# Set for current session
export NDK_PATH=/path/to/android/ndk/25.2.9519653

# Set permanently (add to ~/.bashrc or ~/.zshrc)
echo 'export NDK_PATH=/path/to/android/ndk/25.2.9519653' >> ~/.bashrc
```

## Build Scripts

### PowerShell Script (Windows) - `build-android.ps1`

```powershell
# Build all architectures
.\build-android.ps1

# Clean build and specify output directory
.\build-android.ps1 -Clean -OutputDir "dist/android"

# Show help
.\build-android.ps1 -Help
```

**Features:**
- Builds for ARM64, ARM (v7a), x86_64, and x86 architectures
- Uses NDK_PATH environment variable
- Configurable Android API level (default: 21)
- Clean build option
- Detailed build progress and summary
- File size reporting

### Bash Script (Linux/macOS) - `build-android.sh`

```bash
# Build all architectures
./build-android.sh

# Clean build and specify output directory
./build-android.sh --clean --output-dir "dist/android"

# Show help
./build-android.sh --help
```

**Features:**
- Cross-platform support (Linux and macOS)
- Auto-detects NDK host platform
- Same architecture support as PowerShell version
- Color-coded output
- Progress tracking

## Supported Architectures

| Architecture | ABI Name     | Description                    |
|-------------|--------------|--------------------------------|
| ARM64       | arm64-v8a    | 64-bit ARM (modern devices)   |
| ARM         | armeabi-v7a  | 32-bit ARM (older devices)    |
| x86_64      | x86_64       | 64-bit x86 (emulators)        |
| x86         | x86          | 32-bit x86 (older emulators)  |

## Environment Variables

| Variable     | Description                               | Default |
|-------------|-------------------------------------------|---------|
| NDK_PATH    | Path to Android NDK installation         | Required|
| ANDROID_API | Android API level for compilation        | 21      |

## Output

Both scripts create binaries in the specified output directory with the following naming convention:
```
sforwarder-android-<architecture>
```

Examples:
- `sforwarder-android-arm64-v8a`
- `sforwarder-android-armeabi-v7a`
- `sforwarder-android-x86_64`
- `sforwarder-android-x86`

## Deployment to Android Device

After building, you can deploy to an Android device:

```bash
# Push to device
adb push build/android/sforwarder-android-arm64-v8a /data/local/tmp/sforwarder

# Make executable
adb shell chmod 755 /data/local/tmp/sforwarder

# Test the binary
adb shell /data/local/tmp/sforwarder --help
```

## Troubleshooting

### Common Issues

1. **NDK_PATH not set**
   ```
   Error: NDK_PATH environment variable is not set
   ```
   **Solution:** Set the NDK_PATH environment variable as described above.

2. **Compiler not found**
   ```
   Warning: Compiler not found: /path/to/ndk/toolchains/...
   ```
   **Solution:** 
   - Verify NDK_PATH points to a valid NDK installation
   - Check that the NDK version supports the target API level
   - Ensure the NDK toolchain exists for your host platform
   - **Note for NDK 25+**: Newer NDK versions use `.cmd` files on Windows instead of `.exe` files

3. **All builds fail with "Compiler not found"**
   ```
   Failed architectures: arm64-v8a, armeabi-v7a, x86_64, x86
   ```
   **Solution:** This usually indicates an NDK version compatibility issue:
   - **NDK 29.x and newer**: Uses `.cmd` wrapper scripts (Windows) or shell scripts (Linux/macOS)
   - **NDK 25.x and older**: May use `.exe` files on Windows
   - The build scripts automatically detect the correct format

4. **Build fails with "unsupported platform"**
   ```
   Error: Unsupported platform: xxx
   ```
   **Solution:** The bash script only supports Linux and macOS. Use PowerShell script on Windows.

5. **Permission denied (Linux/macOS)**
   ```
   permission denied: ./build-android.sh
   ```
   **Solution:** Make the script executable:
   ```bash
   chmod +x build-android.sh
   ```

### NDK Version Compatibility

The build scripts support Android NDK versions 21 and newer:

| NDK Version | Windows Compiler Format | Linux/macOS Format | Supported |
|------------|-------------------------|-------------------|-----------|
| NDK 29.x   | `*-clang.cmd`          | `*-clang`         | ✅ Yes    |
| NDK 26-28  | `*-clang.cmd`          | `*-clang`         | ✅ Yes    |
| NDK 25.x   | `*-clang.exe`          | `*-clang`         | ✅ Yes    |
| NDK 21-24  | `*-clang.exe`          | `*-clang`         | ✅ Yes    |

### Verifying NDK Installation

Check if your NDK is properly installed:

```bash
# List available toolchains
ls $NDK_PATH/toolchains/llvm/prebuilt/

# Check for specific compiler
ls $NDK_PATH/toolchains/llvm/prebuilt/*/bin/*android*-clang
```

## Integration with CI/CD

### GitHub Actions Example

```yaml
name: Build Android
on: [push, pull_request]

jobs:
  build-android:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3
    
    - name: Setup Go
      uses: actions/setup-go@v3
      with:
        go-version: '1.21'
    
    - name: Setup Android NDK
      uses: nttld/setup-ndk@v1
      with:
        ndk-version: r25c
    
    - name: Build for Android
      run: |
        export NDK_PATH=$ANDROID_NDK_ROOT
        ./build-android.sh
    
    - name: Upload artifacts
      uses: actions/upload-artifact@v3
      with:
        name: android-binaries
        path: build/android/
```

## Legacy Scripts

The following legacy scripts have been consolidated into the new unified scripts:
- `build-android.ps1` (old single-arch version)
- `build-android.ps1` and `build-android.sh` (new unified scripts)
- Various legacy batch scripts (now removed)

These legacy scripts can be safely removed after migrating to the new scripts.
