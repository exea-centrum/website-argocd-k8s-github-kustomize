# Website ArgoCD K8s GitHub Kustomize

Aplikacja webowa z teorią gier wdrażana za pomocą ArgoCD na Kubernetes.

## Setup

1.  Uruchom `./setup-repo.sh` or `./setup-corect`, aby utworzyć strukturę projektu lub git clone ..... i control+H exea-centrum na Twój
    '''consol

        |.github
          |workflows
            |--build-deploy.yml
        manifests/
        ├── base/
        │   ├── deployment.yaml
        │   ├── service.yaml
        │   ├── ingress.yaml
        │   └── kustomization.yaml
        └── production/
            └── kustomization.yaml
        |.gitignore
        |Dockerfile
        |index.html

'''

2.  Dodaj repozytorium do GitHub 3. Skonfiguruj GitHub Container Registry (GHCR) 4. Zaaplikuj aplikację ArgoCD:  
    `kubectl apply -f argocd-application.yaml`

'''consol

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
        syncOptions:
          - CreateNamespace=true
          - PrunePropagationPolicy=foreground
          - PruneLast=true

'''

## Struktura

- `manifests/base/` – podstawowe manifesty Kubernetes
- `manifests/production/` – kustomizacja dla środowiska produkcyjnego
- `.github/workflows/` – GitHub Actions do CI/CD

## Działanie

Po _pushu_ do gałęzi `main`, GitHub Actions:

- zbuduje i wypchnie obraz Dockera do GHCR,
- zaktualizuje tag obrazu w Kustomize,
- ArgoCD automatycznie wdroży nową wersję aplikacji.
- davtro

### **3\. Jeśli obraz jest prywatny — dodaj dostęp w Kubernetes**

Utwórz **sekret** z danymi logowania do GHCR (z konta, które może odczytywać paczki):

`kubectl create secret docker-registry ghcr-secret \`  
 `--docker-server=ghcr.io \`  
 `--docker-username=<twoj_login_github> \`  
 `--docker-password=<twój_personal_access_token> \`  
 `--namespace=davtrokustomize`

# **@@@@@@@@@@@@@@@@@@@@@@@@@**

## **Polecam użyć PAT "GHCR_PAT" zamiast GITHUB_TOKEN cteate "GHCR_TOKEN"**

### **1️⃣ Upewnij się, że używasz poprawnego loginu do GHCR**

W pliku workflow (`.github/workflows/build.yaml` lub podobnym) znajdź krok logowania do registry, np.:

`- name: Log in to GitHub Container Registry`  
 `uses: docker/login-action@v3`  
 `with:`  
 `registry: ghcr.io`  
 `username: ${{ github.actor }}`  
 `password: ${{ secrets.GITHUB_TOKEN }}`

🟡 **Problem:** domyślny `${{ secrets.GITHUB_TOKEN }}` ma tylko `read:packages`,  
 nie pozwala na `write:packages` (czyli push obrazów).

---

### **2️⃣ 🔑 Utwórz nowy Personal Access Token (PAT)**

1. Wejdź w [https://github.com/settings/tokens](https://github.com/settings/tokens)

2. Kliknij **"Generate new token (classic)" nowy cteate "GHCR_TOKEN" ale tylko z:**

3. Zaznacz uprawnienia:

   - ✅ `write:packages`

   - ✅ `read:packages`

   - ✅ `repo` _(jeśli prywatny repozytorium)_

4. Skopiuj token

---

### **3️⃣ Dodaj go jako sekret w repozytorium**

W repozytorium → **Settings → Secrets and variables → Actions → New repository secret**  
 Nazwij np.:

`GHCR_PAT`

i wklej tam token.

---

### **4️⃣ Zaktualizuj workflow**

Zamiast `GITHUB_TOKEN`, użyj sekretu `GHCR_PAT`:

`- name: Log in to GitHub Container Registry`  
 `uses: docker/login-action@v3`  
 `with:`  
 `registry: ghcr.io`  
 `username: ${{ github.actor }}`  
 `password: ${{ secrets.GHCR_PAT }}`

---

### **5️⃣ (opcjonalnie) Sprawdź, czy repozytorium GHCR jest dostępne**

Wejdź na  
 🔗 `https://github.com/orgs/exea-centrum/packages`

i zobacz, czy masz tam paczkę `website-simple-argocd-k8s-github-kustomize`.

Jeśli nie istnieje — token i workflow ją utworzą automatycznie.

---

### **✅ Gotowy przykład sekcji w workflow**

#### **potrzebne by ubunt w kontenerze mogło budować i zapisywać obrazy w GHCR.io**

#### **jak widać poniżej GitHub Actions buduje obraz i wypchycha po -main czy deweloper do dev a admin do main**

'''consol

      `name: Build and Push Docker image`

      `on:`
      `push:`
      `branches:`
      `- main`

      `jobs:`
      `build:`
      `runs-on: ubuntu-latest`
      `steps:`
      `- name: Checkout code`
      `uses: actions/checkout@v4`

      `- name: Set up Docker Buildx`
        `uses: docker/setup-buildx-action@v3`

      `- name: Log in to GitHub Container Registry`
        `uses: docker/login-action@v3`
        `with:`
          `registry: ghcr.io`
          `username: ${{ github.actor }}`
          `password: ${{ secrets.GHCR_PAT }}`

      `- name: Build and push image`
        `uses: docker/build-push-action@v6`
        `with:`
          `context: .`
          `push: true`
          `tags: ghcr.io/exea-centrum/website-argocd-k8s-github-kustomize:${{ github.sha }}`

'''

### **Poniższe polecenia wykonaj na maszynie z k8s i ArgoCD, przykład na microk8s bastion**

### **potrzebne by argoCD mogło pobierać obraz z GitHube ghcr.io**

'''consol

      export GHCR*TOKEN=ghp*...........

      kubectl create secret docker-registry ghcr-secret --docker-server=ghcr.io --docker-username=exea-centrum --docker-password=ghp\_....................... lub ->GHCR_TOKEN --namespace=davtrokustomize

      możesz z UI k8s lub k9s albo AgroCD poniższe polecenie wykonać
      microk8s kubectl rollout restart deployment website-game-theory -n davtrokustomize

      snap install k9s

      szybki test w przeglądarce http://127.0.0.1:8085/
      microk8s kubectl port-forward -n davtrokustomize svc/website-game-theory-svc 8085:80

'''

### **Wsad dla Argocd z UI Aplications/ New App/ Edit as Yaml**

'''consol
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
        syncOptions:
          - CreateNamespace=true
          - PrunePropagationPolicy=foreground
          - PruneLast=true

'''

# **!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!**

## **✅ Kroki naprawy (dla organizacji `exea-centrum`)**

### **1️⃣ Włącz GHCR permissions dla GITHUB_TOKEN**

Wejdź w:

**Settings → Actions → General → Workflow permissions**

i zaznacz:

`✓ Read and write permissions`

oraz

`✓ Allow GitHub Actions to create and approve pull requests`

➡️ Zapisz zmiany.

🔸 To musisz ustawić **w organizacji** (lub repozytorium), bo GHCR jest przypisany do `exea-centrum`, nie do Twojego osobistego konta.

---

### **2️⃣ Upewnij się, że repozytorium ma dostęp do pakietów GHCR**

Wejdź na stronę Twojego pakietu:

[https://github.com/orgs/exea-centrum/packages](https://github.com/orgs/exea-centrum/packages)

Kliknij w swój pakiet `website-argocd-k8s-github-kustomize` →  
 **Package settings → Manage access**

Dodaj dostęp:

`Repository access → Add repository → wybierz swoje repo (website-argocd-k8s-github-kustomize)`

➡️ Dzięki temu workflow z tego repo **może publikować** obrazy do tego pakietu.

---

### **3️⃣ Upewnij się, że w workflow masz te permissions:**

W `.github/workflows/build.yml`:
'''consol
`permissions:`  
 `contents: write`  
 `packages: write`
'''
Bez tego GitHub Actions nie wygeneruje tokenu z uprawnieniem `write:packages`.

---

### **4️⃣ (Opcjonalnie) Jeśli organizacja wymaga PAT (Personal Access Token)**

Niektóre organizacje blokują GHCR push przy użyciu `GITHUB_TOKEN`.  
 Wtedy trzeba dodać **sekret `GHCR_PAT`** z osobistym tokenem.

Utwórz token:

GitHub → Settings → Developer settings → Personal access tokens (classic)  
 Uprawnienia:

- `write:packages`

- `read:packages`

- `repo`

Dodaj go w repozytorium jako:

`Settings → Secrets → Actions → New repository secret`  
`Name: GHCR_PAT`  
`Value: <twój token>`

A w workflow:
'''consol
`- name: Log in to GHCR`  
 `uses: docker/login-action@v3`  
 `with:`  
 `registry: ghcr.io`  
 `username: ${{ github.actor }}`  
 `password: ${{ secrets.GHCR_PAT }}`
'''

## **1\. Spójność nazw (Docker image, repo, ścieżki)**

**Zmieniono:**

`- website-simple-argocd-k8s-github-kustomize`  
`+ website-argocd-k8s-github-kustomize`

✅ **Dlaczego:**  
 W Twoich błędach z Kubernetes i GHCR widać było, że istnieje repo:  
 `ghcr.io/exea-centrum/website-argocd-k8s-github-kustomize`,  
 więc wszystkie nazwy (image, workflow, Kustomize) muszą być identyczne — wcześniej były pomieszane z „simple”.

---

## **🐋 2\. Poprawiony GitHub Actions workflow**

Oryginalny workflow działał, ale miał kilka błędów i braków bezpieczeństwa.

### **🔹 Było:**

`permissions:`  
 `contents: write`  
 `packages: write`

👉 **Za wysoko (w `jobs` powinno być, nie globalnie)**  
 👉 Zbyt szerokie uprawnienia.

### **🔹 Teraz:**

`permissions:`  
 `contents: read`  
 `packages: write`

✅ **Dlaczego:**  
 To minimalne i zalecane uprawnienia do publikowania obrazów w GHCR.  
 Dodatkowo — przeniosłem je do poziomu **globalnego** (poprawna składnia YAML GitHub Actions).

---

## **🔐 3\. Logowanie do GHCR z fallback tokenem**

### **🔹 Było:**

`password: ${{ secrets.GITHUB_TOKEN }}`

### **🔹 Teraz:**

`password: ${{ secrets.GHCR_PAT || secrets.GITHUB_TOKEN }}`

✅ **Dlaczego:**  
 W niektórych organizacjach `GITHUB_TOKEN` ma ograniczenia do GHCR (403 Forbidden).  
 Dodałem możliwość użycia własnego `GHCR_PAT` (Personal Access Token) jako fallback.

---

## **⚙️ 4\. Najnowsze wersje akcji**

Zaktualizowałem:
'''consol

- `docker/build-push-action@v5` → **`@v6`**

- `docker/setup-buildx-action@v2` → **`@v3`**
  '''
  ✅ **Dlaczego:**  
   Te wersje mają poprawki bezpieczeństwa, wydajności i wsparcie dla `cache-to` / `cache-from`.

---

## **🧱 5\. Dodany cache buildów Dockera**

'''consol
`cache-from: type=gha`  
`cache-to: type=gha,mode=max`
'''
✅ **Dlaczego:**  
 Znacząco przyspiesza kolejne buildy — GitHub Actions zachowuje warstwy Dockera w cache.

---

## **🧩 6\. Aktualizacja `kustomization.yaml`**

W bloku:
'''consol
`sed -i "s|newTag:.*|newTag: ${{ github.sha }}|g" kustomization.yaml`
'''
✅ **Dlaczego:**  
 To automatycznie podmienia tag obrazu na SHA commita (np. `1cd3ada2530dfdca...`),  
 co pozwala ArgoCD wykrywać nowe wersje.

---

## **🔁 7\. Poprawiony commit i push**

Dodałem:

`|| echo "No changes to commit"`

✅ **Dlaczego:**  
 Zapobiega błędowi workflow, jeśli tag w `kustomization.yaml` już się nie zmienił.

---

## **🧾 8\. README.md**

Dodałem:

- pełny link do repozytorium `https://github.com/exea-centrum/website-argocd-k8s-github-kustomize`

- instrukcje dla `GHCR_PAT`

- krótsze, klarowne kroki wdrożenia

---

## **📦 9\. Git initialization / remote**

Zamieniłem dynamiczny remote (`${GITHUB_USER}`) na konkretny:

`git remote add origin https://github.com/exea-centrum/website-argocd-k8s-github-kustomize.git`

✅ **Dlaczego:**  
 Repo już istnieje — nie trzeba dynamicznie pytać o nazwę użytkownika przy każdym setupie.

---

## **🧹 10\. Estetyka i porządek**

- Zmniejszyłem liczbę zbędnych komentarzy (np. „Twoja zawartość HTML pozostaje bez zmian”).

- Dodałem koloryzowane echo i przejrzyste komunikaty.

- Zachowałem Twoje sekcje (Dockerfile, GitHub Actions, Kubernetes, README).

---

## **🧠 Podsumowanie – efekty zmian**

| Obszar          | Co poprawiono                       | Efekt                           |
| --------------- | ----------------------------------- | ------------------------------- |
| 🔤 Nazewnictwo  | `website-simple` → `website-argocd` | Spójność w repo i GHCR          |
| 🔐 Uprawnienia  | `permissions` i token fallback      | Koniec z błędem `403 Forbidden` |
| 🐋 Workflow     | Aktualne wersje `actions` i cache   | Szybsze i stabilniejsze buildy  |
| ⚙️ CI/CD        | `sed` update \+ commit fix          | Auto-update tagów bez crasha    |
| 📦 Kustomize    | Poprawna ścieżka i nazwa image      | ArgoCD rozpoznaje obraz         |
| 🧾 Dokumentacja | Uporządkowany README                | Łatwiejszy onboarding           |
