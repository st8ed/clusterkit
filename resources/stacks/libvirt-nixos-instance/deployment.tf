module "nixos-deployment" {
    source = "../../modules/nixos-deployment"
    
    access_address = module.libvirt-instance.access_address
    system_path = var.system_path
    secrets_path = var.secrets_path
}

