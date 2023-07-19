variable "name" {
  type = string
}
variable "region" {
  type = string
}
variable "node_zones" {
  type = list(string)
}
variable "network" {
  type = string
}
variable "subnetwork" {
  type = string
}
variable "node_count" {
  type = number
}
variable "machine_type" {
  type = string
}
variable "disk_size_gb" {
  type = number
}
variable "disk_type" {
  type = string
}
variable "node_tags" {
  type    = list(string)
  default = []
}
variable "gpu_config" {
  type = object({
    type  = string
    count = number
  })
  default = null
}
