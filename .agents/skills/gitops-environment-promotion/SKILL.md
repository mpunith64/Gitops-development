---
name: gitops-environment-promotion
description: >-
  Promote application versions, Helm charts, and configuration updates across environments
  (e.g., pre-prod to prod) in this GitOps repository. Use when upgrading a service version,
  modifying environment-specific values, or managing GitOps release workflows.
---

# GitOps Environment Promotion Skill

This skill guides the agent through safely promoting service versions and configuration changes across deployment environments (such as `pre-prod` and `prod`).

## Promotion Model

In this repository, promotion follows declarative GitOps principles:
- **Service Version Catalog**: Maintained in `argocd/package-<env>.json` per environment.
- **Environment Overrides**: Maintained in `argocd/values-<env>.yaml` and `common-deployment/`.
- **Promotion Mechanism**: Changes are committed to Git. ArgoCD detects the new Git commit and synchronizes the cluster to the declared state.

## Step-by-Step Promotion Procedure

### Phase 1: Pre-Promotion Assessment

1. **Identify the Service & Target Version**:
   - Determine which service is being promoted (e.g., `website`) and the new semantic version (e.g., `0.2.0`).
2. **Identify the Target Environment**:
   - Confirm target environment file: `argocd/package-<env>.json` (e.g., `package-pre-prod.json`).
3. **Review Config Changes**:
   - Check if new environment variables, secret keys, or resource limits are required.

### Phase 2: Updating Manifests

1. **Update `argocd/package-<env>.json`**:
   Update the version mapped to the service:
   ```json
   {
     "services": {
       "website": "0.2.0"
     }
   }
   ```
   Or use the automated script:
   ```powershell
   pwsh -File .agents/skills/gitops-environment-promotion/scripts/update-service-version.ps1 -Environment pre-prod -Service website -Version 0.2.0
   ```

2. **Update Environment-Specific Values (if applicable)**:
   - Check `common-deployment/values-<env>.yaml` (or `common-deployment/<service>/helm-chart/values-<env>.yaml`).
   - If autoscaling, replica counts, or ingress rules need environment tuning, update them here.

### Phase 3: Dry-Run Validation

1. **Render ArgoCD manifests**:
   ```powershell
   pwsh -File .agents/skills/argocd-service-management/scripts/render-argocd.ps1 -Environment <env>
   ```
2. **Inspect the Git Diff**:
   ```powershell
   git diff argocd/package-<env>.json
   ```
3. **Verify the change is isolated**: Ensure no unintended services or environments were modified.

### Phase 4: Rollback Strategy

If a newly deployed version causes incidents in the target environment:
1. **Immediate Git Rollback**:
   Revert `package-<env>.json` to the last known healthy version:
   ```powershell
   pwsh -File .agents/skills/gitops-environment-promotion/scripts/update-service-version.ps1 -Environment <env> -Service <service> -Version <previous-version>
   ```
2. **Commit and Push**: ArgoCD self-heals by rolling back to the previous version container/chart automatically.

## Helper Scripts

- Update service version in environment package catalog:
  - PowerShell: [scripts/update-service-version.ps1](./scripts/update-service-version.ps1)
  - Bash: [scripts/update-service-version.sh](./scripts/update-service-version.sh)
