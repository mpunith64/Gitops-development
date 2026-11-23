# AI Agent Guide for GitOps-Development

Welcome to the **Gitops-development** repository. This document establishes the operational rules, architectural patterns, workflows, and automated skills available to AI agents and developers operating in this repository.

---

## 1. Repository Purpose & Architecture

This repository manages declarative GitOps deployments for Kubernetes workloads using **ArgoCD** and **Helm**.

```
gitops/
├── Application/                 # Microservice Helm charts
│   └── website/                 # Example web service Helm chart
│       ├── Chart.yaml           # Chart metadata and semantic versions
│       ├── values.yaml          # Base default values
│       └── templates/           # Kubernetes manifests (Deployment, Service, HPA, Ingress)
├── argocd/                      # ArgoCD App-of-Apps management chart
│   ├── Chart.yaml               # ArgoCD root chart definition
│   ├── values.yaml              # Global default values (source repos, OCI registry)
│   ├── values-pre-prod.yaml     # Pre-production environment configuration
│   ├── package-pre-prod.json    # Service version catalog for pre-prod
│   └── templates/
│       ├── parent.yaml          # Root Application (Application-brain)
│       └── deployment.yaml      # Dynamic generator for all service Applications
├── common-deployment/           # Shared environment-level overrides
│   └── values-pre-prod.yaml     # Shared baseline values across services (e.g. autoscaling)
└── .agents/                     # AI Agent customization system
    └── skills/                  # Domain-specific procedural skills & runbooks
        ├── argocd-service-management/
        ├── helm-management/
        ├── gitops-environment-promotion/
        └── gitops-validation/
```

---

## 2. ArgoCD App-of-Apps Architecture

This repository utilizes the **ArgoCD App-of-Apps pattern** combined with **Multi-Source Helm Applications**:

1. **Root Application (`Application-brain`)**:
   - Defined in `argocd/templates/parent.yaml`.
   - Tracks the `argocd/` folder in Git.
   - Synchronizes and generates all child Application CRDs into the `argocd` namespace.

2. **Dynamic Child Applications**:
   - Defined in `argocd/templates/deployment.yaml`.
   - Dynamically parses `argocd/package-<env>.json` based on `.Values.image.environment`.
   - Renders an `Application` CRD for each registered service: `{{ $digitalTenant }}-{{ $serviceName }}`.

3. **Multi-Source Helm Pattern**:
   Each child Application pulls configuration from two distinct sources:
   - **Source 1 (Helm Chart)**: OCI Container Registry (`azure-container-registry.azurecr.io`) or chart repository at `targetRevision: "{{ $version }}"`.
   - **Source 2 (Values Repository)**: This Git repository, mounted under `$values`, supplying:
     - `$values/Application/{{ $serviceName }}/helm-chart/values.yaml` (Base application configuration)
     - `$values/common-deployment/{{ $serviceName }}/helm-chart/values-{{ $env }}.yaml` (Environment overrides)

---

## 3. Operational Rules for AI Agents

Whenever you perform work in this repository, you **MUST** adhere to the following rules:

### A. Validation Before Commit
- **Never commit without running validation**: Always run the repository validation suite before finalizing changes:
  ```powershell
  powershell -File .agents/skills/gitops-validation/scripts/validate-all.ps1
  ```
  Or on Linux/macOS:
  ```bash
  bash .agents/skills/gitops-validation/scripts/validate-all.sh
  ```
- All JSON files in `argocd/` must remain valid JSON.
- All Helm charts must pass `helm lint` without errors.
- `helm template` on `argocd` must execute cleanly with all environment values files.

### B. Declarative GitOps Principles
- **Git is the Single Source of Truth**: All cluster state is derived from Git commits. Never instruct users to manually `kubectl apply` or edit live resources in the cluster unless troubleshooting a broken cluster controller.
- **Understand Automated Pruning**: The ArgoCD sync policy enables `automated.prune: true`. If a service is removed from `package-<env>.json`, ArgoCD will automatically delete that service and all its Kubernetes resources from the cluster. Exercise caution when removing services.
- **Understand Self-Healing**: `automated.selfHeal: true` is active. Manual changes directly made in the cluster will be reverted by ArgoCD to match Git.

### C. Versioning Standards
- Follow [Semantic Versioning (SemVer)](https://semver.org/) for all charts and services.
- `Chart.yaml`:
  - `version`: Bump when chart templates or helper functions are updated.
  - `appVersion`: Bump when the application container/workload image tag changes.
- `argocd/package-<env>.json`: Must reference the exact release version of the chart deployed to that environment.

### D. Security & Secrets Management
- **Never commit plaintext secrets**: Passwords, API tokens, TLS private keys, and connection strings must never be placed in `values.yaml` or JSON files.
- Use Kubernetes `Secret` references, External Secrets Operator, Sealed Secrets, or cloud-native key vaults (e.g. Azure Key Vault via CSI driver).

---

## 4. Key Workflows

### Workflow 1: Onboarding a New Microservice
1. Create the Helm chart in `Application/<service-name>/` with valid `Chart.yaml`, `values.yaml`, and `templates/`.
2. Add default autoscaling, resource limits, and health probes.
3. Add any environment-specific overrides in `common-deployment/`.
4. Register the service in `argocd/package-<env>.json` with its initial version (e.g. `"0.1.0"`).
5. Verify template generation using:
   ```powershell
   powershell -File .agents/skills/argocd-service-management/scripts/render-argocd.ps1 -Environment pre-prod
   ```

### Workflow 2: Promoting a Service to an Environment
1. Identify the target environment (`package-<env>.json`).
2. Update the service version using the promotion helper:
   ```powershell
   powershell -File .agents/skills/gitops-environment-promotion/scripts/update-service-version.ps1 -Environment pre-prod -Service website -Version 0.2.0
   ```
3. Run dry-run template rendering to inspect the diff.
4. Commit and push changes to trigger ArgoCD synchronization.

### Workflow 3: Emergency Rollback
1. Update `package-<env>.json` to the previous known good version:
   ```powershell
   powershell -File .agents/skills/gitops-environment-promotion/scripts/update-service-version.ps1 -Environment pre-prod -Service website -Version <previous-version>
   ```
2. Commit and push. ArgoCD will roll the Deployment back immediately.

---

## 5. Available Agent Skills

This repository includes custom agent skills located in `.agents/skills/`:

| Skill | Directory | Purpose |
| :--- | :--- | :--- |
| **`argocd-service-management`** | [`.agents/skills/argocd-service-management/`](.agents/skills/argocd-service-management/SKILL.md) | Onboarding, configuring, and templating ArgoCD child applications and the root App-of-Apps. |
| **`helm-management`** | [`.agents/skills/helm-management/`](.agents/skills/helm-management/SKILL.md) | Linting, structuring, versioning, and testing Helm charts in `Application/`. |
| **`gitops-environment-promotion`** | [`.agents/skills/gitops-environment-promotion/`](.agents/skills/gitops-environment-promotion/SKILL.md) | Multi-environment promotion, catalog version updates, and rollbacks. |
| **`gitops-validation`** | [`.agents/skills/gitops-validation/`](.agents/skills/gitops-validation/SKILL.md) | Full pre-commit repository validation suite (JSON, Helm lint, and template rendering). |

---

## 6. Quick Command Cheatsheet

```powershell
# 1. Full repository validation
powershell -File .agents/skills/gitops-validation/scripts/validate-all.ps1

# 2. Lint all Helm charts
powershell -File .agents/skills/helm-management/scripts/lint-charts.ps1

# 3. Render ArgoCD applications for pre-prod
powershell -File .agents/skills/argocd-service-management/scripts/render-argocd.ps1 -Environment pre-prod

# 4. Promote / Update a service version
powershell -File .agents/skills/gitops-environment-promotion/scripts/update-service-version.ps1 -Environment pre-prod -Service website -Version 0.2.0

# 5. Direct Helm commands
helm lint Application/website
helm lint argocd
helm template test-website Application/website -f Application/website/values.yaml -f common-deployment/values-pre-prod.yaml
helm template test-argocd argocd -f argocd/values.yaml -f argocd/values-pre-prod.yaml
```
