# Configuration Management & Deployment

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
