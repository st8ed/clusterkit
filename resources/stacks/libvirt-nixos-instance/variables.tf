variable "name" { }
variable "memory" { default = 1024 }
variable "vcpu" { default = 2 }
variable "nvram_file" { default = "" }
variable "pool_name" { default = "default" }
variable "volume_size" { default = 8 }
variable "image_name" { }
variable "extra_disks" { 
    type = list(string)
    default = [] 
}
variable "network_name" { default = "default" }

variable "system_path" { }
variable "secrets_path" { }
