locals {
    nixos_deploy = "@nixos-deploy@/bin/nixos-deploy"
}

data "external" "system_probe" {
  program = ["sh", "-c", <<EOT
    echo '{"path": "'$(readlink -f "${var.system_path}")'"}'
EOT
    ]
}

resource "null_resource" "nixos" {
    triggers = {
        access_address = var.access_address
        system_path = data.external.system_probe.result.path
        secrets_path = var.secrets_path
    }
    
    provisioner "local-exec" {
        command = "${local.nixos_deploy} ${self.triggers.access_address} '${self.triggers.system_path}' '${self.triggers.secrets_path}'"
    }
}
