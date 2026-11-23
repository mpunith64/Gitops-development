# Agent Instructions & Repository Rules

This file defines the operational guidelines, architectural rules, and validation standards for automated agents and developers working in this GitOps repository.

> For full architectural details, deployment workflows, and runbooks, refer to [agent.md](./agent.md).

## Operational Rules

1. **Validation Requirement**: Always execute the validation suite before proposing or finalizing any commit:
   - PowerShell: `powershell -File .agents/skills/gitops-validation/scripts/validate-all.ps1`
   - Bash: `bash .agents/skills/gitops-validation/scripts/validate-all.sh`
2. **Declarative GitOps**: Never suggest manual, non-declarative cluster state mutations. All resources must be managed via Helm charts in `Application/` or registered in `argocd/package-<env>.json`.
3. **No Plaintext Secrets**: Secrets must never be stored in Git. Use references to Kubernetes Secrets, Sealed Secrets, or External Secrets Operator.
4. **Pruning Awareness**: Child applications configured in `argocd/templates/deployment.yaml` run with `syncPolicy.automated.prune = true`. Removing a service from `package-<env>.json` triggers resource deletion in the target Kubernetes namespace.
5. **Chart Versioning**: Keep `version` (SemVer) and `appVersion` in `Chart.yaml` updated and aligned with service releases.

## Repository Skills

The following skills are installed in `.agents/skills/` to assist in common GitOps tasks:
- `argocd-service-management`: Managing and generating ArgoCD Application CRDs.
- `helm-management`: Linting, templating, and authoring Helm charts.
- `gitops-environment-promotion`: Promoting service releases across environments.
- `gitops-validation`: Automated validation of JSON catalogs, charts, and templates.
