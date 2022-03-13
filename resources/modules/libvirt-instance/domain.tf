resource "libvirt_domain" "domain" {
  name = var.name
  running = var.running

  memory = var.memory
  vcpu   = var.vcpu

  firmware = {
    "bios" = ""
    "uefi" = "/run/libvirt/nix-ovmf/OVMF_CODE.fd"
  }[var.firmware]

  nvram {
    file = coalesce(var.nvram_file, "/var/lib/libvirt/qemu/nvram/${var.name}_VARS.fd")
    template = "/run/libvirt/nix-ovmf/OVMF_VARS.fd"
  }

  qemu_agent = true

  network_interface {
    network_name     = var.network_name
    wait_for_lease = true 
  }

  lifecycle {
    ignore_changes = [ 
        network_interface.0.network_name, 
        network_interface.0.bridge,
    ]
  }

  disk {
    volume_id = libvirt_volume.system.id
  }

  dynamic "disk" {
    for_each = var.extra_disks
    content {
      volume_id = disk.value
    }
  }
}
