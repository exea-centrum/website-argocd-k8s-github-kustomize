# Website ArgoCD K8s GitHub Kustomize

Aplikacja webowa z teorią gier wdrażana za pomocą ArgoCD na Kubernetes.

## Setup

1. Uruchom `./setup-repo.sh`, aby utworzyć strukturę projektu  
2. Dodaj repozytorium do GitHub  
3. Skonfiguruj GitHub Container Registry (GHCR)  
4. Zaaplikuj aplikację ArgoCD:  
   `kubectl apply -f argocd-application.yaml`

## Struktura

- `manifests/base/` – podstawowe manifesty Kubernetes  
- `manifests/production/` – kustomizacja dla środowiska produkcyjnego  
- `.github/workflows/` – GitHub Actions do CI/CD  

## Działanie

Po *pushu* do gałęzi `main`, GitHub Actions:
- zbuduje i wypchnie obraz Dockera do GHCR,  
- zaktualizuje tag obrazu w Kustomize,  
- ArgoCD automatycznie wdroży nową wersję aplikacji.
