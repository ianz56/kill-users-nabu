# Build script for Kill Users on Switch Magisk Module
# Run this in PowerShell from the project directory

$ModuleName = "kill-users-on-switch"
$Version = "v1.0.0"
$ZipName = "$ModuleName-$Version.zip"
$ZipPath = Join-Path $PWD $ZipName

# Remove old zip if it exists
if (Test-Path $ZipPath) {
    Remove-Item $ZipPath
    Write-Host "Removed old $ZipName" -ForegroundColor Yellow
}

Write-Host "Building $ZipName ..." -ForegroundColor Cyan

# Use .NET ZipFile to preserve directory structure
Add-Type -AssemblyName System.IO.Compression.FileSystem

$filesToInclude = @(
    "module.prop",
    "service.sh",
    "action.sh",
    "customize.sh",
    "META-INF/com/google/android/update-binary",
    "META-INF/com/google/android/updater-script"
)

$zip = [System.IO.Compression.ZipFile]::Open($ZipPath, 'Create')

foreach ($file in $filesToInclude) {
    $fullPath = Join-Path $PWD $file
    $entryName = $file -replace '\\', '/'
    [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
        $zip, $fullPath, $entryName, [System.IO.Compression.CompressionLevel]::Optimal
    ) | Out-Null
    Write-Host "  + $entryName" -ForegroundColor DarkGray
}

$zip.Dispose()

if (Test-Path $ZipPath) {
    $size = (Get-Item $ZipPath).Length
    Write-Host ""
    Write-Host "Build successful!" -ForegroundColor Green
    Write-Host "Output: $ZipName ($size bytes)" -ForegroundColor Green
    Write-Host ""
    Write-Host "Transfer the ZIP to your device and flash via Magisk Manager." -ForegroundColor White
} else {
    Write-Host "Build failed!" -ForegroundColor Red
    exit 1
}
