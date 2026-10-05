<#
.SYNOPSIS
    Converts an MP4 gameplay video to an optimized GIF and sets it up in README.md.

.PARAMETER VideoPath
    Path to the .mp4 video file.

.PARAMETER ModPath
    Path to the root directory of the mod (defaults to current directory).

.PARAMETER OutputGif
    Relative or absolute path for the output GIF (default: assets/preview.gif).

.PARAMETER MaxWidth
    Maximum image width in pixels (default: 600).

.PARAMETER Fps
    Frames per second for output GIF (default: 12).

.PARAMETER StartTime
    Start time in seconds (default: 0).

.PARAMETER MaxDuration
    Maximum duration in seconds (default: 10, set 0 for full video).

.PARAMETER SkipReadme
    Do not modify README.md.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$VideoPath,

    [string]$ModPath = ".",
    [string]$OutputGif = "assets/preview.gif",
    [int]$MaxWidth = 600,
    [int]$Fps = 12,
    [double]$StartTime = 0.0,
    [double]$MaxDuration = 10.0,
    [switch]$SkipReadme
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$pythonScript = Join-Path $scriptDir "process-preview-gif.py"

if (-not (Test-Path $pythonScript)) {
    throw "Converter script not found at: $pythonScript"
}

$pyCmd = if (Get-Command python -ErrorAction SilentlyContinue) {
    "python"
} elseif (Get-Command py -ErrorAction SilentlyContinue) {
    "py"
} else {
    throw "Python was not found in PATH. Please install Python 3.8+."
}

$argsList = @(
    "`"$pythonScript`"",
    "-i", "`"$VideoPath`"",
    "-o", "`"$OutputGif`"",
    "-m", "`"$ModPath`"",
    "-w", "$MaxWidth",
    "-f", "$Fps",
    "-s", "$StartTime",
    "-d", "$MaxDuration"
)

if ($SkipReadme) {
    $argsList += "--skip-readme"
}

$cmdLine = "$pyCmd $($argsList -join ' ')"
Invoke-Expression $cmdLine
if ($LASTEXITCODE -ne 0) {
    throw "Preview GIF conversion failed with exit code $LASTEXITCODE"
}
