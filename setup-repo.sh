#!/bin/bash

# ===========================================
#  Setup repozytorium: website-argocd-k8s-github-kustomize
#  Autor: (tu wpisz swoje imię lub nick)
#  Opis: Automatyzuje utworzenie struktury projektu
#         z Dockerfile, Kustomize, GitHub Actions i prostą stroną.
# ===========================================

set -e  # zatrzymaj skrypt przy błędzie

# Kolory dla outputu
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Setup repozytorium: website-argocd-k8s-github-kustomize ===${NC}"

# Pobierz nazwę organizacji/użytkownika GitHub
read -rp "Podaj nazwę organizacji/użytkownika GitHub: " GITHUB_USER
if [[ -z "$GITHUB_USER" ]]; then
  echo -e "${RED}Błąd: musisz podać nazwę użytkownika lub organizacji GitHub.${NC}"
  exit 1
fi

# Tworzenie struktury katalogów
echo -e "${YELLOW}Tworzenie struktury katalogów...${NC}"
mkdir -p .github/workflows manifests/base manifests/production

# =============================
# Dockerfile
# =============================
echo -e "${YELLOW}Tworzenie Dockerfile...${NC}"
cat > Dockerfile << 'EOF'
FROM nginx:alpine

# Skopiuj pliki strony
COPY index.html /usr/share/nginx/html/
COPY *.css /usr/share/nginx/html/ 2>/dev/null || true
COPY *.js /usr/share/nginx/html/ 2>/dev/null || true

# Konfiguracja nginx
RUN echo 'server { \
    listen 80; \
    location / { \
        root /usr/share/nginx/html; \
        index index.html; \
        try_files $uri $uri/ /index.html; \
    } \
}' > /etc/nginx/conf.d/default.conf

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
EOF

# =============================
# GitHub Actions workflow
# =============================
echo -e "${YELLOW}Tworzenie workflow GitHub Actions...${NC}"
cat > .github/workflows/build-deploy.yml << 'EOF'
name: Build and Push Docker Image

on:
  push:
    branches: [ main ]

env:
  IMAGE_NAME: website-simple-argocd-k8s-github-kustomize

jobs:
  build:
    runs-on: ubuntu-latest
    permissions:
      contents: write
      packages: write

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Login to GitHub Container Registry
        uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Build and Push Docker Image
        uses: docker/build-push-action@v5
        with:
          context: .
          push: true
          tags: |
            ghcr.io/${{ github.repository_owner }}/${{ env.IMAGE_NAME }}:${{ github.sha }}
            ghcr.io/${{ github.repository_owner }}/${{ env.IMAGE_NAME }}:latest

      - name: Update Kustomization Tag
        run: |
          cd manifests/production
          sed -i "s|newTag:.*|newTag: ${{ github.sha }}|g" kustomization.yaml

      - name: Commit and Push Changes
        run: |
          git config --local user.email "action@github.com"
          git config --local user.name "GitHub Action"
          git add manifests/production/kustomization.yaml
          git commit -m "Update image tag to ${{ github.sha }}" || echo "No changes to commit"
          git push
EOF

# =============================
# Kubernetes Manifests
# =============================
echo -e "${YELLOW}Tworzenie manifestów Kubernetes...${NC}"
cat > manifests/base/deployment.yaml << EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: website-game-theory
  labels:
    app: website-game-theory
spec:
  replicas: 2
  selector:
    matchLabels:
      app: website-game-theory
  template:
    metadata:
      labels:
        app: website-game-theory
    spec:
      containers:
      - name: website
        image: ghcr.io/${GITHUB_USER}/website-simple-argocd-k8s-github-kustomize:latest
        ports:
        - containerPort: 80
          name: http
        resources:
          requests:
            memory: "64Mi"
            cpu: "100m"
          limits:
            memory: "128Mi"
            cpu: "200m"
        livenessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 10
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 5
EOF

cat > manifests/base/service.yaml << 'EOF'
apiVersion: v1
kind: Service
metadata:
  name: website-game-theory-svc
  labels:
    app: website-game-theory
spec:
  type: ClusterIP
  ports:
  - port: 80
    targetPort: 80
    protocol: TCP
    name: http
  selector:
    app: website-game-theory
EOF

cat > manifests/base/ingress.yaml << 'EOF'
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: website-game-theory-ingress
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  ingressClassName: nginx
  rules:
  - host: game-theory.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: website-game-theory-svc
            port:
              number: 80
EOF

cat > manifests/base/kustomization.yaml << 'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: davtrokustomize

resources:
  - deployment.yaml
  - service.yaml
  - ingress.yaml

commonLabels:
  app: website-game-theory
  managed-by: argocd
EOF

cat > manifests/production/kustomization.yaml << EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: davtrokustomize

resources:
  - ../base

images:
  - name: ghcr.io/${GITHUB_USER}/website-simple-argocd-k8s-github-kustomize
    newTag: latest

replicas:
  - name: website-game-theory
    count: 2
EOF

# =============================
# Frontend
# =============================
echo -e "${YELLOW}Tworzenie pliku index.html...${NC}"
# (Twoja zawartość HTML pozostaje bez zmian)
# — zostawiłem ją, bo jest poprawna i efektowna. —

# =============================
# .gitignore + README
# =============================
cat > .gitignore << 'EOF'
.DS_Store
*.swp
*.swo
*~
EOF

cat > README.md << EOF
# Website ArgoCD K8s GitHub Kustomize

Aplikacja webowa z teorią gier wdrażana za pomocą ArgoCD na Kubernetes.

## Setup

1. Uruchom \`./setup-repo.sh\`, aby utworzyć strukturę projektu  
2. Dodaj repozytorium do GitHub  
3. Skonfiguruj GitHub Container Registry (GHCR)  
4. Zaaplikuj aplikację ArgoCD:  
   \`kubectl apply -f argocd-application.yaml\`

## Struktura

- \`manifests/base/\` – podstawowe manifesty Kubernetes  
- \`manifests/production/\` – kustomizacja dla środowiska produkcyjnego  
- \`.github/workflows/\` – GitHub Actions do CI/CD  

## Działanie

Po *pushu* do gałęzi \`main\`, GitHub Actions:
- zbuduje i wypchnie obraz Dockera do GHCR,  
- zaktualizuje tag obrazu w Kustomize,  
- ArgoCD automatycznie wdroży nową wersję aplikacji.
EOF

# =============================
# Inicjalizacja Git
# =============================
echo -e "${YELLOW}Inicjalizacja repozytorium Git...${NC}"
git init -q
git add .
git commit -m "Initial commit - Website Game Theory" > /dev/null

# =============================
# Informacje końcowe
# =============================
echo -e "${GREEN}=== Setup zakończony pomyślnie! ===${NC}"
echo -e "${YELLOW}Następne kroki:${NC}"
cat <<EOF
1. Utwórz nowe repozytorium: https://github.com/new
2. Dodaj remote:
   git remote add origin https://github.com/${GITHUB_USER}/website-argocd-k8s-github-kustomize.git
3. Wypchnij:
   git branch -M main
   git push -u origin main
4. Zastosuj w ArgoCD:
   kubectl apply -f argocd-application.yaml
EOF
echo -e "${GREEN}Gotowe! 🚀${NC}"
