# Aufgabe 1 – Immutable Infrastructure

## Ziel
Eine Infrastruktur nach dem Prinzip der **Immutable Infrastructure** bereitstellen.  
Änderungen erfolgen nicht „in place“, sondern durch **Neu-Provisionierung** mit Terraform + Ansible.  
So wird Configuration Drift vermieden.

---

## Technologieauswahl
- **Terraform**: Provisionierung der VM(s) über deklarative Konfiguration.  
- **Ansible**: Agentenlose Konfiguration der Instanzen per Playbook.  

**Begründung:**  
Terraform und Ansible ergänzen sich ideal: Infrastruktur wird reproduzierbar bereitgestellt,  
Ansible automatisiert die Software-Konfiguration. Änderungen werden immer neu ausgerollt.

---

## Projektstruktur
```
aufgabe1-immutable/
├── ansible/
│   ├── deploy.yaml              # Ansible-Playbook
│   └── inventory/
│       └── inventory.ini        # Inventory mit VM-Daten
└── terraform/
    ├── main.tf                  # Terraform-Konfiguration
    ├── terraform.tfvars         # Variablen für Terraform
    ├── terraform.tfstate        # State
    ├── terraform.tfstate.backup
    └── .terraform.lock.hcl
```

---

## Ablauf / Implementierung

### 1. Terraform initialisieren
```bash
cd terraform
terraform init
```

### 2. Plan anzeigen
```bash
terraform plan -var-file=terraform.tfvars
```

### 3. Infrastruktur provisionieren
```bash
terraform apply -var-file=terraform.tfvars -auto-approve
```

➡️ Terraform erstellt VM(s) und ruft automatisch Ansible auf:  
```bash
ansible-playbook -i ../ansible/inventory/inventory.ini ../ansible/deploy.yaml
```

### 4. Manuelle Verifikation (optional)
```bash
cd ../ansible
ansible-playbook -i inventory/inventory.ini deploy.yaml
```

---

## Immutable Update
1. `terraform.tfvars` oder `main.tf` anpassen (z. B. Image, Name).  
2. Neu ausrollen:
   ```bash
   cd terraform
   terraform apply -var-file=terraform.tfvars -auto-approve
   ```
3. Terraform ersetzt die alte VM und spielt `deploy.yaml` neu aus.  

➡️ Änderungen nur über Infrastructure-as-Code, keine SSH-Bastelei.

---

## Screencast-Skript

### Projekt vorstellen
```bash
cd aufgabe1-immutable
ls -R
```

### Terraform
```bash
cd terraform
terraform init
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars -auto-approve
```

### Ansible
```bash
cd ../ansible
cat inventory/inventory.ini
cat deploy.yaml
ansible-playbook -i inventory/inventory.ini deploy.yaml
```

### Immutable Update
```bash
cd ../terraform
nano terraform.tfvars   # kleine Änderung (z. B. Name oder Tag)
terraform apply -var-file=terraform.tfvars -auto-approve
```

### Optional: Aufräumen
```bash
terraform destroy -var-file=terraform.tfvars -auto-approve
```

---

## Sicherstellung der Unveränderlichkeit
- Änderungen nur per Terraform + Ansible.  
- **Keine** manuellen SSH-Anpassungen.  
- **Versionierung** über Git.  
- Updates = neue Instanz statt „Patchen“ bestehender Systeme.
