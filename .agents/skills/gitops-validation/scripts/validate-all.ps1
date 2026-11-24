[CmdletBinding()]
param()

$ErrorActionPreference = "Continue"

# Find repository root
$current = Get-Item $PSScriptRoot
while ($current -and -not (Test-Path (Join-Path $current.FullName ".git"))) {
    $current = $current.Parent
}
$repoRoot = if ($current) { $current.FullName } else { (Resolve-Path "$PSScriptRoot\..\..\..\..").Path }

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "   GitOps Repository Validation Suite     " -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Repository Root: $repoRoot"

$totalChecks = 0
$failedChecks = 0

# Step 1: Validate JSON files
Write-Host "`n[1/3] Validating JSON files..." -ForegroundColor Yellow
$jsonFiles = Get-ChildItem -Path (Join-Path $repoRoot "argocd") -Filter "package-*.json" -ErrorAction SilentlyContinue

foreach ($file in $jsonFiles) {
    $totalChecks++
    try {
        $null = Get-Content $file.FullName -Raw | ConvertFrom-Json
        Write-Host "  [PASS] $($file.Name)" -ForegroundColor Green
    } catch {
        Write-Host "  [FAIL] $($file.Name): $_" -ForegroundColor Red
        $failedChecks++
    }
}

# Step 2: Lint Helm charts
Write-Host "`n[2/3] Linting Helm charts..." -ForegroundColor Yellow
$chartFiles = Get-ChildItem -Path $repoRoot -Recurse -Filter "Chart.yaml" | Where-Object { $_.FullName -notmatch '\\\.' }

foreach ($chart in $chartFiles) {
    $totalChecks++
    $chartDir = $chart.Directory.FullName
    $rel = $chartDir.Replace($repoRoot, "").TrimStart("\/")
    
    $lintOut = & helm lint $chartDir 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  [PASS] $rel" -ForegroundColor Green
    } else {
        Write-Host "  [FAIL] $rel" -ForegroundColor Red
        Write-Host ($lintOut -join "`n")
        $failedChecks++
    }
}

# Step 3: Render ArgoCD templates for each environment
Write-Host "`n[3/3] Testing ArgoCD template rendering..." -ForegroundColor Yellow
$argocdDir = Join-Path $repoRoot "argocd"
$envFiles = Get-ChildItem -Path $argocdDir -Filter "values-*.yaml"

foreach ($envFile in $envFiles) {
    $totalChecks++
    $envName = $envFile.BaseName.Replace("values-", "")
    Write-Host "  Testing environment: $envName ..." -ForegroundColor Yellow
    
    $renderOut = & helm template $argocdDir -f (Join-Path $argocdDir "values.yaml") -f $envFile.FullName 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  [PASS] argocd ($envName)" -ForegroundColor Green
    } else {
        Write-Host "  [FAIL] argocd ($envName)" -ForegroundColor Red
        Write-Host ($renderOut -join "`n")
        $failedChecks++
    }
}

Write-Host "`n=========================================="
if ($failedChecks -eq 0) {
    Write-Host "Validation SUCCEEDED: All $totalChecks checks passed!" -ForegroundColor Green
    Write-Host "=========================================="
    exit 0
} else {
    Write-Host "Validation FAILED: $failedChecks of $totalChecks checks failed." -ForegroundColor Red
    Write-Host "=========================================="
    exit 1
}
