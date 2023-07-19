terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "= 4.22.0"
    }
    cloudinit = {
      source  = "hashicorp/cloudinit"
      version = "= 2.2.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "= 4.0.2"
    }
  }
  required_version = "= 1.2.4"
}