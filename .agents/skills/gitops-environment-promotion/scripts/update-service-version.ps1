[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Environment,

    [Parameter(Mandatory = $true)]
    [string]$Service,

    [Parameter(Mandatory = $true)]
    [string]$Version
)

$ErrorActionPreference = "Stop"

# Find repository root
$current = Get-Item $PSScriptRoot
while ($current -and -not (Test-Path (Join-Path $current.FullName ".git"))) {
    $current = $current.Parent
}
$repoRoot = if ($current) { $current.FullName } else { (Resolve-Path "$PSScriptRoot\..\..\..\..").Path }

$packageFile = Join-Path $repoRoot "argocd\package-$Environment.json"

Write-Host "=== GitOps Service Version Promotion ===" -ForegroundColor Cyan
Write-Host "Repository Root: $repoRoot"
Write-Host "Environment    : $Environment"
Write-Host "Service        : $Service"
Write-Host "New Version    : $Version"

if (-not (Test-Path $packageFile)) {
    Write-Error "Package catalog file not found: $packageFile"
    exit 1
}

$content = Get-Content $packageFile -Raw | ConvertFrom-Json

if (-not $content.services) {
    Write-Error "No 'services' object found in $packageFile"
    exit 1
}

$oldVersion = $content.services.$Service
if ($null -ne $oldVersion) {
    Write-Host "Current version of '$Service': $oldVersion" -ForegroundColor Yellow
} else {
    Write-Host "Service '$Service' is new to environment '$Environment'" -ForegroundColor Yellow
}

# Update or add service version
$content.services | Add-Member -NotePropertyName $Service -NotePropertyValue $Version -Force

$updatedJson = $content | ConvertTo-Json -Depth 5
Set-Content -Path $packageFile -Value $updatedJson

Write-Host "Updated $packageFile successfully!" -ForegroundColor Green
Write-Host "Summary: $Service promoted to $Version in $Environment." -ForegroundColor Green
