# Socket Forwarder

A Go application that forwards data between different types of sockets, similar to socat functionality. It supports TCP, Unix domain sockets, and abstract Unix sockets with cross-platform compatibility including Android.

> **Note**: This project was created with GitHub Copilot AI assistance.

## Features

- ✅ TCP to Abstract Unix socket forwarding
- ✅ TCP to Unix socket file forwarding  
- ✅ Unix socket to TCP forwarding
- ✅ Bidirectional data forwarding
- ✅ Concurrent connection handling (fork mode)
- ✅ Graceful shutdown handling
- ✅ Cross-platform support (Windows, Linux, macOS, Android)
- ✅ Static binary compilation
- ✅ Unified build scripts with NDK_PATH environment variable
- ✅ Support for multiple Android architectures
- ✅ Detailed logging and error handling

## Prerequisites

### Required Software

1. **Go** (1.19 or later)
   - Download from: <https://golang.org/dl/>
   - Verify installation: `go version`

2. **Git** (for version control)
   - Download from: <https://git-scm.com/>
   - Verify installation: `git --version`

3. **Android NDK** (for Android builds)
   - Download from: <https://developer.android.com/ndk/downloads>
   - Recommended versions: NDK 25+ (supports both `.exe` and `.cmd` formats)

### Environment Setup

#### Windows (PowerShell)

```powershell
# Set NDK path
$env:NDK_PATH = "C:\Android\Sdk\ndk\29.0.13599879"

# Optional: Set Android API level (default: 21)
$env:ANDROID_API = "28"
```

#### Linux/macOS (Bash)

```bash
# Set NDK path
export NDK_PATH="/path/to/android/ndk/29.0.13599879"

# Optional: Set Android API level (default: 21)
export ANDROID_API="28"
```

#### WSL (Windows Subsystem for Linux)

```bash
# Fix PATH if needed
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/local/go/bin

# Set NDK path (use WSL path)
export NDK_PATH="/home/username/android-ndk-r27c"

# Make permanent (add to ~/.bashrc)
echo 'export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/local/go/bin' >> ~/.bashrc
echo 'export NDK_PATH=/home/username/android-ndk-r27c' >> ~/.bashrc
source ~/.bashrc
```

## Building

### Standard Go Build

```bash
# Build for current platform
go build -o sforwarder

# Run tests
go test ./...
```

### Android Cross-Compilation

#### Windows (PowerShell)

```powershell
# Set environment
$env:NDK_PATH = "d:\dev_tools\android\Sdk\ndk\29.0.13599879"

# Build all Android architectures
.\build-android.ps1

# Build with custom options
.\build-android.ps1 -OutputDir "dist/android" -Clean

# Show help
.\build-android.ps1 -Help
```

#### Linux/macOS (Bash)

```bash
# Set environment
export NDK_PATH="/path/to/android/ndk/29.0.13599879"

# Build all Android architectures
./build-android.sh

# Build with custom options
./build-android.sh --output-dir "dist/android" --clean

# Show help
./build-android.sh --help
```

#### WSL (Windows Subsystem for Linux)

```bash
# One-liner command (if PATH not fixed permanently)
wsl bash -c "export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/local/go/bin && export NDK_PATH=/home/varavut/android-ndk-r27c && cd /mnt/d/projects/sforwarder && ./build-android.sh"

# If environment is fixed permanently
cd /mnt/d/projects/sforwarder
./build-android.sh
```

## Usage

### Command Line Options

- `-listen-type`: Type of listener socket (tcp, unix)
- `-listen-addr`: Address to listen on
- `-connect-type`: Type of target socket (tcp, unix, abstract)
- `-connect-addr`: Address to connect to
- `-fork`: Enable concurrent connection handling (default: true)

### Basic Socket Forwarding

```bash
# Replace socat TCP-LISTEN:12347,fork ABSTRACT-CONNECT:webview
./sforwarder -listen-type tcp -listen-addr :12347 -connect-type abstract -connect-addr webview

# Forward TCP to Unix socket file
./sforwarder -listen-type tcp -listen-addr :8080 -connect-type unix -connect-addr /var/run/myapp.sock

# Forward Unix socket to TCP
./sforwarder -listen-type unix -listen-addr /tmp/input.sock -connect-type tcp -connect-addr 127.0.0.1:3000
```

### Android Deployment

```bash
# Push binary to device
adb push build/android/sforwarder-android-arm64-v8a /data/local/tmp/sforwarder

# Make executable
adb shell chmod 755 /data/local/tmp/sforwarder

# Test the binary
adb shell /data/local/tmp/sforwarder --help

# Run with root access (required for privileged ports)
adb shell
su
/data/local/tmp/sforwarder -listen-type tcp -listen-addr :12347 -connect-type abstract -connect-addr webview
```

## Cross-Platform Support

The application works on Windows, Linux, macOS, and Android:

- **Abstract Unix sockets**: Only available on Linux and Android
- **Windows**: Unix sockets are supported through named pipes
- **TCP forwarding**: Works on all platforms
- **Android**: Requires root access for privileged ports and system sockets

### Android Architectures

The build scripts create optimized binaries for all Android architectures:

- `sforwarder-android-arm64-v8a` (modern 64-bit devices)
- `sforwarder-android-armeabi-v7a` (older 32-bit devices)
- `sforwarder-android-x86_64` (64-bit emulators)
- `sforwarder-android-x86` (32-bit emulators)

## Troubleshooting

### NDK Build Failures

**Problem**: All builds fail with "Compiler not found"

```text
Failed architectures: arm64-v8a, armeabi-v7a, x86_64, x86
```

**Solutions**:

1. **Check NDK_PATH**: Ensure it points to a valid NDK installation
2. **NDK Version Compatibility**:
   - NDK 29.x+: Uses `.cmd` files on Windows
   - NDK 25.x and older: May use `.exe` files on Windows
   - The scripts automatically detect the correct format

3. **Verify NDK Structure**:

   ```bash
   # Check toolchain exists
   ls $NDK_PATH/toolchains/llvm/prebuilt/
   
   # Check compilers exist
   ls $NDK_PATH/toolchains/llvm/prebuilt/windows-x86_64/bin/*clang*
   ```

### WSL Issues

**Problem**: Command not found errors in WSL

```bash
./build-android.sh: line 108: mkdir: command not found
```

**Solution**: Fix PATH environment variable

```bash
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/local/go/bin
```

**Problem**: Go not found in WSL

```bash
bash: go: command not found
```

**Solution**: Add Go to PATH or install Go in WSL

```bash
# If Go is installed at /usr/local/go
export PATH=$PATH:/usr/local/go/bin

# Or install Go in WSL
curl -L https://go.dev/dl/go1.21.5.linux-amd64.tar.gz | sudo tar -xzf - -C /usr/local
```

### NDK Version Compatibility

| NDK Version | Windows Format | Linux/macOS Format | Status |
|------------|---------------|-------------------|---------|
| NDK 29.x   | `*-clang.cmd` | `*-clang`         | ✅ Supported |
| NDK 26-28  | `*-clang.cmd` | `*-clang`         | ✅ Supported |
| NDK 25.x   | `*-clang.exe` | `*-clang`         | ✅ Supported |
| NDK 21-24  | `*-clang.exe` | `*-clang`         | ✅ Supported |

## Project Structure

```text
socket-forwarder/
├── main.go                    # Main application
├── main_test.go              # Tests
├── go.mod                    # Go module definition
├── build-android.ps1         # Windows PowerShell build script
├── build-android.sh          # Linux/macOS bash build script
├── README.md                 # This comprehensive guide
├── ANDROID_BUILD.md         # Detailed Android build instructions
├── ANDROID_DEPLOYMENT.md    # Android deployment guide
├── BUILD_SUMMARY.md         # Build system summary
└── GITHUB_SETUP.md          # GitHub repository setup instructions
```

## Notes

- Abstract Unix domain sockets are Linux-specific. On other platforms, they fall back to regular Unix sockets.
- The application handles multiple concurrent connections when fork mode is enabled (default).
- Use Ctrl+C or SIGTERM to gracefully shutdown the forwarder.
- Unix socket files are automatically cleaned up when the application starts.
- Android requires root access for privileged ports and system sockets.
- The unified build scripts use NDK_PATH from environment variables (not hardcoded paths).

## Contributing

This project was created with GitHub Copilot AI assistance. When contributing:

1. Follow Go best practices
2. Update tests for new features
3. Update documentation
4. Test on multiple platforms
5. Ensure Android builds work

## License

[Add your license here]

## Documentation

For detailed information, see:

- `ANDROID_BUILD.md` - Comprehensive Android build instructions
- `ANDROID_DEPLOYMENT.md` - Android deployment guide
- `BUILD_SUMMARY.md` - Build system summary
- `GITHUB_SETUP.md` - GitHub repository setup instructions

## Support

For issues or questions:

1. Check the troubleshooting section above
2. Review the detailed documentation files
3. Create an issue on GitHub

---

**Created with GitHub Copilot AI** - This project demonstrates modern AI-assisted development practices.
- ARM, ARM64, x86, or x86_64 architecture
