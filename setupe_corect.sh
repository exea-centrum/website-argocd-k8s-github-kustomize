#!/bin/bash

# Kolory
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=== Setup repozytorium website-argocd-k8s-github-kustomize ===${NC}"

# Pobierz nazwę użytkownika/org
read -p "Podaj nazwę organizacji/użytkownika GitHub: " GITHUB_USER

# Tworzenie struktury
mkdir -p .github/workflows
mkdir -p manifests/base
mkdir -p manifests/production

# Dockerfile
cat > Dockerfile << 'EOF'
FROM nginx:alpine

COPY index.html /usr/share/nginx/html/
COPY *.css /usr/share/nginx/html/ 2>/dev/null || true
COPY *.js /usr/share/nginx/html/ 2>/dev/null || true

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

# Workflow GitHub Actions
cat > .github/workflows/build-deploy.yml << 'EOF'
name: Build and Push to GHCR

on:
  push:
    branches:
      - main

permissions:
  contents: write
  packages: write

env:
  IMAGE_NAME: website-argocd-k8s-github-kustomize

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Log in to GHCR
        uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Build and Push Docker image
        uses: docker/build-push-action@v6
        with:
          context: .
          push: true
          tags: |
            ghcr.io/${{ github.repository_owner }}/${{ env.IMAGE_NAME }}:${{ github.sha }}
            ghcr.io/${{ github.repository_owner }}/${{ env.IMAGE_NAME }}:latest
EOF

# Deployment
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
        image: ghcr.io/${GITHUB_USER}/website-argocd-k8s-github-kustomize:latest
        ports:
        - containerPort: 80
EOF

# Service
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
    name: http
  selector:
    app: website-game-theory
EOF

# Ingress
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

# Base kustomization
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

# Production kustomization
cat > manifests/production/kustomization.yaml << EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: davtrokustomize
resources:
  - ../base
images:
  - name: ghcr.io/${GITHUB_USER}/website-argocd-k8s-github-kustomize
    newTag: latest
replicas:
  - name: website-game-theory
    count: 2
EOF

# ArgoCD Application
cat > argocd-application.yaml << 'EOF'
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: website-game-theory
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/exea-centrum/website-argocd-k8s-github-kustomize.git
    targetRevision: HEAD
    path: manifests/production
  destination:
    server: https://kubernetes.default.svc
    namespace: davtrokustomize
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
      allowEmpty: false
    syncOptions:
      - CreateNamespace=true
      - PrunePropagationPolicy=foreground
      - PruneLast=true
EOF

# Utwórz index.html
echo -e "${YELLOW}Tworzenie index.html...${NC}"
cat > index.html << 'HTMLEOF'
<!DOCTYPE html>
<html lang="pl">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Teoria Gier - Interaktywna Strona</title>
    <script src="https://cdn.tailwindcss.com"></script>
    <style>
        @keyframes fadeIn {
            from { opacity: 0; transform: translateY(10px); }
            to { opacity: 1; transform: translateY(0); }
        }
        .animate-fade-in { animation: fadeIn 0.5s ease-out; }
    </style>
</head>
<body class="bg-gradient-to-br from-slate-900 via-purple-900 to-slate-900 text-white min-h-screen">
    <header class="border-b border-purple-500/30 backdrop-blur-sm bg-black/20">
        <div class="container mx-auto px-6 py-6">
            <div class="flex items-center justify-between flex-wrap gap-4">
                <div class="flex items-center gap-3">
                    <svg class="w-10 h-10 text-purple-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9.663 17h4.673M12 3v1m6.364 1.636l-.707.707M21 12h-1M4 12H3m3.343-5.657l-.707-.707m2.828 9.9a5 5 0 117.072 0l-.548.547A3.374 3.374 0 0014 18.469V19a2 2 0 11-4 0v-.531c0-.895-.356-1.754-.988-2.386l-.548-.547z"></path>
                    </svg>
                    <h1 class="text-3xl font-bold bg-gradient-to-r from-purple-400 to-pink-400 bg-clip-text text-transparent">
                        Teoria Gier
                    </h1>
                </div>
                <nav class="flex gap-4">
                    <button onclick="showTab('intro')" class="tab-btn px-4 py-2 rounded-lg transition-all text-purple-300" data-tab="intro">Wprowadzenie</button>
                    <button onclick="showTab('apps')" class="tab-btn px-4 py-2 rounded-lg transition-all text-purple-300" data-tab="apps">Zastosowania</button>
                    <button onclick="showTab('interactive')" class="tab-btn px-4 py-2 rounded-lg transition-all text-purple-300" data-tab="interactive">Gra</button>
                </nav>
            </div>
        </div>
    </header>

    <main class="container mx-auto px-6 py-12">
        <div id="intro-tab" class="tab-content">
            <div class="space-y-8 animate-fade-in">
                <div class="bg-gradient-to-br from-purple-500/10 to-pink-500/10 backdrop-blur-lg border border-purple-500/20 rounded-2xl p-8">
                    <h2 class="text-4xl font-bold mb-6 text-purple-300">Czym jest Teoria Gier?</h2>
                    <p class="text-lg text-gray-300 leading-relaxed mb-4">
                        Teoria gier to gałąź matematyki stosowanej, która bada strategie w sytuacjach konkurencyjnych i współpracy. 
                        Analizuje, jak racjonalni gracze podejmują decyzje, gdy wynik zależy nie tylko od ich własnych wyborów, 
                        ale także od decyzji innych uczestników.
                    </p>
                </div>
                <div class="grid md:grid-cols-3 gap-6">
                    <div class="bg-gradient-to-br from-blue-500/10 to-purple-500/10 backdrop-blur-lg border border-blue-500/20 rounded-xl p-6 hover:scale-105 transition-transform">
                        <h3 class="text-xl font-bold mb-3 text-blue-300">Gracze</h3>
                        <p class="text-gray-400">Uczestnicy gry podejmujący decyzje strategiczne</p>
                    </div>
                    <div class="bg-gradient-to-br from-green-500/10 to-emerald-500/10 backdrop-blur-lg border border-green-500/20 rounded-xl p-6 hover:scale-105 transition-transform">
                        <h3 class="text-xl font-bold mb-3 text-green-300">Strategie</h3>
                        <p class="text-gray-400">Możliwe wybory i plany działania graczy</p>
                    </div>
                    <div class="bg-gradient-to-br from-pink-500/10 to-rose-500/10 backdrop-blur-lg border border-pink-500/20 rounded-xl p-6 hover:scale-105 transition-transform">
                        <h3 class="text-xl font-bold mb-3 text-pink-300">Wypłaty</h3>
                        <p class="text-gray-400">Wyniki zależne od kombinacji strategii</p>
                    </div>
                </div>
            </div>
        </div>

        <div id="apps-tab" class="tab-content hidden">
            <div class="space-y-6 animate-fade-in">
                <h2 class="text-4xl font-bold mb-8 text-purple-300">Zastosowania Teorii Gier</h2>
                <div class="bg-gradient-to-br from-slate-800/50 to-slate-900/50 backdrop-blur-lg border border-purple-500/20 rounded-xl p-6">
                    <h3 class="text-2xl font-bold mb-4 text-purple-300">Ekonomia i Biznes</h3>
                    <ul class="space-y-2">
                        <li class="text-gray-400 flex items-center gap-2"><span class="w-1.5 h-1.5 rounded-full bg-purple-400"></span>Strategie cenowe i konkurencja rynkowa</li>
                        <li class="text-gray-400 flex items-center gap-2"><span class="w-1.5 h-1.5 rounded-full bg-purple-400"></span>Aukcje i przetargi</li>
                    </ul>
                </div>
                <div class="bg-gradient-to-br from-slate-800/50 to-slate-900/50 backdrop-blur-lg border border-purple-500/20 rounded-xl p-6">
                    <h3 class="text-2xl font-bold mb-4 text-purple-300">Polityka</h3>
                    <ul class="space-y-2">
                        <li class="text-gray-400 flex items-center gap-2"><span class="w-1.5 h-1.5 rounded-full bg-purple-400"></span>Wyścig zbrojeń</li>
                        <li class="text-gray-400 flex items-center gap-2"><span class="w-1.5 h-1.5 rounded-full bg-purple-400"></span>Koalicje i sojusze</li>
                    </ul>
                </div>
            </div>
        </div>

        <div id="interactive-tab" class="tab-content hidden">
            <div class="space-y-8 animate-fade-in">
                <div class="bg-gradient-to-br from-purple-500/10 to-pink-500/10 backdrop-blur-lg border border-purple-500/20 rounded-2xl p-8">
                    <h2 class="text-4xl font-bold mb-6 text-purple-300">Dylemat Więźnia</h2>
                    <p class="text-lg text-gray-300 mb-8">Wybierz strategię dla każdego gracza!</p>
                    <div class="grid md:grid-cols-2 gap-6 mb-8">
                        <div class="bg-slate-800/50 rounded-xl p-6 border border-blue-500/30">
                            <h3 class="text-xl font-bold mb-4 text-blue-300">Gracz 1</h3>
                            <div class="space-y-3">
                                <button onclick="setChoice('p1', 'cooperate')" class="choice-btn w-full py-3 px-4 rounded-lg transition-all bg-slate-700 text-gray-300 hover:bg-slate-600" data-player="p1" data-choice="cooperate">Współpracuj</button>
                                <button onclick="setChoice('p1', 'betray')" class="choice-btn w-full py-3 px-4 rounded-lg transition-all bg-slate-700 text-gray-300 hover:bg-slate-600" data-player="p1" data-choice="betray">Zdradź</button>
                            </div>
                        </div>
                        <div class="bg-slate-800/50 rounded-xl p-6 border border-pink-500/30">
                            <h3 class="text-xl font-bold mb-4 text-pink-300">Gracz 2</h3>
                            <div class="space-y-3">
                                <button onclick="setChoice('p2', 'cooperate')" class="choice-btn w-full py-3 px-4 rounded-lg transition-all bg-slate-700 text-gray-300 hover:bg-slate-600" data-player="p2" data-choice="cooperate">Współpracuj</button>
                                <button onclick="setChoice('p2', 'betray')" class="choice-btn w-full py-3 px-4 rounded-lg transition-all bg-slate-700 text-gray-300 hover:bg-slate-600" data-player="p2" data-choice="betray">Zdradź</button>
                            </div>
                        </div>
                    </div>
                    <div id="result" class="hidden bg-gradient-to-br from-green-500/20 to-emerald-500/20 border border-green-500/30 rounded-xl p-6">
                        <h3 class="text-2xl font-bold mb-4 text-green-300">Wynik</h3>
                        <p id="result-text" class="text-xl text-gray-300 mb-4"></p>
                        <div class="grid grid-cols-2 gap-4">
                            <div class="bg-slate-800/50 rounded-lg p-4">
                                <p class="text-gray-400 mb-1">Gracz 1</p>
                                <p id="p1-result" class="text-3xl font-bold text-blue-400"></p>
                            </div>
                            <div class="bg-slate-800/50 rounded-lg p-4">
                                <p class="text-gray-400 mb-1">Gracz 2</p>
                                <p id="p2-result" class="text-3xl font-bold text-pink-400"></p>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </main>

    <footer class="border-t border-purple-500/30 backdrop-blur-sm bg-black/20 mt-16">
        <div class="container mx-auto px-6 py-8 text-center text-gray-400">
            <p>Teoria Gier © 2024</p>
        </div>
    </footer>

    <script>
        let choices = { p1: null, p2: null };
        
        function showTab(tabName) {
            document.querySelectorAll('.tab-content').forEach(tab => tab.classList.add('hidden'));
            document.getElementById(tabName + '-tab').classList.remove('hidden');
            document.querySelectorAll('.tab-btn').forEach(btn => {
                btn.classList.remove('bg-purple-500', 'text-white');
                btn.classList.add('text-purple-300');
            });
            document.querySelector(`[data-tab="${tabName}"]`).classList.add('bg-purple-500', 'text-white');
        }

        function setChoice(player, choice) {
            choices[player] = choice;
            document.querySelectorAll(`[data-player="${player}"]`).forEach(btn => {
                btn.classList.remove('bg-blue-500', 'bg-red-500', 'text-white');
                btn.classList.add('bg-slate-700');
            });
            const btn = document.querySelector(`[data-player="${player}"][data-choice="${choice}"]`);
            btn.classList.remove('bg-slate-700');
            btn.classList.add(choice === 'cooperate' ? 'bg-blue-500' : 'bg-red-500', 'text-white');
            
            if (choices.p1 && choices.p2) evaluate();
        }

        function evaluate() {
            let resultText, p1Result, p2Result;
            if (choices.p1 === 'cooperate' && choices.p2 === 'cooperate') {
                resultText = 'Obaj współpracują – umiarkowana nagroda dla obu!';
                p1Result = '+3'; p2Result = '+3';
            } else if (choices.p1 === 'betray' && choices.p2 === 'cooperate') {
                resultText = 'Gracz 1 zdradza, Gracz 2 współpracuje – Gracz 1 wygrywa więcej!';
                p1Result = '+5'; p2Result = '0';
            } else if (choices.p1 === 'cooperate' && choices.p2 === 'betray') {
                resultText = 'Gracz 2 zdradza, Gracz 1 współpracuje – Gracz 2 wygrywa więcej!';
                p1Result = '0'; p2Result = '+5';
            } else {
                resultText = 'Obaj zdradzają – przegrywają!';
                p1Result = '+1'; p2Result = '+1';
            }
            document.getElementById('result').classList.remove('hidden');
            document.getElementById('result-text').textContent = resultText;
            document.getElementById('p1-result').textContent = p1Result;
            document.getElementById('p2-result').textContent = p2Result;
        }

        showTab('intro');
    </script>
</body>
</html>
HTMLEOF

# .gitignore
cat > .gitignore << 'EOF'
# Node / build
node_modules/
dist/
.env
.DS_Store

# Docker
*.log
*.pid
*.tmp

# VSCode / IDE
.vscode/
.idea/

# GitHub actions cache
**/__pycache__/
EOF

echo -e "${GREEN}✅ Skrypt gotowy!${NC}"
