<#
.SYNOPSIS
    Fetches the BepInEx log of a device's r2modman profile so it can be read here.

.PARAMETER Name     Registered device name.
.PARAMETER Pattern  Optional regular expression: only matching lines are printed.
.PARAMETER Tail     How many lines to print (default 60 of the matches, or of the whole log).
.PARAMETER OutFile  Where to save the full log (default: a temp file, path printed).
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Name,
    [string]$Pattern = '',
    [int]$Tail = 60,
    [string]$OutFile = ''
)

. (Join-Path $PSScriptRoot 'DeviceCommon.ps1')

$device = Get-DeviceByName $Name
$status = Invoke-DeviceScript $device 'device-status.ps1' @{ ProfileName = $device.ProfileName }
if (-not $status.profileExists) { throw "The profile '$($device.ProfileName)' does not exist on '$Name'." }

if (-not $OutFile) { $OutFile = Join-Path ([IO.Path]::GetTempPath()) ("{0}-LogOutput.log" -f $Name) }
Receive-DeviceFile $device $status.logPath $OutFile
Write-Host "Log of '$Name' saved to $OutFile ($((Get-Item $OutFile).Length) bytes)" -ForegroundColor Green

$lines = Get-Content -Path $OutFile
if ($Pattern) { $lines = $lines | Where-Object { $_ -match $Pattern } }
$lines | Select-Object -Last $Tail
