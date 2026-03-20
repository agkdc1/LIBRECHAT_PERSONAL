# ─── Cloud Run Service Account ───────────────────────────────────────────────

resource "google_service_account" "cloudrun" {
  account_id   = "cloudrun-sa"
  display_name = "Cloud Run LibreChat SA"
  project      = google_project.this.project_id
  depends_on   = [google_project_service.apis["iam.googleapis.com"]]
}

resource "google_project_iam_member" "cloudrun_vertex_ai" {
  project = google_project.this.project_id
  role    = "roles/aiplatform.user"
  member  = "serviceAccount:${google_service_account.cloudrun.email}"
}

resource "google_project_iam_member" "cloudrun_secret_accessor" {
  project = google_project.this.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.cloudrun.email}"
}

# ─── Cloud Run Service ───────────────────────────────────────────────────────
#
# Ingress: all traffic (cloudflared connects via public .run.app URL)
# Auth gate is Cloudflare Access, not Cloud Run IAM.
#

resource "google_cloud_run_v2_service" "librechat" {
  name     = "librechat"
  project  = google_project.this.project_id
  location = var.region
  ingress             = "INGRESS_TRAFFIC_ALL"
  deletion_protection = false

  template {
    service_account = google_service_account.cloudrun.email

    scaling {
      min_instance_count = 0
      max_instance_count = 1 # cost control
    }

    vpc_access {
      network_interfaces {
        network    = google_compute_network.this.id
        subnetwork = google_compute_subnetwork.cloudrun.id
      }
      egress = "PRIVATE_RANGES_ONLY"
    }

    containers {
      image = "${var.region}-docker.pkg.dev/${google_project.this.project_id}/${google_artifact_registry_repository.ghcr.repository_id}/danny-avila/librechat-dev:latest"

      # Write config file from base64 env var, then start the app
      command = ["/bin/sh", "-c"]
      args    = ["printf '%s' \"$LIBRECHAT_YAML_B64\" | base64 -d > /app/librechat.yaml && exec npm run backend"]

      ports {
        container_port = 3080
      }

      # ── Config file (base64-encoded) ──

      env {
        name  = "LIBRECHAT_YAML_B64"
        value = base64encode(file("${path.module}/librechat.yaml"))
      }

      # ── App settings ──

      env {
        name  = "HOST"
        value = "0.0.0.0"
      }

      env {
        name  = "ALLOW_REGISTRATION"
        value = "false"
      }

      env {
        name  = "ALLOW_SOCIAL_LOGIN"
        value = "false"
      }

      # Vertex AI: use Application Default Credentials from the Cloud Run SA
      env {
        name  = "GOOGLE_KEY"
        value = "user_provided"
      }

      # Domain URLs (sensitive var, not in git — only in tfvars + GCP runtime)
      env {
        name  = "DOMAIN_CLIENT"
        value = "https://${var.custom_domain}"
      }

      env {
        name  = "DOMAIN_SERVER"
        value = "https://${var.custom_domain}"
      }

      # ── Secrets from Secret Manager ──

      env {
        name = "MONGO_URI"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.mongodb_uri.secret_id
            version = "latest"
          }
        }
      }

      env {
        name = "CREDS_KEY"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.creds_key.secret_id
            version = "latest"
          }
        }
      }

      env {
        name = "CREDS_IV"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.creds_iv.secret_id
            version = "latest"
          }
        }
      }

      env {
        name = "JWT_SECRET"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.jwt_secret.secret_id
            version = "latest"
          }
        }
      }

      env {
        name = "JWT_REFRESH_SECRET"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.jwt_refresh_secret.secret_id
            version = "latest"
          }
        }
      }

      resources {
        limits = {
          cpu    = "1"
          memory = "512Mi"
        }
      }
    }
  }

  depends_on = [
    google_project_service.apis["run.googleapis.com"],
    google_secret_manager_secret_version.mongodb_uri,
    google_secret_manager_secret_version.creds_key,
    google_secret_manager_secret_version.creds_iv,
    google_secret_manager_secret_version.jwt_secret,
    google_secret_manager_secret_version.jwt_refresh_secret,
  ]
}

# Allow cloudflared (and tunnel) to invoke Cloud Run without IAM auth
resource "google_cloud_run_v2_service_iam_member" "public" {
  project  = google_project.this.project_id
  location = var.region
  name     = google_cloud_run_v2_service.librechat.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}
