module "libvirt-instance" {
    source = "../../modules/libvirt-instance"

    name = var.name 
    memory = var.memory
    vcpu = var.vcpu
    firmware = "uefi"
    nvram_file = var.nvram_file

    pool_name = var.pool_name
    volume_size = var.volume_size
    base_volume_pool_name = var.pool_name
    base_volume_name = var.image_name
    extra_disks = var.extra_disks

    network_name = var.network_name
}
