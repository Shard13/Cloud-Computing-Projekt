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


# Aufgabe 2 - Configuration Management & Deployment

## Quickstart

### Vorbereitung
- Ansible installieren (z. B. via `apt`, `yum` oder `pip`)
- `ansible/inventory/inventory.ini` mit Ziel-Hosts anpassen

### Deployment
```bash
./scripts/deploy.sh
```

### Update/Change
```bash
./scripts/change.sh
```

### Rollback
```bash
./scripts/rollback.sh
```

### Delete
```bash
./scripts/delete.sh
```

---
👉 Alternativ können die Playbooks direkt ausgeführt werden:
```bash
ansible-playbook -i ansible/inventory/inventory.ini ansible/app_deploy.yml
ansible-playbook -i ansible/inventory/inventory.ini ansible/app_delete.yml
```


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


#   Aufgabe 4 – Data Lake & Big Data Processing

## 1. Zielsetzung & Bewertungsbezug
Mit dieser Dokumentation erfülle ich die Kernanforderungen der Aufgabe 4: Installation des Data Lakes (Hadoop/HDFS + YARN + Spark), Datenhaltung sowie Verarbeitungsschritte (Batch Jobs mit Spark, Ein-/Ausgabe in HDFS) und Ergebnispräsentation. 

## 2. Architekturüberblick

2.1 Cluster-Topologie
               +-----------------------+
               | cornelius-master      |
               | NN (NameNode), RM     |
               | 141.72.13.55          |
               +-----------+-----------+
                           |      \
                           |       \
     +---------------------+        +---------------------+
     |                                               |
+----v-------------------+                 +---------v------------------+
| cornelius-worker-1     |                 | cornelius-worker-2         |
| DN (DataNode), NM      |                 | DN (DataNode), NM          |
| 141.72.13.58           |                 | 141.72.12.68               |
+------------------------+                 +----------------------------+

Rollen:
•	HDFS: NameNode (Master), DataNodes (Worker 1, Worker 2), Replikation = 2
•	YARN: ResourceManager (Master), NodeManagers (Worker 1, Worker 2)
•	Spark: Client/Cluster Modus auf YARN

2.2 Wichtige Ports / Web UIs
•	HDFS NameNode UI: http://141.72.13.55:9870
•	YARN ResourceManager UI: http://141.72.13.55:8088

3. Systemvoraussetzungen
•	Ubuntu (VMs): 1× Master, 2× Worker
•	Java 11 (OpenJDK), Hadoop 3.3.6, Spark 3.5.1 (Hadoop3 build)
•	SSH Zugang per Key, ausgehender Internetzugang für Downloads
•	Ausreichender Plattenplatz für Roh  und Kurationsdaten

## 4. Installation (Reproduzierbar, schrittweise)

Hinweis: Sofern nicht anders angegeben, gelten die Schritte auf allen drei Hosts (Master, Worker 1, Worker 2). Befehle sind idempotent gestaltet, wo möglich.




4.1 Login per SSH (vom lokalen Rechner)
ssh -i ~/.ssh/corne_key.pem ubuntu@141.72.13.55
ssh -i ~/.ssh/corne_key.pem ubuntu@141.72.13.58
ssh -i ~/.ssh/corne_key.pem ubuntu@141.72.12.68

4.2 Basis Pakete & Java

sudo apt-get update -y
sudo apt-get install -y openjdk-11-jdk curl unzip net-tools procps

4.3 Hostnamen auflösen

echo "141.72.13.55   cornelius-master"   | sudo tee -a /etc/hosts
echo "141.72.13.58  cornelius-worker-1" | sudo tee -a /etc/hosts
echo "141.72.12.68   cornelius-worker-2" | sudo tee -a /etc/hosts

4.4 Umgebungsvariablen

# Java
sudo tee /etc/profile.d/java.sh >/dev/null <<'SH'
export JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64
export PATH="$JAVA_HOME/bin:$PATH"
SH
# Hadoop
sudo tee /etc/profile.d/hadoop.sh >/dev/null <<'SH'
export HADOOP_HOME=/opt/hadoop
export HADOOP_CONF_DIR=$HADOOP_HOME/etc/hadoop
export PATH="$HADOOP_HOME/bin:$HADOOP_HOME/sbin:$PATH"
SH
# Spark
sudo tee /etc/profile.d/spark.sh >/dev/null <<'SH'
export SPARK_HOME=/opt/spark-3.5.1-bin-hadoop3
export PATH="$SPARK_HOME/bin:$PATH"
SH
# aktivieren
source /etc/profile.d/java.sh; source /etc/profile.d/hadoop.sh; source /etc/profile.d/spark.sh
java -version

4.5 Hadoop & Spark installieren

# Hadoop 3.3.6
curl -L https://archive.apache.org/dist/hadoop/common/hadoop-3.3.6/hadoop-3.3.6.tar.gz \
 | sudo tar -xz -C /opt
sudo ln -sfn /opt/hadoop-3.3.6 /opt/hadoop

# Spark 3.5.1 (Hadoop3 build)
curl -L https://archive.apache.org/dist/spark/spark-3.5.1/spark-3.5.1-bin-hadoop3.tgz \
 | sudo tar -xz -C /opt

## 5. Hadoop/HDFS + YARN einrichten
5.1 Master konfigurieren (nur auf cornelius-master)

Verzeichnisse
sudo mkdir -p /var/lib/hadoop/hdfs/{namenode,datanode}
sudo chown -R ubuntu:ubuntu /var/lib/hadoop
core-site.xml
<?xml version="1.0"?>
<configuration>
  <property>
    <name>fs.defaultFS</name>
    <value>hdfs://cornelius-master:9000</value>
  </property>
</configuration>
hdfs-site.xml
<?xml version="1.0"?>
<configuration>
  <property><name>dfs.replication</name><value>2</value></property>
  <property><name>dfs.namenode.name.dir</name><value>file:///var/lib/hadoop/hdfs/namenode</value></property>
  <property><name>dfs.datanode.data.dir</name><value>file:///var/lib/hadoop/hdfs/datanode</value></property>
</configuration>
yarn-site.xml (Master/RM)
<?xml version="1.0"?>
<configuration>
  <property><name>yarn.resourcemanager.hostname</name><value>cornelius-master</value></property>
  <property><name>yarn.resourcemanager.address</name><value>cornelius-master:8032</value></property>
  <property><name>yarn.resourcemanager.scheduler.address</name><value>cornelius-master:8030</value></property>
  <property><name>yarn.resourcemanager.resource-tracker.address</name><value>cornelius-master:8031</value></property>
  <property><name>yarn.resourcemanager.webapp.address</name><value>0.0.0.0:8088</value></property>

  <property><name>yarn.nodemanager.aux-services</name><value>mapreduce_shuffle</value></property>
  <property><name>yarn.nodemanager.vmem-check-enabled</name><value>false</value></property>

  <property><name>yarn.scheduler.minimum-allocation-mb</name><value>256</value></property>
  <property><name>yarn.scheduler.maximum-allocation-mb</name><value>4096</value></property>
</configuration>

Worker-Liste

printf "cornelius-worker-1\ncornelius-worker-2\n" | sudo tee /opt/hadoop/etc/hadoop/workers

Namenode initialisieren & Dienste starten

hdfs namenode -format
hdfs --daemon start namenode
yarn  --daemon start resourcemanager
jps
ss -ltnp | grep -E '9000|9870|8088'   # UIs: 9870(HDFS), 8088(YARN)

Konfigs auf Worker verteilen

# lokal:
ssh-add -D
ssh-add ~/.ssh/corne_key.pem
ssh -A -i ~/.ssh/corne_key.pem ubuntu@141.72.13.55

# auf master:
scp /opt/hadoop/etc/hadoop/{core-site.xml,hdfs-site.xml} ubuntu@141.72.13.58:/tmp/
scp /opt/hadoop/etc/hadoop/{core-site.xml,hdfs-site.xml} ubuntu@141.72.12.68:/tmp/

5.2 Worker konfigurieren (auf beiden Workern)

sudo mv /tmp/core-site.xml /opt/hadoop/etc/hadoop/
sudo mv /tmp/hdfs-site.xml  /opt/hadoop/etc/hadoop/

sudo tee /opt/hadoop/etc/hadoop/yarn-site.xml >/dev/null <<'XML'
<?xml version="1.0"?>
<configuration>
  <property><name>yarn.resourcemanager.hostname</name><value>cornelius-master</value></property>
  <property><name>yarn.resourcemanager.address</name><value>cornelius-master:8032</value></property>
  <property><name>yarn.resourcemanager.scheduler.address</name><value>cornelius-master:8030</value></property>
  <property><name>yarn.resourcemanager.resource-tracker.address</name><value>cornelius-master:8031</value></property>

  <property><name>yarn.nodemanager.resource.memory-mb</name><value>2048</value></property>
  <property><name>yarn.nodemanager.resource.cpu-vcores</name><value>1</value></property>

  <property><name>yarn.nodemanager.aux-services</name><value>mapreduce_shuffle</value></property>
  <property><name>yarn.nodemanager.vmem-check-enabled</name><value>false</value></property>
</configuration>
XML

sudo mkdir -p /var/lib/hadoop/hdfs/datanode
sudo chown -R ubuntu:ubuntu /var/lib/hadoop

# Dienste starten
hdfs --daemon start datanode
yarn --daemon start nodemanager
jps

Clusterstatus prüfen

hdfs dfsadmin -report | sed -n '1,120p'
yarn node -list

## 6. Datenhaltung 

6.1 HDFS Namensraum & Zonen
Wir strukturieren den Data Lake in Zonen zur sauberen Trennung von Roh , Kurations- und Ausgabelayern:
/datalake
  /raw        # unveränderte Rohdaten, wie angeliefert (CSV/JSON/Parquet)
  /curated    # bereinigte, validierte, angereicherte Daten (Parquet)
  /sandbox    # Ad hoc Analysen/Experimente
  /results    # finale Analyse-/Berichtsergebnisse (Parquet/CSV)
  /tmp        # temporäre Stagingbereiche

Anlegen:

hdfs dfs -mkdir -p /datalake/{raw,curated,sandbox,results,tmp}

6.2 Replikation, Blockgröße, Quotas
•	dfs.replication = 2 (s.o.), schützt gegen Node Ausfälle bei 2 Worker Knoten.
•	Quotas optional zur Kostenkontrolle: hdfs dfsadmin -setSpaceQuota / -setQuota.
6.3 Dateiformate & Kompression

•	Eingang: häufig CSV/JSON.
•	Kuratiert: Parquet + Snappy (spaltenorientiert, komprimiert, Prädikat Pushdown, Schema Evolution).
•	Partitionierung: nach natürlicher Dimension (z. B. year=2024/month=01), verbessert Prädikatfilter.
•	
6.4 Namenskonventionen
/datalake/raw/<domain>/<dataset>/ingest_date=YYYY-MM-DD/part-*.csv
/datalake/curated/<domain>/<dataset>/year=YYYY/month=MM/part-*.parquet

6.5 Zugriffsrechte
•	POSIX ACLs/HDFS Rechte je Zone (hdfs dfs -chmod, -chown), write once, read many für /raw.

## 7. Verarbeitung mit Spark auf YARN (Batch Pipeline)

7.1 Spark Defaults (empfohlen)

sudo tee /opt/spark-3.5.1-bin-hadoop3/conf/spark-defaults.conf >/dev/null <<'CONF'
spark.eventLog.enabled           true
spark.eventLog.dir               hdfs:///spark-logs
spark.history.fs.logDirectory    hdfs:///spark-logs
CONF
hdfs dfs -mkdir -p /spark-logs
History Server starten (optional):

$SPARK_HOME/sbin/start-history-server.sh

7.2 Beispiel Job (ETL von CSV → Parquet, Partitionierung, Aggregation)
Datei: etl_nyc_taxi.py
#!/usr/bin/env python3
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, year, month, to_timestamp, count, avg

spark = (SparkSession.builder
         .appName("etl-nyc-taxi")
         .getOrCreate())

raw = "/datalake/raw/mobility/nyc_taxi/ingest_date=2025-08-31"
cur = "/datalake/curated/mobility/nyc_taxi"
res = "/datalake/results/mobility/nyc_taxi"

# 1) Laden & Typisierung
 df = (spark.read
        .option("header", True)
        .option("inferSchema", True)
        .csv(raw))

# 2) Bereinigung/Typen
 df = (df
        .withColumn("pickup_ts",  to_timestamp(col("tpep_pickup_datetime")))
        .withColumn("dropoff_ts", to_timestamp(col("tpep_dropoff_datetime")))
        .dropna(subset=["pickup_ts", "dropoff_ts", "passenger_count", "total_amount"]))

# 3) Kuratiert schreiben (Parquet, partitioniert)
 (df.write
    .mode("overwrite")
    .partitionBy(year(col("pickup_ts")).alias("year"), month(col("pickup_ts")).alias("month"))
    .parquet(cur))

# 4) Aggregation (Beispielmetriken)
 agg = (df
        .withColumn("year",  year(col("pickup_ts")))
        .withColumn("month", month(col("pickup_ts")))
        .groupBy("year", "month")
        .agg(count("*").alias("trips"), avg("total_amount").alias("avg_fare")))

# 5) Ergebnisse schreiben
 (agg.write
    .mode("overwrite")
    .partitionBy("year", "month")
    .parquet(res))

spark.stop()

Hinweis: Partitionierung über year, month wird sowohl im Kurations Layer als auch im Ergebnis genutzt.

Ausführung auf YARN (Cluster Modus):
spark-submit \
  --master yarn \
  --deploy-mode cluster \
  --conf spark.yarn.maxAppAttempts=1 \
  --conf spark.executor.memory=1g \
  --conf spark.executor.cores=1 \
  --conf spark.executor.instances=2 \
  etl_nyc_taxi.py

7.3 Validierung & Sichtprüfung
# Ergebnisse ansehen
hdfs dfs -ls -R /datalake/curated/mobility/nyc_taxi | head -n 50
hdfs dfs -ls -R /datalake/results/mobility/nyc_taxi | head -n 50

# Stichprobe lesen (Spark Shell)
spark-shell --master yarn --deploy-mode client <<'SCALA'
val df = spark.read.parquet("/datalake/results/mobility/nyc_taxi")
df.orderBy($"year".desc, $"month".desc).show(12, false)
SCALA

## 8. Ergebnisse & Nutzen
•	Funktionsfähiger Data Lake (HDFS) mit Replikation 2 über zwei Worker.
•	Spark ETL wandelt Roh CSV in Parquet (kuratiert), erzeugt partitionierte Aggregationen (Results).
•	Pipeline ist wiederholbar, nachvollziehbar (optionale History Logs).
•	Strukturierte Datenzonen erleichtern Governance, Performance und spätere Erweiterungen.



