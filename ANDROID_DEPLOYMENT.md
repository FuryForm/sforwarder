# Android Deployment Guide

## Successfully Built Binaries

The following Android binaries have been created:

- `sforwarder-android-arm64` (2,490,432 bytes) - For ARM64/AArch64 devices (most modern Android phones)
- `sforwarder-android-arm` (2,317,064 bytes) - For ARM devices (older Android phones)

## Deployment to Android Device

### Prerequisites

1. **Root Access**: The application requires root access to:
   - Bind to privileged ports (< 1024)
   - Access system sockets
   - Create Unix domain sockets in system directories

2. **ADB (Android Debug Bridge)**: Install Android SDK platform-tools

### Installation Steps

1. **Enable USB Debugging** on your Android device
2. **Connect** your device to the computer
3. **Push the binary** to your device:

```bash
# For ARM64 devices (recommended for modern phones)
adb push sforwarder-android-arm64 /data/local/tmp/sforwarder
adb shell chmod +x /data/local/tmp/sforwarder

# For ARM devices (older phones)
adb push sforwarder-android-arm /data/local/tmp/sforwarder
adb shell chmod +x /data/local/tmp/sforwarder
```

4. **Get shell access**:
```bash
adb shell
su  # Requires root
```

### Usage Examples on Android

#### Forward TCP to Abstract Unix Socket (your original use case)
```bash
# On Android device (as root)
/data/local/tmp/sforwarder -listen-type tcp -listen-addr :12347 -connect-type abstract -connect-addr webview
```

#### Forward TCP to Unix Socket File
```bash
/data/local/tmp/sforwarder -listen-type tcp -listen-addr :8080 -connect-type unix -connect-addr /data/local/tmp/mysocket
```

#### Forward Unix Socket to TCP
```bash
/data/local/tmp/sforwarder -listen-type unix -listen-addr /data/local/tmp/input.sock -connect-type tcp -connect-addr 127.0.0.1:3000
```

### Running as Service

To run the forwarder as a background service on Android:

```bash
# Start in background
nohup /data/local/tmp/sforwarder -listen-type tcp -listen-addr :12347 -connect-type abstract -connect-addr webview > /data/local/tmp/sforwarder.log 2>&1 &

# Check if running
ps | grep sforwarder

# View logs
tail -f /data/local/tmp/sforwarder.log

# Kill the service
pkill sforwarder
```

### Permissions and Security

#### Required Permissions
- `CAP_NET_BIND_SERVICE` - For binding to privileged ports
- File system access to socket directories
- Network access

#### SELinux Considerations
On devices with enforcing SELinux, you may need to:
```bash
# Temporarily set SELinux to permissive (requires root)
setenforce 0

# Check current SELinux status
getenforce
```

### Troubleshooting

#### Common Issues

1. **Permission Denied**
   - Ensure you have root access
   - Check file permissions: `ls -la /data/local/tmp/sforwarder`
   - Make sure the binary is executable: `chmod +x /data/local/tmp/sforwarder`

2. **Address Already in Use**
   - Check if port is already bound: `netstat -tulpn | grep :12347`
   - Kill existing processes using the port

3. **Cannot Connect to Abstract Socket**
   - Verify the abstract socket exists: `netstat -xlpn | grep webview`
   - Check if the target application is running

4. **SELinux Denials**
   - Check SELinux logs: `dmesg | grep denied`
   - Consider setting SELinux to permissive mode for testing

#### Testing the Installation

```bash
# Test TCP listener
/data/local/tmp/sforwarder -listen-type tcp -listen-addr :12347 -connect-type tcp -connect-addr google.com:80

# In another terminal, test the connection
telnet localhost 12347
```

### Architecture Detection

To determine which binary to use:

```bash
adb shell getprop ro.product.cpu.abi
```

Common results:
- `arm64-v8a` → Use `sforwarder-android-arm64`
- `armeabi-v7a` → Use `sforwarder-android-arm`
- `x86_64` → Use `sforwarder-android-x86_64` (if built)
- `x86` → Use `sforwarder-android-x86` (if built)

### Build Information

- **Compiler**: Android NDK 29.0.13599879 with Clang
- **Target API Level**: 28 (Android 9.0)
- **Go Version**: 1.24.2
- **CGO**: Enabled for Android compatibility
- **Optimization**: Stripped symbols (-s -w) for smaller binary size

The binaries are statically linked and should work on most Android devices running Android 9.0 (API 28) or later.
