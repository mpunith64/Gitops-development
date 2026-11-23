[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$Environment = "pre-prod",

    [Parameter(Mandatory = $false)]
    [string]$ChartDir = "argocd"
)

$ErrorActionPreference = "Continue"

# Find repository root
$current = Get-Item $PSScriptRoot
while ($current -and -not (Test-Path (Join-Path $current.FullName ".git"))) {
    $current = $current.Parent
}
$repoRoot = if ($current) { $current.FullName } else { (Resolve-Path "$PSScriptRoot\..\..\..\..").Path }

$targetChart = Join-Path $repoRoot $ChartDir
$valuesDefault = Join-Path $targetChart "values.yaml"
$valuesEnv = Join-Path $targetChart "values-$Environment.yaml"
$packageFile = Join-Path $targetChart "package-$Environment.json"

Write-Host "=== ArgoCD Helm Template Validation ===" -ForegroundColor Cyan
Write-Host "Repository Root: $repoRoot"
Write-Host "Target Chart   : $targetChart"
Write-Host "Environment    : $Environment"

if (-not (Test-Path $valuesDefault)) {
    Write-Error "Default values file not found: $valuesDefault"
    exit 1
}

if (-not (Test-Path $valuesEnv)) {
    Write-Error "Environment values file not found: $valuesEnv"
    exit 1
}

if (-not (Test-Path $packageFile)) {
    Write-Error "Package manifest not found: $packageFile"
    exit 1
}

Write-Host "Validating package JSON syntax..."
try {
    $json = Get-Content $packageFile -Raw | ConvertFrom-Json
    $serviceCount = ($json.services | Get-Member -MemberType NoteProperty).Count
    Write-Host "Found $serviceCount registered service(s) in $packageFile" -ForegroundColor Green
} catch {
    Write-Error "Invalid JSON in ${packageFile}: $_"
    exit 1
}

Write-Host "Executing 'helm template'..."
$output = helm template $targetChart -f $valuesDefault -f $valuesEnv
if ($LASTEXITCODE -ne 0) {
    Write-Error "helm template execution failed!"
    exit $LASTEXITCODE
}

Write-Host "Successfully rendered ArgoCD manifests for '$Environment'!" -ForegroundColor Green
Write-Host "Rendered application list:" -ForegroundColor Yellow
($output -join "`n") -split '---' | ForEach-Object {
    if ($_ -match 'kind:\s*Application' -and $_ -match 'name:\s*([^\r\n]+)') {
        $appName = $matches[1].Trim()
        Write-Host "  -> Application: $appName" -ForegroundColor Cyan
    }
}
