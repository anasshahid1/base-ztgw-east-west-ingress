# Google Cloud provider
provider "google" {
  project = var.project_id
  region  = var.region
}

# Google Cloud Beta provider (required for NSI resources)
provider "google-beta" {
  project = var.project_id
  region  = var.region
}
