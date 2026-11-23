---
name: gitops-validation
description: >-
  Run automated validation, linting, and dry-run rendering for all Helm charts and ArgoCD manifests in this repository.
  Use before committing code, submitting pull requests, or verifying repository integrity.
---

# GitOps Validation Skill

This skill provides comprehensive instructions and automated scripts to validate the entire repository state before changes are committed or merged.

## Validation Suite Scope

The validation process verifies:
1. **JSON Integrity**: Checks all `argocd/package-*.json` files for valid JSON syntax.
2. **Helm Chart Linting**: Runs `helm lint` across all charts under `Application/` and `argocd/`.
3. **ArgoCD Template Rendering**: Executes `helm template` on `argocd/` with each environment's values (`values-<env>.yaml`) to ensure every `Application` resource compiles cleanly.
4. **Application Template Rendering**: Validates that application charts can render with both default and environment values.

## Manual Execution Steps

### 1. Validate JSON Files
```powershell
Get-ChildItem -Path "argocd" -Filter "package-*.json" | ForEach-Object {
    Get-Content $_.FullName -Raw | ConvertFrom-Json | Out-Null
    Write-Host "Valid: $($_.Name)"
}
```

### 2. Lint All Helm Charts
```powershell
helm lint argocd
helm lint Application/website
```

### 3. Dry-Run Render ArgoCD Manifests
```powershell
helm template argocd -f argocd/values.yaml -f argocd/values-pre-prod.yaml
```

### 4. Dry-Run Render Application Charts with Common Values
```powershell
helm template Application/website -f Application/website/values.yaml -f common-deployment/values-pre-prod.yaml
```

## Automated Validation Helper

Run the repository-wide validator:

- PowerShell: [scripts/validate-all.ps1](./scripts/validate-all.ps1)
- Bash: [scripts/validate-all.sh](./scripts/validate-all.sh)

```powershell
pwsh -File .agents/skills/gitops-validation/scripts/validate-all.ps1
```
