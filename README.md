# Socket Forwarder

A Go application that forwards data between different types of sockets, similar to socat functionality.

> **Note**: This project was created with GitHub Copilot AI assistance.

## Features

- Forward data between TCP and Unix domain sockets
- Support for abstract Unix domain sockets (Linux)
- Concurrent connection handling (fork mode)
- Bidirectional data forwarding
- Graceful shutdown handling

## Usage

```bash
# Build the application
go build -o sforwarder

# Forward TCP port 12347 to abstract Unix socket "webview"
./sforwarder -listen-type tcp -listen-addr :12347 -connect-type abstract -connect-addr webview

# Forward TCP port 8080 to Unix socket file
./sforwarder -listen-type tcp -listen-addr :8080 -connect-type unix -connect-addr /tmp/socket

# Forward Unix socket to TCP port
./sforwarder -listen-type unix -listen-addr /tmp/listen.sock -connect-type tcp -connect-addr localhost:9090
```

## Command Line Options

- `-listen-type`: Type of listener socket (tcp, unix)
- `-listen-addr`: Address to listen on
- `-connect-type`: Type of target socket (tcp, unix, abstract)
- `-connect-addr`: Address to connect to
- `-fork`: Enable concurrent connection handling (default: true)

## Examples

### Replace socat TCP-LISTEN:12347,fork ABSTRACT-CONNECT:webview

```bash
./sforwarder -listen-type tcp -listen-addr :12347 -connect-type abstract -connect-addr webview
```

### Forward TCP to Unix socket file

```bash
./sforwarder -listen-type tcp -listen-addr :8080 -connect-type unix -connect-addr /var/run/myapp.sock
```

### Forward Unix socket to TCP

```bash
./sforwarder -listen-type unix -listen-addr /tmp/input.sock -connect-type tcp -connect-addr 127.0.0.1:3000
```

## Notes

- Abstract Unix domain sockets are Linux-specific. On other platforms, they fall back to regular Unix sockets.
- The application handles multiple concurrent connections when fork mode is enabled (default).
- Use Ctrl+C or SIGTERM to gracefully shutdown the forwarder.
- Unix socket files are automatically cleaned up when the application starts.

## Building

```bash
go mod tidy
go build -o sforwarder
```

## Cross-platform Support

The application works on Windows, Linux, macOS, and Android, with the following considerations:

- Abstract Unix sockets are only available on Linux and Android
- On Windows, Unix sockets are supported through named pipes
- TCP forwarding works on all platforms

### Android Support

Cross-compilation for Android is supported using the Android NDK. Use the unified build scripts:

**Windows (PowerShell):**
```powershell
# Set NDK path
$env:NDK_PATH = "C:\Android\Sdk\ndk\25.2.9519653"

# Build for all Android architectures
.\build-android.ps1
```

**Linux/macOS (Bash):**
```bash
# Set NDK path
export NDK_PATH=/path/to/android/ndk/25.2.9519653

# Build for all Android architectures
./build-android.sh
```

This creates optimized binaries for all Android architectures:
- `sforwarder-android-arm64-v8a` (modern 64-bit devices)
- `sforwarder-android-armeabi-v7a` (older 32-bit devices)
- `sforwarder-android-x86_64` (64-bit emulators)
- `sforwarder-android-x86` (32-bit emulators)

See `ANDROID_BUILD.md` for detailed build instructions and `ANDROID_DEPLOYMENT.md` for deployment.

**Android Requirements:**
- Root access for privileged ports and system sockets
- Android API 21 or later (configurable)
- ARM, ARM64, x86, or x86_64 architecture
