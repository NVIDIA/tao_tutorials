terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.31.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "= 2.6.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "= 2.13.1"
    }
    time = {
      source  = "hashicorp/time"
      version = "= 0.9.1"
    }
  }
  required_version = "= 1.2.4"
}