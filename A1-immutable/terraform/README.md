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
terraform apply -var-file=../../terraform.tfvars -auto-approve
# Inventory wird automatisch erzeugt: ../ansible/inventory.ini
cd ../ansible
ansible-playbook -i inventory.ini verify.yml
```

## Immutable Update
Erhöhe die Variable `immutable_version` in `terraform/main.tf` oder übergib sie als CLI-Var:
```bash
terraform apply -var-file=../../terraform.tfvars -var immutable_version=v1.1.0 -auto-approve
```
Durch `create_before_destroy` wird eine neue VM gebaut und die alte anschließend entfernt.
