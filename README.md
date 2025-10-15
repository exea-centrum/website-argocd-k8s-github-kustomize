# Website ArgoCD K8s GitHub Kustomize

Aplikacja webowa z teorią gier wdrażana przez ArgoCD na Kubernetes.

## Setup

1. Uruchom `./setup-repo.sh` aby utworzyć strukturę projektu
2. Dodaj repo do GitHub
3. Skonfiguruj GitHub Container Registry (GHCR) 
4. Zaaplikuj ArgoCD application: `kubectl apply -f argocd-application.yaml`

## Struktura

- `manifests/base/` - podstawowe manifesty Kubernetes
- `manifests/production/` - kustomizacja dla produkcji
- `.github/workflows/` - GitHub Actions do budowania obrazu

## Użycie

Po push do `main` branch, GitHub Actions zbuduje obraz i zaktualizuje tag w kustomization.yaml.
ArgoCD automatycznie wykryje zmiany i wdroży nową wersję.
