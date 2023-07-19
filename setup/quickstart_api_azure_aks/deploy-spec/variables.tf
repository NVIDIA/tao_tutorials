variable "provider_config" {
  type = object({
    tenant_id       = string
    subscription_id = string
    client_id       = string
    client_secret   = string
  })
}
variable "name" {
  type = string
}
variable "region" {
  type = string
}
variable "virtual_network_address_space" {
  type = string
}
variable "node_pool_name" {
  type = string
}
variable "vm_size" {
  type = string
}
variable "node_count" {
  type = number
}
variable "ssh_public_key" {
  type = string
}
variable "ngc_api_key" {
  type      = string
  sensitive = true
}
variable "ngc_email" {
  type = string
}
variable "chart" {
  type = string
}
variable "chart_values" {
  type = string
}
variable "gpu_operator_version" {
  type    = string
  default = null
}
variable "nvidia_driver_version" {
  type    = string
  default = null
}