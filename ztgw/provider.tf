# Google Cloud provider
provider "google" {
  project               = var.project_id
  region                = var.region
  billing_project       = var.billing_project_id
  user_project_override = true
}

# Google Cloud Beta provider (required for NSI resources)
provider "google-beta" {
  project               = var.project_id
  region                = var.region
  billing_project       = var.billing_project_id
  user_project_override = true
}
