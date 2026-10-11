# Script to suppress noisy Android MediaTek CCodec/PipelineWatcher debug logs
# during Flutter development while keeping video autoplay active.

$adbPath = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
if (-not (Test-Path $adbPath)) {
    $adbCmd = Get-Command "adb" -ErrorAction SilentlyContinue
    if ($adbCmd) {
        $adbPath = $adbCmd.Source
    } else {
        Write-Error "adb.exe not found in Android SDK platform-tools."
        exit 1
    }
}

Write-Host "Suppressing MediaCodec & CCodec debug logs on connected Android device..." -ForegroundColor Cyan

$tags = @(
    "PipelineWatcher",
    "CCodecBufferChannel",
    "CCodec",
    "CCodecConfig",
    "Codec2Client",
    "MediaCodec",
    "omx"
)

foreach ($tag in $tags) {
    & $adbPath shell "setprop log.tag.$tag SUPPRESS"
}

Write-Host "Done! Video decoder debug logs are now suppressed in the Flutter terminal." -ForegroundColor Green
