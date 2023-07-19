variable "name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}

variable "instance_type" {
  type = string
}

variable "instance_count" {
  type = number
}

variable "ssh_key" {
  type = string
}

variable "api_server_access_cidr_blocks" {
  type = list(string)
}

variable "cluster_version" {
  type    = string
  default = "1.23"
}

variable "ami_id" {
  type    = string
  default = ""
}

variable "additional_user_data" {
  type    = string
  default = ""
}

variable "additional_sg_ids" {
  type    = list(string)
  default = []
}