variable "aws_region" {
  type = string
}
variable "name" {
  type = string
}
variable "vpc_cidr" {
  type = string
}
variable "access_cidr_blocks" {
  type = list(string)
}
variable "cluster_version" {
  type = string
}
variable "instance_type" {
  type = string
}
variable "instance_count" {
  type = number
}
variable "ssh_public_key" {
  type = string
}