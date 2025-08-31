# Variables
variable "os_user_name" {}
variable "os_password" { sensitive = true }
variable "os_auth_url" {}
variable "os_tenant_id" {}

# Terraform initialization
terraform {
  required_providers {
    local = {
      source = "hashicorp/local"
    }
    openstack = {
      source = "terraform-provider-openstack/openstack"
    }
  }
}

# OpenStack Provider
provider "openstack" {
  user_name         = "pfisterer-cloud-lecture"
  password          = "ss2025"
  auth_url          = "https://stack.dhbw.cloud:5000/v3"
  tenant_id         = var.os_tenant_id # OS_PROJECT_ID
  user_domain_name  = "Default"        # OS_USER_DOMAIN_NAME
  project_domain_id = "default"        # OS_PROJECT_DOMAIN_ID
  region            = "DHBW-MA"        # OS_REGION_NAME
  endpoint_type     = "public"         # OS_INTERFACE
}


resource "random_id" "cluster_id" {
  byte_length = 4
}

# Key pair (optional if not managed here)
# resource "openstack_compute_keypair_v2" "keypair" {
#   name       = "id_ed25519"
#   public_key = var.os_pub_key
# }

# Kubernetes server
resource "openstack_compute_instance_v2" "k3s_server" {
  name        = "k3s-${random_id.cluster_id.hex}-server"
  image_id    = "f445d5f0-e9a6-4e09-b3c4-7e6607aea9fb"
  flavor_name = "mb1.large"
  key_pair    = "id_ed25519"

  network {
    name = "DHBW"
  }
}

# Kubernetes Worker Nodes
resource "openstack_compute_instance_v2" "k3s_worker" {
  count       = 2
  name        = "k3s-${random_id.cluster_id.hex}-agent-${count.index + 1}"
  image_id    = "f445d5f0-e9a6-4e09-b3c4-7e6607aea9fb"
  flavor_name = "mb1.large"
  key_pair    = "id_ed25519"

  network {
    name = "DHBW"
  }
}

resource "local_file" "inventory_ini" {
  content  = <<EOF
[k3s_server]
${openstack_compute_instance_v2.k3s_server.access_ip_v4} ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/id_ed25519

[k3s_agent]
%{for worker in openstack_compute_instance_v2.k3s_worker~}
${worker.access_ip_v4} ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/id_ed25519
%{endfor~}
EOF
  filename = "../ansible/inventory/inventory.ini"
}

resource "null_resource" "ansible_provisioner" {
  depends_on = [
    openstack_compute_instance_v2.k3s_server,
    openstack_compute_instance_v2.k3s_worker,
    local_file.inventory_ini
  ]

  provisioner "local-exec" {
    command = "sleep 60 && ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i ../ansible/inventory/inventory.ini ../ansible/deploy.yaml"
  }

  triggers = {
    server_id  = openstack_compute_instance_v2.k3s_server.id
    server_ip  = openstack_compute_instance_v2.k3s_server.network.0.fixed_ip_v4
    worker_ips = join(",", [for w in openstack_compute_instance_v2.k3s_worker : w.network.0.fixed_ip_v4])
  }
}
