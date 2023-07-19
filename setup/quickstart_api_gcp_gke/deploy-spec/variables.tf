variable "provider_config" {
  type = object({
    project     = string
    credentials = string
  })
}
variable "name" {
  type = string
}
variable "region" {
  type = string
}
variable "zone" {
  type = string
}
variable "network_cidr_range" {
  type = string
}
variable "machine_type" {
  type = string
}
variable "node_count" {
  type = number
}
variable "gpu_type" {
  type    = string
  default = null
}
variable "gpu_count" {
  type    = number
  default = null
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