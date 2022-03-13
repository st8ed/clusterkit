variable "name" {
    type = string
}

variable "running" {
    type = bool
    default = true
}

variable "memory" {
    type = number
}

variable "vcpu" {
    type = number
}

variable "firmware" {
    type = string
}

variable "nvram_file" {
    type = string
    default =  ""
}

variable "pool_name" {
    type = string
}

variable "volume_size" {
    type = number
}

variable "base_volume_pool_name" {
    type = string
    default = ""
}

variable "base_volume_name" {
    type = string
}

variable "extra_disks" {
    type = list(string)
    default = [ ]
}

variable "network_name" {
    type = string
}

output "access_address" {
    value = try(libvirt_domain.domain.network_interface.0.addresses.0, "")
}
