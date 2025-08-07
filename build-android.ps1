#!/usr/bin/env pwsh
# Android Build Script for Go Socket Forwarder
# Builds for multiple Android architectures using NDK

param(
    [string]$OutputDir = "build/android",
    [switch]$Clean,
    [switch]$Help
)

if ($Help) {
    Write-Host "Android Build Script for Go Socket Forwarder"
    Write-Host ""
    Write-Host "Usage: .\build-android.ps1 [options]"
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  -OutputDir <path>  Output directory for binaries (default: build/android)"
    Write-Host "  -Clean             Clean build directory before building"
    Write-Host "  -Help              Show this help message"
    Write-Host ""
    Write-Host "Environment Variables:"
    Write-Host "  NDK_PATH           Path to Android NDK (required)"
    Write-Host "  ANDROID_API        Android API level (default: 21)"
    Write-Host ""
    Write-Host "Features:"
    Write-Host "  - Builds for all Android architectures (ARM64, ARM, x86_64, x86)"
    Write-Host "  - Automatic binary stripping using llvm-strip for minimal size"
    Write-Host "  - Go build optimization with -ldflags '-s -w'"
    Write-Host ""
    Write-Host "Examples:"
    Write-Host "  .\build-android.ps1"
    Write-Host "  .\build-android.ps1 -OutputDir dist -Clean"
    exit 0
}

# Check for required environment variables
if (-not $env:NDK_PATH) {
    Write-Error "NDK_PATH environment variable is not set. Please set it to your Android NDK path."
    Write-Error "Example: `$env:NDK_PATH = 'C:\Android\Sdk\ndk\25.2.9519653'"
    exit 1
}

if (-not (Test-Path $env:NDK_PATH)) {
    Write-Error "NDK_PATH directory does not exist: $env:NDK_PATH"
    exit 1
}

# Set default Android API level if not specified
if (-not $env:ANDROID_API) {
    $env:ANDROID_API = "21"
}

# Android architectures to build for
$architectures = @(
    @{
        GOARCH = "arm64"
        GOOS = "android"
        CC = "$env:NDK_PATH/toolchains/llvm/prebuilt/windows-x86_64/bin/aarch64-linux-android$env:ANDROID_API-clang.cmd"
        Suffix = "arm64-v8a"
    },
    @{
        GOARCH = "arm"
        GOOS = "android"
        CC = "$env:NDK_PATH/toolchains/llvm/prebuilt/windows-x86_64/bin/armv7a-linux-androideabi$env:ANDROID_API-clang.cmd"
        Suffix = "armeabi-v7a"
        GOARM = "7"
    },
    @{
        GOARCH = "amd64"
        GOOS = "android"
        CC = "$env:NDK_PATH/toolchains/llvm/prebuilt/windows-x86_64/bin/x86_64-linux-android$env:ANDROID_API-clang.cmd"
        Suffix = "x86_64"
    },
    @{
        GOARCH = "386"
        GOOS = "android"
        CC = "$env:NDK_PATH/toolchains/llvm/prebuilt/windows-x86_64/bin/i686-linux-android$env:ANDROID_API-clang.cmd"
        Suffix = "x86"
    }
)

Write-Host "Go Socket Forwarder - Android Build Script" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
Write-Host "NDK Path: $env:NDK_PATH" -ForegroundColor Cyan
Write-Host "Android API: $env:ANDROID_API" -ForegroundColor Cyan
Write-Host "Output Directory: $OutputDir" -ForegroundColor Cyan
Write-Host ""

# Clean build directory if requested
if ($Clean -and (Test-Path $OutputDir)) {
    Write-Host "Cleaning build directory..." -ForegroundColor Yellow
    Remove-Item -Recurse -Force $OutputDir
}

# Create output directory
if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir | Out-Null
}

# Get Go module name
$moduleName = "sforwarder"
if (Test-Path "go.mod") {
    $goModContent = Get-Content "go.mod" -First 1
    if ($goModContent -match "^module\s+(.+)$") {
        $moduleName = Split-Path $matches[1] -Leaf
    }
}

$totalBuilds = $architectures.Count
$currentBuild = 0
$successfulBuilds = 0
$failedBuilds = @()

foreach ($arch in $architectures) {
    $currentBuild++
    $outputFile = "$OutputDir/$moduleName-android-$($arch.Suffix)"
    
    Write-Host "[$currentBuild/$totalBuilds] Building for $($arch.Suffix)..." -ForegroundColor Yellow
    
    # Check if compiler exists
    if (-not (Test-Path $arch.CC)) {
        Write-Warning "Compiler not found: $($arch.CC)"
        Write-Warning "Skipping $($arch.Suffix) build"
        $failedBuilds += $arch.Suffix
        continue
    }
    
    # Set environment variables for this build
    $env:GOOS = $arch.GOOS
    $env:GOARCH = $arch.GOARCH
    $env:CC = $arch.CC
    $env:CGO_ENABLED = "1"
    
    if ($arch.GOARM) {
        $env:GOARM = $arch.GOARM
    } else {
        Remove-Item Env:GOARM -ErrorAction SilentlyContinue
    }
    
    try {
        # Build the binary
        Write-Host "  GOOS=$($arch.GOOS) GOARCH=$($arch.GOARCH) CC=$($arch.CC)" -ForegroundColor Gray
        
        $buildResult = & go build -ldflags "-s -w" -o $outputFile .
        
        if ($LASTEXITCODE -eq 0) {
            $fileSizeBeforeStrip = (Get-Item $outputFile).Length
            $fileSizeBeforeStripMB = [math]::Round($fileSizeBeforeStrip / 1MB, 2)
            
            # Strip the binary using NDK strip tool for further size reduction
            $stripTool = "$env:NDK_PATH/toolchains/llvm/prebuilt/windows-x86_64/bin/llvm-strip.exe"
            
            if (Test-Path $stripTool) {
                Write-Host "  Stripping binary..." -ForegroundColor Gray
                & $stripTool $outputFile
                if ($LASTEXITCODE -eq 0) {
                    $fileSizeAfterStrip = (Get-Item $outputFile).Length
                    $fileSizeAfterStripMB = [math]::Round($fileSizeAfterStrip / 1MB, 2)
                    $sizeReduction = [math]::Round((($fileSizeBeforeStrip - $fileSizeAfterStrip) / $fileSizeBeforeStrip) * 100, 1)
                    Write-Host "  ✓ Built and stripped: $outputFile ($fileSizeAfterStripMB MB, $sizeReduction% smaller)" -ForegroundColor Green
                } else {
                    Write-Warning "  Strip failed, keeping unstripped binary ($fileSizeBeforeStripMB MB)"
                }
            } else {
                Write-Host "  ✓ Built successfully: $outputFile ($fileSizeBeforeStripMB MB)" -ForegroundColor Green
            }
            
            $successfulBuilds++
        } else {
            Write-Error "  ✗ Build failed for $($arch.Suffix)"
            $failedBuilds += $arch.Suffix
        }
    }
    catch {
        Write-Error "  ✗ Build failed for $($arch.Suffix): $($_.Exception.Message)"
        $failedBuilds += $arch.Suffix
    }
}

# Clean up environment variables
Remove-Item Env:GOOS -ErrorAction SilentlyContinue
Remove-Item Env:GOARCH -ErrorAction SilentlyContinue
Remove-Item Env:CC -ErrorAction SilentlyContinue
Remove-Item Env:CGO_ENABLED -ErrorAction SilentlyContinue
Remove-Item Env:GOARM -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "Build Summary" -ForegroundColor Green
Write-Host "=============" -ForegroundColor Green
Write-Host "Total builds: $totalBuilds" -ForegroundColor Cyan
Write-Host "Successful: $successfulBuilds" -ForegroundColor Green
Write-Host "Failed: $($failedBuilds.Count)" -ForegroundColor Red

if ($failedBuilds.Count -gt 0) {
    Write-Host "Failed architectures: $($failedBuilds -join ', ')" -ForegroundColor Red
}

if ($successfulBuilds -gt 0) {
    Write-Host ""
    Write-Host "Built binaries:" -ForegroundColor Green
    Get-ChildItem "$OutputDir/$moduleName-android-*" | ForEach-Object {
        $fileSize = [math]::Round($_.Length / 1MB, 2)
        Write-Host "  $($_.Name) ($fileSize MB)" -ForegroundColor Cyan
    }
    
    Write-Host ""
    Write-Host "To deploy to Android device:" -ForegroundColor Yellow
    Write-Host "  adb push $OutputDir/$moduleName-android-arm64-v8a /data/local/tmp/$moduleName" -ForegroundColor Gray
    Write-Host "  adb shell chmod 755 /data/local/tmp/$moduleName" -ForegroundColor Gray
    Write-Host "  adb shell /data/local/tmp/$moduleName --help" -ForegroundColor Gray
}

if ($failedBuilds.Count -gt 0) {
    exit 1
}

Write-Host ""
Write-Host "All builds completed successfully!" -ForegroundColor Green
