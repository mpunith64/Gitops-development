---
name: helm-management
description: >-
  Manage, lint, template, package, and troubleshoot Helm charts in this GitOps repository.
  Use when creating or modifying Application Helm charts, updating Chart.yaml versions,
  configuring values.yaml, or writing Kubernetes resource templates.
---

# Helm Management Skill

This skill provides procedures and standards for developing, maintaining, and testing Helm charts within the `Application/` directory and the root `argocd/` chart.

## Chart Structure Standards

Every Helm chart under `Application/<service-name>` must conform to Helm v2/v3 standards:

```text
Application/<service-name>/
├── Chart.yaml              # Metadata: name, version, appVersion, description
├── values.yaml             # Default values for all environments
├── templates/
│   ├── _helpers.tpl        # Named templates (fullname, labels, chart name)
│   ├── deployment.yaml     # Main Kubernetes Deployment workload
│   ├── service.yaml        # ClusterIP/NodePort/LoadBalancer service
│   ├── serviceaccount.yaml # ServiceAccount definition
│   ├── hpa.yaml            # HorizontalPodAutoscaler (conditional on autoscaling.enabled)
│   ├── ingress.yaml        # Ingress routing (conditional on ingress.enabled)
│   └── NOTES.txt           # Post-install instructions
└── .helmignore             # Files to exclude from packaging
```

## Chart Versioning Rules

- **`version`** (SemVer `MAJOR.MINOR.PATCH`): Increment each time the chart templates, helper definitions, or default values change.
- **`appVersion`**: Matches the container image tag deployed by this chart. When upgrading the application container, bump `appVersion` (and patch `version`).

## Essential Workflows

### 1. Adding a New Application Chart

When scaffolding a new application chart:
1. Create directory `Application/<service-name>/`.
2. Ensure `Chart.yaml` has `apiVersion: v2`, `name: <service-name>`, `version: 0.1.0`, and `type: application`.
3. Provide safe defaults in `values.yaml`:
   - Specify replica counts, container ports, image repository, pull policy, and resource limits.
   - Always define default probe paths (`livenessProbe` and `readinessProbe`).
   - Include default `autoscaling: { enabled: false }` to prevent nil pointer errors in `templates/hpa.yaml`.
4. Run `helm lint Application/<service-name>`.

### 2. Linting Charts

Always lint any modified charts before committing:
```powershell
# Lint specific application
helm lint Application/<service-name>

# Lint argocd chart
helm lint argocd
```

### 3. Rendering Templates Locally

To test how Kubernetes manifests will render without connecting to a cluster:
```powershell
# Render default values
helm template test-release Application/<service-name>

# Render with environment-specific overrides
helm template test-release Application/<service-name> -f Application/<service-name>/values.yaml -f common-deployment/values-pre-prod.yaml
```

## Best Practices Checklist

- [ ] **Resource Limits**: Always define `resources.requests` and `resources.limits` (CPU and Memory) to prevent node starvation.
- [ ] **Health Probes**: Always configure `livenessProbe` and `readinessProbe`.
- [ ] **Labels & Selectors**: Use `{{- include "<chart>.labels" . | nindent 4 }}` and `{{- include "<chart>.selectorLabels" . | nindent 6 }}` consistently for proper Pod matching.
- [ ] **Null Safety**: When referencing nested values in templates (e.g., `.Values.autoscaling.enabled`), ensure parent keys exist or guard with `if and .Values.autoscaling .Values.autoscaling.enabled`.

## Helper Scripts

- Run linting across all charts:
  - PowerShell: [scripts/lint-charts.ps1](./scripts/lint-charts.ps1)
  - Bash: [scripts/lint-charts.sh](./scripts/lint-charts.sh)

Run with:
```powershell
pwsh -File .agents/skills/helm-management/scripts/lint-charts.ps1
```
