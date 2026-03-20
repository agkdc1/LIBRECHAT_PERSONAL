# ==============================================================================
# LibreChat on GCP — Cloud Run + Vertex AI + MongoDB on GCE
# Cloudflare Access + Tunnel for auth and ingress, Secret Manager for secrets
# ==============================================================================

terraform {
  required_version = ">= 1.5"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 6.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
  }
}

provider "google" {
  region = var.region
}

provider "google-beta" {
  region = var.region
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}


# ─── GCP Project ─────────────────────────────────────────────────────────────

resource "google_project" "this" {
  name            = var.project_name
  project_id      = var.project_id
  billing_account = var.billing_account
  deletion_policy = "DELETE"
}
