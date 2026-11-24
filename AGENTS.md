# Agent Instructions & Operational Guidelines

This document establishes the operational rules, architectural patterns, workflows, and automated skills available to automated agents and developers operating in this GitOps repository.

---

## 1. Operational Rules & Standards

Whenever you perform work in this repository, you **MUST** adhere to the following rules:

### A. Validation Requirement
Always execute the validation suite before proposing or finalizing any commit:
- **PowerShell**: `powershell -ExecutionPolicy Bypass -File .agents/skills/gitops-validation/scripts/validate-all.ps1`
- **Bash**: `bash .agents/skills/gitops-validation/scripts/validate-all.sh`
- All JSON files in `argocd/` must remain valid JSON.
- All Helm charts must pass `helm lint` without errors.
- `helm template` on `argocd` must execute cleanly with all environment values files.

### B. Declarative GitOps Principles
- **Git is the Single Source of Truth**: All cluster state is derived from Git commits. Never suggest manual, non-declarative cluster state mutations. All resources must be managed via Helm charts in `Application/` or registered in `argocd/package-<env>.json`.
- **Pruning Awareness**: Child applications configured in `argocd/templates/deployment.yaml` run with `syncPolicy.automated.prune = true`. Removing a service from `package-<env>.json` triggers automated deletion of the application and its Kubernetes resources in the target namespace.
- **Self-Healing Active**: `syncPolicy.automated.selfHeal = true` is enabled. Manual modifications in the cluster will be reconciled back to match Git state.

### C. Versioning Standards
- Maintain [Semantic Versioning (SemVer)](https://semver.org/) for all charts and services.
- `Chart.yaml`:
  - `version`: Bump when chart templates or helper functions change.
  - `appVersion`: Bump when the container image tag changes.
- `argocd/package-<env>.json`: Must reference the exact version deployed in each target environment.

### D. Security & Secrets Management
- **No Plaintext Secrets**: Passwords, API tokens, TLS private keys, and connection strings must never be stored in Git.
- Use references to Kubernetes Secrets, Sealed Secrets, or External Secrets Operator.

---

## 2. Architecture & App-of-Apps Pattern

This repository manages declarative GitOps deployments using **ArgoCD** and **Helm**:

```text
gitops/
├── Application/                 # Microservice Helm charts and source
│   └── hello-world/             # Hello World microservice
│       ├── Dockerfile           # Application container build definition
│       ├── project.json         # Nx project metadata
│       ├── src/                 # Application source code
│       └── helm-chart/          # Kubernetes manifests & Helm package
│           ├── Chart.yaml       # Chart metadata and semantic versions
│           ├── values.yaml      # Base default values
│           └── templates/       # Kubernetes manifests (Deployment, Service, HPA, Ingress)
├── argocd/                      # ArgoCD App-of-Apps management chart
│   ├── Chart.yaml               # ArgoCD root chart definition
│   ├── values.yaml              # Global default values (source repos, OCI registry)
│   ├── values-pre-prod.yaml     # Pre-production environment configuration
│   ├── values-prod.yaml         # Production environment configuration
│   ├── package-pre-prod.json    # Service version catalog for pre-prod
│   ├── package-prod.json        # Service version catalog for prod
│   └── templates/
│       ├── parent.yaml          # Root Application (Application-brain)
│       └── deployment.yaml      # Dynamic generator for all service Applications
├── common-deployment/           # Shared environment-level overrides
│   ├── values-pre-prod.yaml     # Shared baseline values for pre-prod
│   └── values-prod.yaml         # Shared baseline values for prod
└── .agents/                     # Operational skills and runbooks
    └── skills/                  # Domain-specific procedural skills & runbooks
        ├── argocd-service-management/
        ├── helm-management/
        ├── gitops-environment-promotion/
        └── gitops-validation/
```

### ArgoCD Multi-Source Pattern:
1. **Root Application (`Application-brain`)**: Defined in `argocd/templates/parent.yaml`. Watches `argocd/` in Git and continuously syncs child applications.
2. **Dynamic Child Applications**: Defined in `argocd/templates/deployment.yaml`. Loops over services in `argocd/package-<env>.json` to generate `Application` resources (`{{ $digitalTenant }}-{{ $serviceName }}`).
3. **Multi-Source Helm Applications**:
   - **Source 1 (Helm Chart)**: OCI Container Registry (`azure-container-registry.azurecr.io`) at `targetRevision: "{{ $version }}"`.
   - **Source 2 (Values Repository)**: This Git repository mounted under `$values`:
     - Base defaults: `$values/Application/{{ $serviceName }}/helm-chart/values.yaml`
     - Environment overrides: `$values/common-deployment/{{ $serviceName }}/helm-chart/values-{{ $env }}.yaml`

---

## 3. Key Workflows

### Workflow 1: Onboarding a New Microservice
1. Create the Helm chart in `Application/<service-name>/` with valid `Chart.yaml`, `values.yaml`, and `templates/`.
2. Add default autoscaling, resource limits, and health probes.
3. Add any environment-specific overrides in `common-deployment/`.
4. Register the service in `argocd/package-<env>.json` with its initial version (e.g. `"0.1.0"`).
5. Verify template generation using:
   ```powershell
   powershell -ExecutionPolicy Bypass -File .agents/skills/argocd-service-management/scripts/render-argocd.ps1 -Environment pre-prod
   ```

### Workflow 2: Promoting a Service Version
1. Identify target environment (`argocd/package-<env>.json`).
2. Update the service version using the promotion helper:
   ```powershell
   powershell -ExecutionPolicy Bypass -File .agents/skills/gitops-environment-promotion/scripts/update-service-version.ps1 -Environment pre-prod -Service hello-world -Version 0.2.0
   ```
3. Run dry-run template rendering and inspect the git diff.
4. Commit and push changes to trigger ArgoCD synchronization.

### Workflow 3: Emergency Rollback
1. Revert `argocd/package-<env>.json` to the last known good version.
2. Commit and push. ArgoCD will roll back the Deployment automatically.

---

## 4. Repository Skills

The following skills are installed in `.agents/skills/` to automate common GitOps tasks:

| Skill | Directory | Purpose |
| :--- | :--- | :--- |
| **`argocd-service-management`** | [`.agents/skills/argocd-service-management/`](.agents/skills/argocd-service-management/SKILL.md) | Onboarding, configuring, and templating ArgoCD child applications and the root App-of-Apps. |
| **`helm-management`** | [`.agents/skills/helm-management/`](.agents/skills/helm-management/SKILL.md) | Linting, structuring, versioning, and testing Helm charts in `Application/`. |
| **`gitops-environment-promotion`** | [`.agents/skills/gitops-environment-promotion/`](.agents/skills/gitops-environment-promotion/SKILL.md) | Multi-environment promotion, catalog version updates, and rollbacks. |
| **`gitops-validation`** | [`.agents/skills/gitops-validation/`](.agents/skills/gitops-validation/SKILL.md) | Full pre-commit repository validation suite (JSON, Helm lint, and template rendering). |

---

## 5. Quick Command Cheatsheet

```powershell
# Full repository validation
powershell -ExecutionPolicy Bypass -File .agents/skills/gitops-validation/scripts/validate-all.ps1

# Lint all Helm charts
powershell -ExecutionPolicy Bypass -File .agents/skills/helm-management/scripts/lint-charts.ps1

# Render ArgoCD applications for pre-prod
powershell -ExecutionPolicy Bypass -File .agents/skills/argocd-service-management/scripts/render-argocd.ps1 -Environment pre-prod

# Promote / Update a service version
powershell -ExecutionPolicy Bypass -File .agents/skills/gitops-environment-promotion/scripts/update-service-version.ps1 -Environment pre-prod -Service hello-world -Version 0.2.0

# Direct Helm validation commands
helm lint Application/hello-world/helm-chart
helm lint argocd
helm template test-hello-world Application/hello-world/helm-chart -f Application/hello-world/helm-chart/values.yaml -f common-deployment/values-pre-prod.yaml
helm template test-argocd argocd -f argocd/values.yaml -f argocd/values-pre-prod.yaml
```
