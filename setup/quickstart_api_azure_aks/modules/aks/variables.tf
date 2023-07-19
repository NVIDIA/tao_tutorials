variable "name" {
  type = string
}
variable "resource_group_name" {
  type = string
}
variable "region" {
  type = string
}
variable "node_pool_name" {
  type = string
}
variable "node_count" {
  type = number
}
variable "vm_size" {
  type = string
}
variable "disk_size_gb" {
  type = number
}
variable "vnet_subnet_id" {
  type    = string
  default = null
}