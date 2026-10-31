# Reports which RepoAPI and RepoKit revision each mod pins and whether it is behind origin/master.
# Read-only: it never changes a repository. Usage:
#   pwsh -File check-submodule-drift.ps1 [-WorkspaceRoot <path>] [-NoFetch]
param(
	[string]$WorkspaceRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path,
	[switch]$NoFetch
)

$ErrorActionPreference = 'Continue' # git writes expected errors to stderr (no tags, no upstream)
$submodules = @('RepoAPI', 'RepoKit')

function Get-Latest([string]$name) {
	$repo = Join-Path $WorkspaceRoot $name
	if (-not (Test-Path (Join-Path $repo '.git'))) { return $null }
	if (-not $NoFetch) { git -C $repo fetch -q origin 2>$null }
	$sha = (git -C $repo rev-parse origin/master 2>$null)
	if (-not $sha) { $sha = (git -C $repo rev-parse HEAD) }
	return $sha.Trim()
}

$latest = @{}
foreach ($name in $submodules) { $latest[$name] = Get-Latest $name }

$rows = foreach ($mod in Get-ChildItem $WorkspaceRoot -Directory) {
	if (-not (Test-Path (Join-Path $mod.FullName '.git'))) { continue }
	if ($submodules -contains $mod.Name) { continue }
	foreach ($name in $submodules) {
		$entry = git -C $mod.FullName ls-tree HEAD "external/$name" 2>$null
		if (-not $entry) { continue }
		$pinned = ($entry -split '\s+')[2]
		$status = if (-not $latest[$name]) { 'unknown' }
			elseif ($pinned -eq $latest[$name]) { 'current' }
			else {
				$behind = git -C (Join-Path $WorkspaceRoot $name) rev-list --count "$pinned..$($latest[$name])" 2>$null
				if ($behind) { "behind by $behind commit(s)" } else { 'differs (pinned commit not found locally)' }
			}
		[pscustomobject]@{ Mod = $mod.Name; Submodule = $name; Pinned = $pinned.Substring(0, 7); Status = $status }
	}
}

$rows | Sort-Object Submodule, Mod | Format-Table -AutoSize
foreach ($name in $submodules) {
	if ($latest[$name]) { Write-Host ("{0} latest: {1}" -f $name, $latest[$name].Substring(0, 7)) }
}

Write-Host "`nRepository state"
$state = foreach ($repo in Get-ChildItem $WorkspaceRoot -Directory) {
	if (-not (Test-Path (Join-Path $repo.FullName '.git'))) { continue }
	$path = $repo.FullName
	$dirty = @(git -C $path status --porcelain).Count
	$upstream = git -C $path rev-parse --abbrev-ref '@{u}' 2>$null
	$unpushed = if ($upstream) { [int](git -C $path rev-list --count "$upstream..HEAD") } else { 'no upstream' }
	$tag = git -C $path describe --tags --abbrev=0 2>$null
	$sinceTag = if ($tag) { [int](git -C $path rev-list --count "$tag..HEAD") } else { '-' }
	[pscustomobject]@{ Repo = $repo.Name; Uncommitted = $dirty; Unpushed = $unpushed; LastTag = $tag; CommitsSinceTag = $sinceTag }
}
$state | Format-Table -AutoSize
$pending = $state | Where-Object { $_.Uncommitted -gt 0 -or ($_.Unpushed -ne 0) }
if ($pending) { Write-Host ("Work not on GitHub: {0}" -f (($pending | ForEach-Object Repo) -join ', ')) }
else { Write-Host 'Work not on GitHub: none' }
$release = $state | Where-Object { $_.CommitsSinceTag -is [int] -and $_.CommitsSinceTag -gt 0 }
if ($release) { Write-Host ("Commits after last tag (possible release): {0}" -f (($release | ForEach-Object { "$($_.Repo) +$($_.CommitsSinceTag)" }) -join ', ')) }

$noApi = Get-ChildItem $WorkspaceRoot -Directory | Where-Object {
	(Test-Path (Join-Path $_.FullName '.git')) -and ($submodules -notcontains $_.Name) -and
	-not (git -C $_.FullName ls-tree HEAD 'external/RepoAPI' 2>$null)
} | ForEach-Object Name
if ($noApi) { Write-Host ("Mods without RepoAPI submodule: {0}" -f ($noApi -join ', ')) }
