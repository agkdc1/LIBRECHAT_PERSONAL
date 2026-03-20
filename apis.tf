# ─── Enable required GCP APIs ────────────────────────────────────────────────

locals {
  apis = [
    "aiplatform.googleapis.com",
    "iam.googleapis.com",
    "secretmanager.googleapis.com",
    "compute.googleapis.com",
    "run.googleapis.com",
    "storage.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "artifactregistry.googleapis.com",
  ]
}

resource "google_project_service" "apis" {
  for_each           = toset(local.apis)
  project            = google_project.this.project_id
  service            = each.value
  disable_on_destroy = false
}
