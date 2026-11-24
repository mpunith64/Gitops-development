---
name: argocd-service-management
description: >-
  Onboard, configure, and manage microservices deployed via ArgoCD App-of-Apps in this GitOps repository.
  Use when adding a new service, registering charts in package-<env>.json, configuring multi-source
  ArgoCD applications, or modifying ArgoCD application templates.
---

# ArgoCD Service Management Skill

This skill guides the agent through onboarding, updating, and maintaining applications deployed via the ArgoCD App-of-Apps pattern in this repository.

## Architecture Overview

This repository uses an **App-of-Apps** pattern configured in the `argocd/` directory:
1. **Root Application (`Application-brain`)**: Defined in `argocd/templates/parent.yaml`. It points ArgoCD to the `argocd` path of this repository, continuously synchronizing all child Application manifests.
2. **Child Applications**: Defined dynamically in `argocd/templates/deployment.yaml`. It iterates over the services listed in `package-<env>.json` (e.g., `package-pre-prod.json`) for the target environment.
3. **Multi-Source Configuration**: Each child `Application` uses multiple sources:
   - **Source 1 (Helm Chart)**: Fetches the chart named `{{ $serviceName }}` from the OCI container registry (e.g. `azure-container-registry.azurecr.io`) at version `{{ $version }}`.
   - **Source 2 (Values Repository)**: Clones this Git repository with `ref: values`, pulling:
     - `$values/Application/{{ $serviceName }}/helm-chart/values.yaml` (Base application values)
     - `$values/common-deployment/{{ $serviceName }}/helm-chart/values-{{ $env }}.yaml` (Environment-specific overrides)

## Workflows

### 1. Onboard a New Service to an Environment

When adding a new microservice (e.g. `order-service` at version `0.1.0` to `pre-prod`):

1. **Verify or create application values**:
   - Create or verify the application chart/values under `Application/<service-name>/`.
   - Ensure environment-specific values exist under `common-deployment/` (or `common-deployment/<service-name>/`).
2. **Register the service in `argocd/package-<env>.json`**:
   - Open `argocd/package-<env>.json` (e.g., `argocd/package-pre-prod.json`).
   - Add the service entry under `"services"`:
     ```json
     {
       "services": {
         "hello-world": "0.1.0",
         "order-service": "0.1.0"
       }
     }
     ```
3. **Validate template rendering**:
   - Run the rendering helper or Helm command:
     ```powershell
     cd argocd
     helm template . -f values.yaml -f values-<env>.yaml
     ```
   - Verify that the rendered output includes:
     - Kind: `Application`
     - Metadata name: `<tenant>-<service-name>` (e.g., `pre-prod-order-service`)
     - Target revision: `"0.1.0"`
     - Correct namespace and syncPolicy

### 2. Update an Existing Service Version

When releasing a new version of an existing service:

1. Identify the target environment (e.g., `pre-prod`).
2. Update the version string in `argocd/package-<env>.json`:
   ```json
   "hello-world": "0.2.0"
   ```
3. If new configuration parameters are required, update:
   - `Application/<service-name>/values.yaml`
   - `common-deployment/<service-name>/helm-chart/values-<env>.yaml` (or environment values file)
4. Validate rendering with `helm template` (see Validation section).

### 3. Sync Policy & Automated Pruning

Child applications define:
```yaml
syncPolicy:
  automated:
    prune: true
    selfHeal: true
  syncOptions:
    - CreateNamespace=true
```
- **Pruning**: Deleting a service from `package-<env>.json` will cause ArgoCD to prune (delete) that Application and its associated Kubernetes resources from the cluster.
- **Self-Healing**: Manual manual changes in the cluster will be overwritten by Git state.

## Helper Scripts

- Render and validate ArgoCD applications:
  - PowerShell: [scripts/render-argocd.ps1](./scripts/render-argocd.ps1)
  - Bash: [scripts/render-argocd.sh](./scripts/render-argocd.sh)

Run with:
```powershell
pwsh -File .agents/skills/argocd-service-management/scripts/render-argocd.ps1 -Environment pre-prod
```
