# Cloud Computing und Big Data


Matrikelnummern: 6349055, 8562648, 7673841, 1629518

Indieser README findest du die Dokumentation zu allen fünf Aufgaben der Portfolio-Prüfung im Modul Cloud Computing und Big Data.

Unsere gewählte Anwendungsidee lautet Binance Market Data – Crypto-Tick Analytics mit dem Ziel, aus vorhandenen Daten Vorhersagen ableiten zu können.

# Aufgabe 1 – Immutable Infrastructure (OpenStack + Terraform + Ansible)

**Idee:** Wir behandeln die VM als _unveränderliches Artefakt_. Konfiguration passiert ausschließlich per `cloud-init` beim Provisionieren. Ein Update erfolgt durch **Ersetzen** der VM (nicht durch SSH-Mutationen). Der Parameter `immutable_version` triggert die Neuerstellung.

## Struktur
- `terraform/` – erzeugt eine Ubuntu-VM mit NGINX. Die Seite zeigt die aktuell gebaute Version.
- `ansible/` – Playbook prüft nur den Zustand (Version sichtbar, NGINX läuft).

## Variablen & Credentials
Die OpenStack-Zugangsdaten werden **nicht** im Code hartkodiert, sondern via `terraform.tfvars` bereitgestellt (siehe bereitgestellte Datei).

## Schnelleinstieg
```bash
cd terraform
terraform init
terraform apply -var-file=terraform.tfvars -auto-approve
# Inventory wird automatisch erzeugt: ../ansible/inventory.ini
cd ../ansible
ansible-playbook -i inventory.ini deploy.yaml
```

## Immutable Update
Erhöhe die Variable `immutable_version` in `terraform/main.tf` oder übergib sie als CLI-Var:
```bash
terraform apply -var-file=terraform.tfvars -var immutable_version=v1.1.0 -auto-approve
```
Durch `create_before_destroy` wird eine neue VM gebaut und die alte anschließend entfernt.


# Aufgabe 3 – Microservice Infrastructure (Umsetzung von s231854)

**Ziel:** Aufbau einer **Multi-Node Kubernetes**-Infrastruktur (OpenStack) mit **k3s**, **Helm** und **Monitoring**.
Als Beispiel-App deploye ich **zwei versionierte Streamlit-Varianten** derselben Anwendung:

* **guess-v1** → erreichbar unter `/guess/v1/`
* **guess-v2** → erreichbar unter `/guess/v2/`

Die Images liegen in meiner GHCR:

* `ghcr.io/s231854/guess:guess-v1`
* `ghcr.io/s231854/guess:guess-v2`

> Optional „immutable“ Nachweisbarkeit: `ghcr.io/s231854/guess@sha256:<digest>`

---

## Architekturüberblick

* **Terraform** – erzeugt OpenStack-VMs (1× Control Plane, 2× Worker) und generiert das Ansible-Inventory
* **Ansible** – installiert k3s, setzt Ingress-NGINX auf, deployt Helm-Charts
* **k3s** – leichtgewichtiges Kubernetes (containerd inklusive)
* **Helm** – Paketierung/Release für Apps & Monitoring
* **NGINX Ingress** – externe Erreichbarkeit via **NodePort** auf den Worker/Server-IPs
* **Prometheus + Grafana** – Monitoring; **Grafana** läuft unter Subpfad **`/grafana`**

**Warum k3s?**

* kleine Footprint, einfache Installation/Updates
* lokales Storage + integrierte Runtime
* ideal für selbst gemanagte OpenStack-Setups

---

## Repository-Struktur (relevant)

```
A3 - Microservice Infrastructure/
├─ ansible/
│  ├─ deploy.yaml
│  └─ inventory/inventory.ini
├─ helm/
│  └─ app/
│     ├─ Chart.yaml
│     ├─ values.yaml          # Basis-Defaults (nur Frontend + Ingress)
│     └─ templates/
│        ├─ frontend-deployment.yaml
│        ├─ frontend-service.yaml
│        └─ ingress.yaml
├─ terraform/
│  └─ *.tf                     # OpenStack-Infra + Ansible-Trigger
└─ app/
   ├─ guess-v1/                # Streamlit-App v1 (eigenes Dockerfile)
   └─ guess-v2/                # Streamlit-App v2 (eigenes Dockerfile)
```

> **Hinweis:** Die Helm-Templates wurden **auf „Frontend-only“** reduziert – **kein Backend, keine DB** notwendig.

---

## Voraussetzungen

* OpenStack-Zugang (Projekt/Netz „DHBW“), SSH-Key **`corne_key`** hinterlegt
* CLI-Tools lokal: `terraform`, `ansible`, `kubectl`, `helm`, `ssh`
* GitHub Container Registry Zugriff (öffentlich oder `imagePullSecrets` setzen)

---

## 1) Infrastruktur ausrollen (Terraform + Ansible)

Ausführen im Ordner: **`A3 - Microservice Infrastructure`**

```bash
# (optional) Clean Start
terraform -chdir=terraform destroy -auto-approve

# Cluster & Basis deployen (k3s, Ingress, Monitoring-Stack)
terraform -chdir=terraform apply -auto-approve
```

### Kubeconfig beziehen & setzen

```bash
# Server-IP aus dem Ansible-Inventory
SERVER=$(awk '/^\[k3s_server\]/{f=1;next} f && NF {print $1; exit}' ansible/inventory/inventory.ini)
SSH_KEY=~/.ssh/corne_key

# Kubeconfig vom Server holen & auf Server-IP umschreiben
ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no ubuntu@"$SERVER" 'sudo cat /etc/rancher/k3s/k3s.yaml' > kubeconfig
sed -i "s/127\.0\.0\.1/$SERVER/" kubeconfig
export KUBECONFIG=$PWD/kubeconfig

# Checks
kubectl cluster-info
kubectl get nodes -o wide
```

### Ingress NodePort ermitteln

```bash
NODEPORT=$(kubectl -n ingress-nginx get svc ingress-nginx-controller \
  -o jsonpath='{.spec.ports[?(@.name=="http")].nodePort}')
echo "SERVER=$SERVER  NODEPORT=$NODEPORT"
```

---

## 2) App-Chart: Werte pro Version

**Basis-Defaults** in `helm/app/values.yaml` (Frontend + Ingress).
Pro Version nutze ich eine eigene Values-Datei:

`helm/values-guess-v1.yaml`

```yaml
fullnameOverride: guess-v1
frontend:
  image: ghcr.io/s231854/guess:guess-v1
  env:
    - name: STREAMLIT_SERVER_BASE_URL_PATH
      value: /guess/v1
ingress:
  hosts:
    - host: ""
      paths:
        - path: /guess/v1
          pathType: Prefix
```

`helm/values-guess-v2.yaml`

```yaml
fullnameOverride: guess-v2
frontend:
  image: ghcr.io/s231854/guess:guess-v2
  env:
    - name: STREAMLIT_SERVER_BASE_URL_PATH
      value: /guess/v2
ingress:
  hosts:
    - host: ""
      paths:
        - path: /guess/v2
          pathType: Prefix
```

> Das Ingress-Template mapped automatisch auf den jeweiligen Frontend-Service (`<release>-frontend:80`).

---

## 3) Deployments ausrollen (Helm)

```bash
# v1
helm upgrade --install guess-v1 helm/app -n microservices \
  -f helm/values-guess-v1.yaml
kubectl -n microservices rollout status deploy/guess-v1-frontend

# v2
helm upgrade --install guess-v2 helm/app -n microservices \
  -f helm/values-guess-v2.yaml
kubectl -n microservices rollout status deploy/guess-v2-frontend
```

**Smoke-Test (Slash am Ende!)**

```bash
curl -I "http://$SERVER:$NODEPORT/guess/v1/"
curl -I "http://$SERVER:$NODEPORT/guess/v2/"
```

**Browser-URLs**

* v1 → `http://<SERVER>:<NODEPORT>/guess/v1/`
* v2 → `http://<SERVER>:<NODEPORT>/guess/v2/`

---

## 4) Monitoring: Grafana unter /grafana

```bash
# Repo sicherstellen
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts || true
helm repo update

# Grafana via Subpfad + Ingress
helm upgrade monitoring prometheus-community/kube-prometheus-stack -n monitoring \
  --reuse-values \
  --set grafana.ingress.enabled=true \
  --set grafana.ingress.ingressClassName=nginx \
  --set grafana.ingress.hosts[0]="" \
  --set grafana.ingress.path=/grafana \
  --set grafana.ingress.pathType=Prefix \
  --set-string grafana.env.GF_SERVER_ROOT_URL='%(protocol)s://%(domain)s:%(http_port)s/grafana' \
  --set grafana.env.GF_SERVER_SERVE_FROM_SUB_PATH=true

kubectl -n monitoring rollout status deploy/monitoring-grafana

# Zugang
echo -n "Grafana admin password: "
kubectl -n monitoring get secret monitoring-grafana -o jsonpath='{.data.admin-password}' | base64 -d; echo
```

**Grafana-URL:** `http://<SERVER>:<NODEPORT>/grafana`
**Login:** `admin` / (Passwort aus Secret; Standard in diesem Setup oft `admin123`)

---

## 5) Versionierbarkeit nachweisen

```bash
# Laufende Images der Deployments
echo -n "guess-v1 image: "; kubectl -n microservices get deploy guess-v1-frontend -o jsonpath='{.spec.template.spec.containers[0].image}'; echo
echo -n "guess-v2 image: "; kubectl -n microservices get deploy guess-v2-frontend -o jsonpath='{.spec.template.spec.containers[0].image}'; echo

# Exakte ImageIDs (inkl. Digest) der Pods
kubectl -n microservices get pod -l app.kubernetes.io/instance=guess-v1 -o jsonpath='{range .items[*]}{.metadata.name}{" => "}{.status.containerStatuses[0].imageID}{"\n"}{end}'
kubectl -n microservices get pod -l app.kubernetes.io/instance=guess-v2 -o jsonpath='{range .items[*]}{.metadata.name}{" => "}{.status.containerStatuses[0].imageID}{"\n"}{end}'
```

---

## 6) Skalierung & Demo-Last

```bash
# einfache Last
watch -n0.3 'curl -s -o /dev/null -w "%{http_code}\n" "http://'"$SERVER:$NODEPORT"'/guess/v1/"'
watch -n0.3 'curl -s -o /dev/null -w "%{http_code}\n" "http://'"$SERVER:$NODEPORT"'/guess/v2/"'

# v2 horizontal skalieren
kubectl -n microservices scale deploy/guess-v2-frontend --replicas=3
kubectl -n microservices get pods -l app.kubernetes.io/instance=guess-v2 -o wide
```

Empfohlene Dashboards in Grafana:

* **Kubernetes / Compute Resources / Namespace** → `microservices`
* **Kubernetes / Compute Resources / Pod**
* **Kubernetes / Networking / Namespace (Pods)**

---

## 7) Aufräumen

```bash
# Apps (optional)
helm -n microservices uninstall guess-v1 || true
helm -n microservices uninstall guess-v2 || true

# Monitoring (optional)
helm -n monitoring uninstall monitoring || true

# Cluster zerstören
terraform -chdir=terraform destroy -auto-approve
```

---

## Troubleshooting (Kurz)

* **`503 Service Temporarily Unavailable`**
  *Ursache:* falsches Ingress-Backend oder Pod noch nicht „Ready“.
  *Check:*

  ```bash
  kubectl -n microservices get ingress
  kubectl -n microservices get pods -o wide
  kubectl -n microservices describe ingress guess-v2 | sed -n '1,200p'
  ```

* **`Permission denied (publickey)` beim SSH**
  Prüfe SSH-Key-Pfad `~/.ssh/corne_key` und OpenStack-Keypair-Zuordnung.

* **Kubeconfig lokal leer**
  Erneut vom Server kopieren und `127.0.0.1` durch `$SERVER` ersetzen, dann `export KUBECONFIG=$PWD/kubeconfig`.

---

**Fazit:**
Mit zwei separaten Helm-Releases (`guess-v1`, `guess-v2`) und unterschiedlichen Image-Tags ist die **Versionierbarkeit** klar nachvollziehbar. Beide Versionen sind stabil **pfadbasiert** über den Ingress erreichbar und durch **Prometheus/Grafana** monitorbar.
