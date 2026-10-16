param([switch]$SkipRemote)
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
# version-check.ps1 -- 三份插件清单 version 与 git tag、CHANGELOG 三处一致
$Root = $PSScriptRoot
$problems = @(); $warnings = @()
$versions = @{}
foreach ($rel in @('plugin.json', '.codex-plugin\plugin.json', '.codebuddy-plugin\plugin.json')) {
    $p = Join-Path $Root $rel
    if (-not (Test-Path $p)) { $problems += "missing manifest: $rel"; continue }
    $c = [System.IO.File]::ReadAllText($p, [System.Text.UTF8Encoding]::new($false))
    $m = [regex]::Match($c, '"version"\s*:\s*"([^"]+)"')
    if (-not $m.Success) { $problems += "no version: $rel"; continue }
    $versions[$rel] = $m.Groups[1].Value
}
Write-Host '=== manifest versions ==='
foreach ($k in ($versions.Keys | Sort-Object)) { $v = ([string]$versions[$k]); Write-Host ("  {0,-34} {1}" -f $k, $v) }
$uniq = @($versions.Values | Sort-Object -Unique)
if ($uniq.Count -ne 1) { $problems += "versions differ: $($versions.Values -join ' / ')" }
$current = if ($uniq.Count -ge 1) { ([string]$uniq[0]) } else { '' }
if ($current -and $current -notmatch '^\d+\.\d+\.\d+$') { $problems += "not semver: $current" }
$cl = Join-Path $Root 'CHANGELOG.md'
if (-not (Test-Path $cl)) { $problems += 'missing CHANGELOG.md' }
else {
    $clc = [System.IO.File]::ReadAllText($cl, [System.Text.UTF8Encoding]::new($false))
    if ($current -and -not ($clc -match ('\[' + [regex]::Escape($current) + '\]'))) { $problems += "CHANGELOG has no entry for [$current]" }
    else { Write-Host "=== CHANGELOG ===`n  entry [$current] present" }
}
Push-Location $Root
$gitOk = $false
try { $null = git rev-parse --git-dir 2>$null; if ($LASTEXITCODE -eq 0) { $gitOk = $true } } catch {}
if ($gitOk) {
    $localTags = @(git tag --sort=-v:refname 2>$null | Where-Object { $_ })
    $latest = if ($localTags.Count) { $localTags[0] } else { '' }
    Write-Host "=== git tag ===`n  latest: $(if ($latest) { $latest } else { '(none)' })"
    if (-not $latest) { $problems += 'no tags' }
    elseif ($current -and $latest -ne "v$current") { $problems += "latest tag ($latest) != v$current" }
    if (-not $SkipRemote) {
        $raw = $null; $ok = $false
        try { $prev = $ErrorActionPreference; $ErrorActionPreference = 'Continue'; $raw = (git ls-remote --tags origin 2>$null); $ok = ($LASTEXITCODE -eq 0); $ErrorActionPreference = $prev } catch { $ok = $false }
        if (-not ($ok -and $null -ne $raw)) { $warnings += 'remote unreachable, skipped' }
        else {
            $rt = @($raw | ForEach-Object { ($_ -split "`t")[1] } | Where-Object { $_ } | ForEach-Object { $_ -replace '^refs/tags/','' -replace '\^\{\}$','' } | Sort-Object -Unique)
            $np = @($localTags | Where-Object { $rt -notcontains $_ })
            if ($np.Count) { $problems += "tags not pushed: $($np -join ', ')" } else { Write-Host '  OK all tags pushed' }
            $ahead = $null
            try { $prev2 = $ErrorActionPreference; $ErrorActionPreference = 'Continue'; $ahead = (git rev-list --count 'origin/main..HEAD' 2>$null); $ErrorActionPreference = $prev2 } catch { $ahead = $null }
            if ($ahead -and [int]$ahead -gt 0) { $problems += "$ahead commit(s) not pushed" }
        }
    }
} else { $warnings += 'not a git repo' }
Pop-Location
Write-Host ''
foreach ($w in $warnings) { Write-Host "WARN: $w" -ForegroundColor Yellow }
if ($problems.Count) {
    Write-Host 'RESULT: version mismatch' -ForegroundColor Red
    foreach ($x in $problems) { Write-Host "  - $x" -ForegroundColor Red }
    exit 1
}
Write-Host "RESULT: version consistent ($current)" -ForegroundColor Green
exit 0