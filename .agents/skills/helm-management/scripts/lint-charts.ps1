[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$TargetDir = ""
)

$ErrorActionPreference = "Continue"

# Find repository root
$current = Get-Item $PSScriptRoot
while ($current -and -not (Test-Path (Join-Path $current.FullName ".git"))) {
    $current = $current.Parent
}
$repoRoot = if ($current) { $current.FullName } else { (Resolve-Path "$PSScriptRoot\..\..\..\..").Path }

Write-Host "=== Helm Chart Linting ===" -ForegroundColor Cyan
Write-Host "Repository Root: $repoRoot"

$chartsToLint = @()

if ($TargetDir -ne "") {
    $chartsToLint += (Resolve-Path (Join-Path $repoRoot $TargetDir)).Path
} else {
    # Auto-discover charts with Chart.yaml
    Get-ChildItem -Path $repoRoot -Recurse -Filter "Chart.yaml" | Where-Object { $_.FullName -notmatch '\\\.' } | ForEach-Object {
        $chartsToLint += $_.Directory.FullName
    }
}

$failedCount = 0

foreach ($chart in $chartsToLint) {
    $relative = $chart.Replace($repoRoot, "").TrimStart("\/")
    Write-Host "`nLinting chart: $relative ..." -ForegroundColor Yellow
    
    $lintOutput = & helm lint $chart 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[FAIL] $relative" -ForegroundColor Red
        Write-Host ($lintOutput -join "`n")
        $failedCount++
    } else {
        Write-Host "[PASS] $relative" -ForegroundColor Green
    }
}

Write-Host "`n----------------------------------------"
if ($failedCount -eq 0) {
    Write-Host "All $($chartsToLint.Count) chart(s) passed linting successfully!" -ForegroundColor Green
    exit 0
} else {
    Write-Host "$failedCount chart(s) failed linting." -ForegroundColor Red
    exit 1
}
