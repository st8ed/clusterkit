resource "libvirt_volume" "system" {
  name  = var.name
  pool  = var.pool_name
  
  base_volume_pool = coalesce(var.base_volume_pool_name, var.pool_name)
  base_volume_name = var.base_volume_name

  size  = var.volume_size * 1024 * 1024 * 1024 
}
