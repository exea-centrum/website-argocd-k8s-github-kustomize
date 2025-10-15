#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Setting up repository website-argocd-k8s-github-kustomize ===${NC}"

# Check for required dependencies
if ! command -v git &> /dev/null; then
    echo -e "${RED}Error: Git is not installed. Please install Git and try again.${NC}"
    exit 1
fi

# Prompt for GitHub organization/username
read -p "Enter GitHub organization/username: " GITHUB_USER
if [ -z "$GITHUB_USER" ]; then
    echo -e "${RED}Error: GitHub username/organization cannot be empty.${NC}"
    exit 1
fi

# Create directory structure
echo -e "${YELLOW}Creating directory structure...${NC}"
mkdir -p .github/workflows
mkdir -p manifests/base
mkdir -p manifests/production
mkdir -p static # Directory for static assets like CSS/JS

# Create a sample CSS file to avoid COPY failure
echo -e "${YELLOW}Creating sample style.css...${NC}"
cat > static/style.css << 'EOF'
/* Sample CSS for the game theory website */
body {
    font-family: Arial, sans-serif;
}
EOF

# Create Dockerfile
echo -e "${YELLOW}Creating Dockerfile...${NC}"
cat > Dockerfile << 'EOF'
FROM nginx:alpine

# Copy index.html
COPY index.html /usr/share/nginx/html/

# Copy static assets if they exist
RUN if ls static/*.css 2>/dev/null; then cp static/*.css /usr/share/nginx/html/; fi
RUN if ls static/*.js 2>/dev/null; then cp static/*.js /usr/share/nginx/html/; fi

# Nginx configuration
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

# Create GitHub Actions workflow
echo -e "${YELLOW}Creating GitHub Actions workflow...${NC}"
cat > .github/workflows/build-deploy.yml << EOF
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
        uses: actions/checkout@v4 # Updated to latest version

      - name: List build context
        run: ls -la # Debug step to show files in context

      - name: Login to GHCR
        uses: docker/login-action@v3 # Updated to latest version
        with:
          registry: ghcr.io
          username: \${{ github.actor }}
          password: \${{ secrets.GITHUB_TOKEN }}

      - name: Build and push
        uses: docker/build-push-action@v6 # Updated to latest version
        with:
          context: .
          push: true
          tags: |
            ghcr.io/\${{ github.repository_owner }}/\${{ env.IMAGE_NAME }}:\${{ github.sha }}
            ghcr.io/\${{ github.repository_owner }}/\${{ env.IMAGE_NAME }}:latest

      - name: Update Kustomization
        run: |
          cd manifests/production
          sed -i "s|newTag:.*|newTag: \${{ github.sha }}|g" kustomization.yaml
          
      - name: Commit changes
        run: |
          git config --local user.email "action@github.com"
          git config --local user.name "GitHub Action"
          git add manifests/production/kustomization.yaml
          git commit -m "Update image to \${{ github.sha }}" || echo "No changes"
          git push
EOF

# Create Kubernetes manifests - Deployment
echo -e "${YELLOW}Creating Kubernetes manifests...${NC}"
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
        imagePullPolicy: Always
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

# Create Service
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

# Create Ingress
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

# Create base kustomization
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

# Create production kustomization
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

# Create index.html
echo -e "${YELLOW}Creating index.html...${NC}"
cat > index.html << 'HTMLEOF'
<!DOCTYPE html>
<html lang="pl">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Teoria Gier - Interaktywna Strona</title>
    <script src="https://cdn.tailwindcss.com"></script>
    <link rel="stylesheet" href="/style.css">
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
            <p>Teoria Gier © 2025</p>
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
                btn.classList.add('bg-slate-700', 'text-gray-300');
            });
            const selectedBtn = document.querySelector(`[data-player="${player}"][data-choice="${choice}"]`);
            selectedBtn.classList.add(choice === 'cooperate' ? 'bg-blue-500' : 'bg-red-500', 'text-white');
            if (choices.p1 && choices.p2) calculateResult();
        }

        function calculateResult() {
            let result = { p1: 0, p2: 0, desc: '' };
            if (choices.p1 === 'cooperate' && choices.p2 === 'cooperate') {
                result = { p1: -1, p2: -1, desc: 'Obaj współpracują - każdy dostaje 1 rok' };
            } else if (choices.p1 === 'betray' && choices.p2 === 'betray') {
                result = { p1: -3, p2: -3, desc: 'Obaj zdradzają - każdy dostaje 3 lata' };
            } else if (choices.p1 === 'cooperate') {
                result = { p1: -5, p2: 0, desc: 'G1 współpracuje, G2 zdradza - G1: 5 lat, G2: wolny' };
            } else {
                result = { p1: 0, p2: -5, desc: 'G1 zdradza, G2 współpracuje - G1: wolny, G2: 5 lat' };
            }
            document.getElementById('result').classList.remove('hidden');
            document.getElementById('result-text').textContent = result.desc;
            document.getElementById('p1-result').textContent = result.p1 === 0 ? '✓' : result.p1 + ' lat';
            document.getElementById('p2-result').textContent = result.p2 === 0 ? '✓' : result.p2 + ' lat';
        }

        showTab('intro');
    </script>
</body>
</html>
HTMLEOF

# Create .dockerignore
echo -e "${YELLOW}Creating .dockerignore...${NC}"
cat > .dockerignore << 'EOF'
.DS_Store
*.swp
*.swo
*~
.git
.github
manifests
EOF

# Create .gitignore
echo -e "${YELLOW}Creating .gitignore...${NC}"
cat > .gitignore << 'EOF'
.DS_Store
*.swp
*.swo
*~
EOF

# Create README
echo -e "${YELLOW}Creating README.md...${NC}"
cat > README.md << EOF
# Website ArgoCD K8s GitHub Kustomize

A web application for game theory, deployed using ArgoCD on Kubernetes with GitHub Actions and Kustomize.

## Prerequisites

- A GitHub account with a repository created.
- Access to GitHub Container Registry (GHCR).
- A Kubernetes cluster with ArgoCD installed.
- \`kubectl\` configured to interact with your cluster.

## Setup

1. Run \`./setup-repo.sh\` to create the project structure.
2. Add the repository to GitHub:
   \`\`\`bash
   git remote add origin https://github.com/${GITHUB_USER}/website-argocd-k8s-github-kustomize.git
   git push -u origin main
   \`\`\`
3. Configure GitHub Container Registry (GHCR) in your repository settings (ensure the GitHub Actions workflow has write permissions to packages).
4. Apply the ArgoCD application manifest to your cluster:
   \`\`\`bash
   kubectl apply -f argocd-application.yaml
   \`\`\`

## Project Structure

- \`manifests/base/\`: Base Kubernetes manifests for Deployment, Service, and Ingress.
- \`manifests/production/\`: Production-specific Kustomize configuration.
- \`.github/workflows/\`: GitHub Actions workflow for building and pushing the Docker image.
- \`static/\`: Static assets (CSS, JS) for the web application.
- \`index.html\`: Main HTML file for the game theory website.
- \`Dockerfile\`: Docker configuration for building the NGINX-based web server.

## Usage

- On push to the \`main\` branch, GitHub Actions builds a Docker image, pushes it to GHCR, and updates the image tag in \`manifests/production/kustomization.yaml\`.
- ArgoCD detects changes in the repository and deploys the updated application to the Kubernetes cluster.

## Testing Locally

To test the Docker build locally:
\`\`\`bash
docker buildx build --tag test-image .
\`\`\`

## Debugging

- Enable debug logging in GitHub Actions by setting the repository secret \`ACTIONS_STEP_DEBUG\` to \`true\`.
- Check the build context by inspecting the \`ls -la\` output in the GitHub Actions logs.
- Verify that the Kubernetes manifests are correctly applied using:
  \`\`\`bash
  kubectl get all -n davtrokustomize
  \`\`\`

## Notes

- Ensure the \`davtrokustomize\` namespace exists in your Kubernetes cluster before applying the ArgoCD application.
- The Ingress resource assumes an NGINX Ingress Controller is installed. Update the \`host\` in \`manifests/base/ingress.yaml` to match your domain.
EOF

# Initialize git repository
echo -e "${YELLOW}Initializing git repository...${NC}"
git init || { echo -e "${RED}Error: Failed to initialize git repository.${NC}"; exit 1; }
git add .
git commit -m "Initial commit - website with game theory" || { echo -e "${RED}Error: Failed to commit changes.${NC}"; exit 1; }

echo -e "${GREEN}=== Setup completed successfully! ===${NC}"
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Create a repository on GitHub: https://github.com/new"
echo "2. Add remote: git remote add origin https://github.com/${GITHUB_USER}/website-argocd-k8s-github-kustomize.git"
echo "3. Push changes: git push -u origin main"
echo "4. Apply ArgoCD application: kubectl apply -f argocd-application.yaml"
echo ""
echo -e "${GREEN}Done!${NC}"