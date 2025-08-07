#!/bin/bash
# Android Build Script for Go Socket Forwarder
# Builds for multiple Android architectures using NDK

# Enable error handling
set -e

# Default values
OUTPUT_DIR="build/android"
CLEAN=false
HELP=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --output-dir)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        --clean)
            CLEAN=true
            shift
            ;;
        --help|-h)
            HELP=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

if [[ "$HELP" == "true" ]]; then
    echo "Android Build Script for Go Socket Forwarder"
    echo ""
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  --output-dir <path>  Output directory for binaries (default: build/android)"
    echo "  --clean              Clean build directory before building"
    echo "  --help, -h           Show this help message"
    echo ""
    echo "Environment Variables:"
    echo "  NDK_PATH             Path to Android NDK (required)"
    echo "  ANDROID_API          Android API level (default: 21)"
    echo ""
    echo "Features:"
    echo "  - Builds for all Android architectures (ARM64, ARM, x86_64, x86)"
    echo "  - Automatic binary stripping using llvm-strip for minimal size"
    echo "  - Go build optimization with -ldflags '-s -w'"
    echo ""
    echo "Examples:"
    echo "  $0"
    echo "  $0 --output-dir dist --clean"
    echo "  NDK_PATH=/path/to/ndk ANDROID_API=28 $0"
    exit 0
fi

# Check for required environment variables
if [[ -z "$NDK_PATH" ]]; then
    echo "Error: NDK_PATH environment variable is not set."
    echo "Please set it to your Android NDK path."
    echo "Example: export NDK_PATH=/path/to/android/ndk/25.2.9519653"
    exit 1
fi

if [[ ! -d "$NDK_PATH" ]]; then
    echo "Error: NDK_PATH directory does not exist: $NDK_PATH"
    exit 1
fi

# Set default Android API level if not specified
if [[ -z "${ANDROID_API:-}" ]]; then
    ANDROID_API="21"
fi

# Determine NDK host platform
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    NDK_HOST="linux-x86_64"
elif [[ "$OSTYPE" == "darwin"* ]]; then
    NDK_HOST="darwin-x86_64"
else
    echo "Error: Unsupported platform: $OSTYPE"
    echo "This script supports Linux and macOS only"
    exit 1
fi

# Android architectures to build for
declare -A ARCHITECTURES=(
    ["arm64-v8a"]="arm64 android $NDK_PATH/toolchains/llvm/prebuilt/$NDK_HOST/bin/aarch64-linux-android$ANDROID_API-clang"
    ["armeabi-v7a"]="arm android $NDK_PATH/toolchains/llvm/prebuilt/$NDK_HOST/bin/armv7a-linux-androideabi$ANDROID_API-clang 7"
    ["x86_64"]="amd64 android $NDK_PATH/toolchains/llvm/prebuilt/$NDK_HOST/bin/x86_64-linux-android$ANDROID_API-clang"
    ["x86"]="386 android $NDK_PATH/toolchains/llvm/prebuilt/$NDK_HOST/bin/i686-linux-android$ANDROID_API-clang"
)

echo -e "\033[32mGo Socket Forwarder - Android Build Script\033[0m"
echo -e "\033[32m==========================================\033[0m"
echo -e "\033[36mNDK Path: $NDK_PATH\033[0m"
echo -e "\033[36mNDK Host: $NDK_HOST\033[0m"
echo -e "\033[36mAndroid API: $ANDROID_API\033[0m"
echo -e "\033[36mOutput Directory: $OUTPUT_DIR\033[0m"
echo ""

# Clean build directory if requested
if [[ "$CLEAN" == "true" ]] && [[ -d "$OUTPUT_DIR" ]]; then
    echo -e "\033[33mCleaning build directory...\033[0m"
    rm -rf "$OUTPUT_DIR"
fi

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Get Go module name
MODULE_NAME="sforwarder"
if [[ -f "go.mod" ]]; then
    MODULE_LINE=$(head -n 1 go.mod)
    if [[ $MODULE_LINE =~ ^module[[:space:]]+(.+)$ ]]; then
        MODULE_NAME=$(basename "${BASH_REMATCH[1]}")
    fi
fi

TOTAL_BUILDS=${#ARCHITECTURES[@]}
CURRENT_BUILD=0
SUCCESSFUL_BUILDS=0
FAILED_BUILDS=()

for ARCH_NAME in "${!ARCHITECTURES[@]}"; do
    ((CURRENT_BUILD++))
    
    # Parse architecture configuration
    IFS=' ' read -ra ARCH_CONFIG <<< "${ARCHITECTURES[$ARCH_NAME]}"
    GOARCH="${ARCH_CONFIG[0]}"
    GOOS="${ARCH_CONFIG[1]}"
    CC="${ARCH_CONFIG[2]}"
    GOARM="${ARCH_CONFIG[3]:-}"
    
    OUTPUT_FILE="$OUTPUT_DIR/$MODULE_NAME-android-$ARCH_NAME"
    
    echo -e "\033[33m[$CURRENT_BUILD/$TOTAL_BUILDS] Building for $ARCH_NAME...\033[0m"
    
    # Check if compiler exists
    if [[ ! -f "$CC" ]]; then
        echo -e "\033[33m  Warning: Compiler not found: $CC\033[0m"
        echo -e "\033[33m  Skipping $ARCH_NAME build\033[0m"
        FAILED_BUILDS+=("$ARCH_NAME")
        continue
    fi
    
    # Set environment variables for this build
    export GOOS="$GOOS"
    export GOARCH="$GOARCH"
    export CC="$CC"
    export CGO_ENABLED="1"
    
    if [[ -n "$GOARM" ]]; then
        export GOARM="$GOARM"
    else
        unset GOARM
    fi
    
    # Build the binary
    echo -e "\033[37m  GOOS=$GOOS GOARCH=$GOARCH CC=$CC\033[0m"
    
    if go build -ldflags "-s -w" -o "$OUTPUT_FILE" . 2>/dev/null; then
        FILE_SIZE_BEFORE=$(stat -c%s "$OUTPUT_FILE" 2>/dev/null || stat -f%z "$OUTPUT_FILE" 2>/dev/null || echo "0")
        FILE_SIZE_BEFORE_MB=$(echo "scale=2; $FILE_SIZE_BEFORE / 1024 / 1024" | bc -l 2>/dev/null || echo "?.?")
        
        # Strip the binary using NDK strip tool for further size reduction
        STRIP_TOOL="$NDK_PATH/toolchains/llvm/prebuilt/$NDK_HOST/bin/llvm-strip"
        
        if [[ -f "$STRIP_TOOL" ]]; then
            echo -e "\033[37m  Stripping binary...\033[0m"
            if "$STRIP_TOOL" "$OUTPUT_FILE" 2>/dev/null; then
                FILE_SIZE_AFTER=$(stat -c%s "$OUTPUT_FILE" 2>/dev/null || stat -f%z "$OUTPUT_FILE" 2>/dev/null || echo "0")
                FILE_SIZE_AFTER_MB=$(echo "scale=2; $FILE_SIZE_AFTER / 1024 / 1024" | bc -l 2>/dev/null || echo "?.?")
                SIZE_REDUCTION=$(echo "scale=1; ($FILE_SIZE_BEFORE - $FILE_SIZE_AFTER) * 100 / $FILE_SIZE_BEFORE" | bc -l 2>/dev/null || echo "0")
                echo -e "\033[32m  ✓ Built and stripped: $OUTPUT_FILE (${FILE_SIZE_AFTER_MB} MB, ${SIZE_REDUCTION}% smaller)\033[0m"
            else
                echo -e "\033[33m  Strip failed, keeping unstripped binary (${FILE_SIZE_BEFORE_MB} MB)\033[0m"
            fi
        else
            echo -e "\033[32m  ✓ Built successfully: $OUTPUT_FILE (${FILE_SIZE_BEFORE_MB} MB)\033[0m"
        fi
        
        ((SUCCESSFUL_BUILDS++))
    else
        echo -e "\033[31m  ✗ Build failed for $ARCH_NAME\033[0m"
        FAILED_BUILDS+=("$ARCH_NAME")
    fi
done

# Clean up environment variables
unset GOOS GOARCH CC CGO_ENABLED GOARM

echo ""
echo -e "\033[32mBuild Summary\033[0m"
echo -e "\033[32m=============\033[0m"
echo -e "\033[36mTotal builds: $TOTAL_BUILDS\033[0m"
echo -e "\033[32mSuccessful: $SUCCESSFUL_BUILDS\033[0m"
echo -e "\033[31mFailed: ${#FAILED_BUILDS[@]}\033[0m"

if [[ ${#FAILED_BUILDS[@]} -gt 0 ]]; then
    FAILED_LIST=$(IFS=', '; echo "${FAILED_BUILDS[*]}")
    echo -e "\033[31mFailed architectures: $FAILED_LIST\033[0m"
fi

if [[ $SUCCESSFUL_BUILDS -gt 0 ]]; then
    echo ""
    echo -e "\033[32mBuilt binaries:\033[0m"
    for file in "$OUTPUT_DIR"/$MODULE_NAME-android-*; do
        if [[ -f "$file" ]]; then
            FILE_SIZE=$(stat -c%s "$file" 2>/dev/null || stat -f%z "$file" 2>/dev/null || echo "0")
            FILE_SIZE_MB=$(echo "scale=2; $FILE_SIZE / 1024 / 1024" | bc -l 2>/dev/null || echo "?.?")
            echo -e "\033[36m  $(basename "$file") (${FILE_SIZE_MB} MB)\033[0m"
        fi
    done
    
    echo ""
    echo -e "\033[33mTo deploy to Android device:\033[0m"
    echo -e "\033[37m  adb push $OUTPUT_DIR/$MODULE_NAME-android-arm64-v8a /data/local/tmp/$MODULE_NAME\033[0m"
    echo -e "\033[37m  adb shell chmod 755 /data/local/tmp/$MODULE_NAME\033[0m"
    echo -e "\033[37m  adb shell /data/local/tmp/$MODULE_NAME --help\033[0m"
fi

if [[ ${#FAILED_BUILDS[@]} -gt 0 ]]; then
    exit 1
fi

echo ""
echo -e "\033[32mAll builds completed successfully!\033[0m"
