variable "vultr_token" {}
variable "pvt_key" {}
variable "pub_key" {}

provider "vultr" {
  api_key     = var.vultr_token
  rate_limit  = 700
  retry_limit = 3
}

// ZEROTIER

variable instances {
  type = list(object({
    name = string
    ip_assignment = string
    enable_ipv6 = bool
    enable_ipv4 = bool
  }))
  default = [
    {
      name = "Todd"
      ip_assignment = "10.11.0.1"
      enable_ipv6 = true
      enable_ipv4 = true
    }
    ,{
      name = "Josh"
      ip_assignment = "10.11.0.2"
      enable_ipv6 = true
      enable_ipv4 = true
    }
  ]
}

resource "zerotier_network" "test_net" {
  name        = "test net"
  description = ""
  assignment_pool {
    start = "10.11.0.1"
    end   = "10.11.0.254"
  }
  route {
    target = "10.11.0.0/24"
  }
  flow_rules = "accept;"
}

resource "zerotier_identity" "instances" {
  for_each = { for o in var.instances : o.name => o }
}

resource "zerotier_member" "member" {
  for_each = { for o in var.instances : o.name => o }

  name                    = each.key
  member_id               = zerotier_identity.instances["${each.value.name}"].id
  network_id              = zerotier_network.test_net.id
  description             = ""
  ip_assignments          = ["${each.value.ip_assignment}"]
}

resource "zerotier_member" "manual" {
  name                    = "tl"
  member_id               = "46254ec531"
  network_id              = zerotier_network.test_net.id
  description             = "laptop"
  ip_assignments          = ["10.11.0.101"]
}

// VULTR


resource "vultr_instance" "wan" {
  for_each = { for o in var.instances : o.name => o }

  plan        = "vc2-1c-1gb"
  region      = "lax"
  os_id       = "477" # Debian 11
  # os_id       = "2136" # Debian 12
  ssh_key_ids = ["39d6da52-6474-4486-b247-08c9d401cc0d"]

  label       = "test_net-${each.value.name}"
  hostname    = each.value.name
  enable_ipv6 = true
  activation_email = false

  provisioner "remote-exec" {
    inline = ["sudo apt update", "sudo apt install python3 -y", "echo Done!"]

    connection {
      host        = self.main_ip
      type        = "ssh"
      user        = "root"
      private_key = file(var.pvt_key)
    }
  }
}

# this'll run every terraform apply
# putting it in vultr_instance works, but ansible fails all the time and then you can't rerun it
resource "null_resource" "ansible" {
  for_each = { for o in var.instances : o.name => o }

  depends_on = [
    local_file.inventory
  ]

  triggers = {
    key = "${uuid()}"
  }

  provisioner "local-exec" {
    command = "ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -vvv -u root -i inventory.cfg --limit '${vultr_instance.wan["${each.value.name}"].main_ip}' --private-key ${var.pvt_key} -e 'pub_key=${var.pub_key}' -e zt_public=${zerotier_identity.instances["${each.value.name}"].public_key} -e zt_secret=${zerotier_identity.instances["${each.value.name}"].private_key} -e zt_network=${zerotier_network.test_net.id} setup-zerotier.yml"
  }

}

resource "null_resource" "ansible2" {
  for_each = { for o in var.instances : o.name => o }

  depends_on = [
    local_file.inventory,
    null_resource.ansible
  ]

  triggers = {
    key = "${uuid()}"
  }

  provisioner "local-exec" {
    command = "ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -u root -i inventory.cfg --limit 'wan_nodes' --private-key ${var.pvt_key} -e 'pub_key=${var.pub_key}' install-stuff.yml"
  }
}

resource "local_file" "inventory" {
  content = templatefile("${path.module}/inventory.tpl",
    {
      wan_nodes = [for o in vultr_instance.wan : o.main_ip]
      zt_nodes = [for o in zerotier_member.member : one(o.ip_assignments)]
    }
  )
  filename = "./inventory.cfg"
}

output "wan_nodes" {
  value = {
    for k, v in zerotier_member.member : k => [v.id, v.name, tolist(v.ip_assignments)]
  }
}

output "main_ips" {
  value = {
    for k, v in vultr_instance.wan : k => v.main_ip
  }
}

output "network" {
  value = zerotier_network.test_net.id

}
