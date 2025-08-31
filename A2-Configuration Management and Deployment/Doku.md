# Dokumentation: Configuration Management & Deployment

## 1. Projektübersicht
Dieses Projekt beinhaltet ein Deployment-Setup mit Ansible und Shell-Skripten. Ziel ist es, eine Beispielanwendung automatisiert bereitzustellen, zu aktualisieren, zurückzusetzen oder zu entfernen.

## 2. Projektstruktur
- **ansible/**
  - `app_deploy.yml` → Deployment Playbook
  - `app_delete.yml` → Remove Playbook
  - `inventory/inventory.ini` → Hosts-Definition
  - `templates/` → Applikations- und Service-Templates
- **scripts/**
  - `deploy.sh` → Deployment ausführen
  - `delete.sh` → Anwendung entfernen
  - `change.sh` → Version wechseln
  - `rollback.sh` → Rollback durchführen

## 3. Nutzung

### 3.1 Vorbereitung
1. Ansible installieren (z. B. via apt, yum oder pip)
2. `inventory.ini` anpassen (Hosts, SSH-Zugang)
3. ggf. Templates/Variablen anpassen

### 3.2 Deployment
```bash
./scripts/deploy.sh
# oder direkt via Ansible:
ansible-playbook -i ansible/inventory/inventory.ini ansible/app_deploy.yml
```

### 3.3 Update/Change
```bash
./scripts/change.sh
```

### 3.4 Rollback
```bash
./scripts/rollback.sh
```

### 3.5 Delete/Remove
```bash
./scripts/delete.sh
# oder via Ansible:
ansible-playbook -i ansible/inventory/inventory.ini ansible/app_delete.yml
```

## 4. Hinweise
- Alle Skripte sind ausführbar zu machen: `chmod +x scripts/*.sh`
- SSH-Key-basierte Authentifizierung empfohlen
- Templates anpassen, wenn sich App-Version oder Service ändert
