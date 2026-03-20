# ─── Artifact Registry remote repo for ghcr.io ──────────────────────────────
#
# Cloud Run can't pull from ghcr.io directly. This remote repository proxies
# and caches images from GitHub Container Registry.
#

resource "google_artifact_registry_repository" "ghcr" {
  repository_id = "ghcr"
  project       = google_project.this.project_id
  location      = var.region
  format        = "DOCKER"
  mode          = "REMOTE_REPOSITORY"

  remote_repository_config {
    docker_repository {
      custom_repository {
        uri = "https://ghcr.io"
      }
    }
  }

  depends_on = [google_project_service.apis["artifactregistry.googleapis.com"]]
}
