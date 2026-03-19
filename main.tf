# ==============================================================================
# LibreChat — GCP Project for Vertex AI API Only
# Everything else runs locally via Docker + Cloudflare Tunnel
# ==============================================================================

terraform {
  required_version = ">= 1.5"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }
}

provider "google" {
  region = var.region
}

# ─── GCP Project ─────────────────────────────────────────────────────────────

resource "google_project" "this" {
  name            = var.project_name
  project_id      = var.project_id
  billing_account = var.billing_account
  deletion_policy = "DELETE"
}

# ─── Enable Vertex AI API ────────────────────────────────────────────────────

resource "google_project_service" "vertex_ai" {
  project            = google_project.this.project_id
  service            = "aiplatform.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "iam" {
  project            = google_project.this.project_id
  service            = "iam.googleapis.com"
  disable_on_destroy = false
}

# ─── Service Account (for Vertex AI from local machine) ─────────────────────

resource "google_service_account" "librechat" {
  account_id   = "librechat-sa"
  display_name = "LibreChat Local SA"
  project      = google_project.this.project_id
  depends_on   = [google_project_service.iam]
}

resource "google_project_iam_member" "vertex_ai" {
  project = google_project.this.project_id
  role    = "roles/aiplatform.user"
  member  = "serviceAccount:${google_service_account.librechat.email}"
}

# ─── SA Key (downloaded for local Docker use) ────────────────────────────────

resource "google_service_account_key" "librechat" {
  service_account_id = google_service_account.librechat.name
}

resource "local_file" "sa_key" {
  content         = base64decode(google_service_account_key.librechat.private_key)
  filename        = "${path.module}/sa-key.json"
  file_permission = "0600"
}
