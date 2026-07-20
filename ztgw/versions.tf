terraform {
  required_version = ">= 1.5.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 7.27.0, < 8.0.0"
    }

    google-beta = {
      source  = "hashicorp/google-beta"
      version = ">= 7.27.0, < 8.0.0"
    }

    external = {
      source  = "hashicorp/external"
      version = ">= 2.0.0"
    }
  }
}
